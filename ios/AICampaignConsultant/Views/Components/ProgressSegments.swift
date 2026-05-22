//
//  ProgressSegments.swift
//  AICampaignConsultant
//

import SwiftUI

struct ProgressSegments: View {
    let total: Int
    let current: Int // 1-based, segments 1...current are active

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { i in
                let active = i < current
                Capsule()
                    .fill(active
                          ? LinearGradient(colors: [Theme.goldLight, Theme.gold],
                                           startPoint: .leading, endPoint: .trailing)
                          : LinearGradient(colors: [Theme.gold.opacity(0.18), Theme.gold.opacity(0.18)],
                                           startPoint: .leading, endPoint: .trailing))
                    .frame(height: 4)
                    .shadow(color: active ? Theme.gold.opacity(0.5) : .clear, radius: 6, y: 0)
                    .animation(.easeInOut(duration: 0.35), value: active)
            }
        }
    }
}
