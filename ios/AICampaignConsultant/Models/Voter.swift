//
//  Voter.swift
//  AICampaignConsultant
//
//  Voter-data module models. Mirrors the JSON returned by the RPCs in
//  VoterDataSchema.sql. Everything here is decode-only and `nonisolated`
//  so the wire types can be parsed off the main actor.
//

import Foundation

// MARK: - District scope / summary

nonisolated struct DistrictSummary: Decodable, Sendable {
    nonisolated struct StatusCounts: Decodable, Sendable {
        let active: Int
        let confirmation: Int
        let cancelled: Int
    }
    nonisolated struct PartyCounts: Decodable, Sendable {
        let democrat: Int
        let republican: Int
        let unaffiliated: Int
        let other: Int

        var total: Int { democrat + republican + unaffiliated + other }
    }
    let state_code: String?
    let race_id: String?
    let district: String?
    let total_voters: Int
    let status: StatusCounts
    let party: PartyCounts
    /// ISO-8601 timestamp of MAX(updated_at) across voters in scope. Null when
    /// the district is empty (no ingest has run yet).
    let last_refresh_at: String?
}

// MARK: - Party breakdown (overall / precinct / age)

nonisolated struct PartyBucket: Decodable, Sendable, Identifiable {
    let precinct_code: String?
    let bucket: String?
    let dem: Int?
    let rep: Int?
    let total: Int?

    var id: String { precinct_code ?? bucket ?? UUID().uuidString }
    var label: String { precinct_code ?? bucket ?? "—" }
}

// MARK: - Turnout history

nonisolated struct TurnoutEntry: Decodable, Sendable, Identifiable {
    let election_date: String
    let voted: Int
    var id: String { election_date }
}

nonisolated struct TurnoutHistory: Decodable, Sendable {
    let eligible: Int
    let generals: [TurnoutEntry]
    let primaries: [TurnoutEntry]
}

// MARK: - Precincts

nonisolated struct PrecinctStat: Decodable, Sendable, Identifiable {
    let precinct_code: String?
    let voter_count: Int?
    let turnout_rate: Double?

    var id: String { precinct_code ?? UUID().uuidString }
}

// MARK: - Voters list

nonisolated struct VoterRow: Decodable, Sendable, Identifiable, Hashable {
    let id: String
    let first_name: String?
    let last_name: String?
    let age: Int?
    let party: String?
    let status: String?
    let precinct: String?
    let address: String?
    let city: String?
    let zip: String?
    let turnout_score: Int?

    var fullName: String {
        [first_name, last_name].compactMap { $0 }.joined(separator: " ").trimmingCharacters(in: .whitespaces)
    }
    var partyShort: String {
        guard let p = party?.uppercased(), let first = p.first else { return "—" }
        return String(first)
    }
}

nonisolated struct VoterPage: Decodable, Sendable {
    let total: Int
    let page: Int
    let page_size: Int
    let rows: [VoterRow]
}

// MARK: - Filters

struct VoterFilters: Equatable {
    var party: String? = nil          // "D" / "R" / "U" ...
    var status: String? = nil         // "ACTIVE" / "CONFIRMATION" / "CANCELLED"
    var precinct: String? = nil
    var ageMin: Int? = nil
    var ageMax: Int? = nil
    var turnoutMin: Int? = nil
    var turnoutMax: Int? = nil
    var search: String? = nil

    func toJSON() -> [String: Any] {
        var d: [String: Any] = [:]
        if let v = party, !v.isEmpty { d["party"] = v }
        if let v = status, !v.isEmpty { d["status"] = v }
        if let v = precinct, !v.isEmpty { d["precinct"] = v }
        if let v = ageMin { d["age_min"] = v }
        if let v = ageMax { d["age_max"] = v }
        if let v = turnoutMin { d["turnout_min"] = v }
        if let v = turnoutMax { d["turnout_max"] = v }
        if let v = search?.trimmingCharacters(in: .whitespaces), !v.isEmpty { d["search"] = v }
        return d
    }
}

// MARK: - Voter detail

nonisolated struct VoterHistoryRow: Decodable, Sendable, Identifiable {
    let voter_id: String?
    let election_date: String
    let election_type: String
    let party_voted: String?
    var id: String { election_date + "-" + election_type }
}

nonisolated struct VoterFull: Decodable, Sendable {
    let id: String
    let state_code: String?
    let external_voterid: String?
    let first_name: String?
    let middle_name: String?
    let last_name: String?
    let suffix: String?
    let dob: String?
    let registration_date: String?
    let party_affiliation: String?
    let voter_status: String?
    let county: String?
    let precinct_code: String?
    let congressional_district: String?
    let state_senate_district: String?
    let state_rep_district: String?
    let residential_address: String?
    let city: String?
    let zip: String?
}

nonisolated struct VoterDetail: Decodable, Sendable {
    let voter: VoterFull?
    let history: [VoterHistoryRow]
}

// MARK: - Ingest status

nonisolated struct IngestRunSummary: Decodable, Sendable, Identifiable {
    let run_id: String
    let started_at: String?
    let ended_at: String?
    let rows_upserted: Int?
    let history_upserted: Int?
    let failed_counties: Int?
    let success_counties: Int?
    let total_counties: Int?
    var id: String { run_id }
}

nonisolated struct IngestCountyRow: Decodable, Sendable, Identifiable {
    let county: String?
    let status: String?
    let rows_upserted: Int?
    let history_upserted: Int?
    let error: String?
    let started_at: String?
    let ended_at: String?
    var id: String { (county ?? "") + (started_at ?? "") }
}

// MARK: - Targeting goals

enum TargetingGoal: String, CaseIterable, Identifiable {
    case door_knock, phone_bank, persuasion, custom
    var id: String { rawValue }
    var label: String {
        switch self {
        case .door_knock: return "Door-Knock Walk List"
        case .phone_bank: return "Phone Bank List"
        case .persuasion: return "Persuasion Universe"
        case .custom:     return "Custom List"
        }
    }
    var subtitle: String {
        switch self {
        case .door_knock: return "High-propensity voters, sorted by precinct"
        case .phone_bank: return "Medium-propensity voters by phone"
        case .persuasion: return "Low-propensity, target party"
        case .custom:     return "Build your own filter set"
        }
    }
    var icon: String {
        switch self {
        case .door_knock: return "figure.walk"
        case .phone_bank: return "phone.fill"
        case .persuasion: return "person.2.fill"
        case .custom:     return "slider.horizontal.3"
        }
    }
}
