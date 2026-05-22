//
//  LogoView.swift
//  AICampaignConsultant
//

import SwiftUI

struct LogoView: View {
    var size: CGFloat = 48
    var glow: Bool = true

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Theme.goldLight, Theme.gold, Theme.goldDim],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Circle()
                .strokeBorder(Theme.goldLight.opacity(0.6), lineWidth: max(1, size * 0.025))
                .blendMode(.overlay)

            Text("C")
                .font(.system(size: size * 0.6, weight: .black, design: .serif))
                .foregroundStyle(Theme.bg)
                .offset(y: -size * 0.015)
        }
        .frame(width: size, height: size)
        .shadow(color: glow ? Theme.gold.opacity(0.45) : .clear,
                radius: size * 0.25, x: 0, y: 0)
    }
}

#Preview {
    LogoView(size: 96)
        .padding()
        .background(Theme.bg)
}
