//
//  AccountSubmitView.swift
//  AICampaignConsultant
//

import SwiftUI

struct AccountSubmitView: View {
    @Binding var email: String
    @Binding var password: String
    @Binding var phone: String

    var auth: AuthViewModel
    let onBack: () -> Void
    let onSubmit: () -> Void

    @FocusState private var focused: Field?
    enum Field { case email, password, phone }

    var body: some View {
        OnboardingScaffold(step: 3, totalSteps: 3, footer: "STRATEGY · COMMUNICATION · VICTORY") {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("One last step.")
                        .font(Theme.serif(36, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Create your login to start using your AI campaign coach.")
                        .font(Theme.sans(14))
                        .foregroundStyle(Theme.textSecondary)
                }

                VStack(alignment: .leading, spacing: 16) {
                    labeled("EMAIL") {
                        GoldTextField(placeholder: "campaign@yourdomain.com",
                                      text: $email,
                                      submitLabel: .next,
                                      onSubmit: { focused = .password })
                        .focused($focused, equals: .email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    }
                    labeled("PASSWORD") {
                        GoldSecureField(placeholder: "At least 6 characters",
                                        text: $password,
                                        onSubmit: { focused = .phone })
                        .focused($focused, equals: .password)
                    }
                    labeled("BEST PHONE TO REACH YOU") {
                        GoldTextField(placeholder: "(555) 555-5555",
                                      text: $phone,
                                      submitLabel: .done,
                                      onSubmit: { focused = nil })
                        .focused($focused, equals: .phone)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                    }
                }

                Text("By creating an account you agree to our Terms of Service and Privacy Policy.")
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.textMuted)
                    .lineSpacing(2)

                HStack(spacing: 12) {
                    OutlinedButton(title: "←  Back", action: onBack)
                    PrimaryButton(
                        title: "Create account",
                        enabled: canSubmit,
                        loading: auth.isBusy
                    ) {
                        Haptics.success()
                        onSubmit()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func labeled<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(Theme.sans(11, weight: .bold))
                .tracking(2.0)
                .foregroundStyle(Theme.gold)
            content()
        }
    }

    private var canSubmit: Bool {
        let e = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return !e.isEmpty && e.contains("@") && password.count >= 6 && !auth.isBusy
    }
}
