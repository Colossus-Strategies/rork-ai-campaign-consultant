//
//  CornerBrackets.swift
//  AICampaignConsultant
//

import SwiftUI

/// Faint gold corner brackets that frame onboarding content.
struct CornerBrackets: View {
    var length: CGFloat = 22
    var thickness: CGFloat = 1.5
    var color: Color = Theme.gold.opacity(0.55)
    var inset: CGFloat = 12

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                // Top-left
                bracket(rotation: 0).position(x: inset + length/2, y: inset + length/2)
                // Top-right
                bracket(rotation: 90).position(x: w - inset - length/2, y: inset + length/2)
                // Bottom-right
                bracket(rotation: 180).position(x: w - inset - length/2, y: h - inset - length/2)
                // Bottom-left
                bracket(rotation: 270).position(x: inset + length/2, y: h - inset - length/2)
            }
        }
        .allowsHitTesting(false)
    }

    private func bracket(rotation: Double) -> some View {
        ZStack {
            Rectangle()
                .fill(color)
                .frame(width: length, height: thickness)
                .offset(y: -length/2 + thickness/2)
            Rectangle()
                .fill(color)
                .frame(width: thickness, height: length)
                .offset(x: -length/2 + thickness/2)
        }
        .frame(width: length, height: length)
        .rotationEffect(.degrees(rotation))
    }
}
