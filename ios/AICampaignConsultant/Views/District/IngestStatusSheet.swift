//
//  IngestStatusSheet.swift
//  AICampaignConsultant
//
//  Shows per-county detail for the most recent voter-file ingest run.
//  Failed counties surface first with their error message.
//

import SwiftUI

struct IngestStatusSheet: View {
    let run: IngestRunSummary
    let session: SupabaseSession

    @Environment(\.dismiss) private var dismiss
    @State private var rows: [IngestCountyRow] = []
    @State private var loading: Bool = true
    @State private var loadError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    if loading {
                        ProgressView()
                            .tint(Theme.gold)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else if let err = loadError {
                        errorCard(err)
                    } else if rows.isEmpty {
                        emptyCard
                    } else {
                        if !failed.isEmpty {
                            section(title: "FAILED COUNTIES", rows: failed, accent: Color(hex: 0xd14a3b))
                        }
                        if !succeeded.isEmpty {
                            section(title: "SUCCESSFUL COUNTIES", rows: succeeded, accent: Theme.online)
                        }
                    }
                }
                .padding(16)
            }
            .background(Theme.bg)
            .navigationTitle("Ingest Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.gold)
                }
            }
            .task { await load() }
        }
    }

    private var failed: [IngestCountyRow] {
        rows.filter { ($0.status ?? "").lowercased() == "failed" }
    }
    private var succeeded: [IngestCountyRow] {
        rows.filter { ($0.status ?? "").lowercased() != "failed" }
    }

    private var header: some View {
        let total = run.total_counties ?? 0
        let failedCount = run.failed_counties ?? 0
        let success = run.success_counties ?? 0
        let voters = run.rows_upserted ?? 0
        return VStack(alignment: .leading, spacing: 10) {
            Text(runDateLabel())
                .font(Theme.sans(10, weight: .bold))
                .tracking(1.6)
                .foregroundStyle(Theme.gold)
            HStack(spacing: 14) {
                stat(label: "COUNTIES", value: "\(success)/\(total)")
                stat(label: "FAILED", value: "\(failedCount)", tint: failedCount == 0 ? Theme.textPrimary : Color(hex: 0xd14a3b))
                stat(label: "VOTERS UPSERTED", value: voters.formatted())
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14).stroke(Theme.goldFaint, lineWidth: 1)
        )
    }

    private func stat(label: String, value: String, tint: Color = Theme.textPrimary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(Theme.sans(9, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(Theme.textMuted)
            Text(value)
                .font(Theme.serif(20, weight: .bold))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func section(title: String, rows: [IngestCountyRow], accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(Theme.sans(10, weight: .bold))
                .tracking(1.6)
                .foregroundStyle(accent)
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { idx, r in
                    countyRow(r, accent: accent)
                    if idx < rows.count - 1 {
                        Divider().overlay(Theme.goldFaint)
                    }
                }
            }
            .background(Theme.surface)
            .clipShape(.rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12).stroke(Theme.goldFaint, lineWidth: 1)
            )
        }
    }

    private func countyRow(_ r: IngestCountyRow, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle().fill(accent).frame(width: 6, height: 6)
                Text(r.county ?? "—")
                    .font(Theme.sans(13, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("\((r.rows_upserted ?? 0).formatted()) rows")
                    .font(Theme.sans(11, weight: .semibold))
                    .foregroundStyle(Theme.textMuted)
            }
            if let err = r.error, !err.isEmpty {
                Text(err)
                    .font(Theme.sans(11))
                    .foregroundStyle(Color(hex: 0xd14a3b))
                    .lineLimit(3)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var emptyCard: some View {
        Text("No per-county detail available for this run.")
            .font(Theme.sans(12))
            .foregroundStyle(Theme.textMuted)
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
    }

    private func errorCard(_ msg: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Couldn't load run detail", systemImage: "exclamationmark.triangle.fill")
                .font(Theme.sans(13, weight: .bold))
                .foregroundStyle(Color(hex: 0xd14a3b))
            Text(msg).font(Theme.sans(12)).foregroundStyle(Theme.textSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: 12))
    }

    private func runDateLabel() -> String {
        let iso = run.started_at ?? ""
        let parsers: [ISO8601DateFormatter] = {
            let a = ISO8601DateFormatter(); a.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let b = ISO8601DateFormatter(); b.formatOptions = [.withInternetDateTime]
            return [a, b]
        }()
        guard let d = parsers.compactMap({ $0.date(from: iso) }).first else {
            return "RUN \(iso.prefix(16))"
        }
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy 'AT' h:mm a"
        return "RUN \u{2022} " + f.string(from: d).uppercased()
    }

    private func load() async {
        loading = true
        loadError = nil
        do {
            self.rows = try await VoterDataService.ingestRunDetail(session: session, runId: run.run_id)
        } catch {
            self.loadError = (error as? LocalizedError)?.errorDescription ?? "Could not load ingest detail."
        }
        loading = false
    }
}
