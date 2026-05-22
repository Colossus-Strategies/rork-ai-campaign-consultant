//
//  ProgressStore.swift
//  AICampaignConsultant
//
//  Tracks completion of deep-dive steps per user. Local cache in UserDefaults
//  for offline + first-paint; canonical state lives in Supabase
//  (`candidate_progress` table) so progress follows the user across devices.
//

import Foundation
import Observation

@Observable
final class ProgressStore {
    static let shared = ProgressStore()

    private let key = "colossus.progress.completedSteps.v1"
    private(set) var completed: Set<String> = []

    /// Active session is set by AuthViewModel when the user reaches `.ready`.
    /// When nil, mutations fall through to local-only cache.
    var session: SupabaseSession? = nil

    init() {
        if let arr = UserDefaults.standard.array(forKey: key) as? [String] {
            completed = Set(arr)
        }
    }

    func isComplete(_ stepId: String) -> Bool { completed.contains(stepId) }

    func setComplete(_ stepId: String, _ value: Bool) {
        if value { completed.insert(stepId) } else { completed.remove(stepId) }
        persistLocal()
        guard let session else { return }
        Task.detached {
            do {
                if value {
                    try await SupabaseClient.insertProgress(session: session, stepId: stepId)
                } else {
                    try await SupabaseClient.deleteProgress(session: session, stepId: stepId)
                }
            } catch {
                // Local cache already updated; surface failures silently for v1.
            }
        }
    }

    func completedCount(in topic: SubTopic) -> Int {
        topic.steps.reduce(0) { $0 + (isComplete($1.id) ? 1 : 0) }
    }

    func completionFraction(in module: CampaignModule) -> Double {
        let total = module.topics.reduce(0) { $0 + $1.steps.count }
        guard total > 0 else { return 0 }
        let done = module.topics.reduce(0) { $0 + completedCount(in: $1) }
        return Double(done) / Double(total)
    }

    // MARK: - Sync

    /// Called when the user signs in / app is restored with a session.
    /// Pulls server state, merges with any unsynced local entries, pushes
    /// the merged set back, and updates the in-memory cache.
    func attach(session: SupabaseSession) async {
        self.session = session
        do {
            let remote = Set(try await SupabaseClient.fetchProgress(session: session))
            let localOnly = completed.subtracting(remote)
            // Push anything we completed offline.
            for stepId in localOnly {
                try? await SupabaseClient.insertProgress(session: session, stepId: stepId)
            }
            let merged = remote.union(completed)
            await MainActor.run {
                self.completed = merged
                self.persistLocal()
            }
        } catch {
            // Stay on local cache.
        }
    }

    func detach() {
        session = nil
        completed.removeAll()
        UserDefaults.standard.removeObject(forKey: key)
    }

    private func persistLocal() {
        UserDefaults.standard.set(Array(completed), forKey: key)
    }
}
