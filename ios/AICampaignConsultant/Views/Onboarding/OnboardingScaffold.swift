//
//  OnboardingScaffold.swift
//  AICampaignConsultant
//

import SwiftUI

struct OnboardingScaffold<Content: View>: View {
    let step: Int
    var totalSteps: Int = 4
    let footer: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            backdrop
            CornerBrackets()
                .padding(.horizontal, 12)
                .padding(.vertical, 80)

            VStack(spacing: 28) {
                OnboardingHeader(step: step, totalSteps: totalSteps)
                    .padding(.top, 8)

                ScrollView(showsIndicators: false) {
                    content()
                        .padding(.horizontal, 24)
                        .padding(.top, 4)
                        .padding(.bottom, 30)
                }

                Text(footer)
                    .font(Theme.sans(10, weight: .bold))
                    .tracking(3.2)
                    .foregroundStyle(Theme.goldDim)
                    .padding(.bottom, 8)
            }
            .padding(.top, 16)
        }
        .background(Theme.bg.ignoresSafeArea())
    }

    private var backdrop: some View {
        ZStack {
            Theme.bg
            RadialGradient(
                colors: [Theme.gold.opacity(0.18), .clear],
                center: .init(x: 0.5, y: 0.0),
                startRadius: 10, endRadius: 360
            )
            .blendMode(.screen)
            RadialGradient(
                colors: [Theme.userBubble.opacity(0.35), .clear],
                center: .init(x: 0.85, y: 1.05),
                startRadius: 0, endRadius: 420
            )
            .blendMode(.screen)
        }
        .ignoresSafeArea()
    }
}
