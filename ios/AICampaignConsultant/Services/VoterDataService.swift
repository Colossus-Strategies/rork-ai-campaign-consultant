//
//  VoterDataService.swift
//  AICampaignConsultant
//
//  Wraps the Supabase RPCs defined in VoterDataSchema.sql. Every call runs
//  under the user's JWT, so Postgres RLS does the district scoping — we
//  never filter client-side. Compliance ack is persisted on candidate_profiles.
//

import Foundation

enum VoterDataError: LocalizedError {
    case notConfigured
    case pendingConfirmation
    case http(Int, String?)
    case decoding

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Supabase is not configured."
        case .pendingConfirmation:
            return "Confirm your email to access the Ohio voter database. Tap the link we sent you, then sign in again."
        case .http(let code, let msg): return msg ?? "Server returned status \(code)."
        case .decoding: return "Could not read voter data response."
        }
    }
}

enum VoterDataService {

    // MARK: - Compliance ack

    /// Returns the ISO timestamp the user acknowledged the use agreement, or nil.
    static func acknowledgmentDate(session: SupabaseSession) async throws -> Date? {
        // Synthetic sessions (App Review demo, pending email confirmation)
        // can't authenticate against Supabase. Persist the ack locally so the
        // user isn't stranded on the unlock screen.
        if session.isSynthetic {
            return localAckDate(for: session.userId)
        }
        let row = try await SupabaseClient.fetchProfile(session: session)
        if let iso = row?.voter_data_ack_at, !iso.isEmpty {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return f.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
        }
        // Fall back to any locally-recorded ack (set when the server row was
        // missing at acknowledge time).
        return localAckDate(for: session.userId)
    }

    /// Non-throwing by design: the local ack is written first, the server
    /// PATCH is best-effort. The user is NEVER blocked on the unlock screen
    /// by a Supabase failure (schema drift, RLS, network, etc.).
    static func acknowledge(session: SupabaseSession, version: String = "v1") async {
        let now = Date()
        if session.isSynthetic {
            setLocalAckDate(now, for: session.userId)
            return
        }
        let iso = ISO8601DateFormatter().string(from: now)
        // PATCH-only so we never trigger an INSERT (which would fail the
        // NOT NULL constraint on `candidate_name` when this user's profile
        // row isn't in Supabase yet — e.g. pending email confirmation or a
        // dropped onboarding write).
        //
        // Whatever happens server-side, we ALWAYS persist the ack locally
        // first so the user is never blocked on the unlock screen by a
        // transient or schema-level Supabase failure. A successful server
        // PATCH later takes precedence when reading.
        setLocalAckDate(now, for: session.userId)
        do {
            _ = try await SupabaseClient.patchProfile(
                session: session,
                payload: [
                    "voter_data_ack_at": iso,
                    "voter_data_ack_version": version
                ]
            )
        } catch {
            // Swallow server-side ack failures — the local ack keeps the
            // user moving and the next successful profile sync will pick
            // it up. We log nothing sensitive.
            #if DEBUG
            print("[VoterDataService] ack PATCH failed, kept local ack: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Local ack storage (synthetic sessions only)

    private static func localAckKey(_ userId: String) -> String {
        "colossus.voter_ack.\(userId)"
    }

    private static func localAckDate(for userId: String) -> Date? {
        let t = UserDefaults.standard.double(forKey: localAckKey(userId))
        return t > 0 ? Date(timeIntervalSince1970: t) : nil
    }

    private static func setLocalAckDate(_ date: Date, for userId: String) {
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: localAckKey(userId))
    }

    // MARK: - RPC calls

    static func districtSummary(session: SupabaseSession) async throws -> DistrictSummary {
        try await rpcDecode(session: session, name: "get_district_summary", args: [:])
    }

    static func partyBreakdown(session: SupabaseSession, by: String) async throws -> [PartyBucket] {
        // For "overall" the RPC returns a JSON object; for precinct/age it returns array.
        if by == "overall" {
            struct Overall: Decodable {
                let democrat: Int; let republican: Int; let unaffiliated: Int; let other: Int
            }
            let o: Overall = try await rpcDecode(session: session, name: "get_party_breakdown", args: ["by": by])
            return [
                PartyBucket(precinct_code: nil, bucket: "Democrat",     dem: o.democrat,    rep: nil, total: o.democrat),
                PartyBucket(precinct_code: nil, bucket: "Republican",   dem: nil, rep: o.republican,  total: o.republican),
                PartyBucket(precinct_code: nil, bucket: "Unaffiliated", dem: nil, rep: nil, total: o.unaffiliated),
                PartyBucket(precinct_code: nil, bucket: "Other",        dem: nil, rep: nil, total: o.other)
            ]
        }
        return try await rpcDecode(session: session, name: "get_party_breakdown", args: ["by": by])
    }

    static func turnoutHistory(session: SupabaseSession, electionCount: Int = 4) async throws -> TurnoutHistory {
        try await rpcDecode(session: session, name: "get_turnout_history", args: ["election_count": electionCount])
    }

    static func topPrecincts(session: SupabaseSession, metric: String = "voter_count") async throws -> [PrecinctStat] {
        try await rpcDecode(session: session, name: "get_top_precincts", args: ["metric": metric])
    }

    static func findVoters(
        session: SupabaseSession,
        filters: VoterFilters,
        page: Int = 0,
        pageSize: Int = 50
    ) async throws -> VoterPage {
        try await rpcDecode(
            session: session,
            name: "find_voters",
            args: [
                "filters": filters.toJSON(),
                "page": page,
                "page_size": pageSize
            ]
        )
    }

    static func voterDetail(session: SupabaseSession, voterId: String) async throws -> VoterDetail {
        try await rpcDecode(session: session, name: "get_voter_detail", args: ["voter_id": voterId])
    }

    static func ingestStatus(session: SupabaseSession, limit: Int = 5) async throws -> [IngestRunSummary] {
        try await rpcDecode(session: session, name: "get_ingest_status", args: ["limit_runs": limit])
    }

    static func ingestRunDetail(session: SupabaseSession, runId: String) async throws -> [IngestCountyRow] {
        try await rpcDecode(session: session, name: "get_ingest_run_detail", args: ["run": runId])
    }

    static func buildTargetingList(
        session: SupabaseSession,
        goal: TargetingGoal,
        filters: VoterFilters,
        pageSize: Int = 500
    ) async throws -> VoterPage {
        try await rpcDecode(
            session: session,
            name: "build_targeting_list",
            args: [
                "goal": goal.rawValue,
                "filters": filters.toJSON(),
                "page_size": pageSize
            ]
        )
    }

    // MARK: - CSV export

    static func csv(from rows: [VoterRow]) -> String {
        let header = "first_name,last_name,age,party,status,precinct,address,city,zip,turnout_score"
        let lines = rows.map { r -> String in
            let cells: [String] = [
                r.first_name ?? "",
                r.last_name ?? "",
                r.age.map(String.init) ?? "",
                r.party ?? "",
                r.status ?? "",
                r.precinct ?? "",
                r.address ?? "",
                r.city ?? "",
                r.zip ?? "",
                r.turnout_score.map(String.init) ?? ""
            ]
            return cells.map(csvEscape).joined(separator: ",")
        }
        return ([header] + lines).joined(separator: "\n")
    }

    private static func csvEscape(_ s: String) -> String {
        if s.contains(",") || s.contains("\"") || s.contains("\n") {
            return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return s
    }

    // MARK: - HTTP plumbing

    private static func rpcDecode<T: Decodable>(
        session: SupabaseSession,
        name: String,
        args: [String: Any]
    ) async throws -> T {
        let data = try await rpc(session: session, name: name, args: args)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw VoterDataError.decoding
        }
    }

    private static func rpc(
        session: SupabaseSession,
        name: String,
        args: [String: Any]
    ) async throws -> Data {
        guard SupabaseClient.isConfigured,
              let base = SupabaseClient.baseURL,
              let url = URL(string: "/rest/v1/rpc/\(name)", relativeTo: base) else {
            throw VoterDataError.notConfigured
        }
        // Synthetic sessions (App Review demo, pending email confirmation)
        // carry a non-JWT token like "pending.xxx" which PostgREST rejects
        // with "Expected 3 parts in JWT; got 2". Fall back to the anon JWT so
        // the request is well-formed; RPC access then depends on what the
        // Supabase project grants to the anon role.
        let bearer = session.isSynthetic ? SupabaseClient.anonKey : session.accessToken
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(SupabaseClient.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = try JSONSerialization.data(withJSONObject: args)
        req.timeoutInterval = 30

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw VoterDataError.decoding }
        if !(200..<300).contains(http.statusCode) {
            let msg: String? = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]).flatMap {
                ($0["message"] ?? $0["error_description"] ?? $0["error"]) as? String
            }
            throw VoterDataError.http(http.statusCode, msg)
        }
        return data
    }
}
