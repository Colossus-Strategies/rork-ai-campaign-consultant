//
//  SettingsSheet.swift
//  AICampaignConsultant
//

import SwiftUI

struct SettingsSheet: View {
    var auth: AuthViewModel
    let session: SupabaseSession
    let onClose: () -> Void
    let onDelete: () -> Void

    @State private var showAdmin: Bool = false

    private static let adminEmail: String = "anthony@colossus-strategies.com"

    private var isAdmin: Bool {
        (session.email ?? "").lowercased() == Self.adminEmail
    }

    private let termsURL = URL(string: "https://colossus-strategies.com/privacy-policy")!
    private let privacyURL = URL(string: "https://colossus-strategies.com/privacy-policy")!
    private let supportURL = URL(string: "https://colossus-strategies.com")!

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        header

                        sectionCard(title: "LEGAL") {
                            row(icon: "doc.text.fill", title: "Terms of Service", url: termsURL)
                            divider
                            row(icon: "lock.shield.fill", title: "Privacy Policy", url: privacyURL)
                            divider
                            row(icon: "lifepreserver", title: "Support", url: supportURL)
                        }

                        if isAdmin {
                            sectionCard(title: "ADMIN") {
                                actionRow(icon: "checkmark.seal.fill",
                                          title: "User Approvals",
                                          tint: Theme.gold) {
                                    showAdmin = true
                                }
                            }
                        }

                        sectionCard(title: "SUBSCRIPTION") {
                            row(icon: "creditcard.fill",
                                title: "Manage Subscription",
                                url: URL(string: "https://apps.apple.com/account/subscriptions")!)
                        }

                        sectionCard(title: "ACCOUNT") {
                            actionRow(icon: "rectangle.portrait.and.arrow.right",
                                      title: "Sign Out",
                                      tint: Theme.textPrimary) {
                                Task {
                                    await auth.signOut()
                                    onClose()
                                }
                            }
                            divider
                            actionRow(icon: "trash.fill",
                                      title: "Delete Account",
                                      tint: Color.red) {
                                onDelete()
                            }
                        }

                        Text("Deleting your account permanently removes your profile and campaign data. This cannot be undone.")
                            .font(Theme.sans(11))
                            .foregroundStyle(Theme.textMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        Haptics.tap()
                        onClose()
                    }
                    .foregroundStyle(Theme.gold)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Theme.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showAdmin) {
            AdminApprovalsView(session: session, onClose: { showAdmin = false })
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            LogoView(size: 56)
            Text("COLOSSUS CAMPAIGN OS")
                .font(Theme.sans(11, weight: .bold))
                .tracking(2.0)
                .foregroundStyle(Theme.gold)
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(Theme.sans(10, weight: .bold))
                .tracking(1.8)
                .foregroundStyle(Theme.goldDim)
                .padding(.leading, 4)
            VStack(spacing: 0) { content() }
                .background(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Theme.goldFaint, lineWidth: 1)
                )
                .clipShape(.rect(cornerRadius: 14))
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.goldFaint)
            .frame(height: 1)
            .padding(.leading, 52)
    }

    private func row(icon: String, title: String, url: URL) -> some View {
        Link(destination: url) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.gold)
                    .frame(width: 24)
                Text(title)
                    .font(Theme.sans(15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
    }

    private func actionRow(icon: String, title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 24)
                Text(title)
                    .font(Theme.sans(15, weight: .semibold))
                    .foregroundStyle(tint)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
