//
//  StoreViewModel.swift
//  AICampaignConsultant
//

import Foundation
import Observation
import RevenueCat

@Observable
@MainActor
final class StoreViewModel {
    var offerings: Offerings?
    var isPremium: Bool = false
    var isLoading: Bool = false
    var isPurchasing: Bool = false
    var error: String?

    // MARK: - Free Trial (1 hour, local)

    /// Length of the free trial granted on first paywall visit.
    static let trialDuration: TimeInterval = 60 * 60 // 1 hour
    private let trialStartKey = "colossus.trial.startDate.v1"

    /// When the user started the local 1-hour trial, if ever.
    private(set) var trialStartDate: Date?

    /// Drives countdown UI; ticked by an internal timer while the trial is active.
    var trialNow: Date = Date()
    private var trialTimerTask: Task<Void, Never>?

    /// Internal bypass accounts — sign in with one of these emails to skip
    /// the paywall and unlock all premium features. Edit this list to add
    /// or remove comp accounts. Matching is case-insensitive.
    private let bypassEmails: Set<String> = [
        "anthonystratis1888@gmail.com",
        "appreview@colossus-strategies.com"
    ]
    private(set) var isBypassed: Bool = false

    init() {
        if let ts = UserDefaults.standard.object(forKey: trialStartKey) as? Date {
            trialStartDate = ts
        }
        startTrialTickerIfNeeded()
        Task { await listenForUpdates() }
        Task { await fetchOfferings() }
    }

    // MARK: Trial helpers

    /// Whether the local 1-hour trial is currently active.
    var isTrialActive: Bool {
        guard let start = trialStartDate else { return false }
        return Date().timeIntervalSince(start) < Self.trialDuration
    }

    /// Whether the trial has been started at any point (active or expired).
    var hasStartedTrial: Bool { trialStartDate != nil }

    /// Seconds remaining in the trial (0 when inactive/expired).
    var trialSecondsRemaining: TimeInterval {
        guard let start = trialStartDate else { return 0 }
        let remaining = Self.trialDuration - trialNow.timeIntervalSince(start)
        return max(0, remaining)
    }

    /// Start the local 1-hour trial. No-op if already started.
    func startFreeTrial() {
        guard trialStartDate == nil else { return }
        let now = Date()
        trialStartDate = now
        UserDefaults.standard.set(now, forKey: trialStartKey)
        trialNow = now
        startTrialTickerIfNeeded()
        // Reflect entitlement immediately for gating.
        if !isPremium { isPremium = true }
    }

    private func startTrialTickerIfNeeded() {
        guard isTrialActive, trialTimerTask == nil else { return }
        trialTimerTask = Task { @MainActor [weak self] in
            while let self, self.isTrialActive, !Task.isCancelled {
                self.trialNow = Date()
                try? await Task.sleep(for: .seconds(1))
            }
            // Trial expired — drop premium unless purchased/bypassed.
            if let self {
                self.trialTimerTask = nil
                self.trialNow = Date()
                if !self.isBypassed {
                    let active = (try? await Purchases.shared.customerInfo().entitlements["premium"]?.isActive) ?? false
                    self.isPremium = active == true
                }
            }
        }
    }

    private func listenForUpdates() async {
        for await info in Purchases.shared.customerInfoStream {
            let active = info.entitlements["premium"]?.isActive == true
            self.isPremium = active || isBypassed || isTrialActive
        }
    }

    /// Grants premium access if the given email matches a bypass account.
    /// Safe to call repeatedly (no-op if email is nil/empty or not in the list).
    func applyBypass(email: String?) {
        guard let raw = email?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else { return }
        let normalized = raw.lowercased()
        let normalizedSet = Set(bypassEmails.map { $0.lowercased() })
        if normalizedSet.contains(normalized) {
            isBypassed = true
            isPremium = true
        }
    }

    /// Clear bypass state on sign-out so the next user isn't auto-unlocked.
    func clearBypass() {
        isBypassed = false
        // Re-evaluate against the real entitlement on next stream tick.
        isPremium = false
    }

    /// Manually grant bypass (used for TestFlight / review skip).
    func forceBypass() {
        isBypassed = true
        isPremium = true
    }

    /// True when running under TestFlight (sandbox receipt). Lets us safely
    /// expose a paywall-skip control to internal testers and App Review without
    /// affecting production App Store builds.
    static var isTestFlight: Bool {
        guard let url = Bundle.main.appStoreReceiptURL else { return false }
        return url.lastPathComponent == "sandboxReceipt"
    }

    func fetchOfferings() async {
        isLoading = true
        do {
            offerings = try await Purchases.shared.offerings()
        } catch {
            // Silently swallow background fetch failures. We only surface
            // purchase/restore errors when the user explicitly taps a
            // store action so the app never throws an unsolicited alert
            // (e.g. App Review machines without IAP configuration).
            #if DEBUG
            print("[StoreViewModel] offerings fetch failed: \(error.localizedDescription)")
            #endif
        }
        isLoading = false
    }

    /// Find the package matching a race type by packageId then productId.
    /// Searches the current offering first, then all offerings, and finally
    /// falls back to the first available package anywhere. This keeps the
    /// paywall functional even if no "current" offering is set in RevenueCat.
    func package(for race: RaceType) -> Package? {
        let pools: [[Package]] = {
            var out: [[Package]] = []
            if let current = offerings?.current {
                out.append(current.availablePackages)
            }
            if let all = offerings?.all.values {
                for off in all { out.append(off.availablePackages) }
            }
            return out
        }()

        for pool in pools {
            if let m = pool.first(where: { $0.identifier == race.packageId }) { return m }
        }
        for pool in pools {
            if let m = pool.first(where: { $0.storeProduct.productIdentifier == race.productId }) { return m }
        }
        for pool in pools {
            if let m = pool.first { return m }
        }
        return nil
    }

    /// Ensure offerings have been fetched. Re-fetches if missing or empty.
    @discardableResult
    func ensureOfferingsLoaded() async -> Bool {
        if let off = offerings, !off.all.isEmpty { return true }
        await fetchOfferings()
        return offerings?.all.isEmpty == false
    }

    func purchase(package: Package) async -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            if result.userCancelled { return false }
            let active = result.customerInfo.entitlements["premium"]?.isActive == true
            isPremium = active
            return active
        } catch ErrorCode.purchaseCancelledError {
            return false
        } catch ErrorCode.paymentPendingError {
            return false
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func restore() async -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let info = try await Purchases.shared.restorePurchases()
            let active = info.entitlements["premium"]?.isActive == true
            isPremium = active
            return active
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}
