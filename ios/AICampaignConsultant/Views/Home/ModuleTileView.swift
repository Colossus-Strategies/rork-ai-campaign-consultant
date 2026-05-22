//
//  ModuleTileView.swift
//  AICampaignConsultant
//

import SwiftUI

struct ModuleTileView: View {
    let module: CampaignModule
    let onTap: () -> Void

    private var progress: Double { ProgressStore.shared.completionFraction(in: module) }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(module.accent.opacity(0.18))
                        .frame(width: 38, height: 38)
                    Image(systemName: module.symbol)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(module.accent)
                }

                Text(module.title)
                    .font(Theme.serif(15, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text(module.tagline)
                    .font(Theme.sans(11))
                    .foregroundStyle(Theme.textMuted)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 6)

                progressRow
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 150, alignment: .topLeading)
            .padding(12)
            .background(Theme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Theme.goldFaint, lineWidth: 1)
            )
            .clipShape(.rect(cornerRadius: 14))
        }
        .buttonStyle(TilePressStyle())
    }

    private var progressRow: some View {
        HStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.inputBg)
                    Capsule()
                        .fill(LinearGradient(colors: [module.accent.opacity(0.7), module.accent],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(4, geo.size.width * progress))
                }
            }
            .frame(height: 4)
            Text("\(Int(progress * 100))%")
                .font(Theme.sans(10, weight: .bold))
                .foregroundStyle(Theme.textMuted)
        }
    }
}

private struct TilePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
