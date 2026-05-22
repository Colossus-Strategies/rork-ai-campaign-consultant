//
//  RaceType.swift
//  AICampaignConsultant
//

import Foundation

struct RaceType: Identifiable, Hashable {
    let id: String
    let emoji: String
    let label: String
    let subtitle: String
    let price: String
    /// RevenueCat package lookup key (matches offering package identifier).
    let packageId: String
    /// Store product identifier (used as fallback to match packages).
    let productId: String

    // Single flat subscription across all race levels.
    static let proPackageId: String = "pro"
    static let proProductId: String = "campaign_pro_300"
    static let proPrice: String = "$300/mo"

    static let all: [RaceType] = [
        .init(id: "local", emoji: "🏛", label: "Local / Municipal",
              subtitle: "City Council, Mayor, School Board", price: proPrice,
              packageId: proPackageId, productId: proProductId),
        .init(id: "county", emoji: "🗳", label: "County Office",
              subtitle: "Commissioner, Clerk, Sheriff", price: proPrice,
              packageId: proPackageId, productId: proProductId),
        .init(id: "state", emoji: "📋", label: "State Rep / State Senate",
              subtitle: "State House or Senate district seat", price: proPrice,
              packageId: proPackageId, productId: proProductId),
        .init(id: "congress", emoji: "🏟", label: "Congressional",
              subtitle: "U.S. House or U.S. Senate", price: proPrice,
              packageId: proPackageId, productId: proProductId),
        .init(id: "statewide", emoji: "⭐", label: "Statewide Office",
              subtitle: "Governor, Attorney General, Sec. of State", price: proPrice,
              packageId: proPackageId, productId: proProductId),
    ]

    static func find(id: String) -> RaceType? {
        all.first { $0.id == id }
    }
}

enum Party: String, CaseIterable, Identifiable, Hashable {
    case democrat = "Democrat"
    case republican = "Republican"
    case independent = "Independent"
    case nonpartisan = "Nonpartisan"
    var id: String { rawValue }
}

enum CandidateRole: String, CaseIterable, Identifiable, Hashable {
    case challenger = "Challenger"
    case incumbent = "Incumbent"
    case openSeat = "Open seat"
    var id: String { rawValue }
}

struct CandidateProfile {
    var name: String
    var preferredName: String
    var raceType: RaceType
    var office: String
    var location: String
    var state: String
    var district: String
    var party: Party
    var electionDate: Date?
    var role: CandidateRole

    /// Name used when addressing the candidate in chat.
    var displayName: String {
        let p = preferredName.trimmingCharacters(in: .whitespaces)
        if !p.isEmpty { return p }
        return name.split(separator: " ").first.map(String.init) ?? name
    }

    var firstName: String { displayName }
}

extension CandidateProfile {
    init?(row: ProfileRow) {
        guard let race = RaceType.find(id: row.race_id) else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let date: Date? = row.election_date.flatMap { formatter.date(from: $0) }

        self.name = row.candidate_name
        self.preferredName = row.preferred_name ?? ""
        self.raceType = race
        self.office = row.office ?? ""
        self.location = row.location ?? ""
        self.state = row.state ?? ""
        self.district = row.district ?? ""
        self.party = Party(rawValue: row.party ?? "") ?? .nonpartisan
        self.electionDate = date
        self.role = CandidateRole(rawValue: row.role ?? "") ?? .challenger
    }
}

/// In-flight onboarding data, before account submission to Supabase.
struct OnboardingDraft {
    var name: String = ""
    var preferredName: String = ""
    var race: RaceType? = nil
    var office: String = ""
    var location: String = ""
    var state: String = ""
    var district: String = ""
    var party: Party = .nonpartisan
    var electionDate: Date? = nil
    var role: CandidateRole = .challenger

    var firstName: String {
        let p = preferredName.trimmingCharacters(in: .whitespaces)
        if !p.isEmpty { return p }
        let f = name.split(separator: " ").first.map(String.init) ?? name
        return f.trimmingCharacters(in: .whitespaces)
    }

    func toPayload(phone: String) -> [String: Any] {
        let isoDate: String? = electionDate.map { date in
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withFullDate]
            return f.string(from: date)
        }
        var payload: [String: Any] = [
            "candidate_name": name,
            "preferred_name": preferredName,
            "race_id": race?.id ?? "",
            "office": office,
            "location": location,
            "state": state,
            "district": district,
            "party": party.rawValue,
            "role": role.rawValue,
            "phone": phone,
            "approved": false,
        ]
        if let isoDate { payload["election_date"] = isoDate }
        return payload
    }
}
