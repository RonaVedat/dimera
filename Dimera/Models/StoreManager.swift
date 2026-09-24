import Foundation
import StoreKit

/// The single source of truth for Premium status — real StoreKit 2
/// entitlements, not a stored flag this app invents itself. Every existing
/// `@AppStorage("isPremium")` read across the app (`PremiumGate`,
/// `ReportsSection`, Settings, receipt gating, etc.) keeps working exactly
/// as before; this is the one place that *writes* that key now, driven by
/// `StoreKit.Transaction.currentEntitlements` instead of a debug switch. Apple's own
/// on-device receipt/entitlement system means this app never sees a name,
/// email, or card number — only a verified yes/no.
@MainActor
final class StoreManager: ObservableObject {
    static let shared = StoreManager()
    static let premiumProductID = "com.dimera.app.premium.monthly"

    enum PurchaseOutcome: Equatable {
        case success, cancelled, pending
    }

    enum StoreError: Error {
        case failedVerification
        case productUnavailable
        case timedOut
    }

    @Published private(set) var product: Product?
    @Published private(set) var isLoadingProduct = true

    private var updateListenerTask: Task<Void, Never>?
    private let defaults = UserDefaults.standard

    private init() {}

    /// Called once from `DimeraApp` at launch — mirrors how
    /// `NotificationScheduler.shared`/`ReceiptStore.shared` are used
    /// ambiently elsewhere in this app, no environment injection needed.
    func start() {
        guard updateListenerTask == nil else { return }
        updateListenerTask = listenForTransactions()
        Task {
            await loadProduct()
            await refreshEntitlement()
        }
    }

    func loadProduct() async {
        isLoadingProduct = true
        defer { isLoadingProduct = false }
        product = try? await Product.products(for: [Self.premiumProductID]).first
    }

    @discardableResult
    func purchase() async throws -> PurchaseOutcome {
        var target = product
        if target == nil {
            await loadProduct()
            target = product
        }
        guard let target else { throw StoreError.productUnavailable }

        let result = try await target.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await refreshEntitlement()
            return .success
        case .userCancelled:
            return .cancelled
        case .pending:
            return .pending
        @unknown default:
            return .cancelled
        }
    }

    /// Apple's own "device changes and logins" answer — silently asks the
    /// signed-in Apple ID for any past purchase, no account or password of
    /// ours involved. `AppStore.sync()` has no built-in timeout and can
    /// hang indefinitely with no connectivity, so this races it against a
    /// timer rather than leaving the caller's loading state spinning
    /// forever.
    func restorePurchases() async throws {
        try await withTimeout(seconds: 15) {
            try await AppStore.sync()
        }
        await refreshEntitlement()
    }

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

    /// Handles renewals, refunds, and purchases made outside this exact
    /// app session (Family Sharing, a second device) for as long as the
    /// app is running.
    private func listenForTransactions() -> Task<Void, Never> {
        Task {
            // Qualified `StoreKit.Transaction` throughout this file — this
            // app already has its own `Transaction` model (a logged expense
            // or income), and an unqualified reference would silently
            // resolve to that instead of StoreKit's type.
            for await update in StoreKit.Transaction.updates {
                if let transaction = try? checkVerified(update) {
                    await transaction.finish()
                }
                await refreshEntitlement()
            }
        }
    }

    /// The one real ground truth: walks every currently-valid entitlement
    /// Apple knows about for this Apple ID and checks whether our premium
    /// product is among them. Writes the result into the same `"isPremium"`
    /// UserDefaults key every existing read site already uses — nothing
    /// downstream of this needs to know StoreKit exists.
    private func refreshEntitlement() async {
        var isPremium = false
        for await result in StoreKit.Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            if transaction.productID == Self.premiumProductID && transaction.revocationDate == nil {
                isPremium = true
            }
        }
        defaults.set(isPremium, forKey: "isPremium")
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}
