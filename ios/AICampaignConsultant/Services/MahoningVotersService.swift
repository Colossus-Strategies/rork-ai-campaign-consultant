//
//  MahoningVotersService.swift
//  AICampaignConsultant
//
//  Mahoning County voter stats. The overview / district / zip panels are
//  served by a single Supabase RPC (`get_mahoning_stats`) that returns one
//  JSON blob with everything pre-aggregated server-side — no more parallel
//  COUNT fan-out and no more statement timeouts.
//
//  The door-list builder still uses direct PostgREST queries because it
//  needs to filter/sort/page arbitrary subsets and return rows.
//

import Foundation

nonisolated struct MahoningOverview: Sendable {
    let total: Int
    let democrat: Int
    let republican: Int
    let unaffiliated: Int
}

nonisolated struct MahoningDistrictRow: Sendable, Identifiable {
    let congressional: String
    let house: String
    let senate: String
    let total: Int
    var id: String { "\(congressional)-\(house)-\(senate)" }
    var label: String { "CD-\(congressional) · HD-\(house)" }
}

nonisolated struct MahoningZipRow: Sendable, Identifiable {
    let zip: String
    let total: Int
    let democrat: Int
    let republican: Int
    let unaffiliated: Int
    var id: String { zip }
}

nonisolated enum DoorListParty: String, Sendable, CaseIterable, Identifiable {
    case all, democrat, republican, unaffiliated
    var id: String { rawValue }
    var label: String {
        switch self {
        case .all: return "All"
        case .democrat: return "Democrat"
        case .republican: return "Republican"
        case .unaffiliated: return "Unaffiliated"
        }
    }
}

nonisolated enum DoorListDistrict: String, Sendable, CaseIterable, Identifiable {
    case all, cd06, cd14, hd58, hd59
    var id: String { rawValue }
    var label: String {
        switch self {
        case .all: return "All"
        case .cd06: return "CD-06"
        case .cd14: return "CD-14"
        case .hd58: return "HD-58"
        case .hd59: return "HD-59"
        }
    }
}

nonisolated struct DoorListFilter: Sendable {
    var zips: Set<String> = []
    var party: DoorListParty = .all
    var district: DoorListDistrict = .all
}

nonisolated struct DoorListVoter: Sendable, Identifiable, Decodable {
    let sos_voterid: String?
    let first_name: String?
    let last_name: String?
    let residential_address: String?
    let city: String?
    let zip: String?
    let party_affiliation: String?
    var id: String { sos_voterid ?? UUID().uuidString }
    var fullName: String {
        let f = (first_name ?? "").trimmingCharacters(in: .whitespaces)
        let l = (last_name ?? "").trimmingCharacters(in: .whitespaces)
        let s = "\(f) \(l)".trimmingCharacters(in: .whitespaces)
        return s.isEmpty ? "Unknown" : s
    }
    var addressLine: String {
        let street = (residential_address ?? "").trimmingCharacters(in: .whitespaces)
        let cityPart = [city, zip].compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        if street.isEmpty { return cityPart }
        if cityPart.isEmpty { return street }
        return "\(street) · \(cityPart)"
    }
    var partyLetter: String {
        let p = (party_affiliation ?? "").uppercased()
        if p == "D" || p == "R" { return p }
        return "U"
    }
}

nonisolated enum MahoningVotersService {
    static let county = "MAHONING"

    /// The four CD/HD intersections in Mahoning County, all inside SSD-33.
    static let districts: [(cd: String, hd: String, sd: String)] = [
        ("06", "59", "33"),
        ("06", "58", "33"),
        ("14", "58", "33"),
        ("14", "59", "33"),
    ]

    /// Mahoning County zip codes (Youngstown metro + surrounding).
    /// We query each individually so we can rank without server-side
    /// aggregation. Zips with zero results are dropped.
    static let candidateZips: [String] = [
        "44502", "44503", "44504", "44505", "44506", "44507", "44509",
        "44510", "44511", "44512", "44514", "44515",
        "44406", "44436", "44442", "44446", "44460", "44473", "44484",
        "44483", "44490", "44609", "44619", "44644", "44651"
    ]

    // MARK: - RPC payload

    /// Shape of the JSON returned by `public.get_mahoning_stats()`.
    private struct StatsPayload: Decodable {
        let total_active: Int?
        let dem: Int?
        let rep: Int?
        let unaffiliated: Int?
        let cd06_hd59: Int?
        let cd06_hd58: Int?
        let cd14_hd58: Int?
        let cd14_hd59: Int?
        let top_zips: [ZipRow]?
        struct ZipRow: Decodable {
            let zip: String?
            let total: Int?
            let dem: Int?
            let rep: Int?
            let unaffiliated: Int?
        }
    }

    // MARK: - Public

    static func overview(session: SupabaseSession) async throws -> MahoningOverview {
        let s = try await stats(session: session)
        let t = s.total_active ?? 0
        let d = s.dem ?? 0
        let r = s.rep ?? 0
        let u = s.unaffiliated ?? max(0, t - d - r)
        return .init(total: t, democrat: d, republican: r, unaffiliated: u)
    }

    static func districtBreakdown(session: SupabaseSession) async throws -> [MahoningDistrictRow] {
        let s = try await stats(session: session)
        let rows: [MahoningDistrictRow] = [
            .init(congressional: "06", house: "59", senate: "33", total: s.cd06_hd59 ?? 0),
            .init(congressional: "06", house: "58", senate: "33", total: s.cd06_hd58 ?? 0),
            .init(congressional: "14", house: "58", senate: "33", total: s.cd14_hd58 ?? 0),
            .init(congressional: "14", house: "59", senate: "33", total: s.cd14_hd59 ?? 0),
        ]
        return rows.sorted { $0.total > $1.total }
    }

    static func zipBreakdown(session: SupabaseSession, topN: Int = 10) async throws -> [MahoningZipRow] {
        let s = try await stats(session: session)
        let rows = (s.top_zips ?? []).compactMap { z -> MahoningZipRow? in
            guard let zip = z.zip, !zip.isEmpty else { return nil }
            let t = z.total ?? 0
            let d = z.dem ?? 0
            let r = z.rep ?? 0
            let u = z.unaffiliated ?? max(0, t - d - r)
            return MahoningZipRow(zip: zip, total: t, democrat: d, republican: r, unaffiliated: u)
        }
        return Array(rows.sorted { $0.total > $1.total }.prefix(topN))
    }

    /// Calls `public.get_mahoning_stats()` and decodes its JSON payload.
    /// PostgREST RPCs that return a single composite/json value come back
    /// as either a bare object or a single-element array depending on how
    /// the function is declared — we handle both.
    private static func stats(session: SupabaseSession) async throws -> StatsPayload {
        guard SupabaseClient.isConfigured, let base = SupabaseClient.baseURL else {
            throw VoterDataError.notConfigured
        }
        let url = base.appendingPathComponent("/rest/v1/rpc/get_mahoning_stats")
        let bearer = try authenticatedBearer(session)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(SupabaseClient.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = Data("{}".utf8)
        req.timeoutInterval = 30

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw VoterDataError.decoding }
        if !(200..<300).contains(http.statusCode) {
            throw VoterDataError.http(http.statusCode, extractMessage(from: data))
        }
        let decoder = JSONDecoder()
        if let single = try? decoder.decode(StatsPayload.self, from: data) {
            return single
        }
        if let arr = try? decoder.decode([StatsPayload].self, from: data), let first = arr.first {
            return first
        }
        throw VoterDataError.decoding
    }

    // MARK: - Door List

    /// Counts active voters matching the door-list filter. Used to preview the
    /// list size before the user commits to fetching rows.
    static func doorListCount(
        session: SupabaseSession,
        filter: DoorListFilter
    ) async throws -> Int {
        try await count(session: session, extras: doorListExtras(filter))
    }

    /// Fetches up to `limit` active voters matching the door-list filter,
    /// ordered by zip then residential address so canvassers walk efficiently.
    static func doorList(
        session: SupabaseSession,
        filter: DoorListFilter,
        limit: Int = 500
    ) async throws -> [DoorListVoter] {
        guard SupabaseClient.isConfigured, let base = SupabaseClient.baseURL else {
            throw VoterDataError.notConfigured
        }
        var comps = URLComponents(
            url: base.appendingPathComponent("/rest/v1/voters"),
            resolvingAgainstBaseURL: false
        )
        var items: [URLQueryItem] = [
            .init(name: "select", value: "sos_voterid,first_name,last_name,residential_address,city,zip,party_affiliation"),
            .init(name: "voter_status", value: "eq.ACTIVE"),
            .init(name: "order", value: "zip.asc,residential_address.asc"),
            .init(name: "limit", value: "\(limit)"),
        ]
        for (k, v) in doorListExtras(filter) { items.append(.init(name: k, value: v)) }
        comps?.queryItems = items
        guard let url = comps?.url else { throw VoterDataError.decoding }

        // Always use the user's JWT for table reads — RLS on public.voters
        // is the only thing standing between the anon role and the data, so
        // we refuse to fall back to the anon key here.
        let bearer = try authenticatedBearer(session)
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue(SupabaseClient.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 60

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw VoterDataError.decoding }
        if !(200..<300).contains(http.statusCode) {
            throw VoterDataError.http(http.statusCode, extractMessage(from: data))
        }
        do {
            return try JSONDecoder().decode([DoorListVoter].self, from: data)
        } catch {
            throw VoterDataError.decoding
        }
    }

    /// Translates a DoorListFilter into PostgREST query items.
    /// Unaffiliated is modeled as "party not in (D,R)" since the SoS file leaves
    /// unaffiliated rows with blank/null `party_affiliation`.
    private static func doorListExtras(_ filter: DoorListFilter) -> [(String, String)] {
        var extras: [(String, String)] = []
        switch filter.party {
        case .all: break
        case .democrat: extras.append(("party_affiliation", "eq.D"))
        case .republican: extras.append(("party_affiliation", "eq.R"))
        case .unaffiliated:
            // PostgREST: party_affiliation is null OR not in (D,R)
            extras.append(("or", "(party_affiliation.is.null,and(party_affiliation.neq.D,party_affiliation.neq.R))"))
        }
        switch filter.district {
        case .all: break
        case .cd06: extras.append(("congressional_district", "eq.06"))
        case .cd14: extras.append(("congressional_district", "eq.14"))
        case .hd58: extras.append(("state_rep_district", "eq.58"))
        case .hd59: extras.append(("state_rep_district", "eq.59"))
        }
        if !filter.zips.isEmpty {
            let list = filter.zips.sorted().joined(separator: ",")
            extras.append(("zip", "in.(\(list))"))
        }
        return extras
    }

    // MARK: - HTTP

    /// PostgREST count helper, still used by the door-list builder to preview
    /// list size before fetching rows. Scoped to ACTIVE plus any extras.
    private static func count(
        session: SupabaseSession,
        extras: [(String, String)]
    ) async throws -> Int {
        guard SupabaseClient.isConfigured, let base = SupabaseClient.baseURL else {
            throw VoterDataError.notConfigured
        }
        var comps = URLComponents(
            url: base.appendingPathComponent("/rest/v1/voters"),
            resolvingAgainstBaseURL: false
        )
        var items: [URLQueryItem] = [
            .init(name: "select", value: "id"),
            .init(name: "voter_status", value: "eq.ACTIVE"),
        ]
        for (k, v) in extras { items.append(.init(name: k, value: v)) }
        comps?.queryItems = items
        guard let url = comps?.url else { throw VoterDataError.decoding }

        // GET (not HEAD) so PostgREST returns an error body we can surface
        // when something goes wrong (RLS deny, statement timeout, etc.).
        // We still keep the response tiny via `Range: items=0-0` and only
        // select the primary key column.
        let bearer = try authenticatedBearer(session)
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue(SupabaseClient.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        // count=planned uses the planner's estimate — orders of magnitude
        // cheaper than count=exact on a 150k+ row table, which was the
        // source of the 500s when several COUNTs fanned out at once.
        req.setValue("count=planned", forHTTPHeaderField: "Prefer")
        req.setValue("items=0-0", forHTTPHeaderField: "Range")
        req.timeoutInterval = 30

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw VoterDataError.decoding }
        if !(200..<300).contains(http.statusCode) && http.statusCode != 206 {
            throw VoterDataError.http(http.statusCode, extractMessage(from: data))
        }
        // Content-Range: "0-0/129551" (or "*/129551" when range is empty)
        if let cr = http.value(forHTTPHeaderField: "Content-Range"),
           let slash = cr.lastIndex(of: "/") {
            let tail = cr[cr.index(after: slash)...]
            return Int(tail) ?? 0
        }
        return 0
    }

    /// Returns the user's JWT or throws a clear error if the session is
    /// synthetic (demo / pending email confirmation). The anon role is NOT
    /// granted SELECT on `public.voters`, so silently falling back to it
    /// would just produce the 500 the user sees.
    private static func authenticatedBearer(_ session: SupabaseSession) throws -> String {
        if session.isSynthetic { throw VoterDataError.pendingConfirmation }
        return session.accessToken
    }

    /// Best-effort extraction of PostgREST's error message body so the UI
    /// shows the real cause (e.g. "permission denied for table voters",
    /// "canceling statement due to statement timeout") instead of just 500.
    private static func extractMessage(from data: Data) -> String? {
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for k in ["message", "error_description", "error", "hint", "details"] {
                if let s = obj[k] as? String, !s.isEmpty { return s }
            }
        }
        if let s = String(data: data, encoding: .utf8), !s.isEmpty {
            return String(s.prefix(240))
        }
        return nil
    }
}
