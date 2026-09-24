import Foundation

/// Flags transactions that look like common German tax-deductible
/// categories — the same honest, no-fake-ML approach as `AddExpenseForm`'s
/// recurring-payment hints: a small hardcoded keyword list, matched against
/// the merchant name, above a minimum amount to avoid noise. Not NLP, not a
/// language-model call — a transparent heuristic, same honesty standard as
/// the rest of the app's "insights."
enum TaxRadarScanner {
    static let minimumAmount: Decimal = 50

    /// Arbeitsmittel — work equipment.
    private static let arbeitsmittelHints = [
        "macbook", "laptop", "monitor", "desk", "schreibtisch", "bürostuhl", "office chair",
        "printer", "drucker", "keyboard", "tastatur", "webcam", "headset", "ipad", "notebook"
    ]

    /// Werbungskosten — broader income-related expenses.
    private static let werbungskostenHints = [
        "linkedin", "udemy", "coursera", "fortbildung", "seminar", "workshop",
        "conference", "fachliteratur", "fachbuch", "steuerberater"
    ]

    static func scan(_ transactions: [Transaction]) -> [TaxItem] {
        transactions
            .filter { !$0.isIncome && $0.amount >= minimumAmount }
            .compactMap { transaction in
                let name = transaction.merchant.lowercased()
                if arbeitsmittelHints.contains(where: name.contains) {
                    return TaxItem(description: transaction.merchant, category: "Arbeitsmittel", amount: transaction.amount)
                }
                if werbungskostenHints.contains(where: name.contains) {
                    return TaxItem(description: transaction.merchant, category: "Werbungskosten", amount: transaction.amount)
                }
                return nil
            }
    }

    /// The keyword that matched, for the explainability popover — re-derives
    /// rather than storing, since `TaxItem` itself stays a plain value type.
    static func matchedKeyword(for item: TaxItem) -> String? {
        let name = item.description.lowercased()
        let hints = item.category == "Arbeitsmittel" ? arbeitsmittelHints : werbungskostenHints
        return hints.first { name.contains($0) }
    }
}
