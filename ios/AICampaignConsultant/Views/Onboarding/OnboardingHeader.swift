//
//  OnboardingHeader.swift
//  AICampaignConsultant
//

import SwiftUI

struct OnboardingHeader: View {
    let step: Int
    var totalSteps: Int = 4

    var body: some View {
        VStack(spacing: 14) {
            LogoView(size: 72)
                .padding(.top, 8)

            VStack(spacing: 4) {
                Text("COLOSSUS CAMPAIGN OS")
                    .font(Theme.sans(13, weight: .bold))
                    .tracking(2.4)
                    .foregroundStyle(Theme.textPrimary)
                Text("Colossus Strategies & Consulting")
                    .font(Theme.serif(13, weight: .regular))
                    .italic()
                    .foregroundStyle(Theme.gold)
            }

            ProgressSegments(total: totalSteps, current: step)
                .frame(maxWidth: 280)
                .padding(.top, 6)
        }
    }
}
