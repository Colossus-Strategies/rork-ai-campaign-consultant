//
//  MahoningVotersService.swift
//  AICampaignConsultant
//
//  Live Mahoning County voter stats pulled directly from public.voters via
//  PostgREST count=exact HEAD requests. No schema changes — every panel is
//  a small set of parallel COUNT queries scoped to county=MAHONING and
//  voter_status=ACTIVE. RLS still enforces who can read.
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

    // MARK: - Public

    static func overview(session: SupabaseSession) async throws -> MahoningOverview {
        async let total = count(session: session, extras: [])
        async let dem   = count(session: session, extras: [("party_affiliation", "eq.D")])
        async let rep   = count(session: session, extras: [("party_affiliation", "eq.R")])
        let t = try await total
        let d = try await dem
        let r = try await rep
        // Anyone not D or R is treated as Unaffiliated — matches how OH SoS
        // ships the file (blank party = unaffiliated).
        let una = max(0, t - d - r)
        return .init(total: t, democrat: d, republican: r, unaffiliated: una)
    }

    static func districtBreakdown(session: SupabaseSession) async throws -> [MahoningDistrictRow] {
        try await withThrowingTaskGroup(of: MahoningDistrictRow.self) { group in
            for d in districts {
                group.addTask {
                    let n = try await count(session: session, extras: [
                        ("congressional_district", "eq.\(d.cd)"),
                        ("state_rep_district", "eq.\(d.hd)"),
                        ("state_senate_district", "eq.\(d.sd)"),
                    ])
                    return MahoningDistrictRow(congressional: d.cd, house: d.hd, senate: d.sd, total: n)
                }
            }
            var rows: [MahoningDistrictRow] = []
            for try await r in group { rows.append(r) }
            return rows.sorted { $0.total > $1.total }
        }
    }

    static func zipBreakdown(session: SupabaseSession, topN: Int = 10) async throws -> [MahoningZipRow] {
        let rows = try await withThrowingTaskGroup(of: MahoningZipRow?.self) { group -> [MahoningZipRow] in
            for zip in candidateZips {
                group.addTask {
                    async let total = count(session: session, extras: [("zip", "eq.\(zip)")])
                    async let dem   = count(session: session, extras: [("zip", "eq.\(zip)"), ("party_affiliation", "eq.D")])
                    async let rep   = count(session: session, extras: [("zip", "eq.\(zip)"), ("party_affiliation", "eq.R")])
                    let t = try await total
                    if t == 0 { return nil }
                    let d = try await dem
                    let r = try await rep
                    let u = max(0, t - d - r)
                    return MahoningZipRow(zip: zip, total: t, democrat: d, republican: r, unaffiliated: u)
                }
            }
            var out: [MahoningZipRow] = []
            for try await r in group { if let r { out.append(r) } }
            return out
        }
        return Array(rows.sorted { $0.total > $1.total }.prefix(topN))
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

        let bearer = session.isSynthetic ? SupabaseClient.anonKey : session.accessToken
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue(SupabaseClient.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 60

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw VoterDataError.decoding }
        if !(200..<300).contains(http.statusCode) {
            throw VoterDataError.http(http.statusCode, nil)
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

    /// Issues a PostgREST HEAD request with `Prefer: count=exact` against
    /// public.voters, scoped to MAHONING / ACTIVE, plus any extra filters.
    /// Returns the parsed `Content-Range` total.
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

        let bearer = session.isSynthetic ? SupabaseClient.anonKey : session.accessToken
        var req = URLRequest(url: url)
        req.httpMethod = "HEAD"
        req.setValue(SupabaseClient.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        req.setValue("count=exact", forHTTPHeaderField: "Prefer")
        req.setValue("items=0-0", forHTTPHeaderField: "Range")
        req.timeoutInterval = 30

        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw VoterDataError.decoding }
        if !(200..<300).contains(http.statusCode) && http.statusCode != 206 {
            throw VoterDataError.http(http.statusCode, nil)
        }
        // Content-Range: "0-0/129551" (or "*/129551" when range is empty)
        if let cr = http.value(forHTTPHeaderField: "Content-Range"),
           let slash = cr.lastIndex(of: "/") {
            let tail = cr[cr.index(after: slash)...]
            return Int(tail) ?? 0
        }
        return 0
    }
}
