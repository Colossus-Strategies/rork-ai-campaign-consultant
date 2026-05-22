//
//  Theme.swift
//  AICampaignConsultant
//

import SwiftUI
import UIKit

enum Theme {
    // Backgrounds
    static let bg = Color(hex: 0x0a1628)
    static let surface = Color(hex: 0x0f1f3d)
    static let inputBg = Color(hex: 0x162444)
    static let aiBubble = Color(hex: 0x1a2e50)
    static let userBubble = Color(hex: 0x1e4a8a)

    // Accents
    static let gold = Color(hex: 0xc9a84c)
    static let goldLight = Color(hex: 0xe4c06e)
    static let goldDim = Color(hex: 0xa07830)
    static let goldFaint = Color(red: 201/255, green: 168/255, blue: 76/255, opacity: 0.25)

    // Text
    static let textPrimary = Color(hex: 0xf5f0e8)
    static let textSecondary = Color(hex: 0xd4dae6)
    static let textMuted = Color(hex: 0x8a9ab5)

    // Status
    static let online = Color(hex: 0x4caf6e)

    // Fonts — system serif keeps things crisp without bundling files.
    static func serif(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, opacity: opacity)
    }
}

enum Haptics {
    static func tap() {
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.impactOccurred()
    }
    static func soft() {
        let gen = UIImpactFeedbackGenerator(style: .soft)
        gen.impactOccurred()
    }
    static func success() {
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)
    }
}
