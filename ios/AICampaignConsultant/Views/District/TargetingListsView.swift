//
//  TargetingListsView.swift
//  AICampaignConsultant
//
//  "Build a list" flow. Pick a goal, get a result preview, save the
//  combo as a named list, export to CSV or printable PDF walk packet.
//

import SwiftUI

struct TargetingListsView: View {
    let profile: CandidateProfile
    let session: SupabaseSession

    @State private var selectedGoal: TargetingGoal?
    @State private var customFilters = VoterFilters()
    @State private var page: VoterPage?
    @State private var building: Bool = false
    @State private var errorMsg: String?
    @State private var showShare: Bool = false
    @State private var shareItems: [Any] = []
    @State private var showCustomFilters: Bool = false

    // Saved lists
    @State private var store = SavedListsStore.shared
    @State private var activeSavedListId: String? = nil
    @State private var showSaveDialog: Bool = false
    @State private var pendingName: String = ""
    @State private var renamingId: String? = nil
    @State private var renamingText: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Build a List")
                    .font(Theme.serif(22, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                Text("Pick a goal and Colossus will assemble a list scoped to your district.")
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.textMuted)
                    .padding(.horizontal, 16)

                if !store.lists.isEmpty {
                    savedListsSection
                        .padding(.top, 6)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(TargetingGoal.allCases) { goal in
                        goalCard(goal)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)

                if let p = page {
                    resultsCard(p)
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
                } else if let err = errorMsg {
                    Text(err)
                        .font(Theme.sans(12))
                        .foregroundStyle(Color(hex: 0xd14a3b))
                        .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 24)
        }
        .background(Theme.bg)
        .onAppear { store.load(for: session.userId) }
        .sheet(isPresented: $showCustomFilters) {
            VoterFiltersSheet(filters: $customFilters) {
                showCustomFilters = false
                Task { await build(goal: .custom, filters: customFilters) }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showShare) {
            ShareSheet(items: shareItems)
        }
        .alert("Name this list", isPresented: $showSaveDialog) {
            TextField("e.g. Knock list — Ward 6", text: $pendingName)
            Button("Save") { performSave() }
            Button("Cancel", role: .cancel) { pendingName = "" }
        } message: {
            Text("Saved lists keep your goal + filters so you can re-run them with one tap.")
        }
        .alert("Rename list", isPresented: Binding(
            get: { renamingId != nil },
            set: { if !$0 { renamingId = nil; renamingText = "" } }
        )) {
            TextField("List name", text: $renamingText)
            Button("Save") {
                if let id = renamingId {
                    store.rename(id: id, to: renamingText)
                }
                renamingId = nil
                renamingText = ""
            }
            Button("Cancel", role: .cancel) {
                renamingId = nil
                renamingText = ""
            }
        }
    }

    // MARK: - Saved lists

    private var savedListsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("SAVED LISTS")
                    .font(Theme.sans(10, weight: .bold))
                    .tracking(1.6)
                    .foregroundStyle(Theme.gold)
                Spacer()
                Text("\(store.lists.count)")
                    .font(Theme.sans(10, weight: .bold))
                    .foregroundStyle(Theme.textMuted)
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(store.lists) { list in
                        savedListChip(list)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 2)
            }
        }
    }

    private func savedListChip(_ list: SavedList) -> some View {
        let isActive = activeSavedListId == list.id
        return Menu {
            Button {
                Haptics.tap()
                runSaved(list)
            } label: {
                Label("Run list", systemImage: "play.fill")
            }
            Button {
                renamingId = list.id
                renamingText = list.name
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            Button(role: .destructive) {
                Haptics.tap()
                store.delete(id: list.id)
                if activeSavedListId == list.id { activeSavedListId = nil }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: list.goal.icon)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(isActive ? Theme.bg : Theme.gold)
                    Text(list.name)
                        .font(Theme.sans(12, weight: .bold))
                        .foregroundStyle(isActive ? Theme.bg : Theme.textPrimary)
                        .lineLimit(1)
                }
                HStack(spacing: 6) {
                    if let n = list.lastCount {
                        Text("\(n.formatted()) voters")
                            .font(Theme.sans(10))
                            .foregroundStyle(isActive ? Theme.bg.opacity(0.7) : Theme.textMuted)
                    }
                    Text(relativeDate(list.updatedAt))
                        .font(Theme.sans(10))
                        .foregroundStyle(isActive ? Theme.bg.opacity(0.7) : Theme.textMuted)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: 220, alignment: .leading)
            .background(isActive ? Theme.gold : Theme.surface)
            .clipShape(.rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isActive ? Theme.gold : Theme.goldFaint, lineWidth: 1)
            )
        } primaryAction: {
            Haptics.tap()
            runSaved(list)
        }
    }

    private func runSaved(_ list: SavedList) {
        activeSavedListId = list.id
        selectedGoal = list.goal
        let filters = list.filters.toFilters()
        if list.goal == .custom {
            customFilters = filters
        }
        Task {
            await build(goal: list.goal, filters: filters, savedId: list.id)
        }
    }

    private func relativeDate(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - Goal cards

    private func goalCard(_ goal: TargetingGoal) -> some View {
        let isActive = selectedGoal == goal && activeSavedListId == nil
        return Button {
            Haptics.tap()
            activeSavedListId = nil
            selectedGoal = goal
            if goal == .custom {
                showCustomFilters = true
            } else {
                Task { await build(goal: goal, filters: VoterFilters()) }
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: goal.icon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(isActive ? Theme.bg : Theme.gold)
                Text(goal.label)
                    .font(Theme.sans(13, weight: .bold))
                    .foregroundStyle(isActive ? Theme.bg : Theme.textPrimary)
                Text(goal.subtitle)
                    .font(Theme.sans(10))
                    .foregroundStyle(isActive ? Theme.bg.opacity(0.7) : Theme.textMuted)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isActive ? Theme.gold : Theme.surface)
            .clipShape(.rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isActive ? Theme.gold : Theme.goldFaint, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Results

    private func resultsCard(_ p: VoterPage) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("LIST PREVIEW")
                    .font(Theme.sans(10, weight: .bold))
                    .tracking(1.6)
                    .foregroundStyle(Theme.gold)
                Spacer()
                Text("\(p.total.formatted()) matches")
                    .font(Theme.sans(11, weight: .bold))
                    .foregroundStyle(Theme.textMuted)
            }

            if p.rows.isEmpty {
                Text("No voters matched. Try a wider goal or adjust filters.")
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.textMuted)
            } else {
                ForEach(p.rows.prefix(8)) { r in
                    HStack {
                        Text(r.fullName)
                            .font(Theme.sans(13, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Text(r.precinct ?? "—")
                            .font(Theme.sans(11))
                            .foregroundStyle(Theme.textMuted)
                        Text("\(r.turnout_score ?? 0)/5")
                            .font(Theme.sans(11, weight: .bold))
                            .foregroundStyle(Theme.gold)
                            .frame(width: 36, alignment: .trailing)
                    }
                    .padding(.vertical, 4)
                }
                if p.rows.count > 8 {
                    Text("+ \(p.rows.count - 8) more in the list")
                        .font(Theme.sans(11))
                        .foregroundStyle(Theme.textMuted)
                }
            }

            actionRow(rows: p.rows)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14).stroke(Theme.goldFaint, lineWidth: 1)
        )
        .overlay {
            if building {
                ProgressView().tint(Theme.gold)
            }
        }
    }

    @ViewBuilder
    private func actionRow(rows: [VoterRow]) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    Haptics.tap()
                    exportCSV(rows: rows)
                } label: {
                    Label("CSV", systemImage: "tablecells")
                        .font(Theme.sans(12, weight: .bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Theme.gold)
                        .foregroundStyle(Theme.bg)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    Haptics.tap()
                    exportWalkPacket(rows: rows)
                } label: {
                    Label("Walk Packet PDF", systemImage: "doc.text.fill")
                        .font(Theme.sans(12, weight: .bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Theme.inputBg)
                        .foregroundStyle(Theme.gold)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Theme.goldFaint, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(rows.isEmpty)

                Spacer()
            }

            HStack(spacing: 8) {
                if activeSavedListId == nil {
                    Button {
                        Haptics.tap()
                        pendingName = defaultSaveName()
                        showSaveDialog = true
                    } label: {
                        Label("Save list", systemImage: "bookmark.fill")
                            .font(Theme.sans(12, weight: .bold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Theme.inputBg)
                            .foregroundStyle(Theme.textPrimary)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Theme.goldFaint, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(rows.isEmpty)
                } else {
                    Label("Saved", systemImage: "checkmark.seal.fill")
                        .font(Theme.sans(12, weight: .bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .foregroundStyle(Theme.online)
                }
                Spacer()
            }
        }
    }

    // MARK: - Build / save

    private func build(goal: TargetingGoal, filters: VoterFilters, savedId: String? = nil) async {
        building = true
        errorMsg = nil
        do {
            let p = try await VoterDataService.buildTargetingList(
                session: session, goal: goal, filters: filters, pageSize: 500
            )
            page = p
            if let savedId {
                store.updateCount(id: savedId, count: p.total)
            }
        } catch {
            errorMsg = (error as? LocalizedError)?.errorDescription ?? "Couldn't build list."
        }
        building = false
    }

    private func defaultSaveName() -> String {
        guard let goal = selectedGoal else { return "Targeting list" }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return "\(goal.label) — \(f.string(from: Date()))"
    }

    private func performSave() {
        guard let goal = selectedGoal, let p = page else { return }
        let name = pendingName.trimmingCharacters(in: .whitespacesAndNewlines)
        let filters = goal == .custom ? customFilters : VoterFilters()
        let list = store.save(
            name: name.isEmpty ? defaultSaveName() : name,
            goal: goal,
            filters: filters,
            lastCount: p.total
        )
        activeSavedListId = list.id
        pendingName = ""
    }

    // MARK: - Exports

    private func exportCSV(rows: [VoterRow]) {
        let csv = VoterDataService.csv(from: rows)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("walk-list-\(Int(Date().timeIntervalSince1970)).csv")
        try? csv.data(using: .utf8)?.write(to: url)
        shareItems = [url]
        showShare = true
    }

    private func exportWalkPacket(rows: [VoterRow]) {
        let listName: String = {
            if let id = activeSavedListId, let l = store.lists.first(where: { $0.id == id }) {
                return l.name
            }
            return selectedGoal?.label ?? "Walk Packet"
        }()
        if let url = WalkPacketPDF.render(profile: profile, listName: listName, rows: rows) {
            shareItems = [url]
            showShare = true
        } else {
            errorMsg = "Couldn't generate PDF walk packet."
        }
    }
}
