//
//  LibraryView.swift
//  AICampaignConsultant
//
//  Screen 12 — Templates & Checklists Library. Holds Colossus-authored
//  templates plus items the candidate has saved (F07).
//

import SwiftUI

struct LibraryView: View {
    let profile: CandidateProfile
    let onAskCoach: (String) -> Void

    @State private var tab: Tab = .saved
    @State private var selectedFilter: SavedItem.Category? = nil
    @State private var detail: SavedItem? = nil
    private let store = LibraryStore.shared

    enum Tab: String, Hashable, CaseIterable {
        case saved = "Saved by you"
        case templates = "Templates"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    headerBar
                    segmented
                    if tab == .saved { filterChips }
                    content
                }
            }
            .navigationBarHidden(true)
            .sheet(item: $detail) { item in
                SavedItemDetailSheet(item: item, onClose: { detail = nil }, onAskCoach: onAskCoach)
            }
        }
    }

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("LIBRARY")
                    .font(Theme.sans(10, weight: .bold))
                    .tracking(2.0)
                    .foregroundStyle(Theme.goldDim)
                Text("Your campaign binder")
                    .font(Theme.serif(22, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
            }
            Spacer()
            RaceContextBadge(profile: profile, compact: true)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private var segmented: some View {
        HStack(spacing: 8) {
            ForEach(Tab.allCases, id: \.self) { t in
                Button {
                    Haptics.tap()
                    withAnimation(.easeInOut(duration: 0.2)) { tab = t }
                } label: {
                    Text(t.rawValue)
                        .font(Theme.sans(13, weight: .bold))
                        .foregroundStyle(tab == t ? Theme.bg : Theme.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(tab == t
                                    ? AnyShapeStyle(LinearGradient(colors: [Theme.goldLight, Theme.gold],
                                                                   startPoint: .topLeading, endPoint: .bottomTrailing))
                                    : AnyShapeStyle(Theme.surface))
                        .overlay(Capsule().stroke(tab == t ? Color.clear : Theme.goldFaint, lineWidth: 1))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(label: "All", isOn: selectedFilter == nil) { selectedFilter = nil }
                ForEach(SavedItem.Category.allCases) { c in
                    chip(label: c.rawValue, isOn: selectedFilter == c) {
                        selectedFilter = selectedFilter == c ? nil : c
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 8)
    }

    private func chip(label: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            withAnimation { action() }
        } label: {
            Text(label)
                .font(Theme.sans(11, weight: .bold))
                .foregroundStyle(isOn ? Theme.bg : Theme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isOn ? Theme.gold : Theme.surface)
                .overlay(Capsule().stroke(Theme.goldFaint, lineWidth: 1))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .saved: savedContent
        case .templates: templatesContent
        }
    }

    private var filteredItems: [SavedItem] {
        if let f = selectedFilter {
            return store.items.filter { $0.category == f }
        }
        return store.items
    }

    @ViewBuilder
    private var savedContent: some View {
        if store.items.isEmpty {
            emptyState(
                title: "No saved items yet",
                blurb: "Save anything useful from chat — a script, a press pitch, a checklist — and find it here.",
                icon: "tray.fill"
            )
        } else if filteredItems.isEmpty {
            emptyState(
                title: "Nothing in this filter",
                blurb: "Tap 'All' to see everything you've saved.",
                icon: "line.3.horizontal.decrease.circle"
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(filteredItems) { item in
                        savedRow(item)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
    }

    private func savedRow(_ item: SavedItem) -> some View {
        Button {
            Haptics.tap()
            detail = item
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(item.category.rawValue.uppercased())
                        .font(Theme.sans(9, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(Theme.gold)
                    Spacer()
                    Text(Self.dateFormatter.string(from: item.createdAt))
                        .font(Theme.sans(10, weight: .semibold))
                        .foregroundStyle(Theme.textMuted)
                }
                Text(item.name)
                    .font(Theme.serif(15, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.leading)
                Text(item.body)
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.goldFaint, lineWidth: 1))
            .clipShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                store.remove(item.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var templatesContent: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(TemplateLibrary.templates) { t in
                    Button {
                        Haptics.tap()
                        let item = SavedItem(name: t.title, category: t.category, body: t.body)
                        LibraryStore.shared.add(item)
                        detail = item
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: t.symbol)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Theme.gold)
                                Text(t.category.rawValue.uppercased())
                                    .font(Theme.sans(9, weight: .bold))
                                    .tracking(1.2)
                                    .foregroundStyle(Theme.gold)
                                Spacer()
                                Text("Tap to save")
                                    .font(Theme.sans(10, weight: .bold))
                                    .foregroundStyle(Theme.textMuted)
                            }
                            Text(t.title)
                                .font(Theme.serif(15, weight: .bold))
                                .foregroundStyle(Theme.textPrimary)
                                .multilineTextAlignment(.leading)
                            Text(t.preview)
                                .font(Theme.sans(12))
                                .foregroundStyle(Theme.textSecondary)
                                .multilineTextAlignment(.leading)
                                .lineLimit(3)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.surface)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.goldFaint, lineWidth: 1))
                        .clipShape(.rect(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private func emptyState(title: String, blurb: String, icon: String) -> some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 38, weight: .light))
                .foregroundStyle(Theme.goldDim)
            Text(title)
                .font(Theme.serif(18, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Text(blurb)
                .font(Theme.sans(13))
                .foregroundStyle(Theme.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()
}

// MARK: - Saved item detail

struct SavedItemDetailSheet: View {
    let item: SavedItem
    let onClose: () -> Void
    let onAskCoach: (String) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(item.category.rawValue.uppercased())
                        .font(Theme.sans(10, weight: .bold))
                        .tracking(1.6)
                        .foregroundStyle(Theme.gold)
                    Text(item.name)
                        .font(Theme.serif(22, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    if !item.notes.isEmpty {
                        Text(item.notes)
                            .font(Theme.sans(13))
                            .italic()
                            .foregroundStyle(Theme.textMuted)
                    }
                    Text(item.body)
                        .font(Theme.sans(15))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        Haptics.tap()
                        onAskCoach("Help me adapt this saved item to my race:\n\n\(item.body)")
                        onClose()
                    } label: {
                        HStack {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                            Text("Workshop this with the coach")
                                .font(Theme.serif(14, weight: .bold))
                            Spacer()
                            Image(systemName: "arrow.right")
                        }
                        .foregroundStyle(Theme.bg)
                        .padding(14)
                        .background(LinearGradient(colors: [Theme.goldLight, Theme.gold],
                                                   startPoint: .topLeading, endPoint: .bottomTrailing))
                        .clipShape(.rect(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
                .padding(16)
            }
            .background(Theme.bg)
            .navigationTitle("Saved")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: onClose)
                        .foregroundStyle(Theme.gold)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Theme.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Built-in templates

struct CampaignTemplate: Identifiable, Hashable {
    let id: String
    let title: String
    let category: SavedItem.Category
    let symbol: String
    let preview: String
    let body: String
}

enum TemplateLibrary {
    static let templates: [CampaignTemplate] = [
        CampaignTemplate(
            id: "t-call-script",
            title: "Call Time Script — Major Donor",
            category: .script,
            symbol: "phone.fill",
            preview: "Open warm, get to the ask in under 90 seconds, then go quiet.",
            body: """
            CALL TIME SCRIPT — MAJOR DONOR

            Open (15s):
            "Hey [name], it's [you]. Got a minute?"

            Reason (45s):
            "I'm running for [office] because [one-sentence reason that touches their values]. We just hit [milestone], and I'm calling personally because I'd be grateful for your support."

            Ask (15s):
            "Can I count on you for [max-out amount]?"
            (Then SHUT UP. Silence is your friend.)

            If yes: "Thank you — I'll text you the link right now."
            If maybe: "Totally fair. Could you commit half this week and the rest by month-end?"
            If no: "I understand. Could you do $250 to help me hit my weekly goal?"

            Close (10s):
            "Means a lot. I'll keep you in the loop."
            """
        ),
        CampaignTemplate(
            id: "t-door-pitch",
            title: "Door Pitch — 30 Seconds",
            category: .script,
            symbol: "house.fill",
            preview: "Name, office, one issue, ask for the vote. Listen 20 seconds.",
            body: """
            DOOR PITCH — 30 SECONDS

            "Hi, my name is [name]. I'm running for [office] in this district.
            I'm working hard to [one issue — make it local and concrete].
            What matters most to you and your family right now?"

            (Listen 20 seconds. Code the response 1–5.)

            Close:
            "Can the [candidate] count on your vote on [election date]?"

            Leave-behind: literature + handwritten note if 2 or 3.
            """
        ),
        CampaignTemplate(
            id: "t-press-pitch",
            title: "Press Pitch Email",
            category: .pressRelease,
            symbol: "envelope.fill",
            preview: "Three sentences. Why news, why now, why you. Plus a quote.",
            body: """
            SUBJECT: [Candidate] launches [thing] in [district] — story for [day]?

            Hi [reporter first name],

            [Candidate] is announcing [thing] tomorrow at [time/place]. It's the first [unique angle] in [district/state] this cycle, and it ties directly into the [issue] story you wrote on [date].

            Quote you can use:
            "[Single sentence — punchy, quotable, on-message.]"

            Happy to make [candidate] available on background today or for a sit-down tomorrow. Reply or text me at [cell].

            Thanks,
            [Comms director / candidate]
            """
        ),
        CampaignTemplate(
            id: "t-launch-checklist",
            title: "30-Day Launch Checklist",
            category: .checklist,
            symbol: "checklist",
            preview: "Treasurer, bank account, FEC/state filing, website, ActBlue/WinRed, kickoff.",
            body: """
            30-DAY CAMPAIGN LAUNCH CHECKLIST

            ☐ Recruit campaign treasurer (talk to compliance counsel)
            ☐ Open campaign bank account
            ☐ File statement of candidacy with FEC and/or state
            ☐ Register committee with FEC and/or state
            ☐ Reserve candidate name + domain + social handles
            ☐ Set up ActBlue or WinRed fundraising page
            ☐ Build landing page with sign-up + donate
            ☐ Draft one-sentence message
            ☐ Pick top three issues
            ☐ Compile prospect list of 200 names with ask amounts
            ☐ Schedule first 4 weeks of call time blocks (calendar lock)
            ☐ Identify three potential house-party hosts
            ☐ Build press list of 10 reporters
            ☐ Plan kickoff event with date, venue, speakers, press kit
            ☐ Order initial palm cards and yard signs
            ☐ Recruit kickoff team of 10 committed volunteers

            VERIFY all compliance items with your treasurer or counsel before filing.
            """
        ),
        CampaignTemplate(
            id: "t-gotv-plan",
            title: "GOTV Four-Day Plan",
            category: .strategy,
            symbol: "calendar",
            preview: "The ground game that wins close races.",
            body: """
            GOTV FOUR-DAY PLAN

            T-4 (Saturday): Early/absentee chase
            – Pull list of supporters who haven't returned ballots
            – Phones + texts only; no doors
            – Goal: chase the universe twice

            T-3 to T-1 (Sun–Mon): Hard 1s
            – Doors on confirmed 1s (hard yes)
            – Two passes per house; leave literature on no-answer
            – Phones: 2s (leaners) — final persuasion

            Election Day (Tuesday): PULL ops
            – Morning: text all 1s with polling location
            – Afternoon: knock 1s who haven't voted (per voter file checks)
            – Evening: final push on 1s only — no persuasion

            Body count targets (write your number):
            – Doors: ______ / day
            – Calls: ______ / day
            – Texts: ______ / day
            """
        ),
        CampaignTemplate(
            id: "t-message-pillars",
            title: "Three-Pillar Message Worksheet",
            category: .talkingPoint,
            symbol: "list.bullet.rectangle.fill",
            preview: "Pick three issues. Not five. Every comm ladders up.",
            body: """
            THREE-PILLAR MESSAGE WORKSHEET

            ONE-SENTENCE MESSAGE:
            "I'm running because ______, and I'll fight for ______."

            PILLAR 1: ______
            – Why it matters here: ______
            – One concrete proposal: ______
            – Proof point (story / data): ______

            PILLAR 2: ______
            – Why it matters here: ______
            – One concrete proposal: ______
            – Proof point: ______

            PILLAR 3: ______
            – Why it matters here: ______
            – One concrete proposal: ______
            – Proof point: ______

            BRIDGE PHRASES:
            – "That's important, and here's what it's really about…"
            – "The bigger question is…"
            – "What voters keep telling me on the doors is…"
            """
        ),
    ]
}
