import Foundation

/// Backs the app with the hand-authored sample data shown during
/// onboarding, before a real ledger exists — `FinanceStore.load()` only
/// calls this for a genuinely fresh install; a returning user's own data
/// comes straight from `LedgerStorage` with no fetch at all. A small
/// artificial delay stands in for network latency in debug builds only, so
/// the loading state is still exercised during development without making
/// a released app's first-run preview wait for nothing.
struct SampleFinanceDataSource: FinanceDataSource {
    private let simulatedLatency: Duration

    init(simulatedLatency: Duration = Self.defaultLatency) {
        self.simulatedLatency = simulatedLatency
    }

    private static var defaultLatency: Duration {
        #if DEBUG
        .milliseconds(350)
        #else
        .zero
        #endif
    }

    private func delay() async throws {
        try await Task.sleep(for: simulatedLatency)
    }

    func fetchOverview() async throws -> FinanceOverview {
        try await delay()
        return FinanceOverview(cash: 2_150, monthDelta: 340.50)
    }

    func fetchAssets() async throws -> [Asset] {
        try await delay()
        return AssetSampleData.all
    }

    func fetchLiabilities() async throws -> [Liability] {
        try await delay()
        return LiabilitySampleData.all
    }

    func fetchTransactions() async throws -> [Transaction] {
        try await delay()
        return TransactionSampleData.all.sorted { $0.date > $1.date }
    }

    func fetchGoals() async throws -> [Goal] {
        try await delay()
        return GoalSampleData.all
    }

    func fetchRecurring() async throws -> [RecurringEntry] {
        try await delay()
        return RecurringSampleData.all
    }

    func fetchBalanceHistory() async throws -> [ChartPeriod: [BalancePoint]] {
        try await delay()
        return Dictionary(uniqueKeysWithValues: ChartPeriod.allCases.map { ($0, BalanceHistorySampleData.points(for: $0)) })
    }
}
