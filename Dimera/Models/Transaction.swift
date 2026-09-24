import Foundation

struct Transaction: Identifiable, Hashable, Codable {
    let id: UUID
    var merchant: String
    var category: String
    var amount: Decimal
    var date: Date
    let isIncome: Bool
    /// The receipt image itself lives in `ReceiptStore`, keyed by this
    /// transaction's own `id` — nothing about it is duplicated here.
    var hasReceipt: Bool

    init(
        id: UUID = UUID(), merchant: String, category: String, amount: Decimal,
        date: Date, isIncome: Bool, hasReceipt: Bool = false
    ) {
        self.id = id
        self.merchant = merchant
        self.category = category
        self.amount = amount
        self.date = date
        self.isIncome = isIncome
        self.hasReceipt = hasReceipt
    }

    var initial: String {
        String(merchant.first ?? "?")
    }
}

enum TransactionSampleData {
    static func make(daysAgo: Int, hour: Int = 12) -> Date {
        let cal = Calendar.current
        let day = cal.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return cal.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
    }

    static let all: [Transaction] = [
        Transaction(merchant: "REWE", category: "Groceries", amount: 43.20, date: make(daysAgo: 0), isIncome: false),
        Transaction(merchant: "Shell", category: "Fuel", amount: 68.50, date: make(daysAgo: 0, hour: 9), isIncome: false),
        Transaction(merchant: "Salary — TechCorp GmbH", category: "Income", amount: 2450.00, date: make(daysAgo: 1), isIncome: true),
        Transaction(merchant: "Netflix", category: "Subscription", amount: 13.99, date: make(daysAgo: 1, hour: 20), isIncome: false),
        Transaction(merchant: "dm-drogerie markt", category: "Household", amount: 21.35, date: make(daysAgo: 3), isIncome: false),
        Transaction(merchant: "Deutsche Bahn", category: "Transport", amount: 49.90, date: make(daysAgo: 3, hour: 8), isIncome: false),
        Transaction(merchant: "Amazon", category: "Shopping", amount: 67.80, date: make(daysAgo: 3, hour: 18), isIncome: false),
        Transaction(merchant: "L'Osteria", category: "Restaurants", amount: 38.60, date: make(daysAgo: 4, hour: 19), isIncome: false),
        Transaction(merchant: "Telekom", category: "Phone & internet", amount: 49.99, date: make(daysAgo: 4, hour: 10), isIncome: false)
    ]
}
