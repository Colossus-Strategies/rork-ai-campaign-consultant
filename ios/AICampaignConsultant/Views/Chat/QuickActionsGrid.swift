//
//  QuickActionsGrid.swift
//  AICampaignConsultant
//

import SwiftUI

struct QuickAction: Identifiable, Hashable {
    let id: String
    let emoji: String
    let label: String
    let prompt: String

    static let all: [QuickAction] = [
        .init(id: "plan", emoji: "📋", label: "Campaign Planning",
              prompt: "I need help with campaign planning — building a timeline, setting goals, and creating a winning strategy."),
        .init(id: "fund", emoji: "💰", label: "Fundraising Coach",
              prompt: "I need fundraising coaching — help with call scripts, donor outreach, and email templates."),
        .init(id: "voter", emoji: "🗳", label: "Voter Contact",
              prompt: "I need a voter contact strategy — canvassing, phone banking, texting, and GOTV plans."),
        .init(id: "msg", emoji: "📣", label: "Messaging",
              prompt: "I need help with messaging and communications — speeches, press releases, and social media."),
        .init(id: "debate", emoji: "🛡", label: "Debate Prep",
              prompt: "I need debate and message prep — practice answers, talking points, and attack defense."),
        .init(id: "vol", emoji: "👥", label: "Volunteer Training",
              prompt: "I need help with volunteer training and management."),
    ]
}

struct QuickActionsGrid: View {
    let onTap: (QuickAction) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(QuickAction.all) { action in
                Button {
                    Haptics.tap()
                    onTap(action)
                } label: {
                    HStack(spacing: 10) {
                        Text(action.emoji).font(.system(size: 20))
                        Text(action.label)
                            .font(Theme.sans(13, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
                    .background(Theme.surface.opacity(0.85))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Theme.goldFaint, lineWidth: 1)
                    )
                    .clipShape(.rect(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
