//
//  HomeView.swift
//  AICampaignConsultant
//
//  Screen 07 — Home. Greeting, election countdown, suggested focus,
//  six-module grid, and "Ask the consultant" CTA.
//

import SwiftUI

struct HomeView: View {
    let profile: CandidateProfile
    let onOpenModule: (CampaignModule) -> Void
    let onOpenChat: (String?) -> Void
    let onOpenLibrary: () -> Void
    let onOpenSettings: () -> Void

    @State private var showWelcome: Bool = false
    @AppStorage("colossus.home.welcomeDismissed.v1") private var welcomeDismissed: Bool = false

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Welcome back"
        }
    }

    private var focus: DailyFocus.Focus { DailyFocus.today() }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    headerCard
                    raceBadgeRow
                    suggestedFocusCard
                    askConsultantBanner
                    modulesSectionHeader
                    modulesGrid
                    footerNote
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }

            if showWelcome { welcomeOverlay }
        }
        .onAppear {
            if !welcomeDismissed {
                withAnimation(.easeOut(duration: 0.35)) { showWelcome = true }
            }
        }
    }

    // MARK: Header

    private var headerCard: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting + ",")
                    .font(Theme.sans(13, weight: .semibold))
                    .foregroundStyle(Theme.textMuted)
                Text(profile.firstName)
                    .font(Theme.serif(28, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
            }
            Spacer()
            Button {
                Haptics.tap()
                onOpenSettings()
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 40, height: 40)
                    .background(Theme.surface)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Theme.goldFaint, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private var raceBadgeRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            RaceContextBadge(profile: profile)
            Text(profile.raceType.label.uppercased())
                .font(Theme.sans(10, weight: .bold))
                .tracking(1.8)
                .foregroundStyle(Theme.goldDim)
        }
    }

    // MARK: Focus

    private var suggestedFocusCard: some View {
        Button {
            Haptics.tap()
            if let module = ModuleLibrary.find(id: focus.moduleId) {
                onOpenModule(module)
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.gold)
                    Text("TODAY'S FOCUS")
                        .font(Theme.sans(10, weight: .bold))
                        .tracking(1.8)
                        .foregroundStyle(Theme.gold)
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.gold)
                }
                Text(focus.title)
                    .font(Theme.serif(20, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.leading)
                Text(focus.blurb)
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                LinearGradient(colors: [Theme.surface, Theme.inputBg],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Theme.gold.opacity(0.6), lineWidth: 1.5)
            )
            .clipShape(.rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private var askConsultantBanner: some View {
        Button {
            Haptics.tap()
            onOpenChat(nil)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [Theme.goldLight, Theme.gold],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 44, height: 44)
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.bg)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ask the Consultant")
                        .font(Theme.serif(16, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Race-aware answers, on call 24/7.")
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.textMuted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.goldDim)
            }
            .padding(14)
            .background(Theme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Theme.goldFaint, lineWidth: 1)
            )
            .clipShape(.rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    // MARK: Modules

    private var modulesSectionHeader: some View {
        HStack {
            Text("THE SIX MODULES")
                .font(Theme.sans(10, weight: .bold))
                .tracking(2.0)
                .foregroundStyle(Theme.goldDim)
            Spacer()
            Button {
                Haptics.tap()
                onOpenLibrary()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "books.vertical.fill")
                    Text("Library")
                }
                .font(Theme.sans(11, weight: .bold))
                .foregroundStyle(Theme.gold)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 6)
    }

    private var modulesGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(ModuleLibrary.modules) { module in
                ModuleTileView(module: module) {
                    Haptics.tap()
                    onOpenModule(module)
                }
            }
        }
    }

    private var footerNote: some View {
        Text("EDUCATE · EMPOWER · WIN")
            .font(Theme.sans(9, weight: .bold))
            .tracking(3.2)
            .foregroundStyle(Theme.goldDim)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 16)
    }

    // MARK: Welcome overlay (3-card tour)

    @State private var welcomeStep: Int = 0
    private var welcomeOverlay: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
                .onTapGesture { /* swallow taps */ }

            VStack(spacing: 18) {
                Spacer()
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Image(systemName: welcomeCardIcon)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Theme.gold)
                        Text("WELCOME ABOARD")
                            .font(Theme.sans(10, weight: .bold))
                            .tracking(2.0)
                            .foregroundStyle(Theme.gold)
                        Spacer()
                        Text("\(welcomeStep + 1) of 3")
                            .font(Theme.sans(11, weight: .bold))
                            .foregroundStyle(Theme.textMuted)
                    }
                    Text(welcomeCardTitle)
                        .font(Theme.serif(22, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(welcomeCardBody)
                        .font(Theme.sans(14))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 12) {
                        if welcomeStep > 0 {
                            Button("Back") {
                                Haptics.tap()
                                withAnimation { welcomeStep -= 1 }
                            }
                            .font(Theme.sans(14, weight: .bold))
                            .foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                        Button {
                            Haptics.tap()
                            if welcomeStep < 2 {
                                withAnimation { welcomeStep += 1 }
                            } else {
                                dismissWelcome()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(welcomeStep < 2 ? "Next" : "Let's go")
                                Image(systemName: "arrow.right")
                            }
                            .font(Theme.sans(14, weight: .bold))
                            .foregroundStyle(Theme.bg)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(
                                LinearGradient(colors: [Theme.goldLight, Theme.gold],
                                               startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
                .background(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Theme.gold.opacity(0.6), lineWidth: 1.5)
                )
                .clipShape(.rect(cornerRadius: 18))
                .padding(.horizontal, 20)
                .padding(.bottom, 40)

                Button("Skip tour") { dismissWelcome() }
                    .font(Theme.sans(12, weight: .semibold))
                    .foregroundStyle(Theme.textMuted)
                    .padding(.bottom, 12)
            }
            .transition(.opacity)
        }
    }

    private var welcomeCardIcon: String {
        ["sparkles", "rectangle.grid.2x2.fill", "bubble.left.and.bubble.right.fill"][welcomeStep]
    }
    private var welcomeCardTitle: String {
        [
            "Built for your race.",
            "Six modules. One playbook.",
            "Ask anything. Get a real answer."
        ][welcomeStep]
    }
    private var welcomeCardBody: String {
        [
            "Every answer, every checklist, every drill is tailored to your race level, jurisdiction, and timeline. That's what 'race-aware' means.",
            "Fundraising, voter contact, messaging, field, compliance, and earned media. Tap a tile to drill into bite-size training and real exercises.",
            "Tap 'Ask the Consultant' anytime. Your race context goes with every question — including a compliance check when you're near a finance rule."
        ][welcomeStep]
    }

    private func dismissWelcome() {
        Haptics.success()
        withAnimation(.easeOut(duration: 0.25)) { showWelcome = false }
        welcomeDismissed = true
    }
}
