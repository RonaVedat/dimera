import Foundation

struct CategoryDelta: Identifiable, Hashable {
    let id = UUID()
    let category: String
    let increase: Decimal
}

struct TaxItem: Identifiable, Hashable {
    let id = UUID()
    let description: String
    let category: String
    let amount: Decimal
}

struct SpendingInsight {
    let percentIncrease: Int
    let spentSoFar: Decimal
    let aboveAverage: Decimal
    let categoryDeltas: [CategoryDelta]
    let recommendationCategory: String
    let recommendationMonthlyCut: Decimal
    let recommendationAnnualSavings: Decimal

    static let empty = SpendingInsight(
        percentIncrease: 0, spentSoFar: 0, aboveAverage: 0, categoryDeltas: [],
        recommendationCategory: "", recommendationMonthlyCut: 0, recommendationAnnualSavings: 0
    )
}

struct CategoryBreakdownRow: Identifiable, Hashable {
    let id = UUID()
    let category: String
    let total: Decimal
    /// `nil` when there's no other month with this category to compare against.
    let deltaVsAverage: Decimal?
}
