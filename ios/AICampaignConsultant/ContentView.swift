//
//  ContentView.swift
//  AICampaignConsultant
//

import SwiftUI

struct ContentView: View {
    @State private var auth = AuthViewModel()
    @State private var store = StoreViewModel()
    @State private var showSignIn: Bool = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            content
                .transition(.opacity)
        }
        .animation(.easeInOut(duration: 0.4), value: phaseKey)
        .onAppear { applyBypassIfPossible() }
        .onChange(of: phaseKey) { _, _ in applyBypassIfPossible() }
        .alert("Connection Error",
               isPresented: Binding(
                get: { auth.error != nil },
                set: { if !$0 { auth.error = nil } }
               )) {
            Button("OK") { auth.error = nil }
        } message: {
            Text(auth.error ?? "")
        }
        .alert("Check your inbox",
               isPresented: Binding(
                get: { auth.info != nil },
                set: { if !$0 { auth.info = nil } }
               )) {
            Button("Got it") { auth.info = nil }
        } message: {
            Text(auth.info ?? "")
        }
        .alert("Purchase Error",
               isPresented: Binding(
                get: { store.error != nil },
                set: { if !$0 { store.error = nil } }
               )) {
            Button("OK") { store.error = nil }
        } message: {
            Text(store.error ?? "")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch auth.phase {
        case .loading:
            loadingView
        case .signedOut:
            if showSignIn {
                SignInView(auth: auth, onBack: { showSignIn = false })
            } else {
                SplashSignInView(
                    onSignIn: { showSignIn = true },
                    onCreateAccount: {
                        // Drop into onboarding without yet having a session.
                        // Submission at the end creates the auth user.
                        auth.phase = .onboarding(emptySession)
                    }
                )
            }
        case .onboarding:
            OnboardingFlow(store: store, auth: auth)
        case let .awaitingApproval(session, row):
            AwaitingActivationView(auth: auth, session: session, row: row)
        case let .ready(_, _, profile):
            MainTabView(profile: profile, auth: auth, store: store)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            LogoView(size: 72)
            ProgressView()
                .tint(Theme.gold)
        }
    }

    private var phaseKey: String {
        switch auth.phase {
        case .loading: return "loading"
        case .signedOut: return showSignIn ? "signin" : "splash"
        case .onboarding: return "onboarding"
        case .awaitingApproval: return "awaiting"
        case .ready: return "ready"
        }
    }

    /// Placeholder session used when entering onboarding before auth signup.
    /// The OnboardingFlow doesn't read this session — it submits via AuthViewModel.
    private var emptySession: SupabaseSession {
        SupabaseSession(accessToken: "", refreshToken: "", userId: "", email: nil)
    }

    /// If the signed-in user matches a bypass account, unlock premium and
    /// short-circuit the paywall. Cleared on sign-out.
    private func applyBypassIfPossible() {
        switch auth.phase {
        case let .ready(session, _, _),
             let .awaitingApproval(session, _),
             let .onboarding(session):
            store.applyBypass(email: session.email)
        case .signedOut:
            store.clearBypass()
        case .loading:
            break
        }
    }
}

#Preview {
    ContentView()
}
