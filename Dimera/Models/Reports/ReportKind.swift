import Foundation

/// The four report types the Reports section can generate — each one a
/// rendering layer over data `FinanceStore` already computes elsewhere in
/// the app (spending analysis, recurring payments, goals). Nothing here
/// invents a new number; it only presents ones that already exist.
enum ReportKind: String, CaseIterable, Identifiable {
    case monthlySummary
    case spendingAnalysis
    case commitmentReport
    case goalProgress

    var id: String { rawValue }

    var title: String {
        switch self {
        case .monthlySummary: return String.localized("Monthly Summary")
        case .spendingAnalysis: return String.localized("Spending Analysis")
        case .commitmentReport: return String.localized("Commitment Report")
        case .goalProgress: return String.localized("Goal Progress")
        }
    }

    var subtitle: String {
        switch self {
        case .monthlySummary: return String.localized("Income, expenses, and where your money went.")
        case .spendingAnalysis: return String.localized("Every category, compared month to month.")
        case .commitmentReport: return String.localized("Every subscription and contract, and what they add up to yearly.")
        case .goalProgress: return String.localized("How close you are, and when you'll get there.")
        }
    }

    var systemImage: String {
        switch self {
        case .monthlySummary: return "doc.text"
        case .spendingAnalysis: return "chart.pie"
        case .commitmentReport: return "list.bullet.clipboard"
        case .goalProgress: return "target"
        }
    }

    /// Mirrors the tier boundary this data already has elsewhere in
    /// Insights/Goals — Spending Analysis is the same data behind "Unlock
    /// Full Breakdown," Goal Progress the same data behind "Unlock
    /// Forecasting." Not a new tiering decision, just a consistent one.
    var isPremium: Bool {
        switch self {
        case .monthlySummary, .commitmentReport: return false
        case .spendingAnalysis, .goalProgress: return true
        }
    }
}
