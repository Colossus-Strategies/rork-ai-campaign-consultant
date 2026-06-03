//
//  MessageQuotaService.swift
//  AICampaignConsultant
//
//  Per-user daily cap on AI chat messages. Each message your users send runs
//  Claude through the shared Rork AI credit pool, so a handful of heavy users
//  can drain the whole month's budget. This guard caps how many messages a
//  single user can send per calendar day, protecting the pool without
//  degrading model quality.
//
//  State is stored locally in UserDefaults, keyed by user id + day. It resets
//  automatically at the start of each new day (device-local time).
//

import Foundation

/// Tracks and enforces a per-user, per-day message allowance for the AI chat.
enum MessageQuotaService {
    /// Daily allowance for premium / trial / comp accounts.
    static let premiumDailyLimit: Int = 120

    /// Daily allowance for non-subscribed users.
    static let freeDailyLimit: Int = 25

    private static let storageKey = "colossus.chat.dailyQuota.v1"

    private struct Record: Codable {
        var day: String
        var count: Int
    }

    /// Day bucket key in the device's local calendar (YYYY-MM-DD).
    private static func todayKey() -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    /// Namespaced defaults key so different signed-in users don't share a tally.
    private static func defaultsKey(for userId: String) -> String {
        "\(storageKey).\(userId.isEmpty ? "anonymous" : userId)"
    }

    private static func currentRecord(for userId: String) -> Record {
        let key = defaultsKey(for: userId)
        let today = todayKey()
        if let data = UserDefaults.standard.data(forKey: key),
           let record = try? JSONDecoder().decode(Record.self, from: data),
           record.day == today {
            return record
        }
        // No record or it's from a previous day — start fresh.
        return Record(day: today, count: 0)
    }

    private static func save(_ record: Record, for userId: String) {
        let key = defaultsKey(for: userId)
        if let data = try? JSONEncoder().encode(record) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    /// The user's daily allowance given their entitlement state.
    static func dailyLimit(isPremium: Bool) -> Int {
        isPremium ? premiumDailyLimit : freeDailyLimit
    }

    /// Messages already used by this user today.
    static func usedToday(userId: String) -> Int {
        currentRecord(for: userId).count
    }

    /// Messages remaining today for this user.
    static func remaining(userId: String, isPremium: Bool) -> Int {
        max(0, dailyLimit(isPremium: isPremium) - usedToday(userId: userId))
    }

    /// Whether the user can send another message right now.
    static func canSend(userId: String, isPremium: Bool) -> Bool {
        remaining(userId: userId, isPremium: isPremium) > 0
    }

    /// Records one consumed message against today's tally.
    static func recordSend(userId: String) {
        var record = currentRecord(for: userId)
        record.count += 1
        save(record, for: userId)
    }
}
