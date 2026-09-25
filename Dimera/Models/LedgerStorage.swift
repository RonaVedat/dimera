import Foundation

/// The user's real, live position — everything `FinancialSnapshot` doesn't
/// cover. `FinancialSnapshot` only ever holds the four onboarding numbers;
/// this is what actually survives a relaunch once the user starts using the
/// app for real. Same storage shape as `FinancialSnapshotStorage`, just a
/// second key, so a fresh install (nothing here yet) is indistinguishable
/// from "hasn't finished onboarding."
struct Ledger {
    var cash: Decimal
    var monthDelta: Decimal
    var assets: [Asset]
    var liabilities: [Liability]
    var transactions: [Transaction]
    var recurring: [RecurringEntry]
    var goals: [Goal]
    var budgets: [Budget]
    var balanceChangeLog: [BalanceChangeEvent]

    init(
        cash: Decimal, monthDelta: Decimal, assets: [Asset], liabilities: [Liability],
        transactions: [Transaction], recurring: [RecurringEntry], goals: [Goal], budgets: [Budget] = [],
        balanceChangeLog: [BalanceChangeEvent] = []
    ) {
        self.cash = cash
        self.monthDelta = monthDelta
        self.assets = assets
        self.liabilities = liabilities
        self.transactions = transactions
        self.recurring = recurring
        self.goals = goals
        self.budgets = budgets
        self.balanceChangeLog = balanceChangeLog
    }
}

extension Ledger: Codable {
    private enum CodingKeys: String, CodingKey {
        case cash, monthDelta, assets, liabilities, transactions, recurring, goals, budgets, balanceChangeLog
    }

    /// Manual conformance so adding new fields over time (`budgets`, now
    /// `balanceChangeLog`) never breaks decoding of ledgers persisted
    /// before that field existed — synthesized `Decodable` throws on a
    /// missing key, which would otherwise wipe an existing install's real
    /// data back to sample/onboarding state the moment this shipped (the
    /// exact bug class `RecurringEntry` already hit once and fixed the
    /// same way).
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cash = try container.decode(Decimal.self, forKey: .cash)
        monthDelta = try container.decode(Decimal.self, forKey: .monthDelta)
        assets = try container.decode([Asset].self, forKey: .assets)
        liabilities = try container.decode([Liability].self, forKey: .liabilities)
        transactions = try container.decode([Transaction].self, forKey: .transactions)
        recurring = try container.decode([RecurringEntry].self, forKey: .recurring)
        goals = try container.decode([Goal].self, forKey: .goals)
        budgets = try container.decodeIfPresent([Budget].self, forKey: .budgets) ?? []
        balanceChangeLog = try container.decodeIfPresent([BalanceChangeEvent].self, forKey: .balanceChangeLog) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(cash, forKey: .cash)
        try container.encode(monthDelta, forKey: .monthDelta)
        try container.encode(assets, forKey: .assets)
        try container.encode(liabilities, forKey: .liabilities)
        try container.encode(transactions, forKey: .transactions)
        try container.encode(recurring, forKey: .recurring)
        try container.encode(goals, forKey: .goals)
        try container.encode(budgets, forKey: .budgets)
        try container.encode(balanceChangeLog, forKey: .balanceChangeLog)
    }
}

enum LedgerStorage {
    private static let key = "ledgerV1"

    static var current: Ledger? {
        get {
            guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
            return try? JSONDecoder().decode(Ledger.self, from: data)
        }
        set {
            guard let newValue, let data = try? JSONEncoder().encode(newValue) else {
                UserDefaults.standard.removeObject(forKey: key)
                return
            }
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
