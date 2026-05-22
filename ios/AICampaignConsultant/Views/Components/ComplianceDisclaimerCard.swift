//
//  ComplianceDisclaimerCard.swift
//  AICampaignConsultant
//
//  Shared component C01 — Compliance Disclaimer Card.
//  Gold-bordered "verify before you act" card rendered below any AI answer
//  that touches campaign-finance or compliance rules.
//

import SwiftUI

enum ComplianceVerifyWith: String {
    case treasurer
    case attorney
    case stateOffice
    case fec

    var label: String {
        switch self {
        case .treasurer: return "your campaign treasurer"
        case .attorney: return "campaign-finance counsel"
        case .stateOffice: return "your Secretary of State office"
        case .fec: return "the FEC"
        }
    }
}

enum ComplianceSeverity {
    case informational
    case caution
}

struct ComplianceDisclaimerCard: View {
    var jurisdictionContext: String
    var verifyWith: ComplianceVerifyWith = .treasurer
    var severity: ComplianceSeverity = .informational
    var ruleSourceTitle: String? = nil
    var ruleSourceURL: URL? = nil

    @State private var expanded: Bool = false

    private var borderColor: Color {
        switch severity {
        case .informational: return Theme.gold
        case .caution: return Color(hex: 0xff8c5a)
        }
    }

    private var headline: String {
        switch severity {
        case .informational: return "Verify before you act"
        case .caution: return "Do not act without verifying"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: severity == .caution ? "exclamationmark.shield.fill" : "checkmark.shield.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(borderColor)
                Text("COMPLIANCE CHECK")
                    .font(Theme.sans(10, weight: .bold))
                    .tracking(1.6)
                    .foregroundStyle(borderColor)
                Spacer()
                Text(jurisdictionContext)
                    .font(Theme.sans(10, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.textMuted)
                    .lineLimit(1)
            }

            Text(headline)
                .font(Theme.serif(15, weight: .bold))
                .foregroundStyle(Theme.textPrimary)

            Text("Campaign-finance rules vary by jurisdiction and change often. Confirm any specific amount, deadline, or coordination rule with \(verifyWith.label) before you rely on it.")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button {
                    Haptics.tap()
                    withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Text(expanded ? "Hide details" : "Why this matters")
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    }
                    .font(Theme.sans(12, weight: .bold))
                    .foregroundStyle(borderColor)
                }
                .buttonStyle(.plain)

                if let title = ruleSourceTitle, let url = ruleSourceURL {
                    Link(destination: url) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.right.square")
                            Text(title)
                        }
                        .font(Theme.sans(12, weight: .bold))
                        .foregroundStyle(borderColor)
                    }
                }

                Spacer()
            }

            if expanded {
                Text("This answer is a starting point produced by an AI consultant. Treat it as research, not legal advice. Anything involving contribution limits, in-kind support, coordination with PACs or party committees, or disclaimers on paid communications must be verified by \(verifyWith.label) for your jurisdiction.")
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.top, 4)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .background(Theme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(borderColor, lineWidth: 1.5)
        )
        .clipShape(.rect(cornerRadius: 14))
    }
}

#Preview {
    ZStack {
        Theme.bg.ignoresSafeArea()
        VStack(spacing: 16) {
            ComplianceDisclaimerCard(
                jurisdictionContext: "OH-59 · FEC + Ohio",
                verifyWith: .treasurer,
                severity: .informational,
                ruleSourceTitle: "FEC 2025–26 chart",
                ruleSourceURL: URL(string: "https://fec.gov")
            )
            ComplianceDisclaimerCard(
                jurisdictionContext: "OH-59 · FEC + Ohio",
                verifyWith: .attorney,
                severity: .caution
            )
        }
        .padding()
    }
}
