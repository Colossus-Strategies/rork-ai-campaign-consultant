//
//  MahoningVotersView.swift
//  AICampaignConsultant
//
//  "Voters" tab. Live Mahoning County stats from public.voters:
//  summary + party mix, CD/HD breakdown (all SSD-33), and a top-zip list.
//

import SwiftUI

struct MahoningVotersView: View {
    let session: SupabaseSession

    @State private var overview: MahoningOverview?
    @State private var totalInFile: Int?
    @State private var districts: [MahoningDistrictRow] = []
    @State private var zips: [MahoningZipRow] = []
    @State private var loading: Bool = true
    @State private var loadError: String?
    @State private var showDoorList: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Theme.goldFaint).frame(height: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if loading {
                        skeleton
                    } else if let err = loadError {
                        errorCard(err)
                    } else {
                        if let o = overview { summaryCard(o); partyCard(o) }
                        doorListCTA
                        districtsCard
                        zipsCard
                        footer
                    }
                }
                .padding(16)
            }
            .background(Theme.bg)
            .refreshable { await load() }
        }
        .background(Theme.bg.ignoresSafeArea())
        .task { await load() }
        .sheet(isPresented: $showDoorList) {
            DoorListBuilderView(
                session: session,
                availableZips: zips.isEmpty
                    ? MahoningVotersService.candidateZips
                    : zips.map(\.zip)
            )
        }
    }

    // MARK: - Door List CTA

    private var doorListCTA: some View {
        Button {
            showDoorList = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.bg)
                    .frame(width: 36, height: 36)
                    .background(Theme.gold)
                    .clipShape(.rect(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Build a Door List")
                        .font(Theme.sans(13, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Filter by ZIP, party & district")
                        .font(Theme.sans(11, weight: .semibold))
                        .foregroundStyle(Theme.textMuted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.gold)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface)
            .clipShape(.rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Theme.goldFaint, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "person.crop.rectangle.stack.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.gold)
                Text("VOTERS · MAHONING COUNTY")
                    .font(Theme.sans(11, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Theme.gold)
                Spacer()
            }
            Text("Live from your voter file")
                .font(Theme.serif(20, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Text("Active registrations, party mix, districts & top ZIPs")
                .font(Theme.sans(12, weight: .semibold))
                .foregroundStyle(Theme.textMuted)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
    }

    // MARK: - Loading

    private func load() async {
        loading = true
        loadError = nil
        do {
            async let o = MahoningVotersService.overview(session: session)
            async let d = MahoningVotersService.districtBreakdown(session: session)
            async let z = MahoningVotersService.zipBreakdown(session: session, topN: 10)
            async let t = MahoningVotersService.totalInFile(session: session)
            self.overview = try await o
            self.districts = try await d
            self.zips = try await z
            // Total-in-file is a nice-to-have; if it fails we still render.
            self.totalInFile = (try? await t) ?? nil
        } catch {
            self.loadError = (error as? LocalizedError)?.errorDescription
                ?? "Could not load Mahoning voter data."
        }
        loading = false
    }

    // MARK: - Summary

    private func summaryCard(_ o: MahoningOverview) -> some View {
        card {
            VStack(alignment: .leading, spacing: 6) {
                cardEyebrow("TOTAL ACTIVE VOTERS")
                Text(o.total.formatted())
                    .font(Theme.serif(40, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Mahoning County · status = ACTIVE")
                    .font(Theme.sans(11, weight: .semibold))
                    .foregroundStyle(Theme.textMuted)
                if let t = totalInFile, t > o.total {
                    Divider()
                        .background(Theme.goldFaint.opacity(0.4))
                        .padding(.vertical, 6)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("TOTAL IN FILE")
                                .font(Theme.sans(10, weight: .bold))
                                .tracking(1.5)
                                .foregroundStyle(Theme.textMuted)
                            Text("Includes inactive & confirmation")
                                .font(Theme.sans(10, weight: .semibold))
                                .foregroundStyle(Theme.textMuted)
                        }
                        Spacer()
                        Text(t.formatted())
                            .font(Theme.serif(20, weight: .bold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
        }
    }

    private func partyCard(_ o: MahoningOverview) -> some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                cardEyebrow("PARTY MIX")
                partyBar(o)
                partyRow("Democrat",    value: o.democrat,    total: o.total, color: Color(hex: 0x3b6fd1))
                partyRow("Republican",  value: o.republican,  total: o.total, color: Color(hex: 0xd14a3b))
                partyRow("Unaffiliated", value: o.unaffiliated, total: o.total, color: Theme.textMuted)
            }
        }
    }

    private func partyBar(_ o: MahoningOverview) -> some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                segment(o.democrat, total: o.total, width: geo.size.width, color: Color(hex: 0x3b6fd1))
                segment(o.republican, total: o.total, width: geo.size.width, color: Color(hex: 0xd14a3b))
                segment(o.unaffiliated, total: o.total, width: geo.size.width, color: Theme.textMuted)
            }
            .clipShape(Capsule())
        }
        .frame(height: 10)
    }

    private func segment(_ value: Int, total: Int, width: CGFloat, color: Color) -> some View {
        let frac = total > 0 ? CGFloat(value) / CGFloat(total) : 0
        return Rectangle()
            .fill(color)
            .frame(width: max(0, width * frac))
    }

    private func partyRow(_ label: String, value: Int, total: Int, color: Color) -> some View {
        let pct = total > 0 ? Double(value) / Double(total) * 100 : 0
        return HStack(spacing: 10) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(Theme.sans(12, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value.formatted())
                .font(Theme.sans(13, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Text(String(format: "%.1f%%", pct))
                .font(Theme.sans(11, weight: .semibold))
                .foregroundStyle(Theme.textMuted)
                .frame(width: 50, alignment: .trailing)
        }
    }

    // MARK: - Districts

    private var districtsCard: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                cardEyebrow("DISTRICT BREAKDOWN")
                Text("All within Ohio State Senate District 33")
                    .font(Theme.sans(11, weight: .semibold))
                    .foregroundStyle(Theme.textMuted)
                if districts.isEmpty {
                    Text("No district splits available.")
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.textMuted)
                } else {
                    let maxCount = max(1, districts.map(\.total).max() ?? 1)
                    ForEach(districts) { d in
                        districtRow(d, maxCount: maxCount)
                    }
                }
            }
        }
    }

    private func districtRow(_ d: MahoningDistrictRow, maxCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(d.label)
                    .font(Theme.sans(12, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text(d.total.formatted())
                    .font(Theme.sans(13, weight: .bold))
                    .foregroundStyle(Theme.gold)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.inputBg)
                    let frac = Double(d.total) / Double(maxCount)
                    Capsule()
                        .fill(LinearGradient(
                            colors: [Theme.goldDim, Theme.gold],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(2, geo.size.width * CGFloat(frac)))
                }
            }
            .frame(height: 8)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Zips

    private var zipsCard: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                cardEyebrow("TOP ZIPS")
                Text("Active voters by ZIP, ranked")
                    .font(Theme.sans(11, weight: .semibold))
                    .foregroundStyle(Theme.textMuted)
                zipHeaderRow
                if zips.isEmpty {
                    Text("No ZIP data yet.")
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.textMuted)
                } else {
                    ForEach(Array(zips.enumerated()), id: \.element.id) { idx, z in
                        zipRow(z)
                        if idx < zips.count - 1 {
                            Divider().background(Theme.goldFaint.opacity(0.3))
                        }
                    }
                }
            }
        }
    }

    private var zipHeaderRow: some View {
        HStack(spacing: 8) {
            Text("ZIP")
                .frame(width: 60, alignment: .leading)
            Text("Total").frame(maxWidth: .infinity, alignment: .trailing)
            Text("Dem").frame(width: 52, alignment: .trailing)
                .foregroundStyle(Color(hex: 0x3b6fd1))
            Text("Rep").frame(width: 52, alignment: .trailing)
                .foregroundStyle(Color(hex: 0xd14a3b))
            Text("Una").frame(width: 56, alignment: .trailing)
                .foregroundStyle(Theme.textMuted)
        }
        .font(Theme.sans(10, weight: .bold))
        .tracking(1.2)
        .foregroundStyle(Theme.textMuted)
        .padding(.top, 4)
    }

    private func zipRow(_ z: MahoningZipRow) -> some View {
        HStack(spacing: 8) {
            Text(z.zip)
                .font(Theme.sans(13, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 60, alignment: .leading)
            Text(z.total.formatted())
                .font(Theme.sans(13, weight: .bold))
                .foregroundStyle(Theme.gold)
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text(z.democrat.formatted())
                .font(Theme.sans(12, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 52, alignment: .trailing)
            Text(z.republican.formatted())
                .font(Theme.sans(12, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 52, alignment: .trailing)
            Text(z.unaffiliated.formatted())
                .font(Theme.sans(12, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 56, alignment: .trailing)
        }
        .padding(.vertical, 6)
    }

    // MARK: - Footer / Helpers

    private var footer: some View {
        Text("Counts pulled live from Supabase. Refresh by pulling down. Every query is audited.")
            .font(Theme.sans(10))
            .foregroundStyle(Theme.textMuted)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
    }

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

    private func cardEyebrow(_ s: String) -> some View {
        Text(s)
            .font(Theme.sans(10, weight: .bold))
            .tracking(1.8)
            .foregroundStyle(Theme.gold)
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
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Theme.goldFaint, lineWidth: 1)
                    )
            }
        }
    }
}
