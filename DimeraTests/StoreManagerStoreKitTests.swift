import StoreKit
import StoreKitTest
import XCTest
@testable import Dimera

/// End-to-end against Xcode's local StoreKit test environment. There's one
/// shared environment, so every test resets it. Skipped — not passed — when
/// the environment serves no products, which happens with command-line
/// `xcodebuild test` on some setups; run with ⌘U in Xcode to exercise them.
@MainActor
final class StoreManagerStoreKitTests: XCTestCase {
    private var session: SKTestSession!
    private let store = StoreManager.shared

    override func setUp() async throws {
        session = try SKTestSession(configurationFileNamed: "Products")
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        UserDefaults.standard.removeObject(forKey: "premiumAwaitingApproval")
        await store.loadProducts()
        await store.refresh()
        if store.products.isEmpty {
            throw XCTSkip("Local StoreKit test environment returned no products — run from Xcode (⌘U).")
        }
    }

    override func tearDown() async throws {
        session?.clearTransactions()
        await store.refresh()
    }

    private func transactionID(for plan: PremiumPlan) throws -> UInt {
        let productID = try XCTUnwrap(StoreManager.productIDsByPlan[plan])
        return try XCTUnwrap(session.allTransactions().last { $0.productIdentifier == productID }).identifier
    }

    func testLoadsAllThreePlans() {
        XCTAssertEqual(store.products.count, 3)
        XCTAssertTrue(store.familyPlanAvailable)
        XCTAssertEqual(store.products[.monthly]?.isFamilyShareable, false)
        XCTAssertEqual(store.state, .free)
    }

    func testBuyingMonthly() async throws {
        let outcome = try await store.purchase(.monthly)
        XCTAssertEqual(outcome, .success)
        XCTAssertEqual(store.state, .individual(.monthly))
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "isPremium"))
        guard case .renews = store.renewal else {
            return XCTFail("Expected a renewal date, got \(String(describing: store.renewal))")
        }
    }

    func testBuyingFamily() async throws {
        let outcome = try await store.purchase(.family)
        XCTAssertEqual(outcome, .success)
        XCTAssertEqual(store.state, .familyPurchaser)
    }

    func testUpgradingMonthlyToFamilyIsImmediate() async throws {
        _ = try await store.purchase(.monthly)
        let outcome = try await store.purchase(.family)
        XCTAssertEqual(outcome, .success)
        XCTAssertEqual(store.state, .familyPurchaser)
    }

    func testTurningOffAutoRenewShowsEndDate() async throws {
        _ = try await store.purchase(.yearly)
        try session.disableAutoRenewForTransaction(identifier: transactionID(for: .yearly))
        await store.refresh()
        XCTAssertEqual(store.state, .individual(.yearly))
        guard case .ends = store.renewal else {
            return XCTFail("Expected an end date, got \(String(describing: store.renewal))")
        }
    }

    func testExpiryReturnsToFree() async throws {
        _ = try await store.purchase(.monthly)
        try session.expireSubscription(productIdentifier: XCTUnwrap(StoreManager.productIDsByPlan[.monthly]))
        await store.refresh()
        XCTAssertEqual(store.state, .free)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "isPremium"))
    }

    func testRefundReturnsToFree() async throws {
        _ = try await store.purchase(.family)
        try session.refundTransaction(identifier: transactionID(for: .family))
        await store.refresh()
        XCTAssertEqual(store.state, .free)
    }

    func testAskToBuyWaitsThenWelcomes() async throws {
        session.askToBuyEnabled = true
        let outcome = try await store.purchase(.yearly)
        XCTAssertEqual(outcome, .pending)
        XCTAssertEqual(store.state, .free)

        try session.approveAskToBuyTransaction(identifier: transactionID(for: .yearly))
        await store.refresh()
        XCTAssertEqual(store.state, .individual(.yearly))
        XCTAssertEqual(store.pendingWelcome, .individual)
        store.welcomeShown()
    }
}
