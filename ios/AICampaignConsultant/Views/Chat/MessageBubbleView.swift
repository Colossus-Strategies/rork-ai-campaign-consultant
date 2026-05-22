//
//  MessageBubbleView.swift
//  AICampaignConsultant
//

import SwiftUI

struct MessageBubbleView: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if message.role == .assistant {
                LogoView(size: 32, glow: false)
                bubble
                Spacer(minLength: 32)
            } else {
                Spacer(minLength: 32)
                bubble
                userAvatar
            }
        }
    }

    private var bubble: some View {
        let isAI = message.role == .assistant
        return Text(message.content)
            .font(Theme.sans(15))
            .foregroundStyle(Theme.textPrimary)
            .lineSpacing(4)
            .multilineTextAlignment(.leading)
            .textSelection(.enabled)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(isAI ? Theme.aiBubble : Theme.userBubble)
            .overlay(
                BubbleShape(side: isAI ? .left : .right)
                    .stroke(isAI ? Theme.goldFaint : Color.clear, lineWidth: 0.8)
            )
            .clipShape(BubbleShape(side: isAI ? .left : .right))
            .frame(maxWidth: .infinity, alignment: isAI ? .leading : .trailing)
    }

    private var userAvatar: some View {
        ZStack {
            Circle().fill(Theme.userBubble)
            Text("👤").font(.system(size: 16))
        }
        .frame(width: 32, height: 32)
        .overlay(Circle().stroke(Theme.goldFaint, lineWidth: 1))
    }
}
