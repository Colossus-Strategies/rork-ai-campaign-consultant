//
//  OnboardingFlow.swift
//  AICampaignConsultant
//

import SwiftUI

struct OnboardingFlow: View {
    enum Step: Int {
        case name = 1, paywall, details, account
    }

    @State private var step: Step = .name
    @State private var draft: OnboardingDraft = .init()

    // Account submit fields
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var phone: String = ""

    var store: StoreViewModel
    var auth: AuthViewModel

    var body: some View {
        ZStack {
            switch step {
            case .name:
                NameStepView(name: $draft.name, preferredName: $draft.preferredName) {
                    // Single flat tier for all candidates — no race category
                    // selection. Default the draft race so downstream code
                    // (payload submission, AI context) still has a value.
                    if draft.race == nil {
                        draft.race = RaceType.all.first
                    }
                    advance(to: .paywall)
                }
                .transition(slideTransition)

            case .paywall:
                if let race = draft.race {
                    PaywallView(
                        race: race,
                        firstName: draft.firstName,
                        store: store,
                        onSuccess: {
                            Haptics.success()
                            advance(to: .details)
                        },
                        onBack: { advance(to: .name) }
                    )
                    .transition(slideTransition)
                }

            case .details:
                DetailsStepView(
                    office: $draft.office,
                    location: $draft.location,
                    state: $draft.state,
                    district: $draft.district,
                    party: $draft.party,
                    electionDate: $draft.electionDate,
                    role: $draft.role,
                    onBack: { advance(to: .paywall) },
                    onContinue: { advance(to: .account) }
                )
                .transition(slideTransition)

            case .account:
                AccountSubmitView(
                    email: $email,
                    password: $password,
                    phone: $phone,
                    auth: auth,
                    onBack: { advance(to: .details) },
                    onSubmit: { submit() }
                )
                .transition(slideTransition)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.88), value: step)
    }

    private var slideTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    private func advance(to next: Step) {
        Haptics.tap()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            step = next
        }
    }

    private func submit() {
        Task {
            let ok = await auth.submitAccount(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password,
                phone: phone.trimmingCharacters(in: .whitespacesAndNewlines),
                draft: draft
            )
            if ok { Haptics.success() }
        }
    }
}
