import Foundation
import StoreKit

/// The single source of truth for Premium status — real StoreKit 2
/// entitlements resolved into a `PremiumState` by `PremiumStateResolver`.
/// Every existing `@AppStorage("isPremium")` read across the app
/// (`PremiumGate`, `ReportsSection`, receipts, Activity, Insights) keeps
/// working unchanged: this is the one place that writes that key. Apple's
/// on-device entitlement system means this app never sees a name, email,
/// or card number — only verified transactions.
///
/// There's no server, so App Store Server Notifications (e.g. `REVOKE` when
/// someone leaves a family) aren't available. Entitlements are re-read at
/// launch, whenever the app returns to the foreground, and on every
/// `Transaction.updates` / `Status.updates` event while it's running.
@MainActor
final class StoreManager: ObservableObject {
    static let shared = StoreManager()

    static let productIDsByPlan: [PremiumPlan: String] = [
        .monthly: "com.dimera.app.premium.monthly",
        .yearly: "com.dimera.app.premium.yearly",
        .family: "com.dimera.app.premium.family.yearly"
    ]
    static var productIDs: Set<String> { Set(productIDsByPlan.values) }

    static func plan(for productID: String) -> PremiumPlan? {
        productIDsByPlan.first { $0.value == productID }?.key
    }

    enum PurchaseOutcome: Equatable {
        case success, cancelled, pending
    }

    enum StoreError: Error {
        case failedVerification
        case productUnavailable
        case timedOut
    }

    @Published private(set) var products: [PremiumPlan: Product] = [:]
    @Published private(set) var isLoadingProducts = true
    @Published private(set) var state: PremiumState
    @Published private(set) var renewal: RenewalSummary?
    @Published private(set) var canMakePayments = AppStore.canMakePayments
    /// Set when a Premium change arrives outside the paywall that deserves a
    /// welcome — a family member's first access, or an approved Ask to Buy.
    /// `RootTabView` presents it and calls `welcomeShown()`.
    @Published private(set) var pendingWelcome: PremiumWelcomeVariant?

    private var transactionListener: Task<Void, Never>?
    private var statusListener: Task<Void, Never>?
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let isPremium = "isPremium"
        static let state = "premiumState"
        static let awaitingApproval = "premiumAwaitingApproval"
        static let hasSeenFamilyMemberWelcome = "hasSeenFamilyMemberWelcome"
        static let debugOverride = "debugPremiumStateOverride"
    }

    private init() {
        // The persisted state makes the very first frame after a cold launch
        // correct before the async refresh finishes. Installs from before
        // `PremiumState` existed only have the old Bool — and monthly was
        // the only product then.
        if let data = defaults.data(forKey: Keys.state),
           let saved = try? JSONDecoder().decode(PremiumState.self, from: data) {
            state = saved
        } else {
            state = defaults.bool(forKey: Keys.isPremium) ? .individual(.monthly) : .free
        }
    }

    var familyPlanAvailable: Bool { products[.family]?.isFamilyShareable == true }

    var subscriptionGroupID: String? {
        products.values.lazy.compactMap { $0.subscription?.subscriptionGroupID }.first
    }

    /// Called once from `DimeraApp` at launch.
    func start() {
        guard transactionListener == nil else { return }
        transactionListener = listenForTransactions()
        statusListener = listenForStatusUpdates()
        Task {
            await loadProducts()
            await refreshEntitlement(announce: true)
        }
    }

    /// Called when the app returns to the foreground — family membership
    /// and sharing settings can change while Dimera is in the background.
    func refresh() async {
        canMakePayments = AppStore.canMakePayments
        await refreshEntitlement(announce: true)
    }

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        guard let loaded = try? await Product.products(for: Self.productIDs) else { return }
        var byPlan: [PremiumPlan: Product] = [:]
        for product in loaded {
            if let plan = Self.plan(for: product.id) { byPlan[plan] = product }
        }
        products = byPlan
    }

    @discardableResult
    func purchase(_ plan: PremiumPlan) async throws -> PurchaseOutcome {
        if products[plan] == nil { await loadProducts() }
        guard let product = products[plan] else { throw StoreError.productUnavailable }

        switch try await product.purchase() {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await refreshEntitlement(announce: false)
            return .success
        case .userCancelled:
            return .cancelled
        case .pending:
            // Ask to Buy: the approved transaction arrives later through
            // `Transaction.updates`, possibly in a later session.
            defaults.set(true, forKey: Keys.awaitingApproval)
            return .pending
        @unknown default:
            return .cancelled
        }
    }

    /// `AppStore.sync()` has no built-in timeout and can hang indefinitely
    /// with no connectivity, so it races a timer rather than leaving the
    /// caller's loading state spinning forever.
    func restorePurchases() async throws {
        try await withTimeout(seconds: 15) {
            try await AppStore.sync()
        }
        await refreshEntitlement(announce: false)
    }

    func welcomeShown() {
        if pendingWelcome == .familyMember {
            defaults.set(true, forKey: Keys.hasSeenFamilyMemberWelcome)
        }
        pendingWelcome = nil
    }

    // MARK: - Entitlements

    private func refreshEntitlement(announce: Bool) async {
        var snapshots: [EntitlementSnapshot] = []
        // Qualified `StoreKit.Transaction` throughout this file — this app
        // already has its own `Transaction` model (a logged expense or
        // income), and an unqualified reference would resolve to that.
        for await result in StoreKit.Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result),
                  let plan = Self.plan(for: transaction.productID) else { continue }
            snapshots.append(EntitlementSnapshot(
                plan: plan,
                source: Self.source(for: transaction.ownershipType),
                expirationDate: transaction.expirationDate,
                revocationDate: transaction.revocationDate,
                isUpgraded: transaction.isUpgraded
            ))
        }
        apply(PremiumStateResolver.resolve(snapshots, now: Date()), announce: announce)
        await refreshRenewal()
    }

    private static func source(for ownership: StoreKit.Transaction.OwnershipType) -> AccessSource {
        switch ownership {
        case .purchased: return .purchased
        case .familyShared: return .familyShared
        default: return .other
        }
    }

    private func apply(_ resolved: PremiumState, announce: Bool) {
        var newState = resolved
        #if DEBUG
        if let override = debugOverride { newState = override }
        #endif

        if announce && newState.isPremium {
            if case .familyMember = newState, !defaults.bool(forKey: Keys.hasSeenFamilyMemberWelcome) {
                pendingWelcome = .familyMember
            } else if defaults.bool(forKey: Keys.awaitingApproval) {
                pendingWelcome = PremiumWelcomeVariant(state: newState)
            }
        }
        if newState.isPremium {
            defaults.set(false, forKey: Keys.awaitingApproval)
        }

        state = newState
        defaults.set(newState.isPremium, forKey: Keys.isPremium)
        if let data = try? JSONEncoder().encode(newState) {
            defaults.set(data, forKey: Keys.state)
        }
    }

    /// Only the subscription this person actually pays for — with Family
    /// Sharing on, one group can return several statuses (e.g. an expired
    /// own subscription next to an active family-shared one).
    private func refreshRenewal() async {
        #if DEBUG
        if let override = debugOverride {
            renewal = override.canManage ? .renews(Date().addingTimeInterval(30 * 86_400)) : nil
            return
        }
        #endif
        guard let groupID = subscriptionGroupID,
              let statuses = try? await Product.SubscriptionInfo.status(for: groupID) else {
            renewal = nil
            return
        }
        let relevantStates: [Product.SubscriptionInfo.RenewalState] = [.subscribed, .inGracePeriod, .inBillingRetryPeriod]
        for status in statuses where relevantStates.contains(status.state) {
            guard case .verified(let transaction) = status.transaction,
                  transaction.ownershipType == .purchased,
                  case .verified(let info) = status.renewalInfo,
                  let plan = Self.plan(for: transaction.productID) else { continue }
            renewal = RenewalSummary.make(
                currentPlan: plan,
                willAutoRenew: info.willAutoRenew,
                renewalDate: info.renewalDate ?? transaction.expirationDate,
                nextPlan: info.autoRenewPreference.flatMap(Self.plan(for:)),
                isInBillingRetry: status.state == .inBillingRetryPeriod,
                isInGracePeriod: status.state == .inGracePeriod
            )
            return
        }
        renewal = nil
    }

    // MARK: - Listeners

    /// Renewals, refunds, Ask to Buy approvals, offer-code redemptions,
    /// purchases on another device, and Family Sharing grants/revocations.
    private func listenForTransactions() -> Task<Void, Never> {
        Task {
            for await update in StoreKit.Transaction.updates {
                if let transaction = try? checkVerified(update) {
                    await transaction.finish()
                }
                await refreshEntitlement(announce: true)
            }
        }
    }

    /// Turning auto-renew off or on creates no transaction — only a status
    /// change — so Settings' "Renews"/"Ends" line needs this listener too.
    private func listenForStatusUpdates() -> Task<Void, Never> {
        Task {
            for await _ in Product.SubscriptionInfo.Status.updates {
                await refreshEntitlement(announce: true)
            }
        }
    }

    // MARK: - Helpers

    private func withTimeout<T: Sendable>(
        seconds: TimeInterval,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw StoreError.timedOut
            }
            guard let result = try await group.next() else { throw StoreError.timedOut }
            group.cancelAll()
            return result
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Debug

    #if DEBUG
    private var debugOverride: PremiumState? {
        guard let data = defaults.data(forKey: Keys.debugOverride) else { return nil }
        return try? JSONDecoder().decode(PremiumState.self, from: data)
    }

    /// Replaces the old "Simulate Premium" toggle. `nil` returns to real
    /// StoreKit entitlements.
    func setDebugOverride(_ override: PremiumState?) {
        if let override, let data = try? JSONEncoder().encode(override) {
            defaults.set(data, forKey: Keys.debugOverride)
        } else {
            defaults.removeObject(forKey: Keys.debugOverride)
        }
        Task { await refreshEntitlement(announce: false) }
    }

    var currentDebugOverride: PremiumState? { debugOverride }
    #endif
}
