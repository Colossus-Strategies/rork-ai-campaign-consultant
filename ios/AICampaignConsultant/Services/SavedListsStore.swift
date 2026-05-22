//
//  SavedListsStore.swift
//  AICampaignConsultant
//
//  UserDefaults-backed store for saved targeting lists. Scoped per user so
//  switching accounts on the same device doesn't leak lists between candidates.
//

import Foundation
import Observation

@Observable
final class SavedListsStore {
    static let shared = SavedListsStore()

    private(set) var lists: [SavedList] = []
    private var currentUserId: String = ""

    private init() {}

    private func key(for userId: String) -> String {
        "colossus.saved_lists.\(userId)"
    }

    /// Loads saved lists for the given user. Call when the District tab
    /// appears (and when the active session changes).
    func load(for userId: String) {
        currentUserId = userId
        let data = UserDefaults.standard.data(forKey: key(for: userId)) ?? Data()
        if let decoded = try? JSONDecoder().decode([SavedList].self, from: data) {
            lists = decoded.sorted { $0.updatedAt > $1.updatedAt }
        } else {
            lists = []
        }
    }

    private func persist() {
        guard !currentUserId.isEmpty else { return }
        if let data = try? JSONEncoder().encode(lists) {
            UserDefaults.standard.set(data, forKey: key(for: currentUserId))
        }
    }

    /// Inserts a new saved list at the top of the collection.
    func save(name: String, goal: TargetingGoal, filters: VoterFilters, lastCount: Int?) -> SavedList {
        let now = Date()
        let list = SavedList(
            id: UUID().uuidString,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? defaultName(for: goal) : name,
            goalRaw: goal.rawValue,
            filters: SavedFilters(from: filters),
            lastCount: lastCount,
            createdAt: now,
            updatedAt: now
        )
        lists.insert(list, at: 0)
        persist()
        return list
    }

    func updateCount(id: String, count: Int) {
        guard let idx = lists.firstIndex(where: { $0.id == id }) else { return }
        lists[idx].lastCount = count
        lists[idx].updatedAt = Date()
        // Keep most-recently-used at the top.
        let updated = lists.remove(at: idx)
        lists.insert(updated, at: 0)
        persist()
    }

    func rename(id: String, to newName: String) {
        guard let idx = lists.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        lists[idx].name = trimmed
        lists[idx].updatedAt = Date()
        persist()
    }

    func delete(id: String) {
        lists.removeAll { $0.id == id }
        persist()
    }

    private func defaultName(for goal: TargetingGoal) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return "\(goal.label) — \(f.string(from: Date()))"
    }
}
