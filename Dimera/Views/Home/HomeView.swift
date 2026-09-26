import SwiftUI

/// Answers three questions at a glance — how much do I have, how much did I
/// save, am I improving — with data entry demoted to a floating "+" and
/// everything else derived from the position.
struct HomeView: View {
    @EnvironmentObject private var store: FinanceStore
    @Binding var selection: AppTab

    @State private var period: ChartPeriod = .month
    @State private var selectedIndex: Int?
    @State private var activeSheet: ActiveSheet?
    @State private var editingTransaction: Transaction?
    @State private var editingRecurring: RecurringEntry?
    @State private var showMonthlyHistory = false

    private enum ActiveSheet: Identifiable {
        case add(AddEntrySheet.Kind?)
        case settings
        case breakdown
        case deltaBreakdown

        var id: String {
            switch self {
            case .add(let kind): return "add-\(kind?.rawValue ?? "chooser")"
            case .settings: return "settings"
            case .breakdown: return "breakdown"
            case .deltaBreakdown: return "deltaBreakdown"
            }
        }
    }

    private var points: [BalancePoint] { store.balancePoints(for: period) }

    private var displayedValue: Double {
        if let selectedIndex, points.indices.contains(selectedIndex) {
            return points[selectedIndex].value
        }
        return NSDecimalNumber(decimal: store.netWorth).doubleValue
    }

    private var displayedDelta: Double {
        guard let first = points.first else { return 0 }
        return displayedValue - first.value
    }

    private var displayedLabel: String {
        if let selectedIndex, points.indices.contains(selectedIndex) {
            let percent = Int((Double(selectedIndex) / Double(max(points.count - 1, 1))) * 100)
            return String.localized("Net worth · \(percent)% through period")
        }
        return String.localized("Net worth")
    }

    private var deltaWindowLabel: String {
        selectedIndex == nil ? period.windowLabel : String.localized("from period start")
    }

    /// The exact span the visible delta covers — period start through
    /// whatever's currently displayed (today, or a scrubbed point) — reused
    /// as-is for "Why did this change?" so the breakdown always explains
    /// precisely the number just tapped, never a different window.
    private var windowRange: ClosedRange<Date>? {
        guard let start = points.first?.date else { return nil }
        // Mirrors `displayedValue`: when nothing's scrubbed, the headline
        // reflects the live net worth *right now*, not the chart's last
        // plotted point (whose date is fixed at the last history rebuild
        // and can lag behind an event logged seconds ago in this same
        // session) — using that stale date here would silently drop any
        // just-added balance-sheet event from its own explanation.
        let end: Date
        if let selectedIndex, points.indices.contains(selectedIndex) {
            end = points[selectedIndex].date
        } else {
            end = Date()
        }
        guard start <= end else { return nil }
        return start...end
    }

    private var windowBalanceChanges: [BalanceChangeEvent] {
        guard let windowRange else { return [] }
        return store.balanceChanges(in: windowRange)
    }

    private var windowCashFlow: (income: Decimal, expenses: Decimal) {
        guard let windowRange else { return (0, 0) }
        return store.cashFlow(in: windowRange)
    }

    /// One diamond per balance-sheet event across the whole visible chart
    /// period (not just the scrubbed window) — snapped onto the nearest
    /// existing point's own date/value so it always sits exactly on the
    /// rendered line, never at an invented coordinate. Uses `Date()` as the
    /// upper bound, not the chart's last plotted point, for the same reason
    /// `windowRange` does: the trailing point's date is fixed at the last
    /// history rebuild and can otherwise exclude an event from this very
    /// session.
    private var chartEventMarkers: [BalancePoint] {
        guard let start = points.first?.date else { return [] }
        return store.balanceChanges(in: start...Date()).compactMap { event in
            points.min { abs($0.date.timeIntervalSince(event.date)) < abs($1.date.timeIntervalSince(event.date)) }
        }
    }

    /// Only set when the window actually contains a balance-sheet event —
    /// the common case (ordinary spending, no asset/liability edits) is
    /// left exactly as it reads today, since it's already correct there.
    private var deltaQualifier: String? {
        guard !windowBalanceChanges.isEmpty else { return nil }
        let hasCashFlow = windowCashFlow.income > 0 || windowCashFlow.expenses > 0
        return hasCashFlow ? String.localized("Includes a balance change") : String.localized("Balance change")
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: return String.localized("Good morning,")
        case 12..<18: return String.localized("Good afternoon,")
        default: return String.localized("Good evening,")
        }
    }

    private var monthName: String {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.current.locale
        formatter.setLocalizedDateFormatFromTemplate("MMMM")
        return formatter.string(from: Date())
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header

                    netWorthHeadline
                        .padding(.top, 20)
                        .animation(.snappy(duration: 0.15), value: selectedIndex)

                    BalanceLineChart(points: points, selectedIndex: $selectedIndex, events: chartEventMarkers)
                        .frame(height: 170)
                        .padding(.top, 14)

                    PeriodPicker(selection: $period)
                        .padding(.top, 6)
                        .onChange(of: period) { selectedIndex = nil }

                    positionTiles
                        .padding(.top, 24)

                    debtRow
                        .padding(.top, 10)

                    if !store.upcoming.isEmpty {
                        SectionLabel(title: String.localized("Upcoming"))
                            .padding(.top, 26)
                            .padding(.bottom, 10)
                        upcomingCard
                    }

                    if store.monthIncome() > 0 || store.monthExpenses() > 0 {
                        HStack {
                            SectionLabel(title: String.localized("\(monthName) summary"))
                            Spacer()
                            Button {
                                showMonthlyHistory = true
                            } label: {
                                Label("History", systemImage: "clock.arrow.circlepath")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(MonetaColor.textSecondary)
                            }
                        }
                        .padding(.top, 26)
                        .padding(.bottom, 10)
                        monthSummaryCard
                    }

                    // Real, computed insight — only shown once there's enough
                    // history to say something true, never a fabricated claim.
                    if let headline = store.spendingHeadline {
                        SectionLabel(title: String.localized("For you"))
                            .padding(.top, 26)
                            .padding(.bottom, 10)
                        InsightTeaser(headline: headline, subheadline: store.spendingSubheadline) { selection = .insights }
                    }

                    recentSection
                }
                .padding(.horizontal, MonetaMetrics.screenPadding)
                .padding(.bottom, 90)
            }

            floatingAddButton
        }
        .adaptiveContentWidth()
        .background(MonetaColor.canvas)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .add(let kind):
                AddEntrySheet(kind: kind)
            case .settings:
                SettingsView()
            case .breakdown:
                NetWorthBreakdownView()
            case .deltaBreakdown:
                WhyDidThisChangeSheet(
                    periodLabel: deltaWindowLabel, totalDelta: Decimal(displayedDelta),
                    cashFlow: windowCashFlow, balanceChanges: windowBalanceChanges
                )
            }
        }
        .sheet(item: $editingTransaction) { transaction in
            EditTransactionSheet(transaction: transaction)
        }
        .sheet(item: $editingRecurring) { entry in
            EditRecurringSheet(entry: entry)
        }
        .sheet(isPresented: $showMonthlyHistory) {
            MonthlyHistoryView()
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(.subheadline)
                    .foregroundStyle(MonetaColor.textSecondary)
                Text("Vedat")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(MonetaColor.textPrimary)
            }
            Spacer()
            Button {
                activeSheet = .settings
            } label: {
                Circle()
                    .fill(MonetaColor.cardElevated)
                    .frame(width: 36, height: 36)
                    .overlay {
                        Text("V")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(MonetaColor.accent)
                    }
            }
            .accessibilityLabel("Account and settings")
        }
        .padding(.top, 8)
    }

    private var netWorthHeadline: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(displayedLabel)
                .font(.footnote)
                .foregroundStyle(MonetaColor.textSecondary)
                .contentTransition(.identity)
            AmountText(displayedValue, isTransient: selectedIndex != nil)
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .foregroundStyle(MonetaColor.textPrimary)
            Button {
                activeSheet = .deltaBreakdown
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 5) {
                            Image(systemName: displayedDelta >= 0 ? "arrow.up" : "arrow.down")
                                .font(.caption.weight(.bold))
                            AmountText(abs(displayedDelta), isTransient: selectedIndex != nil)
                                .font(.subheadline.weight(.semibold))
                            Text(deltaWindowLabel)
                                .font(.subheadline)
                                .foregroundStyle(MonetaColor.textSecondary)
                        }
                        // On its own line rather than merged into the same
                        // row as the amount — that combination reliably
                        // wrapped mid-phrase on narrower devices, splitting
                        // "this month" from its qualifier in a way that read
                        // as two unrelated fragments (NN Group: aesthetic
                        // and minimalist design — don't force unrelated
                        // information into a single crowded line).
                        if let deltaQualifier {
                            Text(deltaQualifier)
                                .font(.footnote)
                                .foregroundStyle(MonetaColor.textTertiary)
                        }
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(MonetaColor.textTertiary)
                }
                .foregroundStyle(displayedDelta >= 0 ? MonetaColor.gain : MonetaColor.loss)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint("Double tap to see what changed")
        }
    }

    private var positionTiles: some View {
        HStack(spacing: 10) {
            positionTile(title: String.localized("Cash"), amount: store.cash)
            positionTile(title: String.localized("Savings"), amount: store.savingsTotal)
            positionTile(title: String.localized("Investments"), amount: store.investmentsTotal)
        }
    }

    private func positionTile(title: String, amount: Decimal) -> some View {
        Button {
            activeSheet = .breakdown
        } label: {
            StatTile(title: title, amount: amount)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Shows your net worth breakdown")
    }

    private var debtRow: some View {
        Button {
            activeSheet = .breakdown
        } label: {
            HStack {
                Text("Debt")
                    .font(.footnote)
                    .foregroundStyle(MonetaColor.textSecondary)
                Spacer()
                AmountText(store.debtTotal)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(store.debtTotal > 0 ? MonetaColor.loss : MonetaColor.textSecondary)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(MonetaColor.textTertiary)
            }
            .padding(13)
            .monetaCard(radius: MonetaMetrics.tileRadius)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Shows your net worth breakdown")
    }

    private var upcomingCard: some View {
        VStack(spacing: 0) {
            let items = Array(store.upcoming.prefix(3))
            ForEach(items) { entry in
                HStack(spacing: 13) {
                    IconBadge(style: entry.isIncome ? .income : .initial(String(entry.name.first ?? "?")), size: 36)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(entry.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(MonetaColor.textPrimary)
                        Text(entry.dueLabel)
                            .font(.footnote)
                            .foregroundStyle(MonetaColor.textSecondary)
                    }
                    Spacer(minLength: 6)
                    AmountText(entry.amount, signed: entry.isIncome)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(entry.isIncome ? MonetaColor.gain : MonetaColor.textPrimary)
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
                .onTapGesture { editingRecurring = entry }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                if entry.id != items.last?.id {
                    Divider().overlay(MonetaColor.separator)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .monetaCard()
    }

    private var monthSummaryCard: some View {
        let saved = store.monthSaved()
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                summaryStat(title: String.localized("Income"), amount: store.monthIncome(), tint: MonetaColor.gain)
                summaryStat(title: String.localized("Spent"), amount: store.monthExpenses(), tint: MonetaColor.textPrimary)
                summaryStat(title: String.localized("Saved"), amount: saved, tint: saved >= 0 ? MonetaColor.accent : MonetaColor.loss)
            }

            if !store.topSpending().isEmpty {
                Divider().overlay(MonetaColor.separator)
                Text("Top spending")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(MonetaColor.textSecondary)
                VStack(spacing: 8) {
                    ForEach(store.topSpending(), id: \.category) { item in
                        HStack {
                            Text(TransactionCategory(rawValue: item.category)?.title ?? item.category)
                                .font(.subheadline)
                                .foregroundStyle(MonetaColor.textPrimary)
                            Spacer()
                            AmountText(item.total)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(MonetaColor.textPrimary)
                        }
                    }
                }
            }
        }
        .padding(16)
        .monetaCard()
    }

    private func summaryStat(title: String, amount: Decimal, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(MonetaColor.textSecondary)
            AmountText(amount)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var recentSection: some View {
        HStack {
            SectionLabel(title: String.localized("Recent"))
            Spacer()
            if !store.transactions.isEmpty {
                Button {
                    activeSheet = .add(nil)
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(MonetaColor.textSecondary)
                }
            }
        }
        .padding(.top, 26)
        .padding(.bottom, 4)

        if store.transactions.isEmpty {
            emptyStory
        } else {
            VStack(spacing: 0) {
                ForEach(Array(store.transactions.prefix(3))) { transaction in
                    TransactionRow(transaction: transaction)
                        .contentShape(Rectangle())
                        .onTapGesture { editingTransaction = transaction }
                    if transaction.id != store.transactions.prefix(3).last?.id {
                        Divider().overlay(MonetaColor.separator)
                    }
                }
            }
        }
    }

    private var emptyStory: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your financial story starts here.")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MonetaColor.textPrimary)
            Text("Add your first expense — it takes ten seconds.")
                .font(.footnote)
                .foregroundStyle(MonetaColor.textSecondary)
            Button {
                activeSheet = .add(.expense)
            } label: {
                Text("Add expense")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MonetaColor.canvas)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(MonetaColor.textPrimary, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .monetaCard()
    }

    private var floatingAddButton: some View {
        Button {
            activeSheet = .add(nil)
        } label: {
            Group {
                if #available(iOS 26, *) {
                    Image(systemName: "plus")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(MonetaColor.canvas)
                        .frame(width: 56, height: 56)
                        .glassEffect(.regular.tint(MonetaColor.textPrimary).interactive(), in: Circle())
                } else {
                    Image(systemName: "plus")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(MonetaColor.canvas)
                        .frame(width: 56, height: 56)
                        .background(MonetaColor.textPrimary, in: Circle())
                        .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.trailing, 20)
        .padding(.bottom, 14)
        .accessibilityLabel("Add entry")
    }
}

private struct InsightTeaser: View {
    let headline: String
    var subheadline: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(MonetaColor.accent.opacity(0.14))
                    .frame(width: 34, height: 34)
                    .overlay {
                        Image(systemName: "sparkle")
                            .foregroundStyle(MonetaColor.accent)
                    }
                VStack(alignment: .leading, spacing: 1) {
                    Text(headline)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MonetaColor.textPrimary)
                    if let subheadline {
                        Text(subheadline)
                            .font(.footnote)
                            .foregroundStyle(MonetaColor.textSecondary)
                    }
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 6)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(MonetaColor.textTertiary)
            }
            .padding(15)
            .monetaCard()
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens Insights")
    }
}

#Preview {
    let store = FinanceStore()
    RootTabView()
        .environmentObject(store)
        .task { await store.load() }
}
