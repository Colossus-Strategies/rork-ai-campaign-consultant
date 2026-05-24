//
//  DoorListBuilderView.swift
//  AICampaignConsultant
//
//  Lets a canvasser filter Mahoning active voters by zip, party, and district,
//  preview the matching count, then build a walk list ordered by zip + street.
//

import SwiftUI

struct DoorListBuilderView: View {
    let session: SupabaseSession
    let availableZips: [String]

    @Environment(\.dismiss) private var dismiss

    @State private var filter = DoorListFilter()
    @State private var matchCount: Int?
    @State private var countLoading: Bool = false
    @State private var countError: String?

    @State private var voters: [DoorListVoter] = []
    @State private var listLoading: Bool = false
    @State private var listError: String?
    @State private var didBuild: Bool = false

    private let maxResults: Int = 500

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    zipCard
                    partyCard
                    districtCard
                    countCard
                    if didBuild { resultsCard }
                }
                .padding(16)
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Door List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Theme.gold)
                }
            }
            .safeAreaInset(edge: .bottom) {
                buildBar
            }
            .task { await refreshCount() }
            .onChange(of: filter.party) { _, _ in Task { await refreshCount() } }
            .onChange(of: filter.district) { _, _ in Task { await refreshCount() } }
            .onChange(of: filter.zips) { _, _ in Task { await refreshCount() } }
        }
    }

    // MARK: - Cards

    private var zipCard: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                cardEyebrow("ZIP CODES")
                HStack {
                    Text(filter.zips.isEmpty
                         ? "All ZIPs"
                         : "\(filter.zips.count) selected")
                        .font(Theme.sans(12, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    if !filter.zips.isEmpty {
                        Button("Clear") { filter.zips.removeAll() }
                            .font(Theme.sans(11, weight: .bold))
                            .foregroundStyle(Theme.gold)
                    }
                }
                let cols = [GridItem(.adaptive(minimum: 78), spacing: 8)]
                LazyVGrid(columns: cols, spacing: 8) {
                    ForEach(availableZips, id: \.self) { zip in
                        zipChip(zip)
                    }
                }
            }
        }
    }

    private func zipChip(_ zip: String) -> some View {
        let selected = filter.zips.contains(zip)
        return Button {
            if selected { filter.zips.remove(zip) }
            else { filter.zips.insert(zip) }
        } label: {
            Text(zip)
                .font(Theme.sans(12, weight: .bold))
                .foregroundStyle(selected ? Theme.bg : Theme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(selected ? Theme.gold : Theme.inputBg)
                .clipShape(.rect(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(selected ? Theme.gold : Theme.goldFaint, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var partyCard: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                cardEyebrow("PARTY")
                segment(
                    options: DoorListParty.allCases,
                    selection: $filter.party,
                    label: { $0.label }
                )
            }
        }
    }

    private var districtCard: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                cardEyebrow("DISTRICT")
                segment(
                    options: DoorListDistrict.allCases,
                    selection: $filter.district,
                    label: { $0.label }
                )
            }
        }
    }

    private func segment<T: Hashable & Identifiable>(
        options: [T],
        selection: Binding<T>,
        label: @escaping (T) -> String
    ) -> some View {
        let cols = [GridItem(.adaptive(minimum: 90), spacing: 8)]
        return LazyVGrid(columns: cols, spacing: 8) {
            ForEach(options) { opt in
                let isSel = selection.wrappedValue == opt
                Button { selection.wrappedValue = opt } label: {
                    Text(label(opt))
                        .font(Theme.sans(12, weight: .bold))
                        .foregroundStyle(isSel ? Theme.bg : Theme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(isSel ? Theme.gold : Theme.inputBg)
                        .clipShape(.rect(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isSel ? Theme.gold : Theme.goldFaint, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var countCard: some View {
        card {
            VStack(alignment: .leading, spacing: 6) {
                cardEyebrow("MATCHING VOTERS")
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if countLoading {
                        ProgressView()
                            .tint(Theme.gold)
                    } else if let n = matchCount {
                        Text(n.formatted())
                            .font(Theme.serif(34, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                        if n > maxResults {
                            Text("· list capped at \(maxResults)")
                                .font(Theme.sans(11, weight: .semibold))
                                .foregroundStyle(Theme.textMuted)
                        }
                    } else if let err = countError {
                        Text(err)
                            .font(Theme.sans(12))
                            .foregroundStyle(Color(hex: 0xd14a3b))
                    } else {
                        Text("—")
                            .font(Theme.serif(34, weight: .bold))
                            .foregroundStyle(Theme.textMuted)
                    }
                }
                Text("Active registrations in Mahoning County")
                    .font(Theme.sans(11, weight: .semibold))
                    .foregroundStyle(Theme.textMuted)
            }
        }
    }

    private var resultsCard: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    cardEyebrow("WALK LIST")
                    Spacer()
                    if !voters.isEmpty {
                        Text("\(voters.count) voters")
                            .font(Theme.sans(11, weight: .bold))
                            .foregroundStyle(Theme.gold)
                    }
                }
                if listLoading {
                    HStack {
                        ProgressView().tint(Theme.gold)
                        Text("Building list…")
                            .font(Theme.sans(12, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
                } else if let err = listError {
                    Text(err)
                        .font(Theme.sans(12))
                        .foregroundStyle(Color(hex: 0xd14a3b))
                } else if voters.isEmpty {
                    Text("No voters match these filters.")
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.textMuted)
                } else {
                    ForEach(Array(voters.enumerated()), id: \.element.id) { idx, v in
                        voterRow(v)
                        if idx < voters.count - 1 {
                            Divider().background(Theme.goldFaint.opacity(0.3))
                        }
                    }
                }
            }
        }
    }

    private func voterRow(_ v: DoorListVoter) -> some View {
        HStack(alignment: .top, spacing: 10) {
            partyBadge(v.partyLetter)
            VStack(alignment: .leading, spacing: 2) {
                Text(v.fullName)
                    .font(Theme.sans(13, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(v.addressLine)
                    .font(Theme.sans(11, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }

    private func partyBadge(_ letter: String) -> some View {
        let color: Color = letter == "D" ? Color(hex: 0x3b6fd1)
            : letter == "R" ? Color(hex: 0xd14a3b)
            : Theme.textMuted
        return Text(letter)
            .font(Theme.sans(11, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(color)
            .clipShape(Circle())
    }

    // MARK: - Build Bar

    private var buildBar: some View {
        VStack(spacing: 0) {
            Divider().background(Theme.goldFaint)
            Button {
                Task { await build() }
            } label: {
                HStack(spacing: 8) {
                    if listLoading {
                        ProgressView().tint(Theme.bg)
                    } else {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 14, weight: .bold))
                    }
                    Text(buildButtonLabel)
                        .font(Theme.sans(13, weight: .bold))
                        .tracking(1.2)
                }
                .foregroundStyle(Theme.bg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(canBuild ? Theme.gold : Theme.gold.opacity(0.4))
                .clipShape(.rect(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(!canBuild)
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 8)
        }
        .background(Theme.surface)
    }

    private var canBuild: Bool {
        !listLoading && (matchCount ?? 0) > 0
    }

    private var buildButtonLabel: String {
        if listLoading { return "BUILDING…" }
        guard let n = matchCount else { return "BUILD DOOR LIST" }
        let take = min(n, maxResults)
        return "BUILD DOOR LIST · \(take.formatted())"
    }

    // MARK: - Loading

    private func refreshCount() async {
        countLoading = true
        countError = nil
        let snapshot = filter
        do {
            let n = try await MahoningVotersService.doorListCount(
                session: session, filter: snapshot
            )
            // Drop stale results if the filter changed mid-flight.
            if snapshot.party == filter.party
                && snapshot.district == filter.district
                && snapshot.zips == filter.zips {
                matchCount = n
            }
        } catch {
            countError = (error as? LocalizedError)?.errorDescription
                ?? "Couldn't count voters."
            matchCount = nil
        }
        countLoading = false
    }

    private func build() async {
        listLoading = true
        listError = nil
        didBuild = true
        do {
            voters = try await MahoningVotersService.doorList(
                session: session, filter: filter, limit: maxResults
            )
        } catch {
            voters = []
            listError = (error as? LocalizedError)?.errorDescription
                ?? "Couldn't build the door list."
        }
        listLoading = false
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

    private func cardEyebrow(_ s: String) -> some View {
        Text(s)
            .font(Theme.sans(10, weight: .bold))
            .tracking(1.8)
            .foregroundStyle(Theme.gold)
    }
}
