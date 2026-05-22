//
//  LibraryStore.swift
//  AICampaignConsultant
//
//  Stores items the candidate saves from chat or modules (F07).
//  Local UserDefaults cache for offline + first-paint; canonical state lives
//  in Supabase (`candidate_library` table) so the binder follows the user.
//

import Foundation
import Observation

struct SavedItem: Identifiable, Codable, Hashable {
    enum Category: String, Codable, CaseIterable, Identifiable {
        case script = "Script"
        case talkingPoint = "Talking Point"
        case checklist = "Checklist"
        case strategy = "Strategy"
        case pressRelease = "Press Release"
        case other = "Other"
        var id: String { rawValue }
    }
    let id: UUID
    var name: String
    var category: Category
    var notes: String
    var body: String
    let createdAt: Date

    init(id: UUID = .init(), name: String, category: Category, notes: String = "", body: String, createdAt: Date = .init()) {
        self.id = id
        self.name = name
        self.category = category
        self.notes = notes
        self.body = body
        self.createdAt = createdAt
    }
}

@Observable
final class LibraryStore {
    static let shared = LibraryStore()

    private let key = "colossus.library.saved.v1"
    private(set) var items: [SavedItem] = []

    /// Active session is set by AuthViewModel on `.ready`. Mutations fall back
    /// to local-only when nil.
    var session: SupabaseSession? = nil

    init() {
        load()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        if let decoded = try? JSONDecoder().decode([SavedItem].self, from: data) {
            items = decoded.sorted { $0.createdAt > $1.createdAt }
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func add(_ item: SavedItem) {
        // Auto-rename on collision.
        var unique = item
        if items.contains(where: { $0.name == item.name }) {
            let stamp = DateFormatter.shortStamp.string(from: item.createdAt)
            unique = SavedItem(
                id: item.id,
                name: "\(item.name) · \(stamp)",
                category: item.category,
                notes: item.notes,
                body: item.body,
                createdAt: item.createdAt
            )
        }
        items.insert(unique, at: 0)
        save()
        Haptics.success()
        pushRemote(unique)
    }

    func remove(_ id: UUID) {
        items.removeAll { $0.id == id }
        save()
        guard let session else { return }
        Task.detached {
            try? await SupabaseClient.deleteLibraryItem(session: session, id: id.uuidString)
        }
    }

    func clearAll() {
        let ids = items.map(\.id)
        items.removeAll()
        save()
        guard let session else { return }
        Task.detached {
            for id in ids {
                try? await SupabaseClient.deleteLibraryItem(session: session, id: id.uuidString)
            }
        }
    }

    // MARK: - Sync

    func attach(session: SupabaseSession) async {
        self.session = session
        do {
            let rows = try await SupabaseClient.fetchLibrary(session: session)
            let remoteItems = rows.compactMap { Self.toItem($0) }
            let remoteIds = Set(remoteItems.map(\.id))

            // Local items that aren't on the server yet — push them.
            let localOnly = items.filter { !remoteIds.contains($0.id) }
            for item in localOnly {
                pushRemote(item)
            }

            // Merge: prefer remote ordering (server is source of truth), then
            // append any local-only that we just queued for upload so the user
            // doesn't see them disappear before the push completes.
            let merged = remoteItems + localOnly.filter { !remoteIds.contains($0.id) }
            await MainActor.run {
                self.items = merged.sorted { $0.createdAt > $1.createdAt }
                self.save()
            }
        } catch {
            // Stay on local cache.
        }
    }

    func detach() {
        session = nil
        items.removeAll()
        UserDefaults.standard.removeObject(forKey: key)
    }

    private func pushRemote(_ item: SavedItem) {
        guard let session else { return }
        let payload = (
            id: item.id.uuidString,
            name: item.name,
            category: item.category.rawValue,
            notes: item.notes,
            body: item.body,
            createdAt: Self.isoFormatter.string(from: item.createdAt)
        )
        Task.detached {
            try? await SupabaseClient.insertLibraryItem(
                session: session,
                id: payload.id,
                name: payload.name,
                category: payload.category,
                notes: payload.notes,
                body: payload.body,
                createdAt: payload.createdAt
            )
        }
    }

    private static func toItem(_ row: LibraryRow) -> SavedItem? {
        guard let uuid = UUID(uuidString: row.id) else { return nil }
        let category = SavedItem.Category(rawValue: row.category) ?? .other
        let createdAt = row.created_at.flatMap { isoFormatter.date(from: $0) } ?? Date()
        return SavedItem(
            id: uuid,
            name: row.name,
            category: category,
            notes: row.notes,
            body: row.body,
            createdAt: createdAt
        )
    }

    nonisolated(unsafe) static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}

private extension DateFormatter {
    static let shortStamp: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, h:mma"
        return f
    }()
}
