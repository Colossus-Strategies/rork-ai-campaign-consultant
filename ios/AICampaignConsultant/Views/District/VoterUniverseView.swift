//
//  VoterUniverseView.swift
//  AICampaignConsultant
//
//  Filterable list of voters in the candidate's district. Tap a row for
//  full detail + vote history. Export to CSV gated by compliance ack
//  (already enforced at the parent level).
//

import SwiftUI

struct VoterUniverseView: View {
    let profile: CandidateProfile
    let session: SupabaseSession

    @State private var filters = VoterFilters()
    @State private var search: String = ""
    @State private var page: Int = 0
    @State private var rows: [VoterRow] = []
    @State private var total: Int = 0
    @State private var loading: Bool = false
    @State private var loadError: String?
    @State private var detail: VoterRow?
    @State private var showFilters: Bool = false
    @State private var showShare: Bool = false
    @State private var csvURL: URL?

    private let pageSize = 50

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            statsBar
            list
        }
        .background(Theme.bg)
        .task { await load(reset: true) }
        .sheet(isPresented: $showFilters) {
            VoterFiltersSheet(filters: $filters) {
                showFilters = false
                Task { await load(reset: true) }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $detail) { row in
            VoterDetailView(voterId: row.id, session: session)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showShare) {
            if let url = csvURL {
                ShareSheet(items: [url])
            }
        }
    }

    // MARK: - Search

    private var searchBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Theme.textMuted)
                    TextField("", text: $search, prompt: Text("Search name…").foregroundColor(Theme.textMuted))
                        .font(Theme.sans(14))
                        .foregroundStyle(Theme.textPrimary)
                        .tint(Theme.gold)
                        .submitLabel(.search)
                        .onSubmit { applySearch() }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Theme.inputBg)
                .clipShape(.rect(cornerRadius: 10))

                Button {
                    Haptics.tap()
                    showFilters = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(activeFiltersCount > 0 ? Theme.bg : Theme.gold)
                        .frame(width: 40, height: 40)
                        .background(activeFiltersCount > 0 ? Theme.gold : Theme.inputBg)
                        .clipShape(.rect(cornerRadius: 10))
                        .overlay(alignment: .topTrailing) {
                            if activeFiltersCount > 0 {
                                Text("\(activeFiltersCount)")
                                    .font(Theme.sans(9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(4)
                                    .background(Color(hex: 0xd14a3b))
                                    .clipShape(Circle())
                                    .offset(x: 4, y: -4)
                            }
                        }
                }
                .buttonStyle(.plain)

                Button {
                    Haptics.tap()
                    Task { await exportCSV() }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.gold)
                        .frame(width: 40, height: 40)
                        .background(Theme.inputBg)
                        .clipShape(.rect(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(rows.isEmpty || loading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Theme.surface)
    }

    private var statsBar: some View {
        HStack {
            Text("\(total.formatted()) voters")
                .font(Theme.sans(11, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(Theme.textMuted)
            Spacer()
            if loading {
                ProgressView().tint(Theme.gold).scaleEffect(0.7)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Theme.bg)
    }

    private var list: some View {
        Group {
            if let err = loadError {
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color(hex: 0xd14a3b))
                    Text(err).font(Theme.sans(13)).foregroundStyle(Theme.textSecondary)
                    Button("Retry") { Task { await load(reset: true) } }
                        .font(Theme.sans(12, weight: .bold))
                        .foregroundStyle(Theme.gold)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if rows.isEmpty && !loading {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(rows) { r in
                            Button {
                                Haptics.tap()
                                detail = r
                            } label: { voterRow(r) }
                                .buttonStyle(.plain)
                                .onAppear {
                                    if r == rows.last, rows.count < total {
                                        Task { await loadMore() }
                                    }
                                }
                            Divider().background(Theme.goldFaint.opacity(0.5))
                        }
                        if loading && !rows.isEmpty {
                            ProgressView().tint(Theme.gold).padding(.vertical, 12)
                        }
                    }
                }
                .refreshable { await load(reset: true) }
            }
        }
    }

    private func voterRow(_ r: VoterRow) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(partyColor(r.partyShort))
                    .frame(width: 36, height: 36)
                Text(r.partyShort)
                    .font(Theme.sans(12, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(r.fullName.isEmpty ? "—" : r.fullName)
                    .font(Theme.sans(14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                HStack(spacing: 6) {
                    if let age = r.age { Text("\(age) yrs").font(Theme.sans(11)).foregroundStyle(Theme.textMuted) }
                    if let p = r.precinct { Text("· \(p)").font(Theme.sans(11)).foregroundStyle(Theme.textMuted) }
                }
                if let addr = r.address {
                    Text(addr)
                        .font(Theme.sans(11))
                        .foregroundStyle(Theme.textMuted)
                        .lineLimit(1)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(r.turnout_score ?? 0)/5")
                    .font(Theme.sans(12, weight: .bold))
                    .foregroundStyle(Theme.gold)
                Text("turnout")
                    .font(Theme.sans(9))
                    .foregroundStyle(Theme.textMuted)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 36))
                .foregroundStyle(Theme.goldDim)
            Text("No voters match your filters")
                .font(Theme.sans(14, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Text("Adjust the filters above, or wait for the next daily ingest.")
                .font(Theme.sans(12))
                .foregroundStyle(Theme.textMuted)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Data

    private var activeFiltersCount: Int {
        var n = 0
        if filters.party != nil { n += 1 }
        if filters.status != nil { n += 1 }
        if filters.precinct != nil { n += 1 }
        if filters.ageMin != nil || filters.ageMax != nil { n += 1 }
        if filters.turnoutMin != nil || filters.turnoutMax != nil { n += 1 }
        return n
    }

    private func applySearch() {
        filters.search = search
        Task { await load(reset: true) }
    }

    private func load(reset: Bool) async {
        if reset { page = 0; rows = []; total = 0 }
        loading = true
        loadError = nil
        do {
            let p = try await VoterDataService.findVoters(
                session: session, filters: filters, page: page, pageSize: pageSize
            )
            self.total = p.total
            self.rows = reset ? p.rows : (rows + p.rows)
        } catch {
            self.loadError = (error as? LocalizedError)?.errorDescription ?? "Could not load voters."
        }
        loading = false
    }

    private func loadMore() async {
        page += 1
        await load(reset: false)
    }

    private func exportCSV() async {
        // Pull a larger slice for export — use targeting list with current filters.
        do {
            let page = try await VoterDataService.findVoters(
                session: session, filters: filters, page: 0, pageSize: 2000
            )
            let csv = VoterDataService.csv(from: page.rows)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("voters-\(Int(Date().timeIntervalSince1970)).csv")
            try csv.data(using: .utf8)?.write(to: url)
            csvURL = url
            showShare = true
        } catch {
            loadError = (error as? LocalizedError)?.errorDescription ?? "Export failed."
        }
    }

    private func partyColor(_ short: String) -> Color {
        switch short {
        case "D": return Color(hex: 0x3b6fd1)
        case "R": return Color(hex: 0xd14a3b)
        default:  return Theme.goldDim
        }
    }
}

// MARK: - Filters sheet

struct VoterFiltersSheet: View {
    @Binding var filters: VoterFilters
    var onApply: () -> Void

    @State private var party: String = ""
    @State private var status: String = ""
    @State private var precinct: String = ""
    @State private var ageMin: String = ""
    @State private var ageMax: String = ""
    @State private var turnoutMin: Double = 0
    @State private var turnoutMax: Double = 5

    var body: some View {
        NavigationStack {
            Form {
                Section("Party") {
                    Picker("Party", selection: $party) {
                        Text("Any").tag("")
                        Text("Democrat").tag("D")
                        Text("Republican").tag("R")
                        Text("Unaffiliated").tag("U")
                    }.pickerStyle(.segmented)
                }
                Section("Status") {
                    Picker("Status", selection: $status) {
                        Text("Any").tag("")
                        Text("Active").tag("ACTIVE")
                        Text("Confirmation").tag("CONFIRMATION")
                        Text("Cancelled").tag("CANCELLED")
                    }.pickerStyle(.segmented)
                }
                Section("Age range") {
                    HStack {
                        TextField("Min", text: $ageMin).keyboardType(.numberPad)
                        Text("–").foregroundStyle(.secondary)
                        TextField("Max", text: $ageMax).keyboardType(.numberPad)
                    }
                }
                Section("Turnout score (last 5 elections)") {
                    Text("\(Int(turnoutMin)) – \(Int(turnoutMax))")
                        .font(.subheadline.bold())
                    HStack {
                        Slider(value: $turnoutMin, in: 0...5, step: 1)
                        Slider(value: $turnoutMax, in: 0...5, step: 1)
                    }
                }
                Section("Precinct code") {
                    TextField("e.g. 06-A", text: $precinct)
                        .textInputAutocapitalization(.characters)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") {
                        party = ""; status = ""; precinct = ""
                        ageMin = ""; ageMax = ""
                        turnoutMin = 0; turnoutMax = 5
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Apply") {
                        filters.party = party.isEmpty ? nil : party
                        filters.status = status.isEmpty ? nil : status
                        filters.precinct = precinct.isEmpty ? nil : precinct
                        filters.ageMin = Int(ageMin)
                        filters.ageMax = Int(ageMax)
                        filters.turnoutMin = turnoutMin > 0 ? Int(turnoutMin) : nil
                        filters.turnoutMax = turnoutMax < 5 ? Int(turnoutMax) : nil
                        onApply()
                    }
                    .bold()
                }
            }
            .onAppear {
                party = filters.party ?? ""
                status = filters.status ?? ""
                precinct = filters.precinct ?? ""
                ageMin = filters.ageMin.map(String.init) ?? ""
                ageMax = filters.ageMax.map(String.init) ?? ""
                turnoutMin = Double(filters.turnoutMin ?? 0)
                turnoutMax = Double(filters.turnoutMax ?? 5)
            }
        }
    }
}

// MARK: - Share sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
