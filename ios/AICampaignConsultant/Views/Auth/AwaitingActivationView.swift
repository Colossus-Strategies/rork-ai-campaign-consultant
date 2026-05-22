//
//  AwaitingActivationView.swift
//  AICampaignConsultant
//

import SwiftUI

struct AwaitingActivationView: View {
    var auth: AuthViewModel
    let session: SupabaseSession
    let row: ProfileRow

    @State private var pulse: Bool = false
    @State private var refreshing: Bool = false
    @State private var autoChecking: Bool = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            backdrop
            VStack(spacing: 22) {
                header
                hourglass
                titleBlock
                whileYouWaitCard
                Spacer(minLength: 8)
                VStack(spacing: 8) {
                    OutlinedFullWidthButton(title: (refreshing || autoChecking) ? "Checking…" : "Check status") {
                        Task {
                            refreshing = true
                            await auth.refreshProfile(session: session)
                            refreshing = false
                        }
                    }
                    Text("Auto-checking every 30 seconds")
                        .font(Theme.sans(11, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(Theme.textMuted)
                }
                .padding(.horizontal, 24)
                Button {
                    Haptics.tap()
                    Task { await auth.signOut() }
                } label: {
                    Text("Sign out")
                        .font(Theme.sans(13, weight: .semibold))
                        .foregroundStyle(Theme.textMuted)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 16)
            }
            .padding(.top, 24)
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                if Task.isCancelled { break }
                autoChecking = true
                await auth.refreshProfile(session: session)
                autoChecking = false
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            LogoView(size: 36, glow: false)
            VStack(alignment: .leading, spacing: 2) {
                Text("COLOSSUS CAMPAIGN OS")
                    .font(Theme.sans(12, weight: .bold))
                    .tracking(1.6)
                    .foregroundStyle(Theme.textPrimary)
                Text("Colossus Strategies & Consulting")
                    .font(Theme.serif(11, weight: .regular))
                    .italic()
                    .foregroundStyle(Theme.gold)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private var hourglass: some View {
        ZStack {
            Circle()
                .stroke(Theme.gold.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [4, 6]))
                .frame(width: 130, height: 130)
                .rotationEffect(.degrees(pulse ? 360 : 0))
                .animation(.linear(duration: 18).repeatForever(autoreverses: false), value: pulse)
            Image(systemName: "hourglass")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Theme.gold)
                .scaleEffect(pulse ? 1.06 : 1.0)
                .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: pulse)
        }
        .padding(.top, 6)
        .onAppear { pulse = true }
    }

    private var titleBlock: some View {
        VStack(spacing: 10) {
            Text("Submission received.")
                .font(Theme.serif(28, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Text("Colossus is reviewing your application, \(row.preferred_name?.isEmpty == false ? row.preferred_name! : firstNameFromFull). You'll get an email the moment your account is activated — usually within one business day.")
                .multilineTextAlignment(.center)
                .font(Theme.sans(14))
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(3)
                .padding(.horizontal, 30)
        }
    }

    private var whileYouWaitCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("WHILE YOU WAIT")
                .font(Theme.sans(11, weight: .bold))
                .tracking(2.0)
                .foregroundStyle(Theme.gold)
            row(icon: "phone.fill",
                title: "Talk to Colossus",
                subtitle: "anthony@colossus-strategies.com")
            row(icon: "doc.text.fill",
                title: "Day-1 candidate checklist",
                subtitle: "Free preview · 4 min read")
        }
        .padding(16)
        .background(Theme.surface.opacity(0.7))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Theme.goldFaint, lineWidth: 1)
        )
        .clipShape(.rect(cornerRadius: 14))
        .padding(.horizontal, 24)
    }

    private func row(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.gold)
                .frame(width: 32, height: 32)
                .background(Theme.inputBg)
                .clipShape(.rect(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.sans(14, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(subtitle)
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.textMuted)
            }
            Spacer()
        }
    }

    private var firstNameFromFull: String {
        row.candidate_name.split(separator: " ").first.map(String.init) ?? row.candidate_name
    }

    private var backdrop: some View {
        RadialGradient(
            colors: [Theme.gold.opacity(0.15), .clear],
            center: .init(x: 0.5, y: 0.18),
            startRadius: 10, endRadius: 320
        )
        .blendMode(.screen)
        .ignoresSafeArea()
    }
}
