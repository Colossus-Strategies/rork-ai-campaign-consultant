//
//  VoterComplianceModal.swift
//  AICampaignConsultant
//
//  One-time use agreement shown before any voter-data screen unlocks.
//  Persists the acknowledgment to candidate_profiles.voter_data_ack_at.
//

import SwiftUI

struct VoterComplianceModal: View {
    let stateName: String
    let notice: String
    let onAcknowledge: () async -> Void
    let onCancel: () -> Void

    @State private var checked: Bool = false
    @State private var submitting: Bool = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    Text("\(stateName) Voter Data Use Agreement")
                        .font(Theme.serif(22, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)

                    Text(notice)
                        .font(Theme.sans(14))
                        .foregroundStyle(Theme.textSecondary)
                        .lineSpacing(4)

                    Divider().background(Theme.goldFaint)

                    rulesList

                    Button {
                        Haptics.tap()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { checked.toggle() }
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(checked ? Theme.gold : Theme.goldFaint, lineWidth: 1.5)
                                    .frame(width: 24, height: 24)
                                if checked {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(Theme.gold)
                                }
                            }
                            Text("I acknowledge these terms and will use \(stateName) voter data solely for my declared campaign. I will not redistribute, resell, or use it for any commercial solicitation.")
                                .font(Theme.sans(13, weight: .medium))
                                .foregroundStyle(Theme.textPrimary)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)

                    Spacer(minLength: 12)

                    PrimaryButton(title: submitting ? "Saving…" : "Agree & Continue") {
                        Task {
                            submitting = true
                            await onAcknowledge()
                            submitting = false
                        }
                    }
                    .opacity(checked && !submitting ? 1 : 0.4)
                    .disabled(!checked || submitting)

                    Button("Not now", action: onCancel)
                        .font(Theme.sans(13, weight: .semibold))
                        .foregroundStyle(Theme.textMuted)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                }
                .padding(20)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.gold)
            VStack(alignment: .leading, spacing: 2) {
                Text("COMPLIANCE")
                    .font(Theme.sans(10, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Theme.gold)
                Text("Required to unlock voter data")
                    .font(Theme.sans(12, weight: .semibold))
                    .foregroundStyle(Theme.textMuted)
            }
            Spacer()
        }
    }

    private var rulesList: some View {
        VStack(alignment: .leading, spacing: 10) {
            rule("Campaign use only — election, governmental, or political purposes.")
            rule("No commercial solicitation, marketing, or resale.")
            rule("Every query you run is logged for audit.")
            rule("Access is scoped automatically to your declared race & district.")
        }
    }

    private func rule(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle().fill(Theme.gold).frame(width: 6, height: 6).padding(.top, 7)
            Text(text)
                .font(Theme.sans(13))
                .foregroundStyle(Theme.textSecondary)
        }
    }
}
