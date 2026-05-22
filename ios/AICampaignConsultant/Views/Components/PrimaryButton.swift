//
//  PrimaryButton.swift
//  AICampaignConsultant
//

import SwiftUI

struct PrimaryButton: View {
    let title: String
    var enabled: Bool = true
    var loading: Bool = false
    let action: () -> Void

    var body: some View {
        Button {
            guard enabled, !loading else { return }
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 10) {
                if loading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(Theme.bg)
                }
                Text(title)
                    .font(Theme.sans(16, weight: .bold))
                    .tracking(0.5)
            }
            .foregroundStyle(Theme.bg)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                LinearGradient(
                    colors: enabled ? [Theme.goldLight, Theme.gold] : [Theme.goldDim.opacity(0.4), Theme.goldDim.opacity(0.4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(.rect(cornerRadius: 12))
            .shadow(color: enabled ? Theme.gold.opacity(0.35) : .clear, radius: 14, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(!enabled || loading)
        .opacity(enabled ? 1 : 0.7)
    }
}

struct OutlinedButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Text(title)
                .font(Theme.sans(16, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .frame(height: 54)
                .padding(.horizontal, 22)
                .background(Color.white.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Theme.textMuted.opacity(0.4), lineWidth: 1)
                )
                .clipShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

struct GoldTextField: View {
    let placeholder: String
    @Binding var text: String
    var submitLabel: SubmitLabel = .next
    var onSubmit: () -> Void = {}

    var body: some View {
        TextField("", text: $text, prompt:
                    Text(placeholder).foregroundStyle(Theme.textMuted)
        )
        .font(Theme.sans(17, weight: .regular))
        .foregroundStyle(Theme.textPrimary)
        .tint(Theme.gold)
        .submitLabel(submitLabel)
        .onSubmit(onSubmit)
        .padding(.horizontal, 16)
        .frame(height: 54)
        .background(Theme.inputBg)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.goldFaint, lineWidth: 1)
        )
        .clipShape(.rect(cornerRadius: 12))
        .autocorrectionDisabled()
    }
}
