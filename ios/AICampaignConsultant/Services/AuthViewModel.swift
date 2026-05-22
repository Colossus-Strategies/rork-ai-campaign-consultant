//
//  AuthViewModel.swift
//  AICampaignConsultant
//

import Foundation
import Observation
import Security

@Observable
final class AuthViewModel {
    enum Phase {
        case loading
        case signedOut
        case onboarding(SupabaseSession)
        case awaitingApproval(SupabaseSession, ProfileRow)
        case ready(SupabaseSession, ProfileRow, CandidateProfile)
    }

    var phase: Phase = .loading
    var error: String? = nil
    var isBusy: Bool = false
    /// Non-error informational message shown to the user (e.g. “We sent
    /// a confirmation email — you can keep using the app while you verify”).
    var info: String? = nil

    private let sessionKey = "colossus.session.v1"

    /// Emails that bypass the Colossus approval gate. Used so Apple App Review
    /// (and internal demo accounts) can evaluate the full app without waiting
    /// for manual admin activation. Matching is case-insensitive.
    private static let reviewerEmails: Set<String> = [
        "anthonystratis1888@gmail.com",
        "appreview@colossus-strategies.com",
        "demo@colossus-strategies.com"
    ]

    /// Universal demo password accepted for any reviewer email. Keeps App
    /// Review unblocked even if the Supabase password was rotated or the
    /// account was never created server-side.
    private static let reviewerPassword = "Tbone12345"

    private static func isReviewer(_ email: String?) -> Bool {
        guard let raw = email?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return false }
        return reviewerEmails.contains(raw.lowercased())
    }

    /// Synthesize a fully-active local session for App Review. Bypasses
    /// Supabase entirely so demo credentials always work — even on a fresh
    /// device with no network or with a rotated server-side password.
    @MainActor
    private func enterReviewerDemo(email: String) {
        let userId = "demo-" + UUID().uuidString.lowercased()
        let synthSession = SupabaseSession(
            accessToken: "demo.\(userId)",
            refreshToken: "demo.refresh",
            userId: userId,
            email: email
        )
        let demo = Self.demoProfile()
        let row = ProfileRow(
            id: userId,
            candidate_name: demo.name,
            preferred_name: demo.preferredName,
            race_id: demo.raceType.id,
            office: demo.office,
            location: demo.location,
            state: demo.state,
            district: demo.district,
            party: demo.party.rawValue,
            election_date: nil,
            role: demo.role.rawValue,
            phone: nil,
            approved: true,
            created_at: nil,
            voter_data_ack_at: nil,
            voter_data_ack_version: nil
        )
        // Do NOT persist this synthetic session — it has no real tokens.
        phase = .ready(synthSession, row, demo)
    }

    init() {
        Task { await restore() }
    }

    // MARK: - Public flows

    func restore() async {
        guard SupabaseClient.isConfigured else {
            phase = .signedOut
            return
        }
        guard let session = loadSession() else {
            phase = .signedOut
            return
        }
        await refreshProfile(session: session)
    }

    /// Upgrades a synthetic (`pending.*`) session to a real Supabase session
    /// by signing in with the user's password. Mirrors the in-memory profile
    /// row up to Supabase if it isn't there yet, so the user lands directly
    /// in `.ready` with a real JWT (and the District tab unlocks).
    /// Returns true on a successful real-token upgrade.
    @discardableResult
    func upgradeSession(email: String, password: String) async -> Bool {
        isBusy = true
        defer { isBusy = false }
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)

        let cachedRow: ProfileRow?
        let cachedProfile: CandidateProfile?
        if case let .ready(_, row, profile) = phase {
            cachedRow = row
            cachedProfile = profile
        } else {
            cachedRow = nil
            cachedProfile = nil
        }

        do {
            let session = try await SupabaseClient.signIn(email: trimmed, password: password)
            saveSession(session)

            if let profile = cachedProfile {
                let payload: [String: Any] = [
                    "candidate_name": profile.name,
                    "preferred_name": profile.preferredName.isEmpty ? NSNull() : profile.preferredName,
                    "race_id": profile.raceType.id,
                    "office": profile.office.isEmpty ? NSNull() : profile.office,
                    "location": profile.location.isEmpty ? NSNull() : profile.location,
                    "state": profile.state.isEmpty ? NSNull() : profile.state,
                    "district": profile.district.isEmpty ? NSNull() : profile.district,
                    "party": profile.party.rawValue,
                    "role": profile.role.rawValue,
                    "phone": cachedRow?.phone ?? NSNull(),
                    "approved": true
                ]
                try? await SupabaseClient.upsertProfile(session: session, payload: payload)
            }

            await refreshProfile(session: session)

            if case let .ready(s, _, _) = phase, !s.isSynthetic {
                return true
            }
            if case .onboarding = phase, let profile = cachedProfile {
                let row = cachedRow ?? ProfileRow(
                    id: session.userId,
                    candidate_name: profile.name,
                    preferred_name: profile.preferredName.isEmpty ? nil : profile.preferredName,
                    race_id: profile.raceType.id,
                    office: profile.office.isEmpty ? nil : profile.office,
                    location: profile.location.isEmpty ? nil : profile.location,
                    state: profile.state.isEmpty ? nil : profile.state,
                    district: profile.district.isEmpty ? nil : profile.district,
                    party: profile.party.rawValue,
                    election_date: nil,
                    role: profile.role.rawValue,
                    phone: nil,
                    approved: true,
                    created_at: nil,
                    voter_data_ack_at: nil,
                    voter_data_ack_version: nil
                )
                phase = .ready(session, row, profile)
                await attachStores(to: session)
                return true
            }
            return false
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            let lower = message.lowercased()
            if lower.contains("email not confirmed") {
                await SupabaseClient.resendConfirmation(email: trimmed)
                self.info = "Supabase still says this email isn’t confirmed. Open Authentication → Users in Supabase, verify the email matches, and run the SQL update again."
            } else if lower.contains("invalid login") || lower.contains("invalid grant") {
                self.error = "Wrong password for \(trimmed). Reset it in Supabase → Authentication → Users."
            } else {
                self.error = message
            }
            return false
        }
    }

    func signIn(email: String, password: String) async {
        isBusy = true
        defer { isBusy = false }
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        // App Review / demo bypass — any reviewer email with the demo
        // password drops straight into the ready phase without hitting
        // Supabase. This guarantees the credentials in App Store Connect
        // always work, even if the server-side account is missing or has
        // a different password.
        if Self.isReviewer(trimmed), password == Self.reviewerPassword {
            enterReviewerDemo(email: trimmed)
            return
        }
        do {
            let session = try await SupabaseClient.signIn(email: trimmed, password: password)
            saveSession(session)
            await refreshProfile(session: session)
        } catch {
            // Fallback: if this is a reviewer email and Supabase failed for
            // any reason (network, rate limit, missing account), still let
            // them in via the demo path. Real users see the error.
            if Self.isReviewer(trimmed) {
                enterReviewerDemo(email: trimmed)
                return
            }
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            // Friendly handling for the most common Supabase signup gotcha:
            // "Email not confirmed". Trigger a resend and surface a clear,
            // non-scary message rather than a generic "Connection Error".
            if message.lowercased().contains("email not confirmed") {
                await SupabaseClient.resendConfirmation(email: trimmed)
                self.info = "We sent a confirmation email to \(trimmed). Tap the link in that message, then sign in again."
            } else {
                self.error = message
            }
        }
    }

    func submitAccount(
        email: String,
        password: String,
        phone: String,
        draft: OnboardingDraft
    ) async -> Bool {
        isBusy = true
        defer { isBusy = false }
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        // Reviewer account creation always succeeds via the local demo path.
        if Self.isReviewer(trimmed) {
            enterReviewerDemo(email: trimmed)
            return true
        }
        do {
            // Sign up; if the account already exists, fall back to sign-in.
            // Supabase may also return success-without-session when email
            // confirmation is enabled — we handle that explicitly so the
            // user is never stranded on the signup screen.
            let outcome: SupabaseClient.SignUpOutcome
            do {
                outcome = try await SupabaseClient.signUp(email: trimmed, password: password)
            } catch {
                let session = try await SupabaseClient.signIn(email: trimmed, password: password)
                outcome = .session(session)
            }

            switch outcome {
            case let .session(session):
                saveSession(session)
                try await SupabaseClient.upsertProfile(
                    session: session,
                    payload: draft.toPayload(phone: phone)
                )
                await refreshProfile(session: session)
                return true

            case let .confirmationRequired(userId, emailFromServer):
                // Email confirmation may be required by Supabase. Try an
                // immediate password sign-in first — if the project has
                // "Confirm email" disabled (or the account was already
                // confirmed), this returns a real JWT and we land in the
                // fully active phase with server access to the voter DB.
                let effectiveEmail = emailFromServer ?? trimmed
                if let session = try? await SupabaseClient.signIn(email: trimmed, password: password) {
                    saveSession(session)
                    try? await SupabaseClient.upsertProfile(
                        session: session,
                        payload: draft.toPayload(phone: phone)
                    )
                    await refreshProfile(session: session)
                    return true
                }
                // Confirmation is still enforced — fall back to a synthetic
                // local session so the user isn't blocked, and resend the
                // confirmation email.
                await SupabaseClient.resendConfirmation(email: effectiveEmail)
                self.info = "We sent a confirmation email to \(effectiveEmail). You can start using the app now \u{2014} tap the link in that email later to enable cloud sync."
                enterPendingConfirmation(
                    userId: userId ?? "pending-\(UUID().uuidString.lowercased())",
                    email: effectiveEmail,
                    draft: draft,
                    phone: phone
                )
                return true
            }
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            if message.lowercased().contains("email not confirmed") {
                // Account already exists but hasn't been confirmed. Resend
                // the email and let the user keep moving with a local session
                // built from their onboarding draft.
                await SupabaseClient.resendConfirmation(email: trimmed)
                self.info = "We sent a confirmation email to \(trimmed). You can start using the app now \u{2014} tap the link in that email later to enable cloud sync."
                enterPendingConfirmation(
                    userId: "pending-\(UUID().uuidString.lowercased())",
                    email: trimmed,
                    draft: draft,
                    phone: phone
                )
                return true
            }
            self.error = message
            return false
        }
    }

    /// Drops a newly-signed-up user into the ready phase using a synthetic
    /// local session, when Supabase requires email confirmation. The user's
    /// real onboarding answers drive their profile so the app feels real.
    @MainActor
    private func enterPendingConfirmation(
        userId: String,
        email: String,
        draft: OnboardingDraft,
        phone: String
    ) {
        let synthSession = SupabaseSession(
            accessToken: "pending.\(userId)",
            refreshToken: "pending.refresh",
            userId: userId,
            email: email
        )
        let profile = CandidateProfile(
            name: draft.name.isEmpty ? "Candidate" : draft.name,
            preferredName: draft.preferredName,
            raceType: draft.race ?? (RaceType.find(id: "state") ?? RaceType.all[0]),
            office: draft.office,
            location: draft.location,
            state: draft.state,
            district: draft.district,
            party: draft.party,
            electionDate: draft.electionDate,
            role: draft.role
        )
        let row = ProfileRow(
            id: userId,
            candidate_name: profile.name,
            preferred_name: profile.preferredName.isEmpty ? nil : profile.preferredName,
            race_id: profile.raceType.id,
            office: profile.office.isEmpty ? nil : profile.office,
            location: profile.location.isEmpty ? nil : profile.location,
            state: profile.state.isEmpty ? nil : profile.state,
            district: profile.district.isEmpty ? nil : profile.district,
            party: profile.party.rawValue,
            election_date: nil,
            role: profile.role.rawValue,
            phone: phone.isEmpty ? nil : phone,
            approved: true,
            created_at: nil,
            voter_data_ack_at: nil,
            voter_data_ack_version: nil
        )
        // Do NOT persist this synthetic session — it has no real tokens.
        // The user will sign in normally once they confirm their email.
        phase = .ready(synthSession, row, profile)
    }

    func refreshProfile(session: SupabaseSession) async {
        let reviewer = Self.isReviewer(session.email)
        do {
            if let row = try await SupabaseClient.fetchProfile(session: session) {
                // Open signup: every account with a complete profile is
                // automatically active. No manual approval gate.
                if let profile = CandidateProfile(row: row) {
                    phase = .ready(session, row, profile)
                    await attachStores(to: session)
                } else {
                    // Profile row exists but is incomplete — seed a default
                    // profile so the app is fully usable. (Edge case: legacy
                    // rows missing required fields.)
                    let demo = Self.demoProfile()
                    phase = .ready(session, row, demo)
                    await attachStores(to: session)
                }
            } else if reviewer {
                // No profile row yet for the reviewer — seed a demo profile
                // row so they land directly in the active app.
                let draft = Self.demoOnboardingDraft()
                try? await SupabaseClient.upsertProfile(
                    session: session,
                    payload: draft.toPayload(phone: "")
                )
                let row = (try? await SupabaseClient.fetchProfile(session: session))
                let demo = Self.demoProfile()
                if let row {
                    phase = .ready(session, row, demo)
                } else {
                    // Synthesize a minimal row if Supabase write failed.
                    let synth = ProfileRow(
                        id: session.userId,
                        candidate_name: demo.name,
                        preferred_name: demo.preferredName,
                        race_id: demo.raceType.id,
                        office: demo.office,
                        location: demo.location,
                        state: demo.state,
                        district: demo.district,
                        party: demo.party.rawValue,
                        election_date: nil,
                        role: demo.role.rawValue,
                        phone: nil,
                        approved: true,
                        created_at: nil,
                        voter_data_ack_at: nil,
                        voter_data_ack_version: nil
                    )
                    phase = .ready(session, synth, demo)
                }
                await attachStores(to: session)
            } else {
                phase = .onboarding(session)
            }
        } catch {
            // Treat as needing onboarding rather than blocking.
            phase = .onboarding(session)
        }
    }

    /// Default candidate profile used for the App Review demo experience.
    private static func demoProfile() -> CandidateProfile {
        let race = RaceType.find(id: "state") ?? RaceType.all[0]
        var components = DateComponents()
        components.year = Calendar.current.component(.year, from: Date()) + 1
        components.month = 11
        components.day = 3
        let electionDate = Calendar.current.date(from: components)
        return CandidateProfile(
            name: "Demo Candidate",
            preferredName: "Demo",
            raceType: race,
            office: "State Representative",
            location: "Columbus, OH",
            state: "Ohio",
            district: "OH-59",
            party: .democrat,
            electionDate: electionDate,
            role: .challenger
        )
    }

    private static func demoOnboardingDraft() -> OnboardingDraft {
        var draft = OnboardingDraft()
        draft.name = "Demo Candidate"
        draft.preferredName = "Demo"
        draft.race = RaceType.find(id: "state")
        draft.office = "State Representative"
        draft.location = "Columbus, OH"
        draft.state = "Ohio"
        draft.district = "OH-59"
        draft.party = .democrat
        draft.role = .challenger
        var components = DateComponents()
        components.year = Calendar.current.component(.year, from: Date()) + 1
        components.month = 11
        components.day = 3
        draft.electionDate = Calendar.current.date(from: components)
        return draft
    }

    private func attachStores(to session: SupabaseSession) async {
        await ProgressStore.shared.attach(session: session)
        await LibraryStore.shared.attach(session: session)
    }

    func deleteAccount() async -> Bool {
        isBusy = true
        defer { isBusy = false }
        let session: SupabaseSession?
        switch phase {
        case let .ready(s, _, _): session = s
        case let .awaitingApproval(s, _): session = s
        case let .onboarding(s): session = s
        default: session = nil
        }
        guard let s = session else {
            clearSession()
            phase = .signedOut
            return true
        }
        do {
            try await SupabaseClient.deleteAccount(session: s)
            ProgressStore.shared.detach()
            LibraryStore.shared.detach()
            clearSession()
            phase = .signedOut
            return true
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }

    func signOut() async {
        if case let .ready(session, _, _) = phase { await SupabaseClient.signOut(session: session) }
        else if case let .awaitingApproval(session, _) = phase { await SupabaseClient.signOut(session: session) }
        else if case let .onboarding(session) = phase { await SupabaseClient.signOut(session: session) }
        ProgressStore.shared.detach()
        LibraryStore.shared.detach()
        clearSession()
        phase = .signedOut
    }

    // MARK: - Keychain

    private func saveSession(_ session: SupabaseSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: sessionKey,
        ]
        SecItemDelete(query as CFDictionary)
        var attrs = query
        attrs[kSecValueData as String] = data
        SecItemAdd(attrs as CFDictionary, nil)
    }

    private func loadSession() -> SupabaseSession? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: sessionKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return try? JSONDecoder().decode(SupabaseSession.self, from: data)
    }

    private func clearSession() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: sessionKey,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
