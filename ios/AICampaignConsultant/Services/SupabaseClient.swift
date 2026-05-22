//
//  SupabaseClient.swift
//  AICampaignConsultant
//
//  Thin REST wrapper around Supabase GoTrue + PostgREST.
//  No external SDK dependency.
//
//  Required schema (run in Supabase SQL editor before first signup):
//
//  create table public.candidate_profiles (
//    id uuid primary key references auth.users(id) on delete cascade,
//    candidate_name text not null,
//    preferred_name text,
//    race_id text not null,
//    office text,
//    location text,
//    state text,
//    district text,
//    party text,
//    election_date date,
//    role text,
//    phone text,
//    approved boolean not null default false,
//    created_at timestamptz not null default now()
//  );
//  alter table public.candidate_profiles enable row level security;
//  create policy "owner can read"   on public.candidate_profiles for select using (auth.uid() = id);
//  create policy "owner can insert" on public.candidate_profiles for insert with check (auth.uid() = id);
//  create policy "owner can update" on public.candidate_profiles for update using (auth.uid() = id);
//
//  -- Progress (one row per completed deep-dive step per user)
//  create table public.candidate_progress (
//    user_id uuid not null references auth.users(id) on delete cascade,
//    step_id text not null,
//    completed_at timestamptz not null default now(),
//    primary key (user_id, step_id)
//  );
//  alter table public.candidate_progress enable row level security;
//  create policy "owner read progress"   on public.candidate_progress for select using (auth.uid() = user_id);
//  create policy "owner insert progress" on public.candidate_progress for insert with check (auth.uid() = user_id);
//  create policy "owner delete progress" on public.candidate_progress for delete using (auth.uid() = user_id);
//
//  -- Library (saved items per user)
//  create table public.candidate_library (
//    id uuid primary key,
//    user_id uuid not null references auth.users(id) on delete cascade,
//    name text not null,
//    category text not null,
//    notes text not null default '',
//    body text not null,
//    created_at timestamptz not null default now()
//  );
//  create index on public.candidate_library (user_id, created_at desc);
//  alter table public.candidate_library enable row level security;
//  create policy "owner read library"   on public.candidate_library for select using (auth.uid() = user_id);
//  create policy "owner insert library" on public.candidate_library for insert with check (auth.uid() = user_id);
//  create policy "owner update library" on public.candidate_library for update using (auth.uid() = user_id);
//  create policy "owner delete library" on public.candidate_library for delete using (auth.uid() = user_id);
//

import Foundation

enum SupabaseError: LocalizedError {
    case missingConfig
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .missingConfig: return "Supabase is not configured."
        case .invalidResponse: return "Unexpected response from server."
        case .server(let m): return m
        }
    }
}

nonisolated struct SupabaseSession: Codable, Sendable {
    let accessToken: String
    let refreshToken: String
    let userId: String
    let email: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case user
    }
    enum UserKeys: String, CodingKey { case id, email }

    init(accessToken: String, refreshToken: String, userId: String, email: String?) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.userId = userId
        self.email = email
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.accessToken = try c.decode(String.self, forKey: .accessToken)
        self.refreshToken = try c.decode(String.self, forKey: .refreshToken)
        let u = try c.nestedContainer(keyedBy: UserKeys.self, forKey: .user)
        self.userId = try u.decode(String.self, forKey: .id)
        self.email = try? u.decode(String.self, forKey: .email)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(accessToken, forKey: .accessToken)
        try c.encode(refreshToken, forKey: .refreshToken)
        var u = c.nestedContainer(keyedBy: UserKeys.self, forKey: .user)
        try u.encode(userId, forKey: .id)
        try u.encodeIfPresent(email, forKey: .email)
    }

    /// True when this session was synthesized locally (App Review demo path
    /// or post-signup-before-email-confirmation). Such tokens are not valid
    /// JWTs and any Supabase REST call with them will 401. Callers must use
    /// local storage instead of hitting the server.
    var isSynthetic: Bool {
        accessToken.hasPrefix("demo.") || accessToken.hasPrefix("pending.")
    }
}

nonisolated struct ProgressRow: Codable, Sendable {
    let user_id: String
    let step_id: String
    let completed_at: String?
}

nonisolated struct LibraryRow: Codable, Sendable {
    let id: String
    let user_id: String
    let name: String
    let category: String
    let notes: String
    let body: String
    let created_at: String?
}

nonisolated struct ProfileRow: Codable, Sendable {
    let id: String
    let candidate_name: String
    let preferred_name: String?
    let race_id: String
    let office: String?
    let location: String?
    let state: String?
    let district: String?
    let party: String?
    let election_date: String?
    let role: String?
    let phone: String?
    let approved: Bool
    let created_at: String?
    let voter_data_ack_at: String?
    let voter_data_ack_version: String?
}

nonisolated enum SupabaseClient {
    static var baseURL: URL? { URL(string: SupabaseConfig.url) }
    static var anonKey: String { SupabaseConfig.anonKey }

    static var isConfigured: Bool {
        !SupabaseConfig.url.isEmpty && !SupabaseConfig.anonKey.isEmpty
    }

    // MARK: - Auth

    /// Outcome of a sign-up call. Supabase returns HTTP 200 with no
    /// `access_token` when the project requires email confirmation — that's
    /// `.confirmationRequired`, not an error. The caller decides how to handle
    /// the gap (we synthesize a local session so the user isn't stranded).
    enum SignUpOutcome {
        case session(SupabaseSession)
        case confirmationRequired(userId: String?, email: String?)
    }

    static func signUp(email: String, password: String) async throws -> SignUpOutcome {
        let body: [String: Any] = ["email": email, "password": password]
        let data = try await post(path: "/auth/v1/signup", json: body, auth: nil)
        if let session = try? JSONDecoder().decode(SupabaseSession.self, from: data) {
            return .session(session)
        }
        // No session in the response — confirmation is required. Extract the
        // user id/email if present so we can keep them consistent locally.
        let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        let user = (obj?["user"] as? [String: Any]) ?? obj
        let userId = user?["id"] as? String
        let userEmail = (user?["email"] as? String) ?? email
        return .confirmationRequired(userId: userId, email: userEmail)
    }

    static func signIn(email: String, password: String) async throws -> SupabaseSession {
        let body: [String: Any] = ["email": email, "password": password]
        let data = try await post(path: "/auth/v1/token?grant_type=password", json: body, auth: nil)
        return try decodeSession(data)
    }

    /// Asks Supabase to (re)send the confirmation email. Best-effort —
    /// failures are non-fatal because the user already has a working local
    /// session and can keep using the app.
    static func resendConfirmation(email: String) async {
        _ = try? await post(
            path: "/auth/v1/resend",
            json: ["type": "signup", "email": email],
            auth: nil
        )
    }

    static func signOut(session: SupabaseSession) async {
        _ = try? await post(path: "/auth/v1/logout", json: [:], auth: session.accessToken)
    }

    /// Deletes the user's profile row. RLS owner policy allows the user to delete their own row.
    /// Auth user record is removed by the database cascade (`on delete cascade` on the profile FK).
    static func deleteAccount(session: SupabaseSession) async throws {
        guard let base = baseURL else { throw SupabaseError.missingConfig }
        var comps = URLComponents(url: base.appendingPathComponent("/rest/v1/candidate_profiles"), resolvingAgainstBaseURL: false)
        comps?.queryItems = [.init(name: "id", value: "eq.\(session.userId)")]
        guard let url = comps?.url else { throw SupabaseError.invalidResponse }
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        try validate(resp: resp, data: data)
        _ = try? await post(path: "/auth/v1/logout", json: [:], auth: session.accessToken)
    }

    // MARK: - Profile

    static func upsertProfile(session: SupabaseSession, payload: [String: Any]) async throws {
        var body = payload
        body["id"] = session.userId
        _ = try await postRest(
            path: "/rest/v1/candidate_profiles",
            json: body,
            auth: session.accessToken,
            preferHeader: "resolution=merge-duplicates,return=minimal"
        )
    }

    /// PATCH-only update of the existing profile row. Returns true if a row
    /// was actually updated (PostgREST returns the affected rows when we ask
    /// for `return=representation`). Used for partial updates like the voter
    /// data ack, where we must NOT trigger an INSERT that would fail NOT NULL
    /// constraints on columns we don't include in the payload.
    @discardableResult
    static func patchProfile(session: SupabaseSession, payload: [String: Any]) async throws -> Bool {
        guard let base = baseURL else { throw SupabaseError.missingConfig }
        var comps = URLComponents(url: base.appendingPathComponent("/rest/v1/candidate_profiles"), resolvingAgainstBaseURL: false)
        comps?.queryItems = [.init(name: "id", value: "eq.\(session.userId)")]
        guard let url = comps?.url else { throw SupabaseError.invalidResponse }
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("return=representation", forHTTPHeaderField: "Prefer")
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, resp) = try await URLSession.shared.data(for: req)
        try validate(resp: resp, data: data)
        if let arr = try? JSONSerialization.jsonObject(with: data) as? [Any] {
            return !arr.isEmpty
        }
        return false
    }

    // MARK: - Admin

    /// Lists profiles for the admin console. Requires an admin RLS policy in Supabase
    /// that grants the admin email read access on `candidate_profiles`.
    static func adminListProfiles(session: SupabaseSession, approved: Bool? = nil) async throws -> [ProfileRow] {
        guard let base = baseURL else { throw SupabaseError.missingConfig }
        var comps = URLComponents(url: base.appendingPathComponent("/rest/v1/candidate_profiles"), resolvingAgainstBaseURL: false)
        var items: [URLQueryItem] = [
            .init(name: "select", value: "*"),
            .init(name: "order", value: "created_at.desc"),
        ]
        if let approved {
            items.append(.init(name: "approved", value: "eq.\(approved)"))
        }
        comps?.queryItems = items
        guard let url = comps?.url else { throw SupabaseError.invalidResponse }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, resp) = try await URLSession.shared.data(for: req)
        try validate(resp: resp, data: data)
        return try JSONDecoder().decode([ProfileRow].self, from: data)
    }

    /// Updates the `approved` flag on a profile. Requires admin RLS policy.
    static func adminSetApproved(session: SupabaseSession, profileId: String, approved: Bool) async throws {
        guard let base = baseURL else { throw SupabaseError.missingConfig }
        var comps = URLComponents(url: base.appendingPathComponent("/rest/v1/candidate_profiles"), resolvingAgainstBaseURL: false)
        comps?.queryItems = [.init(name: "id", value: "eq.\(profileId)")]
        guard let url = comps?.url else { throw SupabaseError.invalidResponse }
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["approved": approved])
        let (data, resp) = try await URLSession.shared.data(for: req)
        try validate(resp: resp, data: data)
    }

    static func fetchProfile(session: SupabaseSession) async throws -> ProfileRow? {
        guard let base = baseURL else { throw SupabaseError.missingConfig }
        var comps = URLComponents(url: base.appendingPathComponent("/rest/v1/candidate_profiles"), resolvingAgainstBaseURL: false)
        comps?.queryItems = [
            .init(name: "id", value: "eq.\(session.userId)"),
            .init(name: "select", value: "*"),
            .init(name: "limit", value: "1"),
        ]
        guard let url = comps?.url else { throw SupabaseError.invalidResponse }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, resp) = try await URLSession.shared.data(for: req)
        try validate(resp: resp, data: data)
        let rows = try JSONDecoder().decode([ProfileRow].self, from: data)
        return rows.first
    }

    // MARK: - Progress sync

    static func fetchProgress(session: SupabaseSession) async throws -> [String] {
        guard let base = baseURL else { throw SupabaseError.missingConfig }
        var comps = URLComponents(url: base.appendingPathComponent("/rest/v1/candidate_progress"), resolvingAgainstBaseURL: false)
        comps?.queryItems = [
            .init(name: "user_id", value: "eq.\(session.userId)"),
            .init(name: "select", value: "step_id"),
        ]
        guard let url = comps?.url else { throw SupabaseError.invalidResponse }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, resp) = try await URLSession.shared.data(for: req)
        try validate(resp: resp, data: data)
        struct StepOnly: Decodable { let step_id: String }
        let rows = try JSONDecoder().decode([StepOnly].self, from: data)
        return rows.map(\.step_id)
    }

    static func insertProgress(session: SupabaseSession, stepId: String) async throws {
        _ = try await postRest(
            path: "/rest/v1/candidate_progress",
            json: ["user_id": session.userId, "step_id": stepId],
            auth: session.accessToken,
            preferHeader: "resolution=merge-duplicates,return=minimal"
        )
    }

    static func deleteProgress(session: SupabaseSession, stepId: String) async throws {
        guard let base = baseURL else { throw SupabaseError.missingConfig }
        var comps = URLComponents(url: base.appendingPathComponent("/rest/v1/candidate_progress"), resolvingAgainstBaseURL: false)
        comps?.queryItems = [
            .init(name: "user_id", value: "eq.\(session.userId)"),
            .init(name: "step_id", value: "eq.\(stepId)"),
        ]
        guard let url = comps?.url else { throw SupabaseError.invalidResponse }
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        try validate(resp: resp, data: data)
    }

    // MARK: - Library sync

    static func fetchLibrary(session: SupabaseSession) async throws -> [LibraryRow] {
        guard let base = baseURL else { throw SupabaseError.missingConfig }
        var comps = URLComponents(url: base.appendingPathComponent("/rest/v1/candidate_library"), resolvingAgainstBaseURL: false)
        comps?.queryItems = [
            .init(name: "user_id", value: "eq.\(session.userId)"),
            .init(name: "select", value: "*"),
            .init(name: "order", value: "created_at.desc"),
        ]
        guard let url = comps?.url else { throw SupabaseError.invalidResponse }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, resp) = try await URLSession.shared.data(for: req)
        try validate(resp: resp, data: data)
        return try JSONDecoder().decode([LibraryRow].self, from: data)
    }

    static func insertLibraryItem(
        session: SupabaseSession,
        id: String,
        name: String,
        category: String,
        notes: String,
        body: String,
        createdAt: String
    ) async throws {
        _ = try await postRest(
            path: "/rest/v1/candidate_library",
            json: [
                "id": id,
                "user_id": session.userId,
                "name": name,
                "category": category,
                "notes": notes,
                "body": body,
                "created_at": createdAt,
            ],
            auth: session.accessToken,
            preferHeader: "resolution=merge-duplicates,return=minimal"
        )
    }

    static func deleteLibraryItem(session: SupabaseSession, id: String) async throws {
        guard let base = baseURL else { throw SupabaseError.missingConfig }
        var comps = URLComponents(url: base.appendingPathComponent("/rest/v1/candidate_library"), resolvingAgainstBaseURL: false)
        comps?.queryItems = [
            .init(name: "user_id", value: "eq.\(session.userId)"),
            .init(name: "id", value: "eq.\(id)"),
        ]
        guard let url = comps?.url else { throw SupabaseError.invalidResponse }
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        try validate(resp: resp, data: data)
    }

    // MARK: - HTTP plumbing

    private static func decodeSession(_ data: Data) throws -> SupabaseSession {
        do {
            return try JSONDecoder().decode(SupabaseSession.self, from: data)
        } catch {
            throw SupabaseError.invalidResponse
        }
    }

    @discardableResult
    private static func post(path: String, json: [String: Any], auth: String?) async throws -> Data {
        guard let base = baseURL,
              let url = URL(string: path, relativeTo: base) else { throw SupabaseError.missingConfig }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let auth { req.setValue("Bearer \(auth)", forHTTPHeaderField: "Authorization") }
        req.httpBody = try JSONSerialization.data(withJSONObject: json)
        let (data, resp) = try await URLSession.shared.data(for: req)
        try validate(resp: resp, data: data)
        return data
    }

    @discardableResult
    private static func postRest(path: String, json: [String: Any], auth: String, preferHeader: String) async throws -> Data {
        guard let base = baseURL,
              let url = URL(string: path, relativeTo: base) else { throw SupabaseError.missingConfig }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(auth)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(preferHeader, forHTTPHeaderField: "Prefer")
        req.httpBody = try JSONSerialization.data(withJSONObject: json)
        let (data, resp) = try await URLSession.shared.data(for: req)
        try validate(resp: resp, data: data)
        return data
    }

    private static func validate(resp: URLResponse, data: Data) throws {
        guard let http = resp as? HTTPURLResponse else { throw SupabaseError.invalidResponse }
        if (200..<300).contains(http.statusCode) { return }
        // Try to extract a friendly message
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let msg = (obj["msg"] ?? obj["message"] ?? obj["error_description"] ?? obj["error"]) as? String
            throw SupabaseError.server(msg ?? "Request failed (\(http.statusCode)).")
        }
        throw SupabaseError.server("Request failed (\(http.statusCode)).")
    }
}
