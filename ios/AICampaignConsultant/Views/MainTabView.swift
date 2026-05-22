//
//  MainTabView.swift
//  AICampaignConsultant
//
//  Root navigation after approval. Hosts Home (07), Chat (10), and
//  Library (12). Settings opens as a sheet from any tab.
//

import SwiftUI

struct MainTabView: View {
    let profile: CandidateProfile
    var auth: AuthViewModel

    @State private var selection: Tab = .home
    @State private var homePath: [HomeRoute] = []
    @State private var pendingChatSeed: String? = nil
    @State private var chatResetToken: UUID = .init()
    @State private var showSettings: Bool = false
    @State private var showDeleteConfirm: Bool = false

    enum Tab: Hashable { case home, district, chat, library }

    enum HomeRoute: Hashable {
        case module(String)
        case topic(moduleId: String, topicId: String)
    }

    private var currentSession: SupabaseSession? {
        if case let .ready(session, _, _) = auth.phase { return session }
        return nil
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            content
                .padding(.bottom, 60) // reserve space for tab bar
            customTabBar
        }
        .background(Theme.bg.ignoresSafeArea())
        .sheet(isPresented: $showSettings) {
            if let session = currentSession {
                SettingsSheet(
                    auth: auth,
                    session: session,
                    onClose: { showSettings = false },
                    onDelete: { showDeleteConfirm = true }
                )
            }
        }
        .alert("Delete Account?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    _ = await auth.deleteAccount()
                    showSettings = false
                }
            }
        } message: {
            Text("This permanently deletes your account and campaign data. This cannot be undone.")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch selection {
        case .home: homeStack
        case .district: districtTab
        case .chat: chatTab
        case .library: libraryTab
        }
    }

    private var homeStack: some View {
        NavigationStack(path: $homePath) {
            HomeView(
                profile: profile,
                onOpenModule: { module in
                    homePath.append(.module(module.id))
                },
                onOpenChat: { seed in
                    pendingChatSeed = seed
                    selection = .chat
                },
                onOpenLibrary: { selection = .library },
                onOpenSettings: { showSettings = true }
            )
            .navigationBarHidden(true)
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case let .module(id):
                    if let module = ModuleLibrary.find(id: id) {
                        ModuleOverviewView(
                            module: module,
                            profile: profile,
                            onOpenTopic: { topic in
                                homePath.append(.topic(moduleId: module.id, topicId: topic.id))
                            },
                            onAskCoach: { seed in
                                pendingChatSeed = seed
                                selection = .chat
                            }
                        )
                    }
                case let .topic(moduleId, topicId):
                    if let module = ModuleLibrary.find(id: moduleId),
                       let topic = module.topics.first(where: { $0.id == topicId }) {
                        DeepDiveView(
                            module: module,
                            topic: topic,
                            profile: profile,
                            onPracticeWithCoach: { seed in
                                pendingChatSeed = seed
                                selection = .chat
                            }
                        )
                    }
                }
            }
        }
    }

    private var chatTab: some View {
        ChatView(
            profile: profile,
            auth: auth,
            seedPrompt: pendingChatSeed,
            onSeedConsumed: { pendingChatSeed = nil }
        )
        .id(chatResetToken)
    }

    @ViewBuilder
    private var districtTab: some View {
        if let session = currentSession {
            DistrictTabView(profile: profile, session: session, auth: auth)
        } else {
            VStack {
                Spacer()
                Text("Sign in to access voter data.")
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.textMuted)
                Spacer()
            }
        }
    }

    private var libraryTab: some View {
        LibraryView(
            profile: profile,
            onAskCoach: { seed in
                pendingChatSeed = seed
                selection = .chat
            }
        )
    }

    // MARK: - Custom tab bar (so Chat header stays full-bleed)

    private var customTabBar: some View {
        HStack {
            tabButton(.home, label: "Home", icon: "house.fill")
            tabButton(.district, label: "District", icon: "map.fill")
            tabButton(.chat, label: "Chat", icon: "bubble.left.and.bubble.right.fill")
            tabButton(.library, label: "Library", icon: "books.vertical.fill")
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 24)
        .background(
            Theme.surface
                .overlay(alignment: .top) {
                    Rectangle().fill(Theme.gold.opacity(0.45)).frame(height: 1)
                }
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func tabButton(_ tab: Tab, label: String, icon: String) -> some View {
        Button {
            Haptics.tap()
            if selection == tab, tab == .home, !homePath.isEmpty {
                homePath.removeLast(homePath.count)
            }
            selection = tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                Text(label)
                    .font(Theme.sans(10, weight: .bold))
                    .tracking(0.6)
            }
            .foregroundStyle(selection == tab ? Theme.gold : Theme.textMuted)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
