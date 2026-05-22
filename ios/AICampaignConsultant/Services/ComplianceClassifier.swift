//
//  ComplianceClassifier.swift
//  AICampaignConsultant
//
//  Heuristic classifier used by chat (F06) to decide whether a question
//  or AI answer touches campaign-finance or compliance rules. If so, the
//  Compliance Disclaimer Card is rendered alongside the response.
//

import Foundation

nonisolated enum ComplianceClassifier {
    /// Keywords that strongly imply a compliance-domain question.
    private static let triggers: [String] = [
        "contribution limit",
        "donation limit",
        "donor limit",
        "in-kind",
        "in kind",
        "coordination",
        "coordinate with",
        "pac ",
        " pac.",
        "super pac",
        "party committee",
        "disclaimer",
        "paid for by",
        "report deadline",
        "filing deadline",
        "fec",
        "campaign finance",
        "treasurer",
        "501(c)",
        "lobbying",
        "bundling",
        "foreign national",
        "personal funds",
        "loan to campaign",
        "reimburse",
        "straw donor",
        "earmark",
        "joint fundraising",
    ]

    /// Dollar mention + donate verbs = fallback trigger per spec.
    static func isCompliance(_ text: String) -> Bool {
        let lower = text.lowercased()
        for t in triggers where lower.contains(t) {
            return true
        }
        let hasDollar = lower.contains("$") || lower.range(of: #"\b\d+\s*(?:dollars|usd)\b"#, options: .regularExpression) != nil
        let donateWords = ["donate", "contribute", "contribution", "donor", "give to my campaign", "fundrais"]
        if hasDollar, donateWords.contains(where: { lower.contains($0) }) {
            return true
        }
        return false
    }

    /// Builds a jurisdiction-context string for the badge inside the card.
    static func jurisdictionContext(for profile: CandidateProfile) -> String {
        let scope: String
        switch profile.raceType.id {
        case "congress", "statewide":
            scope = "FEC + \(profile.state.isEmpty ? "state" : profile.state)"
        default:
            scope = profile.state.isEmpty ? "state + local" : profile.state
        }
        let where_ = !profile.district.isEmpty ? "\(profile.state)-\(profile.district)" : (profile.office.isEmpty ? profile.location : profile.office)
        let prefix = where_.trimmingCharacters(in: .whitespacesAndNewlines)
        return prefix.isEmpty ? scope : "\(prefix) · \(scope)"
    }

    static func verifyWith(for profile: CandidateProfile) -> ComplianceVerifyWith {
        switch profile.raceType.id {
        case "congress", "statewide": return .treasurer
        default: return .stateOffice
        }
    }
}
