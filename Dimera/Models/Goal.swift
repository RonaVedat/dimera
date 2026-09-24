import Foundation

/// A goal either tracks a real `Asset` automatically (its progress is
/// always that asset's current value, never stale) or is updated by hand —
/// for cash, or an account this app doesn't otherwise model.
enum GoalTrackingMode: String, Codable, Hashable {
    case linked
    case manual
}

struct Goal: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var targetAmount: Decimal
    var monthlyContribution: Decimal
    var trackingMode: GoalTrackingMode
    var linkedAssetID: Asset.ID?
    /// The progress amount when `trackingMode == .manual` — also doubles as
    /// the last-known snapshot if a linked asset is later deleted, so a
    /// goal never shows a stale or broken number (see
    /// `FinanceStore.deleteAsset`).
    var manualCurrentAmount: Decimal

    init(
        id: UUID = UUID(), name: String, targetAmount: Decimal, monthlyContribution: Decimal,
        trackingMode: GoalTrackingMode, linkedAssetID: Asset.ID? = nil, manualCurrentAmount: Decimal = 0
    ) {
        self.id = id
        self.name = name
        self.targetAmount = targetAmount
        self.monthlyContribution = monthlyContribution
        self.trackingMode = trackingMode
        self.linkedAssetID = linkedAssetID
        self.manualCurrentAmount = manualCurrentAmount
    }
}

enum GoalSampleData {
    static var all: [Goal] {
        [
            Goal(name: String.localized("Emergency fund"), targetAmount: 10_000, monthlyContribution: 1_000, trackingMode: .manual, manualCurrentAmount: 3_000),
            Goal(name: String.localized("Japan trip 2027"), targetAmount: 2_500, monthlyContribution: 150, trackingMode: .manual, manualCurrentAmount: 1_200)
        ]
    }
}

/// A stable, language-independent signal for the grade's color/tier — `grade`
/// itself is a localized display string, unsafe to `switch`/compare against
/// literal English text once translated (a real bug caught while localizing:
/// `GoalsView.healthGradeColor` used to compare `grade == "Excellent"`,
/// which silently stopped matching in every non-English language).
enum HealthTier {
    case strong, attention, building
}

struct FinancialHealth: Equatable {
    let score: Int
    let grade: String
    let tier: HealthTier
    let strengths: [String]

    /// The honest bootstrap state for a brand-new ledger — no transactions
    /// yet means nothing to compute, so this says that plainly rather than
    /// showing a fabricated score. A computed `var`, not `static let` — a
    /// stored constant would freeze in whatever language was active the
    /// first time it was touched, even after switching `AppLanguage` later.
    static var empty: FinancialHealth {
        FinancialHealth(
            score: 0,
            grade: String.localized("Getting Started"),
            tier: .building,
            strengths: [String.localized("Log a few transactions and your financial health score will appear here.")]
        )
    }
}
