//
//  NameStepView.swift
//  AICampaignConsultant
//

import SwiftUI

struct NameStepView: View {
    @Binding var name: String
    @Binding var preferredName: String
    let onContinue: () -> Void

    @FocusState private var focused: Field?
    enum Field { case name, preferred }

    var body: some View {
        OnboardingScaffold(step: 1, totalSteps: 3, footer: "STRATEGY · COMMUNICATION · VICTORY") {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Let's get started.")
                        .font(Theme.serif(40, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    Text("First — who are we working with? This goes on your account and shapes every suggestion.")
                        .font(Theme.sans(14))
                        .foregroundStyle(Theme.textSecondary)
                        .lineSpacing(3)
                }

                VStack(alignment: .leading, spacing: 18) {
                    labeled("CANDIDATE NAME") {
                        GoldTextField(
                            placeholder: "e.g. Sarah Johnson",
                            text: $name,
                            submitLabel: .next,
                            onSubmit: { focused = .preferred }
                        )
                        .focused($focused, equals: .name)
                        .textContentType(.name)
                        .autocapitalization(.words)
                    }
                    labeled("PREFERRED NAME") {
                        GoldTextField(
                            placeholder: "What people call you",
                            text: $preferredName,
                            submitLabel: .go,
                            onSubmit: { if canContinue { onContinue() } }
                        )
                        .focused($focused, equals: .preferred)
                        .textContentType(.nickname)
                        .autocapitalization(.words)
                    }
                }

                Spacer(minLength: 8)

                PrimaryButton(title: "Continue   →", enabled: canContinue) {
                    onContinue()
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { focused = .name }
        }
    }

    @ViewBuilder
    private func labeled<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(Theme.sans(11, weight: .bold))
                .tracking(2.0)
                .foregroundStyle(Theme.gold)
            content()
        }
    }

    private var canContinue: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
