//
//  RaceStepView.swift
//  AICampaignConsultant
//

import SwiftUI

struct RaceStepView: View {
    let firstName: String
    @Binding var selected: RaceType?
    let onSelect: (RaceType) -> Void

    var body: some View {
        OnboardingScaffold(step: 2, totalSteps: 4, footer: "STRATEGY · COMMUNICATION · VICTORY") {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("What office are you running for, \(firstName)?")
                        .font(Theme.serif(30, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(3)
                        .minimumScaleFactor(0.7)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("We'll tailor your experience to match your race.")
                        .font(Theme.sans(14))
                        .foregroundStyle(Theme.textSecondary)
                }

                VStack(spacing: 12) {
                    ForEach(RaceType.all) { race in
                        RaceCard(race: race, selected: selected?.id == race.id) {
                            selected = race
                            Haptics.soft()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                                onSelect(race)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct RaceCard: View {
    let race: RaceType
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text(race.emoji)
                    .font(.system(size: 26))
                    .frame(width: 40)
                VStack(alignment: .leading, spacing: 3) {
                    Text(race.label)
                        .font(Theme.sans(16, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(race.subtitle)
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.textMuted)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                Text(race.price)
                    .font(Theme.sans(12, weight: .bold))
                    .tracking(0.4)
                    .foregroundStyle(Theme.bg)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        LinearGradient(colors: [Theme.goldLight, Theme.gold],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(Capsule())
            }
            .padding(14)
            .background(selected ? Theme.gold.opacity(0.12) : Theme.surface.opacity(0.6))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(selected ? Theme.gold : Theme.goldFaint,
                            lineWidth: selected ? 1.5 : 1)
            )
            .clipShape(.rect(cornerRadius: 14))
            .shadow(color: selected ? Theme.gold.opacity(0.35) : .clear, radius: 12, y: 4)
            .animation(.easeOut(duration: 0.18), value: selected)
        }
        .buttonStyle(.plain)
    }
}
