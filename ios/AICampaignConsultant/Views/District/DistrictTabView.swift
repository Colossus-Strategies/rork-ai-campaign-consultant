//
//  DistrictTabView.swift
//  AICampaignConsultant
//
//  Parent container for the Voter Data module. Hosts a section switcher
//  (Dashboard / Voters / Lists) and the compliance gate.
//

import SwiftUI

struct DistrictTabView: View {
    let profile: CandidateProfile
    let session: SupabaseSession
    var auth: AuthViewModel

    enum Section: String, CaseIterable, Identifiable {
        case dashboard = "Dashboard"
        case voters = "Voters"
        case lists = "Lists"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .dashboard: return "chart.pie.fill"
            case .voters: return "person.3.fill"
            case .lists: return "list.bullet.rectangle.fill"
            }
        }
    }

    @State private var section: Section = .dashboard
    @State private var ackDate: Date? = nil
    @State private var ackLoaded: Bool = false
    @State private var showCompliance: Bool = false
    @State private var ackError: String? = nil
    @State private var resendBusy: Bool = false
    @State private var resendSent: Bool = false
    @State private var reauthPassword: String = ""
    @State private var reauthBusy: Bool = false
    @State private var reauthError: String? = nil
    @State private var showPassword: Bool = false
    @FocusState private var passwordFocused: Bool
    @State private var stateName: String = "Ohio"
    @State private var notice: String =
        "Ohio voter registration data is a public record provided by the Ohio Secretary of State. " +
        "Per Ohio Revised Code §3503.13 and §111.41, this data may be used for election, governmental, " +
        "or political purposes only and MAY NOT be used for any commercial solicitation."

    var body: some View {
        VStack(spacing: 0) {
            header
            sectionSwitcher
            Divider().background(Theme.goldFaint).frame(height: 1)
            content
        }
        .background(Theme.bg.ignoresSafeArea())
        .task { await loadAck() }
        .sheet(isPresented: $showCompliance) {
            VoterComplianceModal(
                stateName: stateName,
                notice: notice,
                onAcknowledge: {
                    await VoterDataService.acknowledge(session: session)
                    ackDate = Date()
                    ackError = nil
                    showCompliance = false
                },
                onCancel: { showCompliance = false }
            )
            .presentationDetents([.large])
        }
        .alert("Couldn\u{2019}t unlock voter data", isPresented: .constant(ackError != nil)) {
            Button("OK") { ackError = nil }
        } message: {
            Text(ackError ?? "")
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "map.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.gold)
                Text("MY DISTRICT")
                    .font(Theme.sans(11, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Theme.gold)
                Spacer()
                if ackDate != nil {
                    Label("Compliant", systemImage: "checkmark.shield.fill")
                        .font(Theme.sans(10, weight: .bold))
                        .foregroundStyle(Theme.online)
                }
            }
            Text(raceLine)
                .font(Theme.serif(20, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Text(locationLine)
                .font(Theme.sans(12, weight: .semibold))
                .foregroundStyle(Theme.textMuted)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.gold.opacity(0.45)).frame(height: 1)
        }
    }

    private var raceLine: String {
        let race = profile.raceType.label
        let dist = profile.district.isEmpty ? profile.state : profile.district
        return "Running for \(race) — \(dist)"
    }

    private var locationLine: String {
        let parts = [profile.office, profile.location].filter { !$0.isEmpty }
        return parts.joined(separator: " · ")
    }

    private var sectionSwitcher: some View {
        HStack(spacing: 6) {
            ForEach(Section.allCases) { s in
                Button {
                    Haptics.tap()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { section = s }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: s.icon)
                            .font(.system(size: 12, weight: .bold))
                        Text(s.rawValue)
                            .font(Theme.sans(12, weight: .bold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .foregroundStyle(section == s ? Theme.bg : Theme.textMuted)
                    .background(
                        Capsule().fill(section == s ? Theme.gold : Theme.inputBg)
                    )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.surface)
    }

    // MARK: Gated content

    @ViewBuilder
    private var content: some View {
        if !ackLoaded {
            loadingState
        } else if ackDate == nil {
            unlockGate
        } else {
            switch section {
            case .dashboard: DistrictDashboardView(profile: profile, session: session)
            case .voters:    VoterUniverseView(profile: profile, session: session)
            case .lists:     TargetingListsView(profile: profile, session: session)
            }
        }
    }

    private var confirmEmailGate: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "envelope.badge.shield.half.filled.fill")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(Theme.gold)
                Text("Sign In to Unlock")
                    .font(Theme.serif(22, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Already confirmed your email? Re-enter your password to upgrade this device to a verified session and unlock the Ohio voter database.")
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)

                VStack(spacing: 10) {
                    // Real username TextField (read-only) — required so iOS
                    // pairs the SecureField below into a proper sign-in form
                    // and doesn't hijack it with the Strong Password overlay.
                    TextField("Email", text: .constant(session.email ?? ""))
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .disabled(true)
                        .font(Theme.sans(13, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .padding(12)
                        .background(Theme.inputBg, in: .rect(cornerRadius: 10))

                    HStack(spacing: 8) {
                        Group {
                            if showPassword {
                                TextField("Password", text: $reauthPassword)
                                    .textContentType(.password)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                            } else {
                                SecureField("Password", text: $reauthPassword)
                                    .textContentType(.password)
                            }
                        }
                        .focused($passwordFocused)
                        .submitLabel(.go)
                        .onSubmit { Task { await reauthenticate() } }
                        .foregroundStyle(Theme.textPrimary)
                        .tint(Theme.gold)

                        Button {
                            showPassword.toggle()
                            passwordFocused = true
                        } label: {
                            Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                .foregroundStyle(Theme.textMuted)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .background(Theme.inputBg, in: .rect(cornerRadius: 10))
                    .contentShape(.rect)
                    .onTapGesture { passwordFocused = true }

                    if let reauthError {
                        Text(reauthError)
                            .font(Theme.sans(12, weight: .semibold))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 28)

                PrimaryButton(title: reauthBusy ? "Signing In…" : "Sign In & Unlock") {
                    Task { await reauthenticate() }
                }
                .disabled(reauthBusy)
                .padding(.horizontal, 28)

                Divider().background(Theme.goldFaint).padding(.vertical, 4)

                Text("Haven\u{2019}t confirmed yet?")
                    .font(Theme.sans(11, weight: .semibold))
                    .foregroundStyle(Theme.textMuted)
                if resendSent {
                    Label("Confirmation email sent", systemImage: "checkmark.circle.fill")
                        .font(Theme.sans(12, weight: .semibold))
                        .foregroundStyle(Theme.online)
                }
                Button(resendBusy ? "Sending…" : "Resend Confirmation Email") {
                    Task { await resendConfirmation() }
                }
                .font(Theme.sans(13, weight: .semibold))
                .foregroundStyle(Theme.gold)
                .disabled(resendBusy || (session.email ?? "").isEmpty)
            }
            .padding(.top, 40)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity)
        }
    }

    private func reauthenticate() async {
        guard let email = session.email, !email.isEmpty else {
            reauthError = "No email on this session. Sign out and sign in again."
            return
        }
        let pwd = reauthPassword
        guard !pwd.isEmpty else {
            reauthError = "Enter your password to continue."
            passwordFocused = true
            return
        }
        reauthBusy = true
        reauthError = nil
        passwordFocused = false
        let success = await auth.upgradeSession(email: email, password: pwd)
        reauthBusy = false

        if let err = auth.error {
            reauthError = err
            auth.error = nil
            return
        }
        if let info = auth.info {
            reauthError = info
            auth.info = nil
            return
        }
        guard success else {
            reauthError = "Sign-in didn\u{2019}t produce a verified session. Double-check the password, and verify auth.users.email_confirmed_at is set for this email in Supabase."
            return
        }
        reauthPassword = ""
        Haptics.success()
    }

    private func resendConfirmation() async {
        guard let email = session.email, !email.isEmpty else { return }
        resendBusy = true
        await SupabaseClient.resendConfirmation(email: email)
        resendBusy = false
        resendSent = true
        Haptics.success()
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView().tint(Theme.gold)
            Text("Loading…")
                .font(Theme.sans(12, weight: .semibold))
                .foregroundStyle(Theme.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var unlockGate: some View {
        VStack(spacing: 18) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 42, weight: .bold))
                .foregroundStyle(Theme.gold)
            Text("Voter Data Locked")
                .font(Theme.serif(22, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Text("Acknowledge the \(stateName) data-use agreement to unlock district analytics, voter lookup, and targeting lists.")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            PrimaryButton(title: "Review & Unlock") {
                ackError = nil
                showCompliance = true
            }
            .padding(.horizontal, 28)
            .padding(.top, 6)
            Spacer()
        }
        .padding(.top, 60)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadAck() async {
        do {
            ackDate = try await VoterDataService.acknowledgmentDate(session: session)
        } catch {
            ackDate = nil
        }
        ackLoaded = true
    }
}
