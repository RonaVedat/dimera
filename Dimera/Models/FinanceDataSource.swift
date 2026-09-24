import Foundation

/// The cash side of the user's position — what a real backend would return
/// from a single "accounts overview" endpoint. Assets and liabilities are
/// fetched separately; net worth is derived in `FinanceStore`, never stored,
/// so the three can't drift apart.
struct FinanceOverview {
    let cash: Decimal
    let monthDelta: Decimal

    static let empty = FinanceOverview(cash: 0, monthDelta: 0)
}

/// Everything `FinanceStore` needs, decoupled from where it comes from.
/// `SampleFinanceDataSource` is the only conformance today; a PSD2
/// aggregator-backed conformance (Tink, FinTecSystems) can drop in later
/// without any view or `FinanceStore` code changing.
protocol FinanceDataSource {
    func fetchOverview() async throws -> FinanceOverview
    func fetchAssets() async throws -> [Asset]
    func fetchLiabilities() async throws -> [Liability]
    func fetchTransactions() async throws -> [Transaction]
    func fetchGoals() async throws -> [Goal]
    func fetchRecurring() async throws -> [RecurringEntry]
    func fetchBalanceHistory() async throws -> [ChartPeriod: [BalancePoint]]
}
