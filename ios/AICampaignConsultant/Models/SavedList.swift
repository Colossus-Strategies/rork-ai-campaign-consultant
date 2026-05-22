//
//  SavedList.swift
//  AICampaignConsultant
//
//  Persisted "saved targeting list" — a named snapshot of a goal + filter
//  combination so candidates can re-run the same list later without
//  re-picking every filter.
//

import Foundation

/// Codable snapshot of `VoterFilters`. We keep this separate from the
/// runtime filter struct so additions to the runtime type don't break
/// previously-persisted lists.
nonisolated struct SavedFilters: Codable, Equatable, Sendable {
    var party: String?
    var status: String?
    var precinct: String?
    var ageMin: Int?
    var ageMax: Int?
    var turnoutMin: Int?
    var turnoutMax: Int?
    var search: String?

    init(from filters: VoterFilters) {
        self.party = filters.party
        self.status = filters.status
        self.precinct = filters.precinct
        self.ageMin = filters.ageMin
        self.ageMax = filters.ageMax
        self.turnoutMin = filters.turnoutMin
        self.turnoutMax = filters.turnoutMax
        self.search = filters.search
    }

    func toFilters() -> VoterFilters {
        var f = VoterFilters()
        f.party = party
        f.status = status
        f.precinct = precinct
        f.ageMin = ageMin
        f.ageMax = ageMax
        f.turnoutMin = turnoutMin
        f.turnoutMax = turnoutMax
        f.search = search
        return f
    }
}

nonisolated struct SavedList: Codable, Identifiable, Equatable, Sendable {
    let id: String
    var name: String
    var goalRaw: String
    var filters: SavedFilters
    var lastCount: Int?
    var createdAt: Date
    var updatedAt: Date

    var goal: TargetingGoal {
        TargetingGoal(rawValue: goalRaw) ?? .custom
    }
}
