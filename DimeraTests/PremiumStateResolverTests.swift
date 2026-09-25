import Foundation
import Testing
@testable import Dimera

/// Family-shared and organization-assigned transactions can't be produced
/// by Xcode's local StoreKit Testing, so the precedence rules are covered
/// here directly.
struct PremiumStateResolverTests {
    private static let now = Date(timeIntervalSince1970: 1_800_000_000)
    private static let future = now.addingTimeInterval(86_400)
    private static let past = now.addingTimeInterval(-86_400)

    struct Case: CustomTestStringConvertible {
        let name: String
        let entitlements: [EntitlementSnapshot]
        let expected: PremiumState
        var testDescription: String { name }
    }

    static let cases: [Case] = [
        Case(name: "nothing", entitlements: [], expected: .free),
        Case(name: "monthly",
             entitlements: [.init(plan: .monthly, source: .purchased, expirationDate: future)],
             expected: .individual(.monthly)),
        Case(name: "yearly",
             entitlements: [.init(plan: .yearly, source: .purchased, expirationDate: future)],
             expected: .individual(.yearly)),
        Case(name: "monthly upgraded to family",
             entitlements: [
                .init(plan: .monthly, source: .purchased, expirationDate: future, isUpgraded: true),
                .init(plan: .family, source: .purchased, expirationDate: future)
             ],
             expected: .familyPurchaser),
        Case(name: "family shared",
             entitlements: [.init(plan: .family, source: .familyShared, expirationDate: future)],
             expected: .familyMember(alsoPays: nil)),
        Case(name: "family shared plus own monthly",
             entitlements: [
                .init(plan: .family, source: .familyShared, expirationDate: future),
                .init(plan: .monthly, source: .purchased, expirationDate: future)
             ],
             expected: .familyMember(alsoPays: .monthly)),
        Case(name: "family shared but revoked (left family)",
             entitlements: [.init(plan: .family, source: .familyShared, expirationDate: future, revocationDate: past)],
             expected: .free),
        Case(name: "family shared revoked, own yearly still active",
             entitlements: [
                .init(plan: .family, source: .familyShared, expirationDate: future, revocationDate: past),
                .init(plan: .yearly, source: .purchased, expirationDate: future)
             ],
             expected: .individual(.yearly)),
        Case(name: "monthly expired",
             entitlements: [.init(plan: .monthly, source: .purchased, expirationDate: past)],
             expected: .free),
        Case(name: "monthly refunded",
             entitlements: [.init(plan: .monthly, source: .purchased, expirationDate: future, revocationDate: past)],
             expected: .free),
        Case(name: "assigned through an organization",
             entitlements: [.init(plan: .yearly, source: .other, expirationDate: future)],
             expected: .otherShared),
        Case(name: "own purchase beats organization access",
             entitlements: [
                .init(plan: .yearly, source: .other, expirationDate: future),
                .init(plan: .monthly, source: .purchased, expirationDate: future)
             ],
             expected: .individual(.monthly))
    ]

    @Test(arguments: cases)
    func resolves(_ testCase: Case) {
        #expect(PremiumStateResolver.resolve(testCase.entitlements, now: Self.now) == testCase.expected)
    }

    @Test func derivedPermissions() {
        #expect(PremiumState.free.shouldOfferPurchase)
        #expect(!PremiumState.familyMember(alsoPays: nil).shouldOfferPurchase)
        #expect(PremiumState.individual(.monthly).canUpgradeToFamily)
        #expect(!PremiumState.familyPurchaser.canUpgradeToFamily)
        #expect(!PremiumState.familyMember(alsoPays: nil).canManage)
        #expect(PremiumState.familyMember(alsoPays: .yearly).canManage)
        #expect(!PremiumState.otherShared.canManage)
    }

    @Test func stateSurvivesPersistence() throws {
        for state: PremiumState in [.free, .individual(.yearly), .familyPurchaser, .familyMember(alsoPays: .monthly), .otherShared] {
            let data = try JSONEncoder().encode(state)
            #expect(try JSONDecoder().decode(PremiumState.self, from: data) == state)
        }
    }
}

struct RenewalSummaryTests {
    private let date = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func renews() {
        #expect(RenewalSummary.make(currentPlan: .monthly, willAutoRenew: true, renewalDate: date, nextPlan: .monthly,
                                    isInBillingRetry: false, isInGracePeriod: false) == .renews(date))
    }

    @Test func pendingDowngradeOrPeriodChange() {
        #expect(RenewalSummary.make(currentPlan: .yearly, willAutoRenew: true, renewalDate: date, nextPlan: .monthly,
                                    isInBillingRetry: false, isInGracePeriod: false) == .switches(to: .monthly, on: date))
    }

    @Test func autoRenewOff() {
        #expect(RenewalSummary.make(currentPlan: .family, willAutoRenew: false, renewalDate: date, nextPlan: nil,
                                    isInBillingRetry: false, isInGracePeriod: false) == .ends(date))
    }

    @Test func billingProblems() {
        #expect(RenewalSummary.make(currentPlan: .monthly, willAutoRenew: true, renewalDate: date, nextPlan: .monthly,
                                    isInBillingRetry: true, isInGracePeriod: false) == .paymentProblem)
        #expect(RenewalSummary.make(currentPlan: .monthly, willAutoRenew: true, renewalDate: date, nextPlan: .monthly,
                                    isInBillingRetry: false, isInGracePeriod: true) == .paymentProblem)
    }
}
