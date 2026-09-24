import Foundation

/// A real monthly limit for one category — the thing "Spending Alert"
/// (a single-category, one-time nudge) was explicitly documented as not
/// being. One budget per category; `category` is a `TransactionCategory`
/// raw value, matching how every other category-keyed lookup in this app
/// works (`Transaction.category`, `categoryBreakdown`, the old spending
/// alert).
struct Budget: Identifiable, Hashable, Codable {
    let id: UUID
    var category: String
    var monthlyLimit: Decimal
    /// Per-budget now, rather than one global toggle — mirrors how a
    /// contract's reminder is set on that contract, not in Settings.
    var alertsEnabled: Bool
    /// "yyyy-M" guard so a crossed limit notifies at most once a month,
    /// colocated on the budget itself since there are now N of these,
    /// not the single flat UserDefaults key the old alert used.
    var lastAlertedMonth: String?

    init(
        id: UUID = UUID(), category: String, monthlyLimit: Decimal,
        alertsEnabled: Bool = true, lastAlertedMonth: String? = nil
    ) {
        self.id = id
        self.category = category
        self.monthlyLimit = monthlyLimit
        self.alertsEnabled = alertsEnabled
        self.lastAlertedMonth = lastAlertedMonth
    }
}

/// A computed presentation tier, never stored — mirrors the
/// `ContractStatus`/`HealthTier` pattern already used elsewhere in this
/// app so status can't drift from the numbers it's derived from.
enum BudgetStatus {
    case onTrack, nearLimit, overBudget
}
