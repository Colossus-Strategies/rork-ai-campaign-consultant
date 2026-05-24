//
//  ServicesView.swift
//  AICampaignConsultant
//
//  "Services" tab. Pitches Colossus Fundraising Pro + Deep Strategy and
//  opens the intake form sheet.
//

import SwiftUI

struct ServicesView: View {
    let profile: CandidateProfile

    @State private var preselected: ServiceKind? = nil
    @State private var showForm: Bool = false
    @State private var showDistrictForm: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Theme.goldFaint).frame(height: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    DistrictIntelligenceCard {
                        Haptics.tap()
                        showDistrictForm = true
                    }

                    ServiceCard(
                        eyebrow: "FUNDRAISING",
                        title: "Colossus Fundraising Pro",
                        tagline: "Raise the money you need to win.",
                        bodyText: "Unlock unlimited access to fundraising data, donor intelligence, and campaign finance insights. Fundraising Pro also includes a dedicated Customer Success Manager who helps your campaign stay focused, organized, and on track toward its fundraising goals.",
                        bestFor: "Campaigns that need aggressive call time, donor targeting, finance planning, and accountability.",
                        bullets: [
                            "Unlimited fundraising data access",
                            "Dedicated Customer Success Manager",
                            "Donor targeting support",
                            "Call time planning",
                            "Fundraising progress check-ins",
                            "Finance strategy recommendations",
                        ],
                        icon: "dollarsign.circle.fill",
                        accent: Color(hex: 0x4caf6e),
                        cta: "Request Fundraising Pro"
                    ) {
                        preselected = .fundraising
                        showForm = true
                    }

                    ServiceCard(
                        eyebrow: "STRATEGY",
                        title: "Colossus Deep Strategy",
                        tagline: "Targeted research and strategic firepower.",
                        bodyText: "Deep Strategy gives your campaign access to advanced research, analysis, and live support from top consultants nationwide. Services may include opposition research, district analysis, message testing, strategic memos, and rapid-response support.",
                        bestFor: "Campaigns that need deeper insight, sharper messaging, or high-level strategic backup.",
                        bullets: [
                            "Targeted campaign research",
                            "Opposition research",
                            "District and voter analysis",
                            "Strategic messaging support",
                            "Live consultant support",
                            "Custom strategy memos",
                            "Rapid-response analysis",
                        ],
                        icon: "scope",
                        accent: Color(hex: 0xd14a3b),
                        cta: "Request Deep Strategy"
                    ) {
                        preselected = .strategy
                        showForm = true
                    }

                    Button {
                        Haptics.tap()
                        preselected = nil
                        showForm = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 14, weight: .bold))
                            Text("Not sure? Tell us what you need")
                                .font(Theme.sans(13, weight: .bold))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundStyle(Theme.gold)
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .background(Theme.surface)
                        .clipShape(.rect(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Theme.goldFaint, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    footer
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .background(Theme.bg)
        }
        .background(Theme.bg.ignoresSafeArea())
        .sheet(isPresented: $showForm) {
            ServiceIntakeFormView(profile: profile, preselected: preselected)
        }
        .sheet(isPresented: $showDistrictForm) {
            DistrictDataRequestFormView(profile: profile)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "briefcase.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.gold)
                Text("COLOSSUS SERVICES")
                    .font(Theme.sans(11, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Theme.gold)
                Spacer()
            }
            Text("Upgrade your campaign support")
                .font(Theme.serif(20, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Text("Fundraising, research, strategy, and live expert help built for campaigns that need more than the standard toolkit.")
                .font(Theme.sans(12, weight: .semibold))
                .foregroundStyle(Theme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Pricing & engagement details shared after review.")
                .font(Theme.sans(11, weight: .semibold))
                .foregroundStyle(Theme.textMuted)
            Text("Typical response: 1 business day.")
                .font(Theme.sans(11, weight: .semibold))
                .foregroundStyle(Theme.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }
}

// MARK: - District Intelligence Card

private struct DistrictIntelligenceCard: View {
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: 0x0a1628), Color(hex: 0x0f1f3d), Color(hex: 0x0a1628)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                USAHeatMapView()
                    .padding(.horizontal, 10)
                    .padding(.vertical, 14)
                LinearGradient(
                    colors: [Color.black.opacity(0.0), Color.black.opacity(0.35)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
                VStack {
                    HStack {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color(hex: 0x4caf6e))
                                .frame(width: 6, height: 6)
                            Text("INCLUDED IN APP")
                                .font(Theme.sans(9, weight: .bold))
                                .tracking(1.6)
                                .foregroundStyle(Color(hex: 0x4caf6e))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: 0x4caf6e).opacity(0.14))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color(hex: 0x4caf6e).opacity(0.4), lineWidth: 0.5))
                        Spacer()
                    }
                    Spacer()
                }
                .padding(12)
            }
            .frame(height: 200)
            .clipShape(.rect(cornerRadii: .init(topLeading: 16, bottomLeading: 0, bottomTrailing: 0, topTrailing: 16)))

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Theme.bg)
                        .frame(width: 44, height: 44)
                        .background(Theme.gold)
                        .clipShape(.rect(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("DISTRICT INTELLIGENCE")
                            .font(Theme.sans(10, weight: .bold))
                            .tracking(2)
                            .foregroundStyle(Theme.gold)
                        Text("Know your district inside out")
                            .font(Theme.serif(20, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                    }
                    Spacer(minLength: 0)
                }

                Text("Request a custom data pull for your race — voter file, turnout history, persuasion universes, and precinct-level analytics, delivered by the Colossus team.")
                    .font(Theme.sans(13, weight: .regular))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    badge("Voter file")
                    badge("Turnout")
                    badge("Walk lists")
                }
                HStack(spacing: 8) {
                    badge("Persuasion")
                    badge("GOTV")
                    badge("Custom")
                }

                Button {
                    Haptics.tap()
                    action()
                } label: {
                    HStack {
                        Text("Request District Data")
                            .font(Theme.sans(13, weight: .bold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(Theme.bg)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(Theme.gold)
                    .clipShape(.rect(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.goldFaint, lineWidth: 1)
        )
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(Theme.sans(11, weight: .bold))
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Theme.inputBg)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Theme.goldFaint, lineWidth: 0.5))
    }
}

// MARK: - Service Card

private struct ServiceCard: View {
    let eyebrow: String
    let title: String
    let tagline: String
    let bodyText: String
    let bestFor: String
    let bullets: [String]
    let icon: String
    let accent: Color
    let cta: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.bg)
                    .frame(width: 44, height: 44)
                    .background(accent)
                    .clipShape(.rect(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 3) {
                    Text(eyebrow)
                        .font(Theme.sans(10, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(accent)
                    Text(title)
                        .font(Theme.serif(20, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                }
                Spacer(minLength: 0)
            }

            Text(tagline)
                .font(Theme.sans(13, weight: .bold))
                .foregroundStyle(Theme.gold)

            Text(bodyText)
                .font(Theme.sans(13, weight: .regular))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 4) {
                Text("BEST FOR")
                    .font(Theme.sans(10, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(Theme.textMuted)
                Text(bestFor)
                    .font(Theme.sans(12, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("INCLUDES")
                    .font(Theme.sans(10, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(Theme.textMuted)
                ForEach(bullets, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(accent)
                            .frame(width: 14, height: 14)
                            .padding(.top, 2)
                        Text(item)
                            .font(Theme.sans(12, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Button {
                Haptics.tap()
                action()
            } label: {
                HStack {
                    Text(cta)
                        .font(Theme.sans(13, weight: .bold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(Theme.bg)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(Theme.gold)
                .clipShape(.rect(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.goldFaint, lineWidth: 1)
        )
    }
}
