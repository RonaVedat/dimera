import Foundation

/// Single source of truth for the app's data, fed by a `FinanceDataSource`.
///
/// The mental model is a *financial position*, not an expense ledger:
/// cash + assets − liabilities = net worth, with transactions as the cash
/// flow that moves it. Data entry mutates the position; every view reads
/// derived numbers from here so nothing can drift.
///
/// Two modes share this store: fresh installs see rich sample data (so the
/// product demos well), and once the user completes their financial
/// snapshot the store switches to *their* numbers with an empty ledger.
@MainActor
final class FinanceStore: ObservableObject {
    @Published private(set) var overview: FinanceOverview = .empty
    @Published private(set) var assets: [Asset] = []
    @Published private(set) var liabilities: [Liability] = []
    @Published private(set) var transactions: [Transaction] = []
    @Published private(set) var recurring: [RecurringEntry] = []
    @Published private(set) var goals: [Goal] = []
    @Published private(set) var budgets: [Budget] = []
    @Published private(set) var balanceChangeLog: [BalanceChangeEvent] = []

    @Published private(set) var isLoading = false
    @Published private(set) var loadError: String?

    private var balanceHistory: [ChartPeriod: [BalancePoint]] = [:]
    private var hasLoadedOnce = false
    private let dataSource: FinanceDataSource

    init(dataSource: FinanceDataSource = SampleFinanceDataSource()) {
        self.dataSource = dataSource
    }

    // MARK: - Position (derived, never stored)

    var cash: Decimal { overview.cash }
    var monthDelta: Decimal { overview.monthDelta }

    var savingsTotal: Decimal {
        assets.filter { $0.kind == .savings }.reduce(0) { $0 + $1.value }
    }

    var investmentsTotal: Decimal {
        assets.filter { $0.kind == .investment }.reduce(0) { $0 + $1.value }
    }

    var otherAssetsTotal: Decimal {
        assets.filter { $0.kind == .other }.reduce(0) { $0 + $1.value }
    }

    var debtTotal: Decimal {
        liabilities.reduce(0) { $0 + $1.amount }
    }

    var assetsTotal: Decimal {
        assets.reduce(0) { $0 + $1.value }
    }

    var netWorth: Decimal {
        cash + savingsTotal + investmentsTotal + otherAssetsTotal - debtTotal
    }

    // MARK: - Loading

    /// Fetches everything in parallel. A no-op if data already loaded
    /// successfully once — onboarding and the tab view each call this on
    /// appear, and the second call shouldn't re-flash a loading spinner.
    func load() async {
        if hasLoadedOnce && loadError == nil { return }

        isLoading = true
        loadError = nil

        do {
            async let overview = dataSource.fetchOverview()
            async let assets = dataSource.fetchAssets()
            async let liabilities = dataSource.fetchLiabilities()
            async let transactions = dataSource.fetchTransactions()
            async let recurring = dataSource.fetchRecurring()
            async let goals = dataSource.fetchGoals()
            async let balanceHistory = dataSource.fetchBalanceHistory()

            self.overview = try await overview
            self.assets = try await assets
            self.liabilities = try await liabilities
            self.transactions = try await transactions
            self.recurring = try await recurring
            self.goals = try await goals
            self.balanceHistory = try await balanceHistory
            hasLoadedOnce = true

            // A persisted ledger means the user owns this dashboard for
            // real — load their actual (possibly empty) data straight from
            // disk instead of the sample-data preview just fetched above.
            if let ledger = LedgerStorage.current {
                // `self.` is required throughout: the local `async let`s
                // above shadow these property names for the rest of scope.
                self.overview = FinanceOverview(cash: ledger.cash, monthDelta: ledger.monthDelta)
                self.assets = ledger.assets
                self.liabilities = ledger.liabilities
                self.transactions = ledger.transactions
                self.recurring = ledger.recurring
                self.goals = ledger.goals
                self.budgets = ledger.budgets
                self.balanceChangeLog = ledger.balanceChangeLog
                rebuildFlatHistory()
            } else if let snapshot = FinancialSnapshotStorage.current {
                // Onboarding finished in a previous run but nothing's been
                // persisted yet — shouldn't normally happen once
                // `applySnapshot` persists immediately, kept as a fallback.
                apply(snapshot: snapshot)
                persistLedger()
            }
            // Resyncs reminders for whatever loaded — a no-op unless the
            // user already turned reminders on in a previous session.
            // (`self.` is required here: the local `async let recurring`
            // above shadows the property for the rest of this scope.)
            NotificationScheduler.shared.syncSchedule(with: self.recurring)
        } catch {
            loadError = String.localized("Couldn't load your accounts. Check your connection and try again.")
        }

        isLoading = false
    }

    // MARK: - First-time snapshot

    /// Replaces the sample position with the user's own numbers and clears
    /// the sample cash-flow data — transactions, recurring entries, and
    /// goals — so their real ledger starts clean, same as a fresh account
    /// with nothing invented on their behalf. Financial Health, spending
    /// insight, recurring payments, tax radar, and the forecast all need no
    /// clearing — they're fully computed from live data (see the sections
    /// below), so an empty ledger automatically produces their honest
    /// bootstrap states with nothing extra to reset by hand.
    func applySnapshot(_ snapshot: FinancialSnapshot) {
        FinancialSnapshotStorage.current = snapshot
        apply(snapshot: snapshot)
        // Persisting here (not just on the next mutation) is what makes
        // `LedgerStorage.current` the permanent signal for "this user has a
        // real, if empty, ledger" from this point forward.
        persistLedger()
        NotificationScheduler.shared.syncSchedule(with: recurring)
    }

    private func apply(snapshot: FinancialSnapshot) {
        overview = FinanceOverview(cash: snapshot.cash, monthDelta: 0)

        var newAssets: [Asset] = []
        if snapshot.savings > 0 {
            newAssets.append(Asset(name: String.localized("Savings"), value: snapshot.savings, kind: .savings))
        }
        if snapshot.investments > 0 {
            newAssets.append(Asset(name: String.localized("Investments"), value: snapshot.investments, kind: .investment))
        }
        assets = newAssets

        liabilities = snapshot.debt > 0
            ? [Liability(name: String.localized("Debt"), amount: snapshot.debt, monthlyPayment: nil)]
            : []

        transactions = []
        recurring = []
        goals = []
        budgets = []
        balanceChangeLog = []

        rebuildFlatHistory()
    }

    /// A brand-new dashboard has no movement yet — an honest flat line,
    /// which starts moving the moment entries arrive.
    private func rebuildFlatHistory() {
        let value = NSDecimalNumber(decimal: netWorth).doubleValue
        let cal = Calendar.current
        for period in ChartPeriod.allCases {
            let spanDays: Int
            switch period {
            case .week: spanDays = 7
            case .month: spanDays = 30
            case .year: spanDays = 365
            case .max: spanDays = 900
            }
            let points = stride(from: spanDays, through: 0, by: -max(spanDays / 12, 1)).map { daysBack in
                BalancePoint(date: cal.date(byAdding: .day, value: -daysBack, to: Date()) ?? Date(), value: value)
            }
            balanceHistory[period] = points
        }
    }

    // MARK: - Entry (the supporting functionality)

    @discardableResult
    func addExpense(merchant: String, category: String, amount: Decimal, date: Date, id: UUID = UUID(), hasReceipt: Bool = false) -> Transaction {
        let transaction = Transaction(id: id, merchant: merchant, category: category, amount: amount, date: date, isIncome: false, hasReceipt: hasReceipt)
        insert(transaction)
        applyCashDelta(-amount)
        checkBudgetAlertsIfNeeded()
        persistLedger()
        return transaction
    }

    func addIncome(source: String, amount: Decimal, date: Date, frequency: RecurringFrequency?) {
        let transaction = Transaction(merchant: source, category: "Income", amount: amount, date: date, isIncome: true)
        insert(transaction)
        applyCashDelta(amount)
        if let frequency {
            addRecurring(
                name: source, amount: amount, isIncome: true, frequency: frequency,
                lastOccurrence: date, originTransactionID: transaction.id
            )
        }
        persistLedger()
    }

    func addAsset(name: String, value: Decimal, kind: AssetKind) {
        assets.append(Asset(name: name, value: value, kind: kind))
        registerNetWorthChange(value, label: name, kind: .assetAdded)
        persistLedger()
    }

    func addLiability(name: String, amount: Decimal, monthlyPayment: Decimal?) {
        liabilities.append(Liability(name: name, amount: amount, monthlyPayment: monthlyPayment))
        registerNetWorthChange(-amount, label: name, kind: .liabilityAdded)
        persistLedger()
    }

    /// Goals track money that's already counted elsewhere as cash or an
    /// asset — they're a motivation layer, not a new net-worth contributor,
    /// so unlike `addAsset`/`addLiability` this never touches net worth.
    func addGoal(
        name: String, targetAmount: Decimal, monthlyContribution: Decimal,
        trackingMode: GoalTrackingMode, linkedAssetID: Asset.ID?, manualCurrentAmount: Decimal
    ) {
        goals.append(Goal(
            name: name, targetAmount: targetAmount, monthlyContribution: monthlyContribution,
            trackingMode: trackingMode, linkedAssetID: linkedAssetID, manualCurrentAmount: manualCurrentAmount
        ))
        persistLedger()
    }

    /// One budget per category — callers (`AddBudgetSheet`) are expected to
    /// exclude categories already budgeted, but this doesn't re-enforce
    /// that itself; editing an existing category's limit goes through
    /// `updateBudget`, not a second `addBudget`.
    func addBudget(category: String, monthlyLimit: Decimal, alertsEnabled: Bool = true) {
        budgets.append(Budget(category: category, monthlyLimit: monthlyLimit, alertsEnabled: alertsEnabled))
        persistLedger()
    }

    /// `lastOccurrence` is the date of the transaction the user just logged
    /// (defaults to today) — the entry anchors one period *past* it, so
    /// "Upcoming" shows the next occurrence rather than re-surfacing the
    /// payment already visible in Recent. `originTransactionID`, when set,
    /// means deleting that transaction also removes this entry.
    func addRecurring(
        name: String, amount: Decimal, isIncome: Bool, frequency: RecurringFrequency,
        lastOccurrence date: Date = Date(), originTransactionID: UUID? = nil, kind: CommitmentKind = .subscription
    ) {
        recurring.append(.afterLoggedTransaction(
            name: name, amount: amount, isIncome: isIncome, frequency: frequency,
            transactionDate: date, originTransactionID: originTransactionID, kind: kind
        ))
        recurring.sort { $0.nextDate < $1.nextDate }
        NotificationScheduler.shared.syncSchedule(with: recurring)
        persistLedger()
    }

    /// Adding a subscription directly (not spawned from a logged expense) —
    /// "what am I paying every month," entered up front rather than
    /// discovered after the fact.
    func addSubscription(name: String, amount: Decimal, frequency: RecurringFrequency, providerName: String?) {
        recurring.append(RecurringEntry(
            name: name, amount: amount, isIncome: false, frequency: frequency, anchorDate: Date(),
            kind: .subscription, providerName: providerName
        ))
        recurring.sort { $0.nextDate < $1.nextDate }
        NotificationScheduler.shared.syncSchedule(with: recurring)
        persistLedger()
    }

    /// Adding a contract directly — the obligations side of Commitments,
    /// always entered up front (a contract isn't discovered from a logged
    /// transaction the way "looks recurring" catches a subscription).
    func addContract(
        name: String, amount: Decimal, frequency: RecurringFrequency, anchorDate: Date,
        providerName: String?, contractEndDate: Date?, cancellationDeadline: Date?,
        reminderDate: Date?, providerNotes: String?
    ) {
        let entry = RecurringEntry(
            name: name, amount: amount, isIncome: false, frequency: frequency, anchorDate: anchorDate,
            kind: .contract, providerName: providerName, contractEndDate: contractEndDate,
            cancellationDeadline: cancellationDeadline, reminderDate: reminderDate, providerNotes: providerNotes
        )
        recurring.append(entry)
        recurring.sort { $0.nextDate < $1.nextDate }
        NotificationScheduler.shared.syncSchedule(with: recurring)
        if let reminderDate {
            NotificationScheduler.shared.scheduleContractReminder(id: entry.id, name: entry.name, date: reminderDate)
        }
        persistLedger()
    }

    // MARK: - Edit

    func updateTransaction(_ transaction: Transaction, merchant: String, category: String, amount: Decimal, date: Date, hasReceipt: Bool? = nil) {
        guard let index = transactions.firstIndex(where: { $0.id == transaction.id }) else { return }
        let old = transactions[index]
        transactions[index].merchant = merchant
        transactions[index].category = category
        transactions[index].amount = amount
        transactions[index].date = date
        if let hasReceipt {
            transactions[index].hasReceipt = hasReceipt
        }
        transactions.sort { $0.date > $1.date }

        // Reverse the old cash effect, then apply the new one — handles an
        // edited amount correctly regardless of which direction it changed.
        let reverseOld = old.isIncome ? -old.amount : old.amount
        let applyNew = transaction.isIncome ? amount : -amount
        applyCashDelta(reverseOld + applyNew)
        checkBudgetAlertsIfNeeded()
        persistLedger()
    }

    func updateAsset(_ asset: Asset, name: String, value: Decimal, kind: AssetKind) {
        guard let index = assets.firstIndex(where: { $0.id == asset.id }) else { return }
        let delta = value - assets[index].value
        assets[index].name = name
        assets[index].value = value
        assets[index].kind = kind
        registerNetWorthChange(delta, label: name, kind: .assetChanged)
        persistLedger()
    }

    func updateLiability(_ liability: Liability, name: String, amount: Decimal, monthlyPayment: Decimal?) {
        guard let index = liabilities.firstIndex(where: { $0.id == liability.id }) else { return }
        let delta = liabilities[index].amount - amount // debt decreasing raises net worth
        liabilities[index].name = name
        liabilities[index].amount = amount
        liabilities[index].monthlyPayment = monthlyPayment
        registerNetWorthChange(delta, label: name, kind: .liabilityChanged)
        persistLedger()
    }

    func updateGoal(
        _ goal: Goal, name: String, targetAmount: Decimal, monthlyContribution: Decimal,
        trackingMode: GoalTrackingMode, linkedAssetID: Asset.ID?, manualCurrentAmount: Decimal
    ) {
        guard let index = goals.firstIndex(where: { $0.id == goal.id }) else { return }
        goals[index].name = name
        goals[index].targetAmount = targetAmount
        goals[index].monthlyContribution = monthlyContribution
        goals[index].trackingMode = trackingMode
        goals[index].linkedAssetID = linkedAssetID
        goals[index].manualCurrentAmount = manualCurrentAmount
        persistLedger()
    }

    func updateBudget(_ budget: Budget, monthlyLimit: Decimal, alertsEnabled: Bool) {
        guard let index = budgets.firstIndex(where: { $0.id == budget.id }) else { return }
        budgets[index].monthlyLimit = monthlyLimit
        budgets[index].alertsEnabled = alertsEnabled
        persistLedger()
    }

    func updateRecurring(_ entry: RecurringEntry, name: String, amount: Decimal, frequency: RecurringFrequency) {
        guard let index = recurring.firstIndex(where: { $0.id == entry.id }) else { return }
        recurring[index].name = name
        recurring[index].amount = amount
        recurring[index].frequency = frequency
        recurring.sort { $0.nextDate < $1.nextDate }
        NotificationScheduler.shared.syncSchedule(with: recurring)
        persistLedger()
    }

    /// "Change Plan" on a subscription — same fields as `updateRecurring`
    /// plus the provider name now that subscriptions can carry one too.
    func updateSubscription(_ entry: RecurringEntry, name: String, amount: Decimal, frequency: RecurringFrequency, providerName: String?) {
        guard let index = recurring.firstIndex(where: { $0.id == entry.id }) else { return }
        recurring[index].name = name
        recurring[index].amount = amount
        recurring[index].frequency = frequency
        recurring[index].providerName = providerName
        recurring.sort { $0.nextDate < $1.nextDate }
        NotificationScheduler.shared.syncSchedule(with: recurring)
        persistLedger()
    }

    func updateContract(
        _ entry: RecurringEntry, name: String, amount: Decimal, frequency: RecurringFrequency,
        providerName: String?, contractEndDate: Date?, cancellationDeadline: Date?,
        reminderDate: Date?, providerNotes: String?
    ) {
        guard let index = recurring.firstIndex(where: { $0.id == entry.id }) else { return }
        recurring[index].name = name
        recurring[index].amount = amount
        recurring[index].frequency = frequency
        recurring[index].providerName = providerName
        recurring[index].contractEndDate = contractEndDate
        recurring[index].cancellationDeadline = cancellationDeadline
        recurring[index].reminderDate = reminderDate
        recurring[index].providerNotes = providerNotes
        recurring.sort { $0.nextDate < $1.nextDate }
        NotificationScheduler.shared.syncSchedule(with: recurring)
        if let reminderDate {
            NotificationScheduler.shared.scheduleContractReminder(id: entry.id, name: name, date: reminderDate)
        } else {
            NotificationScheduler.shared.cancelContractReminder(id: entry.id)
        }
        persistLedger()
    }

    /// A paused subscription drops out of `subscriptionsMonthlyTotal` and
    /// its own reminders, but stays in the list — "I paused this in real
    /// life" is different from "I cancelled it."
    func togglePause(_ entry: RecurringEntry) {
        guard let index = recurring.firstIndex(where: { $0.id == entry.id }) else { return }
        recurring[index].isPaused.toggle()
        NotificationScheduler.shared.syncSchedule(with: recurring)
        persistLedger()
    }

    /// Mirrors `Transaction.hasReceipt`'s update pattern — the flag lives
    /// here, the file itself lives in `ContractDocumentStore`, keyed by
    /// this entry's own `id`.
    func setHasDocument(_ hasDocument: Bool, for entry: RecurringEntry) {
        guard let index = recurring.firstIndex(where: { $0.id == entry.id }) else { return }
        recurring[index].hasDocument = hasDocument
        persistLedger()
    }

    /// Marks a contract cancelled without deleting it — the cancellation
    /// itself (that it happened, roughly when) is worth keeping, unlike a
    /// subscription, which `deleteRecurring` removes outright.
    func cancelContract(_ entry: RecurringEntry) {
        guard let index = recurring.firstIndex(where: { $0.id == entry.id }) else { return }
        recurring[index].isCancelled = true
        NotificationScheduler.shared.syncSchedule(with: recurring)
        NotificationScheduler.shared.cancelContractReminder(id: entry.id)
        persistLedger()
    }

    // MARK: - Delete

    func deleteTransaction(_ transaction: Transaction) {
        guard let index = transactions.firstIndex(where: { $0.id == transaction.id }) else { return }
        transactions.remove(at: index)
        applyCashDelta(transaction.isIncome ? -transaction.amount : transaction.amount)
        // A recurring entry spawned from this transaction has nothing left
        // to anchor to — stop tracking it too, rather than leaving a payment
        // schedule for something the user just said didn't happen.
        recurring.removeAll { $0.originTransactionID == transaction.id }
        NotificationScheduler.shared.syncSchedule(with: recurring)
        if transaction.hasReceipt {
            Task { await ReceiptStore.shared.delete(for: transaction.id) }
        }
        persistLedger()
    }

    func deleteAsset(_ asset: Asset) {
        guard let index = assets.firstIndex(where: { $0.id == asset.id }) else { return }
        // A goal linked to this asset has nothing left to track — snapshot
        // its last known value into manual tracking rather than leaving a
        // dangling reference that would silently show a stale or zero number.
        for i in goals.indices where goals[i].linkedAssetID == asset.id {
            goals[i].manualCurrentAmount = assets[index].value
            goals[i].trackingMode = .manual
            goals[i].linkedAssetID = nil
        }
        assets.remove(at: index)
        registerNetWorthChange(-asset.value, label: asset.name, kind: .assetRemoved)
        persistLedger()
    }

    func deleteGoal(_ goal: Goal) {
        goals.removeAll { $0.id == goal.id }
        persistLedger()
    }

    func deleteBudget(_ budget: Budget) {
        budgets.removeAll { $0.id == budget.id }
        NotificationScheduler.shared.cancelBudgetAlert(budgetID: budget.id)
        persistLedger()
    }

    func deleteLiability(_ liability: Liability) {
        guard let index = liabilities.firstIndex(where: { $0.id == liability.id }) else { return }
        liabilities.remove(at: index)
        registerNetWorthChange(liability.amount, label: liability.name, kind: .liabilityRemoved)
        persistLedger()
    }

    func deleteRecurring(_ entry: RecurringEntry) {
        recurring.removeAll { $0.id == entry.id }
        NotificationScheduler.shared.syncSchedule(with: recurring)
        NotificationScheduler.shared.cancelContractReminder(id: entry.id)
        if entry.hasDocument {
            Task { await ContractDocumentStore.shared.delete(for: entry.id) }
        }
        persistLedger()
    }

    private func insert(_ transaction: Transaction) {
        transactions.append(transaction)
        transactions.sort { $0.date > $1.date }
    }

    private func applyCashDelta(_ delta: Decimal) {
        overview = FinanceOverview(cash: overview.cash + delta, monthDelta: overview.monthDelta + delta)
        syncHistoryEndpoint()
    }

    /// Asset/liability changes move net worth but not cash — and unlike a
    /// real transaction, there was previously no record of *when* one of
    /// these happened, only the resulting current value. Logging it here,
    /// in the one place every asset/liability mutation already funnels
    /// through, is what lets "Why did this change?" tell a balance-sheet
    /// event apart from an ordinary bad spending month.
    private func registerNetWorthChange(_ delta: Decimal, label: String, kind: BalanceChangeEvent.Kind) {
        overview = FinanceOverview(cash: overview.cash, monthDelta: overview.monthDelta + delta)
        balanceChangeLog.append(BalanceChangeEvent(label: label, kind: kind, delta: delta))
        syncHistoryEndpoint()
    }

    /// Pins every chart period's endpoint to the current net worth so the
    /// line never contradicts the headline number above it.
    private func syncHistoryEndpoint() {
        let value = NSDecimalNumber(decimal: netWorth).doubleValue
        for period in ChartPeriod.allCases {
            guard var series = balanceHistory[period], let last = series.last else { continue }
            series[series.count - 1] = BalancePoint(date: last.date, value: value)
            balanceHistory[period] = series
        }
    }

    /// Writes the live ledger to disk. Called at the end of every mutating
    /// method above — explicit at each call site rather than a central hook,
    /// matching this file's existing style for `NotificationScheduler`
    /// resyncs. Net-worth chart history isn't part of this: it's already
    /// synthetic (see `rebuildFlatHistory`), and persisting a fabricated
    /// historical trend would be less honest than what's there today.
    private func persistLedger() {
        LedgerStorage.current = Ledger(
            cash: overview.cash, monthDelta: overview.monthDelta,
            assets: assets, liabilities: liabilities, transactions: transactions,
            recurring: recurring, goals: goals, budgets: budgets, balanceChangeLog: balanceChangeLog
        )
    }

    /// Checked after every expense add/edit — event-driven, not scheduled.
    /// A no-op unless a budget exists for that exact category. Each budget
    /// tracks its own `lastAlertedMonth`, so several can independently
    /// cross their limit in the same month without stepping on each other
    /// (the old single-category Spending Alert this replaced could only
    /// ever track one at a time).
    private func checkBudgetAlertsIfNeeded() {
        for budget in budgets where budget.alertsEnabled {
            let spend = categoryTotal(budget.category, in: Date())
            guard spend >= budget.monthlyLimit else { continue }
            let monthKey = NotificationScheduler.monthKey(for: Date())
            guard budget.lastAlertedMonth != monthKey else { continue }
            NotificationScheduler.shared.checkBudgetAlert(
                budgetID: budget.id, category: budget.category, currentTotal: spend, limit: budget.monthlyLimit
            )
            if let index = budgets.firstIndex(where: { $0.id == budget.id }) {
                budgets[index].lastAlertedMonth = monthKey
            }
        }
    }

    // MARK: - Derived reads

    func balancePoints(for period: ChartPeriod) -> [BalancePoint] {
        balanceHistory[period] ?? []
    }

    /// The "Money in/out" half of "Why did this change?" — real income and
    /// spending in a window, straight from `transactions`. No new data
    /// needed here, unlike the balance-sheet half below.
    func cashFlow(in range: ClosedRange<Date>) -> (income: Decimal, expenses: Decimal) {
        let windowed = transactions.filter { range.contains($0.date) }
        let income = windowed.filter(\.isIncome).reduce(Decimal(0)) { $0 + $1.amount }
        let expenses = windowed.filter { !$0.isIncome }.reduce(Decimal(0)) { $0 + $1.amount }
        return (income, expenses)
    }

    /// The "Balance changes" half — every asset/liability mutation logged
    /// in the window, most recent first.
    func balanceChanges(in range: ClosedRange<Date>) -> [BalanceChangeEvent] {
        balanceChangeLog.filter { range.contains($0.date) }.sorted { $0.date > $1.date }
    }

    /// A category's real spend this month — also the pre-fill source for
    /// the "Set a [category] limit" sheet.
    func categorySpend(for category: String, month: Date = Date()) -> Decimal {
        categoryTotal(category, in: month)
    }

    func budgetSpend(for budget: Budget, month: Date = Date()) -> Decimal {
        categorySpend(for: budget.category, month: month)
    }

    /// Deliberately **not** capped at 1.0, unlike `progress(for goal:)` —
    /// a budget needs to express "34% over," not just "done." Views clamp
    /// their own visual fill separately.
    func budgetProgress(for budget: Budget, month: Date = Date()) -> Double {
        guard budget.monthlyLimit > 0 else { return 0 }
        let spend = budgetSpend(for: budget, month: month)
        return NSDecimalNumber(decimal: spend / budget.monthlyLimit).doubleValue
    }

    func budgetStatus(for budget: Budget, month: Date = Date()) -> BudgetStatus {
        let progress = budgetProgress(for: budget, month: month)
        if progress >= 1.0 { return .overBudget }
        if progress >= 0.8 { return .nearLimit }
        return .onTrack
    }

    var upcoming: [RecurringEntry] {
        recurring.sorted { $0.nextDate < $1.nextDate }
    }

    /// Every non-income recurring entry — rent and insurance sit alongside
    /// Netflix here, so this reads as "Recurring payments," not
    /// "Subscriptions": `RecurringEntry` has no category field, so a
    /// subscription-specific filter isn't reconstructable from real data.
    var recurringPayments: [RecurringEntry] {
        recurring.filter { !$0.isIncome }.sorted { $0.nextDate < $1.nextDate }
    }

    var recurringPaymentsMonthlyTotal: Decimal {
        recurringPayments.reduce(0) { $0 + $1.monthlyEquivalentAmount }
    }

    /// "What am I paying every month?" — the spending-control half of
    /// Commitments.
    var subscriptions: [RecurringEntry] {
        recurringPayments.filter { $0.kind == .subscription }
    }

    /// Excludes paused entries — a paused subscription shouldn't count
    /// toward "what am I paying," even though it stays visible in the list.
    var subscriptionsMonthlyTotal: Decimal {
        subscriptions.filter { !$0.isPaused }.reduce(0) { $0 + $1.monthlyEquivalentAmount }
    }

    /// "What am I locked into, and when can I get out?" — the obligations
    /// half of Commitments.
    var contracts: [RecurringEntry] {
        recurringPayments.filter { $0.kind == .contract }
    }

    /// Real transactions scanned against a small honest keyword list — see
    /// `TaxRadarScanner`. Not NLP, not a language-model call.
    var taxItems: [TaxItem] {
        TaxRadarScanner.scan(transactions)
    }

    var taxDeductibleTotal: Decimal {
        taxItems.reduce(0) { $0 + $1.amount }
    }

    /// The live progress amount for a goal — whatever its linked asset is
    /// currently worth, or the manually-entered amount. Never stored on
    /// `Goal` itself, so a linked goal can never drift from its asset.
    func currentAmount(for goal: Goal) -> Decimal {
        guard goal.trackingMode == .linked, let linkedAssetID = goal.linkedAssetID,
              let asset = assets.first(where: { $0.id == linkedAssetID }) else {
            return goal.manualCurrentAmount
        }
        return asset.value
    }

    func progress(for goal: Goal) -> Double {
        guard goal.targetAmount > 0 else { return 0 }
        let ratio = currentAmount(for: goal) / goal.targetAmount
        return min(1, max(0, NSDecimalNumber(decimal: ratio).doubleValue))
    }

    /// `nil` means no monthly contribution is set — there's nothing to
    /// project a completion date from, which the view distinguishes from
    /// "0 months to go."
    func monthsRemaining(for goal: Goal) -> Int? {
        guard goal.monthlyContribution > 0 else { return nil }
        let remaining = goal.targetAmount - currentAmount(for: goal)
        guard remaining > 0 else { return 0 }
        return Int(ceil(NSDecimalNumber(decimal: remaining / goal.monthlyContribution).doubleValue))
    }

    /// Income/expense totals for any month — defaults to the current one.
    /// Generalized (rather than hardcoded to "now") so the same math powers
    /// both the live Home summary and the Monthly History browser.
    func monthIncome(for month: Date = Date()) -> Decimal {
        transactionsInMonth(month).filter(\.isIncome).reduce(0) { $0 + $1.amount }
    }

    func monthExpenses(for month: Date = Date()) -> Decimal {
        transactionsInMonth(month).filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }
    }

    func monthSaved(for month: Date = Date()) -> Decimal {
        monthIncome(for: month) - monthExpenses(for: month)
    }

    func savingsRate(for month: Date = Date()) -> Double {
        let income = monthIncome(for: month)
        guard income > 0 else { return 0 }
        let rate = (income - monthExpenses(for: month)) / income
        return max(0, NSDecimalNumber(decimal: rate).doubleValue)
    }

    /// Top three expense categories for the month, largest first — the
    /// whole "monthly summary", no analytics overload.
    func topSpending(for month: Date = Date()) -> [(category: String, total: Decimal)] {
        let expenses = transactionsInMonth(month).filter { !$0.isIncome }
        let grouped = Dictionary(grouping: expenses, by: \.category)
            .mapValues { $0.reduce(Decimal(0)) { $0 + $1.amount } }
        return grouped.sorted { $0.value > $1.value }.prefix(3).map { ($0.key, $0.value) }
    }

    /// Distinct months that have at least one transaction, most recent
    /// first — what Monthly History lets the user page through. The
    /// current month is always included even when empty, so "this month"
    /// is never a dead end the first time you open it.
    var monthsWithActivity: [Date] {
        let cal = Calendar.current
        var starts = Set(transactions.map { cal.dateInterval(of: .month, for: $0.date)?.start ?? $0.date })
        starts.insert(cal.dateInterval(of: .month, for: Date())?.start ?? Date())
        return starts.sorted(by: >)
    }

    private func transactionsInMonth(_ month: Date) -> [Transaction] {
        let cal = Calendar.current
        return transactions.filter { cal.isDate($0.date, equalTo: month, toGranularity: .month) }
    }

    /// A plain-language comparison of the month's top category against its
    /// own average across other months with data — real arithmetic on real
    /// transactions, framed conversationally. Not a language-model call;
    /// same honesty as the rest of the app's "insights."
    func monthlyInsight(for month: Date) -> String? {
        let cal = Calendar.current
        guard let topCategory = topSpending(for: month).first else { return nil }

        let otherMonths = monthsWithActivity.filter { !cal.isDate($0, equalTo: month, toGranularity: .month) }
        let otherTotals = otherMonths.compactMap { other -> Decimal? in
            let total = transactionsInMonth(other)
                .filter { !$0.isIncome && $0.category == topCategory.category }
                .reduce(Decimal(0)) { $0 + $1.amount }
            return total > 0 ? total : nil
        }

        let categoryName = categoryTitle(topCategory.category)
        guard !otherTotals.isEmpty else {
            return String.localized("\(categoryName) was your top category, at \(Currency.string(topCategory.total)).")
        }

        let average = otherTotals.reduce(Decimal(0), +) / Decimal(otherTotals.count)
        guard average > 0 else { return nil }
        let diff = NSDecimalNumber(decimal: (topCategory.total - average) / average).doubleValue
        let percent = Int(abs(diff) * 100)

        if diff > 0.1 {
            return String.localized("\(categoryName) ran \(percent)% above your typical month.")
        } else if diff < -0.1 {
            return String.localized("\(categoryName) ran \(percent)% below your typical month — nice.")
        } else {
            return String.localized("\(categoryName) spending was about typical this month.")
        }
    }

    /// Maps a stored category key (`TransactionCategory.rawValue`, always
    /// English — it's what's persisted on `Transaction` and matched
    /// elsewhere) to its localized display name. Falls back to the raw
    /// value for categories outside the closed set (e.g. "Income", which
    /// never appears here since this only ever runs over expenses).
    private func categoryTitle(_ raw: String) -> String {
        TransactionCategory(rawValue: raw)?.title ?? raw
    }

    // MARK: - Spending insight

    /// This month's total spend vs. its own average across other months —
    /// same honesty standard as `monthlyInsight`, generalized from one
    /// category to the whole month, with per-category deltas explaining
    /// what's driving the change. Returns `.empty` (never a fabricated
    /// number) when there's no expense activity or no comparable history.
    var spendingInsight: SpendingInsight {
        let month = Date()
        let spent = monthExpenses(for: month)
        guard spent > 0, let average = monthlyAverageExpenses(excluding: month) else { return .empty }

        let diff = NSDecimalNumber(decimal: (spent - average) / average).doubleValue
        let percentIncrease = Int((diff * 100).rounded())
        let deltas = categoryDeltas(for: month)
        let topDelta = deltas.first

        return SpendingInsight(
            percentIncrease: percentIncrease,
            spentSoFar: spent,
            aboveAverage: max(0, spent - average),
            categoryDeltas: deltas,
            recommendationCategory: topDelta?.category ?? "",
            recommendationMonthlyCut: topDelta?.increase ?? 0,
            recommendationAnnualSavings: (topDelta?.increase ?? 0) * 12
        )
    }

    /// Shared by the Insights tab and Home's teaser, so the two never say
    /// different things. Falls back to `monthlyInsight` (already handles
    /// the above/below/typical cases) when there's no category driving a
    /// real increase — never a hardcoded claim.
    var spendingHeadline: String? {
        guard !spendingInsight.categoryDeltas.isEmpty else { return monthlyInsight(for: Date()) }
        return String.localized("Spending is up \(spendingInsight.percentIncrease)% this month")
    }

    var spendingSubheadline: String? {
        guard !spendingInsight.categoryDeltas.isEmpty else { return nil }
        let names = spendingInsight.categoryDeltas.prefix(2).map { categoryTitle($0.category) }
        return String.localized("Mostly \(names.joined(separator: " and ")) — see why")
    }

    /// Every category present this month, largest first, each with its
    /// real month-over-month change — the "deeper breakdown" Premium adds
    /// on top of the free top-3 `topSpending`.
    func categoryBreakdown(for month: Date = Date()) -> [CategoryBreakdownRow] {
        let expenses = transactionsInMonth(month).filter { !$0.isIncome }
        let grouped = Dictionary(grouping: expenses, by: \.category)
            .mapValues { $0.reduce(Decimal(0)) { $0 + $1.amount } }
        return grouped.map { category, total in
            CategoryBreakdownRow(category: category, total: total, deltaVsAverage: categoryAverage(category, excluding: month).map { total - $0 })
        }.sorted { $0.total > $1.total }
    }

    /// The plain-language "why" behind a category delta bar — real counts,
    /// not a fabricated observation, in the spirit of "4 more times than
    /// usual": this app tracks per-category transaction counts, not
    /// per-merchant visits, so that's the honest analog.
    func explanation(for delta: CategoryDelta, month: Date = Date()) -> String {
        let count = categoryTransactionCount(delta.category, in: month)
        let categoryName = categoryTitle(delta.category)
        guard let averageCount = categoryAverageTransactionCount(delta.category, excluding: month) else {
            return String.localized("\(categoryName) ran \(Currency.string(delta.increase)) above your typical month.")
        }
        return String.localized("You logged \(count) \(categoryName) purchases this month, versus your usual \(averageCount) — \(Currency.string(delta.increase)) more than your average spend.")
    }

    private func categoryTotal(_ category: String, in month: Date) -> Decimal {
        transactionsInMonth(month).filter { !$0.isIncome && $0.category == category }.reduce(Decimal(0)) { $0 + $1.amount }
    }

    private func categoryTransactionCount(_ category: String, in month: Date) -> Int {
        transactionsInMonth(month).filter { !$0.isIncome && $0.category == category }.count
    }

    private func categoryAverage(_ category: String, excluding month: Date) -> Decimal? {
        let cal = Calendar.current
        let otherMonths = monthsWithActivity.filter { !cal.isDate($0, equalTo: month, toGranularity: .month) }
        let totals = otherMonths.compactMap { other -> Decimal? in
            let total = categoryTotal(category, in: other)
            return total > 0 ? total : nil
        }
        guard !totals.isEmpty else { return nil }
        return totals.reduce(Decimal(0), +) / Decimal(totals.count)
    }

    private func categoryAverageTransactionCount(_ category: String, excluding month: Date) -> Int? {
        let cal = Calendar.current
        let otherMonths = monthsWithActivity.filter { !cal.isDate($0, equalTo: month, toGranularity: .month) }
        let counts = otherMonths.map { categoryTransactionCount(category, in: $0) }.filter { $0 > 0 }
        guard !counts.isEmpty else { return nil }
        return Int((Double(counts.reduce(0, +)) / Double(counts.count)).rounded())
    }

    private func monthlyAverageExpenses(excluding month: Date) -> Decimal? {
        let cal = Calendar.current
        let otherMonths = monthsWithActivity.filter { !cal.isDate($0, equalTo: month, toGranularity: .month) }
        let totals = otherMonths.compactMap { other -> Decimal? in
            let total = monthExpenses(for: other)
            return total > 0 ? total : nil
        }
        guard !totals.isEmpty else { return nil }
        return totals.reduce(Decimal(0), +) / Decimal(totals.count)
    }

    /// Top categories this month with a real, positive increase over their
    /// own average — never invented, largest increase first.
    private func categoryDeltas(for month: Date) -> [CategoryDelta] {
        topSpending(for: month).compactMap { category, total -> CategoryDelta? in
            guard let average = categoryAverage(category, excluding: month) else { return nil }
            let increase = total - average
            guard increase > 0 else { return nil }
            return CategoryDelta(category: category, increase: increase)
        }.sorted { $0.increase > $1.increase }
    }

    // MARK: - Financial health

    /// A 0–100 score computed purely from the user's real position —
    /// savings rate, debt load, cash runway, and how much transaction
    /// history there is to judge from. Same honesty standard as
    /// `monthlyInsight`: real arithmetic on real data, recomputed live from
    /// `@Published` state, never a fabricated or stale number.
    var financialHealth: FinancialHealth {
        guard !transactions.isEmpty else { return .empty }

        let savings = savingsRateScore()
        let debt = debtScore()
        let runway = cashRunwayScore()
        let history = historyScore()
        let score = min(100, max(0, Int((savings + debt + runway + history).rounded())))
        let monthsWithData = monthsWithActivity.count

        return FinancialHealth(
            score: score,
            grade: healthGrade(score: score, monthsWithData: monthsWithData),
            tier: healthTier(score: score, monthsWithData: monthsWithData),
            strengths: healthStrengths(savingsScore: savings, debtScore: debt, runwayScore: runway, monthsWithData: monthsWithData)
        )
    }

    /// Mirrors `healthGrade`'s thresholds but returns a stable, non-localized
    /// tier — `GoalsView` colors the grade from this, never from the
    /// localized `grade` string itself.
    private func healthTier(score: Int, monthsWithData: Int) -> HealthTier {
        guard monthsWithData >= 2 else { return .building }
        switch score {
        case 50...: return .strong
        case 30..<50: return .attention
        default: return .building
        }
    }

    /// Full marks at a 20% savings rate or better — the commonly-cited
    /// personal-finance rule of thumb.
    private func savingsRateScore() -> Double {
        min(1, savingsRate() / 0.20) * 40
    }

    /// Full marks with no debt at all; otherwise scored against debt as a
    /// share of everything that could pay it down.
    private func debtScore() -> Double {
        guard debtTotal > 0 else { return 25 }
        let base = max(assetsTotal + cash, 1)
        let ratio = NSDecimalNumber(decimal: debtTotal / base).doubleValue
        return max(0, 1 - min(1, ratio)) * 25
    }

    /// Full marks at 6 months of expenses covered in cash — a standard
    /// emergency-fund benchmark.
    private func cashRunwayScore() -> Double {
        let expenses = monthExpenses()
        guard expenses > 0 else { return cash > 0 ? 25 : 0 }
        let months = NSDecimalNumber(decimal: cash / expenses).doubleValue
        return min(1, max(0, months / 6)) * 25
    }

    /// Full marks at 3 or more distinct months of activity — enough to
    /// judge a trend rather than a single snapshot.
    private func historyScore() -> Double {
        min(1, max(0, (Double(monthsWithActivity.count) - 1) / 2)) * 10
    }

    private func healthGrade(score: Int, monthsWithData: Int) -> String {
        guard monthsWithData >= 2 else { return String.localized("Building Your Picture") }
        switch score {
        case 85...: return String.localized("Excellent")
        case 70..<85: return String.localized("Great")
        case 50..<70: return String.localized("Good")
        case 30..<50: return String.localized("Needs Attention")
        default: return String.localized("Getting Started")
        }
    }

    private func healthStrengths(savingsScore: Double, debtScore: Double, runwayScore: Double, monthsWithData: Int) -> [String] {
        guard monthsWithData >= 2 else {
            var lines = [String.localized("We'll get a fuller picture as you log more months of activity.")]
            if savingsScore >= 28 {
                lines.append(savingsRateSentence())
            } else if debtScore >= 17.5 {
                lines.append(debtSentence())
            }
            return lines
        }

        var lines: [String] = []
        if savingsScore >= 28 { lines.append(savingsRateSentence()) }
        if debtScore >= 17.5 { lines.append(debtSentence()) }
        if runwayScore >= 17.5 { lines.append(runwaySentence()) }
        if lines.count < 2 {
            lines.append(weakestFactorSentence(savingsScore: savingsScore, debtScore: debtScore, runwayScore: runwayScore))
        }
        return Array(lines.prefix(4))
    }

    private func savingsRateSentence() -> String {
        String.localized("You're saving \(Int(savingsRate() * 100))% of your income each month — well above the recommended 20%.")
    }

    private func debtSentence() -> String {
        String.localized("Your debt is well under control relative to your assets.")
    }

    private func runwaySentence() -> String {
        let expenses = monthExpenses()
        guard expenses > 0 else { return String.localized("You have a cash buffer with no regular expenses tracked yet.") }
        let months = Int(NSDecimalNumber(decimal: cash / expenses).doubleValue)
        return String.localized("You have \(months) months of expenses covered in cash — a solid safety buffer.")
    }

    private func weakestFactorSentence(savingsScore: Double, debtScore: Double, runwayScore: Double) -> String {
        let factors: [(score: Double, max: Double, message: String)] = [
            (savingsScore, 40, String.localized("Try setting aside a bit more each month — even a small savings rate adds up.")),
            (debtScore, 25, String.localized("Paying down debt relative to your assets will strengthen your position.")),
            (runwayScore, 25, String.localized("Building a bigger cash buffer will give you more breathing room."))
        ]
        return factors.min { $0.score / $0.max < $1.score / $1.max }!.message
    }

    // MARK: - Forecast (Premium)

    /// A real 30-day projection — a least-squares trend line fit to the
    /// actual last 30 days of balance history, anchored to continue exactly
    /// from today's real value, netted against real upcoming bills. No
    /// fabricated numbers; a brand-new account's flat history naturally
    /// produces a flat ("holding steady") projection, not a crash.
    var forecast: ForecastData {
        let past = balancePoints(for: .month)
        guard past.count >= 2, let today = past.last else { return .empty }

        let slope = Self.trendSlope(past)
        let projected = projectedPoints(anchoredAt: today, slope: slope, days: 30)
        let bills = upcomingBillsTotal(within: 30)
        let afterBills = (projected.last?.value ?? today.value) - NSDecimalNumber(decimal: bills).doubleValue

        return ForecastData(
            past: past, projected: projected, afterBills: afterBills,
            projectedDateLabel: Self.dateLabel(daysFromNow: 30)
        )
    }

    /// The "why" behind the forecast chart — real trend direction and real
    /// known upcoming bills, framed conversationally. Built the same honest
    /// way as `monthlyInsight`: genuinely computed, never an LLM call.
    var forecastNarrative: String? {
        let past = balancePoints(for: .month)
        guard past.count >= 2 else { return nil }

        let slope = Self.trendSlope(past)
        let bills = upcomingBillsTotal(within: 30)

        // Six complete sentences, not a composed fragment — concatenating a
        // translated clause into different templates doesn't hold up across
        // languages with different grammar/word order, so each combination
        // gets its own full, independently-translatable sentence.
        if bills > 0 {
            let billsAmount = Currency.string(bills)
            if slope > 1 {
                return String.localized("Based on the last 30 days, your balance has been trending up, with \(billsAmount) in known bills ahead.")
            } else if slope < -1 {
                return String.localized("Based on the last 30 days, your balance has been trending down, with \(billsAmount) in known bills ahead.")
            } else {
                return String.localized("Based on the last 30 days, your balance has been holding steady, with \(billsAmount) in known bills ahead.")
            }
        } else {
            if slope > 1 {
                return String.localized("Based on the last 30 days, your balance has been trending up.")
            } else if slope < -1 {
                return String.localized("Based on the last 30 days, your balance has been trending down.")
            } else {
                return String.localized("Based on the last 30 days, your balance has been holding steady.")
            }
        }
    }

    private func upcomingBillsTotal(within days: Int) -> Decimal {
        let cutoff = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
        return recurring.filter { !$0.isIncome && $0.nextDate <= cutoff }.reduce(Decimal(0)) { $0 + $1.amount }
    }

    /// Least-squares slope (value change per day) over a balance series.
    private static func trendSlope(_ points: [BalancePoint]) -> Double {
        guard points.count >= 2, let first = points.first?.date else { return 0 }
        let cal = Calendar.current
        let xs = points.map { Double(cal.dateComponents([.day], from: first, to: $0.date).day ?? 0) }
        let ys = points.map(\.value)
        let n = Double(xs.count)
        let sumX = xs.reduce(0, +)
        let sumY = ys.reduce(0, +)
        let sumXY = zip(xs, ys).reduce(0) { $0 + $1.0 * $1.1 }
        let sumXX = xs.reduce(0) { $0 + $1 * $1 }
        let denominator = n * sumXX - sumX * sumX
        guard denominator != 0 else { return 0 }
        return (n * sumXY - sumX * sumY) / denominator
    }

    /// Anchored exactly at today's real balance (not the regression's
    /// fitted value for today, which could differ slightly) so the chart
    /// never shows a visible jump where "past" meets "projected."
    private func projectedPoints(anchoredAt today: BalancePoint, slope: Double, days: Int) -> [BalancePoint] {
        let cal = Calendar.current
        let stepCount = 8
        return (0...stepCount).map { step in
            let dayOffset = Double(days) * Double(step) / Double(stepCount)
            let date = cal.date(byAdding: .day, value: Int(dayOffset), to: today.date) ?? today.date
            return BalancePoint(date: date, value: today.value + slope * dayOffset)
        }
    }

    private static func dateLabel(daysFromNow days: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.current.locale
        formatter.setLocalizedDateFormatFromTemplate("d MMM")
        return formatter.string(from: date)
    }

    /// Grouped by calendar day, most recent first, for the Activity list's sections.
    var transactionsByDay: [(label: String, items: [Transaction])] {
        let cal = Calendar.current
        let groups = Dictionary(grouping: transactions) { cal.startOfDay(for: $0.date) }
        return groups.keys.sorted(by: >).map { day in
            (label: Self.dayLabel(for: day), items: groups[day]!.sorted { $0.date > $1.date })
        }
    }

    private static func dayLabel(for day: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(day) { return String.localized("Today") }
        if cal.isDateInYesterday(day) { return String.localized("Yesterday") }
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.current.locale
        formatter.setLocalizedDateFormatFromTemplate("EEEE, d MMMM")
        return formatter.string(from: day)
    }
}
