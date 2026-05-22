//
//  DistrictDashboardView.swift
//  AICampaignConsultant
//
//  "My District" dashboard. Loads the materialized-view-backed RPC data
//  and renders summary cards: total voters, party donut, voter status,
//  turnout history, top precincts.
//

import SwiftUI

struct DistrictDashboardView: View {
    let profile: CandidateProfile
    let session: SupabaseSession

    @State private var summary: DistrictSummary?
    @State private var turnout: TurnoutHistory?
    @State private var topPrecincts: [PrecinctStat] = []
    @State private var ingest: IngestRunSummary?
    @State private var showIngestSheet: Bool = false
    @State private var loading: Bool = true
    @State private var loadError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if loading {
                    skeleton
                } else if let err = loadError {
                    errorCard(err)
                } else if let s = summary {
                    refreshBadge(s)
                    if let i = ingest { ingestPill(i) }
                    totalCard(s)
                    HStack(spacing: 12) {
                        partyCard(s).frame(maxWidth: .infinity)
                        statusCard(s).frame(maxWidth: .infinity)
                    }
                    turnoutCard
                    precinctsCard
                    auditFooter
                } else {
                    emptyCard
                }
            }
            .padding(16)
        }
        .background(Theme.bg)
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $showIngestSheet) {
            if let i = ingest {
                IngestStatusSheet(run: i, session: session)
            }
        }
    }

    // MARK: - Loading

    private func load() async {
        loading = true
        loadError = nil
        do {
            async let s = VoterDataService.districtSummary(session: session)
            async let t = VoterDataService.turnoutHistory(session: session, electionCount: 4)
            async let p = VoterDataService.topPrecincts(session: session, metric: "voter_count")
            self.summary = try await s
            self.turnout = try await t
            self.topPrecincts = try await p
            // Ingest status is best-effort — never fail the dashboard over it.
            self.ingest = try? await VoterDataService.ingestStatus(session: session, limit: 1).first
        } catch {
            self.loadError = (error as? LocalizedError)?.errorDescription ?? "Could not load district data."
        }
        loading = false
    }

    // MARK: - Cards

    private func refreshBadge(_ s: DistrictSummary) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Theme.gold)
            Text(refreshLabel(s.last_refresh_at))
                .font(Theme.sans(10, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(Theme.textMuted)
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Ingest pill

    private func ingestPill(_ i: IngestRunSummary) -> some View {
        let total = i.total_counties ?? 0
        let failed = i.failed_counties ?? 0
        let success = i.success_counties ?? 0
        let isHealthy = failed == 0 && total > 0
        let accent: Color = isHealthy ? Theme.online : Color(hex: 0xd14a3b)
        let icon = isHealthy ? "checkmark.seal.fill" : "exclamationmark.triangle.fill"
        let summaryText: String = {
            if total == 0 { return "NO INGEST RECORDED" }
            if failed == 0 { return "LAST INGEST \u{2022} \(success)/\(total) COUNTIES" }
            return "LAST INGEST \u{2022} \(success)/\(total) \u{2022} \(failed) FAILED"
        }()
        return Button {
            if total > 0 { showIngestSheet = true }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(accent)
                Text(summaryText)
                    .font(Theme.sans(10, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(Theme.textPrimary)
                Spacer(minLength: 0)
                if total > 0 {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.textMuted)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Theme.surface)
            .clipShape(.rect(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(accent.opacity(0.4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(total == 0)
    }

    private func refreshLabel(_ iso: String?) -> String {
        guard let iso, !iso.isEmpty else { return "AWAITING FIRST INGEST" }
        let parsers: [ISO8601DateFormatter] = {
            let a = ISO8601DateFormatter(); a.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let b = ISO8601DateFormatter(); b.formatOptions = [.withInternetDateTime]
            return [a, b]
        }()
        let date = parsers.compactMap { $0.date(from: iso) }.first
        guard let date else { return "LAST REFRESH \u{2022} \(iso.prefix(10))" }
        let now = Date()
        let delta = now.timeIntervalSince(date)
        let phrase: String
        if delta < 60 { phrase = "JUST NOW" }
        else if delta < 3600 { phrase = "\(Int(delta / 60))M AGO" }
        else if delta < 86_400 { phrase = "\(Int(delta / 3600))H AGO" }
        else {
            let days = Int(delta / 86_400)
            phrase = days == 1 ? "YESTERDAY" : "\(days)D AGO"
        }
        return "LAST REFRESH \u{2022} \(phrase)"
    }

    private func totalCard(_ s: DistrictSummary) -> some View {
        card {
            VStack(alignment: .leading, spacing: 4) {
                Text("REGISTERED VOTERS")
                    .font(Theme.sans(10, weight: .bold))
                    .tracking(1.8)
                    .foregroundStyle(Theme.gold)
                Text(s.total_voters.formatted())
                    .font(Theme.serif(40, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Active in your district scope")
                    .font(Theme.sans(11, weight: .semibold))
                    .foregroundStyle(Theme.textMuted)
            }
        }
    }

    private func partyCard(_ s: DistrictSummary) -> some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                cardTitle("PARTY MIX")
                DonutBreakdown(
                    segments: [
                        .init(label: "Dem", value: s.party.democrat, color: Color(hex: 0x3b6fd1)),
                        .init(label: "Rep", value: s.party.republican, color: Color(hex: 0xd14a3b)),
                        .init(label: "Una", value: s.party.unaffiliated, color: Theme.textMuted),
                        .init(label: "Oth", value: s.party.other, color: Theme.goldDim),
                    ]
                )
            }
        }
    }

    private func statusCard(_ s: DistrictSummary) -> some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                cardTitle("VOTER STATUS")
                statusRow("Active", s.status.active, Theme.online)
                statusRow("Confirmation", s.status.confirmation, Theme.goldDim)
                statusRow("Cancelled", s.status.cancelled, Color(hex: 0xd14a3b))
            }
        }
    }

    private func statusRow(_ label: String, _ value: Int, _ color: Color) -> some View {
        HStack {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(Theme.sans(12, weight: .semibold)).foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value.formatted()).font(Theme.sans(13, weight: .bold)).foregroundStyle(Theme.textPrimary)
        }
    }

    private var turnoutCard: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                cardTitle("TURNOUT — LAST 4 ELECTIONS")
                if let t = turnout, !(t.generals.isEmpty && t.primaries.isEmpty) {
                    chartSection(label: "General", entries: t.generals, eligible: t.eligible, color: Color(hex: 0x3b6fd1))
                    chartSection(label: "Primary", entries: t.primaries, eligible: t.eligible, color: Theme.gold)
                } else {
                    Text("No history loaded yet. Data refreshes daily from the SoS feed.")
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.textMuted)
                }
            }
        }
    }

    private func chartSection(label: String, entries: [TurnoutEntry], eligible: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(Theme.sans(10, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(Theme.textMuted)
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(entries) { e in
                    VStack(spacing: 4) {
                        let pct = eligible > 0 ? Double(e.voted) / Double(eligible) : 0
                        let height: CGFloat = max(6, CGFloat(pct) * 80)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(color)
                            .frame(height: height)
                        Text(shortDate(e.election_date))
                            .font(Theme.sans(9, weight: .semibold))
                            .foregroundStyle(Theme.textMuted)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 100, alignment: .bottom)
        }
    }

    private var precinctsCard: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                cardTitle("TOP 5 PRECINCTS BY VOTER COUNT")
                if topPrecincts.isEmpty {
                    Text("No precincts yet — awaiting next ingest.")
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.textMuted)
                } else {
                    let maxCount = max(1, topPrecincts.compactMap(\.voter_count).max() ?? 1)
                    ForEach(topPrecincts) { p in
                        HStack(spacing: 10) {
                            Text(p.precinct_code ?? "—")
                                .font(Theme.sans(12, weight: .bold))
                                .foregroundStyle(Theme.textPrimary)
                                .frame(width: 80, alignment: .leading)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Theme.inputBg)
                                    let frac = Double(p.voter_count ?? 0) / Double(maxCount)
                                    Capsule().fill(Theme.gold)
                                        .frame(width: max(2, geo.size.width * CGFloat(frac)))
                                }
                            }
                            .frame(height: 8)
                            Text((p.voter_count ?? 0).formatted())
                                .font(Theme.sans(11, weight: .bold))
                                .foregroundStyle(Theme.textSecondary)
                                .frame(width: 60, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }

    private var auditFooter: some View {
        Text("Every query you run is logged for compliance. Data refreshes daily from the Ohio Secretary of State.")
            .font(Theme.sans(10))
            .foregroundStyle(Theme.textMuted)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
    }

    // MARK: - Helpers

    private func card<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface)
            .clipShape(.rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Theme.goldFaint, lineWidth: 1)
            )
    }

    private func cardTitle(_ s: String) -> some View {
        Text(s)
            .font(Theme.sans(10, weight: .bold))
            .tracking(1.8)
            .foregroundStyle(Theme.gold)
    }

    private var emptyCard: some View {
        card {
            VStack(alignment: .leading, spacing: 6) {
                Text("Awaiting voter file ingest")
                    .font(Theme.serif(16, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Your district will populate once the daily Ohio Secretary of State snapshot is loaded by the ingest worker.")
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private func errorCard(_ msg: String) -> some View {
        card {
            VStack(alignment: .leading, spacing: 8) {
                Label("Couldn't load", systemImage: "exclamationmark.triangle.fill")
                    .font(Theme.sans(13, weight: .bold))
                    .foregroundStyle(Color(hex: 0xd14a3b))
                Text(msg).font(Theme.sans(12)).foregroundStyle(Theme.textSecondary)
                Button("Retry") { Task { await load() } }
                    .font(Theme.sans(12, weight: .bold))
                    .foregroundStyle(Theme.gold)
            }
        }
    }

    private var skeleton: some View {
        VStack(spacing: 14) {
            ForEach(0..<4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 14)
                    .fill(Theme.surface)
                    .frame(height: 110)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14).stroke(Theme.goldFaint, lineWidth: 1)
                    )
            }
        }
    }

    private func shortDate(_ iso: String) -> String {
        let inF = ISO8601DateFormatter()
        inF.formatOptions = [.withFullDate]
        if let d = inF.date(from: iso) {
            let outF = DateFormatter()
            outF.dateFormat = "MMM ''yy"
            return outF.string(from: d)
        }
        return String(iso.prefix(7))
    }
}

// MARK: - Donut

private struct DonutBreakdown: View {
    struct Segment: Identifiable {
        let id = UUID()
        let label: String
        let value: Int
        let color: Color
    }
    let segments: [Segment]

    private var total: Int { segments.map(\.value).reduce(0, +) }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().stroke(Theme.inputBg, lineWidth: 14).frame(width: 90, height: 90)
                if total > 0 {
                    let scaled = segments.map { Double($0.value) / Double(total) }
                    let cumulative: [Double] = scaled.enumerated().map { i, _ in
                        scaled.prefix(i).reduce(0, +)
                    }
                    ForEach(Array(segments.enumerated()), id: \.element.id) { i, seg in
                        Circle()
                            .trim(from: cumulative[i], to: cumulative[i] + scaled[i])
                            .stroke(seg.color, style: StrokeStyle(lineWidth: 14, lineCap: .butt))
                            .frame(width: 90, height: 90)
                            .rotationEffect(.degrees(-90))
                    }
                }
                VStack(spacing: 0) {
                    Text(total.formatted())
                        .font(Theme.sans(13, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("total")
                        .font(Theme.sans(9))
                        .foregroundStyle(Theme.textMuted)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                ForEach(segments) { seg in
                    HStack(spacing: 6) {
                        Circle().fill(seg.color).frame(width: 7, height: 7)
                        Text(seg.label)
                            .font(Theme.sans(11, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                        Text(seg.value.formatted())
                            .font(Theme.sans(11, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                    }
                }
            }
        }
    }
}
