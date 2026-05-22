//
//  RaceContextBadge.swift
//  AICampaignConsultant
//
//  Shared component C02 — Race-Context Badge.
//  Compact gold pill showing the candidate's race scope so the user
//  always sees the jurisdiction the AI is reasoning about.
//

import SwiftUI

struct RaceContextBadge: View {
    let profile: CandidateProfile
    var compact: Bool = false

    private var partyShort: String {
        switch profile.party {
        case .democrat: return "D"
        case .republican: return "R"
        case .independent: return "I"
        case .nonpartisan: return "NP"
        }
    }

    private var officeShort: String {
        let trimmed = profile.office.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { return trimmed }
        let loc = profile.location.trimmingCharacters(in: .whitespaces)
        return loc.isEmpty ? profile.raceType.label : loc
    }

    private var daysToElection: Int? {
        guard let date = profile.electionDate else { return nil }
        let cal = Calendar.current
        let d1 = cal.startOfDay(for: Date())
        let d2 = cal.startOfDay(for: date)
        let days = cal.dateComponents([.day], from: d1, to: d2).day ?? 0
        return days
    }

    private var isFinalPush: Bool {
        if let days = daysToElection, days >= 0, days <= 30 { return true }
        return false
    }

    private var countdownText: String {
        guard let days = daysToElection else { return "" }
        if days < 0 { return "Race day passed" }
        if days == 0 { return "Election day" }
        if isFinalPush { return "Final \(days)d push" }
        return "\(days)d out"
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(officeShort)
                .font(Theme.sans(11, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
            dot
            Text(partyShort)
                .font(Theme.sans(11, weight: .bold))
                .foregroundStyle(Theme.gold)
            dot
            Text(profile.role.rawValue)
                .font(Theme.sans(11, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
            if !countdownText.isEmpty {
                dot
                Text(countdownText)
                    .font(Theme.sans(11, weight: .bold))
                    .foregroundStyle(isFinalPush ? Color(hex: 0xff8c5a) : Theme.gold)
            }
        }
        .padding(.horizontal, compact ? 10 : 12)
        .padding(.vertical, compact ? 5 : 6)
        .background(Theme.inputBg)
        .overlay(
            Capsule()
                .stroke(isFinalPush ? Color(hex: 0xff8c5a).opacity(0.6) : Theme.goldFaint, lineWidth: 1)
        )
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Race context: \(officeShort), party \(partyShort), \(profile.role.rawValue). \(countdownText)")
    }

    private var dot: some View {
        Text("·").foregroundStyle(Theme.goldDim)
    }
}

#Preview {
    ZStack {
        Theme.bg.ignoresSafeArea()
        VStack(spacing: 16) {
            RaceContextBadge(profile: .preview())
            RaceContextBadge(profile: .previewFinalPush())
        }
    }
}

extension CandidateProfile {
    static func preview() -> CandidateProfile {
        CandidateProfile(
            name: "Sarah Mitchell",
            preferredName: "Sarah",
            raceType: RaceType.all[3],
            office: "OH-59",
            location: "Ohio · District 59",
            state: "Ohio",
            district: "59",
            party: .democrat,
            electionDate: Calendar.current.date(byAdding: .day, value: 176, to: Date()),
            role: .challenger
        )
    }

    static func previewFinalPush() -> CandidateProfile {
        var p = preview()
        p.electionDate = Calendar.current.date(byAdding: .day, value: 14, to: Date())
        return p
    }
}
