//
//  SignInView.swift
//  AICampaignConsultant
//

import SwiftUI

struct SignInView: View {
    var auth: AuthViewModel
    let onBack: () -> Void

    @State private var email: String = ""
    @State private var password: String = ""
    @FocusState private var focused: Field?
    enum Field { case email, password }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 24) {
                topBar
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Welcome back.")
                                .font(Theme.serif(36, weight: .bold))
                                .foregroundStyle(Theme.textPrimary)
                            Text("Sign in to continue your campaign work.")
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
                                GoldSecureField(placeholder: "••••••••",
                                                text: $password,
                                                onSubmit: { submit() })
                                .focused($focused, equals: .password)
                            }
                        }

                        PrimaryButton(
                            title: "Sign in",
                            enabled: canSubmit,
                            loading: auth.isBusy
                        ) { submit() }

                        Text("Trouble signing in? Contact support@colossus-strategies.com.")
                            .font(Theme.sans(12))
                            .foregroundStyle(Theme.textMuted)
                            .lineSpacing(2)
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 30)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { focused = .email }
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                Haptics.tap()
                onBack()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .font(Theme.sans(14, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, 12).padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            Spacer()
            LogoView(size: 36, glow: false)
            Spacer()
            Color.clear.frame(width: 60, height: 1)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
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

    private var canSubmit: Bool {
        let e = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return !e.isEmpty && password.count >= 6 && !auth.isBusy
    }

    private func submit() {
        guard canSubmit else { return }
        Task {
            await auth.signIn(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password
            )
        }
    }
}

struct GoldSecureField: View {
    let placeholder: String
    @Binding var text: String
    var onSubmit: () -> Void = {}

    var body: some View {
        SecureField("", text: $text, prompt:
                    Text(placeholder).foregroundStyle(Theme.textMuted)
        )
        .font(Theme.sans(17, weight: .regular))
        .foregroundStyle(Theme.textPrimary)
        .tint(Theme.gold)
        .submitLabel(.done)
        .onSubmit(onSubmit)
        .padding(.horizontal, 16)
        .frame(height: 54)
        .background(Theme.inputBg)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.goldFaint, lineWidth: 1)
        )
        .clipShape(.rect(cornerRadius: 12))
        .autocorrectionDisabled()
        .textContentType(.password)
    }
}
