//
//  AdminApprovalsView.swift
//  AICampaignConsultant
//

import SwiftUI

struct AdminApprovalsView: View {
    let session: SupabaseSession
    let onClose: () -> Void

    @State private var rows: [ProfileRow] = []
    @State private var filter: Filter = .pending
    @State private var isLoading: Bool = false
    @State private var error: String? = nil
    @State private var workingIds: Set<String> = []

    enum Filter: String, CaseIterable, Identifiable {
        case pending = "Pending"
        case approved = "Approved"
        case all = "All"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    filterBar
                    if isLoading && rows.isEmpty {
                        loadingState
                    } else if rows.isEmpty {
                        emptyState
                    } else {
                        list
                    }
                }
            }
            .navigationTitle("Approvals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        Haptics.tap()
                        onClose()
                    }
                    .foregroundStyle(Theme.gold)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.tap()
                        Task { await load() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(Theme.gold)
                    }
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Theme.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .alert("Error",
                   isPresented: Binding(
                    get: { error != nil },
                    set: { if !$0 { error = nil } }
                   )) {
                Button("OK") { error = nil }
            } message: {
                Text(error ?? "")
            }
            .task { await load() }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Filter bar

    private var filterBar: some View {
        HStack(spacing: 8) {
            ForEach(Filter.allCases) { f in
                Button {
                    Haptics.tap()
                    filter = f
                    Task { await load() }
                } label: {
                    Text(f.rawValue)
                        .font(Theme.sans(12, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(filter == f ? Theme.bg : Theme.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(filter == f ? Theme.gold : Theme.inputBg)
                        .overlay(
                            Capsule().stroke(Theme.goldFaint, lineWidth: 1)
                        )
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            Spacer()
            if !rows.isEmpty {
                Text("\(rows.count)")
                    .font(Theme.sans(12, weight: .bold))
                    .foregroundStyle(Theme.goldDim)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.surface.opacity(0.6))
    }

    // MARK: - List

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(rows, id: \.id) { row in
                    card(for: row)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 32)
        }
        .refreshable { await load() }
    }

    private func card(for row: ProfileRow) -> some View {
        let working = workingIds.contains(row.id)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(row.candidate_name)
                        .font(Theme.serif(17, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    if let preferred = row.preferred_name, !preferred.isEmpty,
                       preferred != row.candidate_name {
                        Text("\u{201C}\(preferred)\u{201D}")
                            .font(Theme.sans(12))
                            .foregroundStyle(Theme.textMuted)
                    }
                }
                Spacer()
                statusPill(approved: row.approved)
            }

            VStack(alignment: .leading, spacing: 4) {
                detailRow(icon: "flag.fill", text: row.office ?? "—")
                detailRow(icon: "mappin.and.ellipse", text: row.location ?? "—")
                if let party = row.party, !party.isEmpty {
                    detailRow(icon: "person.2.fill", text: party)
                }
                if let phone = row.phone, !phone.isEmpty {
                    detailRow(icon: "phone.fill", text: phone)
                }
                detailRow(icon: "calendar", text: row.election_date ?? "—")
            }

            HStack(spacing: 8) {
                if row.approved {
                    Button {
                        Haptics.tap()
                        Task { await setApproved(row, approved: false) }
                    } label: {
                        actionLabel(title: working ? "…" : "Revoke",
                                    icon: "xmark.circle.fill",
                                    tint: Color.red.opacity(0.85),
                                    filled: false)
                    }
                    .buttonStyle(.plain)
                    .disabled(working)
                } else {
                    Button {
                        Haptics.success()
                        Task { await setApproved(row, approved: true) }
                    } label: {
                        actionLabel(title: working ? "Approving…" : "Approve",
                                    icon: "checkmark.seal.fill",
                                    tint: Theme.gold,
                                    filled: true)
                    }
                    .buttonStyle(.plain)
                    .disabled(working)
                }
            }
            .padding(.top, 4)
        }
        .padding(14)
        .background(Theme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Theme.goldFaint, lineWidth: 1)
        )
        .clipShape(.rect(cornerRadius: 14))
    }

    private func statusPill(approved: Bool) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(approved ? Theme.online : Theme.goldDim)
                .frame(width: 7, height: 7)
            Text(approved ? "Approved" : "Pending")
                .font(Theme.sans(10, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(approved ? Theme.online : Theme.goldDim)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background((approved ? Theme.online : Theme.goldDim).opacity(0.12))
        .clipShape(Capsule())
    }

    private func detailRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.goldDim)
                .frame(width: 14)
            Text(text)
                .font(Theme.sans(13))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
    }

    private func actionLabel(title: String, icon: String, tint: Color, filled: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
            Text(title)
                .font(Theme.sans(13, weight: .bold))
                .tracking(0.5)
        }
        .foregroundStyle(filled ? Theme.bg : tint)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity)
        .background(filled ? tint : Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(tint, lineWidth: filled ? 0 : 1)
        )
        .clipShape(.rect(cornerRadius: 10))
    }

    // MARK: - Empty/loading

    private var loadingState: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView().tint(Theme.gold)
            Text("Loading…")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.textMuted)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: filter == .pending ? "checkmark.circle.fill" : "tray")
                .font(.system(size: 38, weight: .light))
                .foregroundStyle(Theme.goldDim)
            Text(filter == .pending ? "No pending applicants" : "No profiles here yet")
                .font(Theme.serif(17, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Text(filter == .pending
                 ? "You're all caught up. New sign-ups will appear here."
                 : "Switch filters to see other profiles.")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Data

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let approvedFilter: Bool? = {
                switch filter {
                case .pending: return false
                case .approved: return true
                case .all: return nil
                }
            }()
            let result = try await SupabaseClient.adminListProfiles(
                session: session,
                approved: approvedFilter
            )
            withAnimation(.easeOut(duration: 0.2)) {
                rows = result
            }
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func setApproved(_ row: ProfileRow, approved: Bool) async {
        workingIds.insert(row.id)
        defer { workingIds.remove(row.id) }
        do {
            try await SupabaseClient.adminSetApproved(
                session: session,
                profileId: row.id,
                approved: approved
            )
            await load()
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
