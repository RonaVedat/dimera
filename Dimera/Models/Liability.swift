import Foundation

/// Debt the user owes — a car loan, a credit card balance. Most trackers
/// ignore this side entirely; Dimera counts it against net worth so the
/// headline number is honest.
struct Liability: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var amount: Decimal
    /// What leaves the account for it each month, when the user knows it.
    var monthlyPayment: Decimal?

    init(id: UUID = UUID(), name: String, amount: Decimal, monthlyPayment: Decimal?) {
        self.id = id
        self.name = name
        self.amount = amount
        self.monthlyPayment = monthlyPayment
    }
}

enum LiabilitySampleData {
    // The sample persona is debt-free — the dashboard should still show the
    // Debt row at €0 so the concept is visible before it's ever needed.
    static let all: [Liability] = []
}
