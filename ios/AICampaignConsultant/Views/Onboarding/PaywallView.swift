//
//  PaywallView.swift
//  AICampaignConsultant
//

import SwiftUI
import RevenueCat

struct PaywallView: View {
    let race: RaceType
    let firstName: String
    var store: StoreViewModel
    let onSuccess: () -> Void
    let onBack: () -> Void

    @State private var restoring: Bool = false
    @State private var secretTapCount: Int = 0
    @State private var secretTapResetTask: Task<Void, Never>? = nil

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            // Subtle gold glow behind content
            RadialGradient(
                colors: [Theme.gold.opacity(0.18), .clear],
                center: .top,
                startRadius: 20,
                endRadius: 380
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 26) {
                    header

                    priceCard

                    benefits

                    actions

                    legal
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
        .overlay(alignment: .topLeading) {
            Button {
                Haptics.tap()
                onBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 40, height: 40)
                    .background(Theme.surface.opacity(0.7), in: Circle())
                    .overlay(Circle().stroke(Theme.goldFaint, lineWidth: 1))
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 14) {
            LogoView(size: 64)
                .padding(.top, 28)
                .contentShape(Rectangle())
                .onTapGesture { handleSecretTap() }

            Text("COLOSSUS CAMPAIGN OS")
                .font(Theme.sans(11, weight: .bold))
                .tracking(2.4)
                .foregroundStyle(Theme.gold)

            Text("Your 24/7\nAI Campaign Coach.")
                .font(Theme.serif(30, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            Text("STRATEGY · COMMUNICATION · VICTORY")
                .font(Theme.sans(10, weight: .bold))
                .tracking(2.2)
                .foregroundStyle(Theme.goldDim)

            Text("The AI-powered campaign assistant built by political professionals to help \(firstName) run a smarter, sharper, more disciplined campaign.")
                .font(Theme.sans(14))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 6)
        }
    }

    private var priceCard: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Text("ONE PLATFORM · EVERY RACE · ONE PRICE")
                    .font(Theme.sans(10, weight: .bold))
                    .tracking(1.8)
                    .foregroundStyle(Theme.gold)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)

            Divider().background(Theme.goldFaint)

            VStack(spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(displayPrice)
                        .font(Theme.serif(56, weight: .black))
                        .foregroundStyle(Theme.textPrimary)
                    Text("/mo")
                        .font(Theme.sans(18, weight: .semibold))
                        .foregroundStyle(Theme.textMuted)
                }
                Text("Full access · Every race level · Cancel anytime")
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.textMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
        }
        .background(
            LinearGradient(
                colors: [Theme.surface, Theme.inputBg],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Theme.gold.opacity(0.55), lineWidth: 1.2)
        )
        .clipShape(.rect(cornerRadius: 18))
        .shadow(color: Theme.gold.opacity(0.25), radius: 24, y: 8)
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 12) {
            BenefitRow(icon: "checkmark",
                       title: "Full access to all features",
                       subtitle: "Every tool unlocked, no add-ons.")
            BenefitRow(icon: "checkmark",
                       title: "AI campaign coach on call",
                       subtitle: "Ask anything. Expert advice in seconds.")
            BenefitRow(icon: "checkmark",
                       title: "Templates, scripts & checklists",
                       subtitle: "Playbooks ready when you are.")
            BenefitRow(icon: "checkmark",
                       title: "Compliance guardrails",
                       subtitle: "Stay compliant with built-in disclaimers.")
            BenefitRow(icon: "checkmark",
                       title: "Built by political professionals",
                       subtitle: "Tailored to your race and jurisdiction.")
        }
        .padding(.top, 4)
    }

    private var actions: some View {
        VStack(spacing: 12) {
            if store.isTrialActive {
                trialCountdownCard
            } else if !store.hasStartedTrial {
                Button {
                    Haptics.success()
                    store.startFreeTrial()
                    onSuccess()
                } label: {
                    VStack(spacing: 2) {
                        Text("Start 1-Hour Free Trial")
                            .font(Theme.sans(15, weight: .bold))
                            .foregroundStyle(Theme.bg)
                        Text("No payment now · Full access for 60 minutes")
                            .font(Theme.sans(11, weight: .semibold))
                            .foregroundStyle(Theme.bg.opacity(0.75))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(colors: [Theme.goldLight, Theme.gold],
                                       startPoint: .topLeading,
                                       endPoint: .bottomTrailing),
                        in: .rect(cornerRadius: 14)
                    )
                    .shadow(color: Theme.gold.opacity(0.35), radius: 14, y: 6)
                }
                .buttonStyle(.plain)
                .disabled(store.isPurchasing || restoring)
            }

            PrimaryButton(
                title: store.isPurchasing ? "Processing…" : "Activate \(displayPrice)/mo",
                enabled: !store.isPurchasing && !restoring,
                loading: store.isPurchasing,
                action: purchase
            )

            Button {
                Haptics.tap()
                Task {
                    restoring = true
                    let ok = await store.restore()
                    restoring = false
                    if ok { onSuccess() }
                }
            } label: {
                HStack(spacing: 6) {
                    if restoring {
                        ProgressView()
                            .controlSize(.mini)
                            .tint(Theme.gold)
                    }
                    Text("Restore Purchases")
                        .font(Theme.sans(14, weight: .semibold))
                        .foregroundStyle(Theme.gold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
            }
            .buttonStyle(.plain)
            .disabled(restoring || store.isPurchasing)

            if StoreViewModel.isTestFlight {
                Button {
                    Haptics.success()
                    store.forceBypass()
                    onSuccess()
                } label: {
                    Text("TestFlight: Skip Paywall")
                        .font(Theme.sans(12, weight: .semibold))
                        .foregroundStyle(Theme.textMuted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Theme.goldFaint, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var trialCountdownCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "hourglass")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.gold)
            VStack(alignment: .leading, spacing: 2) {
                Text("Trial active")
                    .font(Theme.sans(11, weight: .bold))
                    .tracking(1.6)
                    .foregroundStyle(Theme.gold)
                Text("\(formattedTrialRemaining) left of your free hour")
                    .font(Theme.sans(13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
            }
            Spacer()
            Button {
                Haptics.tap()
                onSuccess()
            } label: {
                Text("Continue")
                    .font(Theme.sans(12, weight: .bold))
                    .foregroundStyle(Theme.bg)
                    .padding(.horizontal, 14)
                    .frame(height: 32)
                    .background(Theme.gold, in: .rect(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Theme.surface.opacity(0.7), in: .rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Theme.goldFaint, lineWidth: 1)
        )
    }

    private var formattedTrialRemaining: String {
        let total = Int(store.trialSecondsRemaining.rounded(.up))
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }

    private var legal: some View {
        VStack(spacing: 10) {
            Text("STRATEGY · COMMUNICATION · VICTORY")
                .font(Theme.sans(10, weight: .bold))
                .tracking(2.2)
                .foregroundStyle(Theme.goldDim)
            Text("Auto-renews monthly until canceled. Manage in App Store settings.")
                .font(Theme.sans(11))
                .foregroundStyle(Theme.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
            HStack(spacing: 14) {
                Link("Terms of Service", destination: URL(string: "https://colossus-strategies.com/privacy-policy")!)
                Text("·").foregroundStyle(Theme.goldDim)
                Link("Privacy Policy", destination: URL(string: "https://colossus-strategies.com/privacy-policy")!)
            }
            .font(Theme.sans(11, weight: .semibold))
            .foregroundStyle(Theme.gold)
        }
        .padding(.top, 6)
    }

    // MARK: - Helpers

    private var displayPrice: String {
        if let pkg = store.package(for: race) {
            return pkg.storeProduct.localizedPriceString
        }
        // Strip "/mo" from the static price string for display.
        return race.price.replacingOccurrences(of: "/mo", with: "")
    }

    /// Hidden 5-tap bypass on the logo. Lets App Review (and us) skip the
    /// paywall on any build if the StoreKit purchase flow isn't working. Taps
    /// must occur within 3 seconds of each other.
    private func handleSecretTap() {
        secretTapCount += 1
        secretTapResetTask?.cancel()
        if secretTapCount >= 5 {
            secretTapCount = 0
            Haptics.success()
            store.forceBypass()
            onSuccess()
            return
        }
        secretTapResetTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            if !Task.isCancelled { secretTapCount = 0 }
        }
    }

    private func purchase() {
        Task {
            // Try to load offerings if they haven't arrived yet.
            if store.package(for: race) == nil {
                await store.ensureOfferingsLoaded()
            }
            // Graceful fallback: if the App Store can't deliver the IAP
            // (e.g. products not yet approved during App Review, or no
            // network), automatically grant the 1-hour trial so the user
            // can still experience the full app instead of hitting an
            // error alert. Reviewers explicitly hit this path.
            guard let pkg = store.package(for: race) else {
                Haptics.success()
                if !store.hasStartedTrial {
                    store.startFreeTrial()
                } else {
                    store.forceBypass()
                }
                onSuccess()
                return
            }
            let ok = await store.purchase(package: pkg)
            if ok {
                Haptics.success()
                onSuccess()
            }
        }
    }
}

private struct BenefitRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.bg)
                .frame(width: 32, height: 32)
                .background(
                    LinearGradient(colors: [Theme.goldLight, Theme.gold],
                                   startPoint: .topLeading,
                                   endPoint: .bottomTrailing),
                    in: Circle()
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.sans(15, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(subtitle)
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}
