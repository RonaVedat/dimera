import Foundation

/// StoreKit-free model of who has Premium and why. `StoreManager` maps
/// StoreKit transactions into `EntitlementSnapshot`s and hands them to
/// `PremiumStateResolver`; everything here is plain values so the precedence
/// rules can be unit tested — Xcode's local StoreKit Testing can't produce
/// family-shared transactions, so tests are the only way to cover them
/// short of a Sandbox Test Family.
enum PremiumPlan: String, Codable, CaseIterable {
    case monthly, yearly, family

    var title: String {
        switch self {
        case .monthly: return String.localized("Monthly")
        case .yearly: return String.localized("Yearly")
        case .family: return String.localized("Premium Family")
        }
    }
}

/// Mirrors `StoreKit.Transaction.OwnershipType`. `other` covers `.assigned`
/// (access through an organization) and any value StoreKit adds later —
/// `OwnershipType` is a struct, not a closed enum.
enum AccessSource: String, Codable {
    case purchased, familyShared, other
}

struct EntitlementSnapshot: Equatable {
    let plan: PremiumPlan
    let source: AccessSource
    var expirationDate: Date? = nil
    var revocationDate: Date? = nil
    var isUpgraded: Bool = false
}

enum PremiumState: Codable, Equatable {
    case free
    case individual(PremiumPlan)
    /// Bought Premium Family themselves. Not necessarily the family group's
    /// organizer — any adult member can buy and share a subscription.
    case familyPurchaser
    /// Has access through someone else's Premium Family. `alsoPays` is an
    /// individual plan they still pay for themselves, if any.
    case familyMember(alsoPays: PremiumPlan?)
    case otherShared

    var isPremium: Bool { self != .free }

    /// Apple HIG: encourage a new subscription only when someone isn't
    /// already a subscriber.
    var shouldOfferPurchase: Bool { self == .free }

    var canUpgradeToFamily: Bool {
        if case .individual = self { return true }
        return false
    }

    /// Family members can't manage a subscription someone else pays for —
    /// unless they're also paying for their own.
    var canManage: Bool {
        switch self {
        case .individual, .familyPurchaser: return true
        case .familyMember(let alsoPays): return alsoPays != nil
        case .free, .otherShared: return false
        }
    }
}

enum PremiumStateResolver {
    /// Precedence, first match wins, over entitlements that are still valid
    /// (not revoked, not superseded by an upgrade, not expired — the same
    /// filter Apple's own `Transaction.updates` sample applies).
    static func resolve(_ entitlements: [EntitlementSnapshot], now: Date = Date()) -> PremiumState {
        let valid = entitlements.filter { entitlement in
            entitlement.revocationDate == nil
                && !entitlement.isUpgraded
                && (entitlement.expirationDate.map { $0 > now } ?? true)
        }

        func has(_ plan: PremiumPlan, from source: AccessSource) -> Bool {
            valid.contains { $0.plan == plan && $0.source == source }
        }

        let ownIndividualPlan: PremiumPlan? = has(.yearly, from: .purchased)
            ? .yearly
            : (has(.monthly, from: .purchased) ? .monthly : nil)

        if has(.family, from: .purchased) { return .familyPurchaser }
        if valid.contains(where: { $0.source == .familyShared }) {
            return .familyMember(alsoPays: ownIndividualPlan)
        }
        if let ownIndividualPlan { return .individual(ownIndividualPlan) }
        if valid.contains(where: { $0.source == .other }) { return .otherShared }
        return .free
    }
}

/// What Settings says about the subscription this person pays for.
enum RenewalSummary: Equatable {
    case renews(Date)
    case switches(to: PremiumPlan, on: Date)
    case ends(Date)
    case paymentProblem

    static func make(
        currentPlan: PremiumPlan, willAutoRenew: Bool, renewalDate: Date?, nextPlan: PremiumPlan?,
        isInBillingRetry: Bool, isInGracePeriod: Bool
    ) -> RenewalSummary? {
        if isInBillingRetry || isInGracePeriod { return .paymentProblem }
        guard let renewalDate else { return nil }
        guard willAutoRenew else { return .ends(renewalDate) }
        if let nextPlan, nextPlan != currentPlan {
            return .switches(to: nextPlan, on: renewalDate)
        }
        return .renews(renewalDate)
    }

    var displayText: String {
        switch self {
        case .renews(let date):
            return String.localized("Renews on \(Self.format(date))")
        case .switches(let plan, let date):
            return String.localized("Switches to \(plan.title) on \(Self.format(date))")
        case .ends(let date):
            return String.localized("Ends on \(Self.format(date))")
        case .paymentProblem:
            return String.localized("Your Premium payment didn't go through.")
        }
    }

    private static func format(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).year().locale(AppLanguage.current.locale))
    }
}

enum PremiumWelcomeVariant: String, Identifiable {
    case individual, familyPurchaser, familyMember

    var id: String { rawValue }

    init?(state: PremiumState) {
        switch state {
        case .individual, .otherShared: self = .individual
        case .familyPurchaser: self = .familyPurchaser
        case .familyMember: self = .familyMember
        case .free: return nil
        }
    }
}
