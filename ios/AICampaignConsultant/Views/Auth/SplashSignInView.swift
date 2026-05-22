//
//  SplashSignInView.swift
//  AICampaignConsultant
//

import SwiftUI

struct SplashSignInView: View {
    let onSignIn: () -> Void
    let onCreateAccount: () -> Void

    @State private var glow: Bool = false

    var body: some View {
        ZStack {
            backdrop
            VStack(spacing: 24) {
                Spacer(minLength: 60)

                LogoView(size: 110)
                    .shadow(color: Theme.gold.opacity(glow ? 0.55 : 0.25), radius: glow ? 32 : 18, y: 4)
                    .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: glow)
                    .onAppear { glow = true }

                VStack(spacing: 6) {
                    Text("COLOSSUS")
                        .font(Theme.sans(22, weight: .black))
                        .tracking(6.4)
                        .foregroundStyle(Theme.textPrimary)
                    Text("CAMPAIGN OS")
                        .font(Theme.sans(13, weight: .bold))
                        .tracking(3.2)
                        .foregroundStyle(Theme.gold)
                }
                .padding(.top, 8)

                Text("Your 24/7 AI campaign coach.\nBuilt by professionals.")
                    .multilineTextAlignment(.center)
                    .font(Theme.sans(14))
                    .foregroundStyle(Theme.textSecondary)
                    .lineSpacing(3)
                    .padding(.top, 4)

                Spacer()

                VStack(spacing: 12) {
                    PrimaryButton(title: "Sign in", enabled: true, action: onSignIn)
                    OutlinedFullWidthButton(title: "Create candidate account", action: onCreateAccount)
                    Text("For candidates and their teams")
                        .font(Theme.sans(11, weight: .semibold))
                        .tracking(1.2)
                        .foregroundStyle(Theme.textMuted)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 24)

                Text("STRATEGY · COMMUNICATION · VICTORY")
                    .font(Theme.sans(10, weight: .bold))
                    .tracking(3.2)
                    .foregroundStyle(Theme.goldDim)
                    .padding(.top, 24)
                    .padding(.bottom, 16)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
    }

    private var backdrop: some View {
        ZStack {
            Theme.bg
            RadialGradient(
                colors: [Theme.gold.opacity(0.22), .clear],
                center: .center, startRadius: 10, endRadius: 380
            )
            .blendMode(.screen)
            RadialGradient(
                colors: [Theme.userBubble.opacity(0.4), .clear],
                center: .init(x: 0.85, y: 1.05),
                startRadius: 0, endRadius: 420
            )
            .blendMode(.screen)
        }
        .ignoresSafeArea()
    }
}

struct OutlinedFullWidthButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Text(title)
                .font(Theme.sans(16, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color.white.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Theme.goldFaint, lineWidth: 1)
                )
                .clipShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
