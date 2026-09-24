import Foundation

/// Backs the app with the hand-authored sample data used throughout
/// development. A small artificial delay stands in for network latency so
/// the loading state is actually exercised, not just theoretical.
struct SampleFinanceDataSource: FinanceDataSource {
    private let simulatedLatency: Duration

    init(simulatedLatency: Duration = .milliseconds(350)) {
        self.simulatedLatency = simulatedLatency
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
