import SwiftUI

/// The drill-down behind the Home delta caption — answers exactly the
/// question a big net-worth swing raises: was this normal spending, or did
/// something on the balance sheet move? Splits the same window's activity
/// into "Money in/out" (real transactions) and "Balance changes" (asset/
/// liability edits), reusing `NetWorthBreakdownView`'s visual conventions so
/// the two sibling sheets feel like one family.
struct WhyDidThisChangeSheet: View {
    @Environment(\.dismiss) private var dismiss

    let periodLabel: String
    let totalDelta: Decimal
    let cashFlow: (income: Decimal, expenses: Decimal)
    let balanceChanges: [BalanceChangeEvent]

    private var netCashFlow: Decimal { cashFlow.income - cashFlow.expenses }
    private var netBalanceChange: Decimal { balanceChanges.reduce(Decimal(0)) { $0 + $1.delta } }
    /// Whatever the two known categories don't account for — inevitable for
    /// windows that predate this log's rollout, since there's no retroactive
    /// history. Shown explicitly rather than letting the breakdown silently
    /// under-count (NN Group: match between system and the real world).
    private var earlierActivity: Decimal { totalDelta - netCashFlow - netBalanceChange }

    private var hasCashFlow: Bool { cashFlow.income != 0 || cashFlow.expenses != 0 }
    private var hasBalanceChanges: Bool { !balanceChanges.isEmpty }
    private var hasEarlierActivity: Bool { earlierActivity != 0 }
    private var hasAnyActivity: Bool { hasCashFlow || hasBalanceChanges || hasEarlierActivity }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    headerCard
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                }

                if hasAnyActivity {
                    if hasCashFlow {
                        moneyInOutSection
                    }
                    if hasBalanceChanges {
                        balanceChangesSection
                    }
                    if hasEarlierActivity {
                        earlierActivitySection
                    }
                } else {
                    emptyStateSection
                }
            }
            .scrollContentBackground(.hidden)
            .background(MonetaColor.canvas)
            .navigationTitle(String.localized("Why did this change?"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String.localized("Done")) { dismiss() }
                }
            }
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(spacing: 6) {
            Text(periodLabel)
                .font(.subheadline)
                .foregroundStyle(MonetaColor.textSecondary)
            HStack(spacing: 5) {
                Image(systemName: totalDelta >= 0 ? "arrow.up" : "arrow.down")
                    .font(.title3.weight(.bold))
                Text(Currency.string(abs(totalDelta)))
                    .font(.title2.weight(.bold))
                    .monospacedDigit()
            }
            .foregroundStyle(totalDelta >= 0 ? MonetaColor.gain : MonetaColor.loss)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .monetaCard()
        .accessibilityElement(children: .combine)
    }

    // MARK: - Money in/out

    private var moneyInOutSection: some View {
        Section {
            if cashFlow.income != 0 {
                flowRow(
                    icon: "arrow.down.circle.fill", tint: MonetaColor.gain,
                    label: String.localized("Income"), amount: cashFlow.income, signed: "+"
                )
            }
            if cashFlow.expenses != 0 {
                flowRow(
                    icon: "arrow.up.circle.fill", tint: MonetaColor.textPrimary,
                    label: String.localized("Expenses"), amount: cashFlow.expenses, signed: "−"
                )
            }
        } header: {
            Text("Money in/out")
        } footer: {
            Text("Your everyday income and spending in this period.")
        }
    }

    private func flowRow(icon: String, tint: Color, label: String, amount: Decimal, signed: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(tint)
                .frame(width: 20)
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MonetaColor.textPrimary)
            Spacer()
            Text("\(signed)\(Currency.string(abs(amount)))")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(MonetaColor.textPrimary)
        }
        .listRowBackground(MonetaColor.card)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Balance changes

    private var balanceChangesSection: some View {
        Section {
            ForEach(balanceChanges) { event in
                HStack(spacing: 12) {
                    Image(systemName: event.systemImage)
                        .font(.subheadline)
                        .foregroundStyle(event.delta >= 0 ? MonetaColor.gain : MonetaColor.loss)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(event.reasonLabel)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(MonetaColor.textPrimary)
                        Text(event.label)
                            .font(.footnote)
                            .foregroundStyle(MonetaColor.textSecondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(Currency.string(event.delta))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(event.delta >= 0 ? MonetaColor.gain : MonetaColor.loss)
                        Text(event.date.formatted(.relative(presentation: .named)))
                            .font(.caption2)
                            .foregroundStyle(MonetaColor.textTertiary)
                    }
                }
                .listRowBackground(MonetaColor.card)
                .accessibilityElement(children: .combine)
            }
        } header: {
            Text("Balance changes")
        } footer: {
            Text("One-time changes to what you own or owe — not everyday spending.")
        }
    }

    // MARK: - Earlier activity

    private var earlierActivitySection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.subheadline)
                    .foregroundStyle(MonetaColor.textSecondary)
                    .frame(width: 20)
                Text("Earlier activity")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MonetaColor.textPrimary)
                Spacer()
                Text(Currency.string(earlierActivity))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(MonetaColor.textPrimary)
            }
            .listRowBackground(MonetaColor.card)
            .accessibilityElement(children: .combine)
        } footer: {
            Text("From before detailed tracking started for this period.")
        }
    }

    // MARK: - Empty state

    private var emptyStateSection: some View {
        Section {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle")
                    .font(.title2)
                    .foregroundStyle(MonetaColor.textTertiary)
                Text("Nothing to show")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MonetaColor.textPrimary)
                Text("No activity in this period yet.")
                    .font(.footnote)
                    .foregroundStyle(MonetaColor.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }
}

private extension BalanceChangeEvent {
    var systemImage: String {
        switch kind {
        case .assetAdded, .assetChanged, .assetRemoved: return "banknote"
        case .liabilityAdded, .liabilityChanged, .liabilityRemoved: return "creditcard"
        }
    }

    /// Plain-language description of what happened, derived from the kind
    /// of edit plus the sign of its net-worth impact — never accounting
    /// jargon like "asset revaluation."
    var reasonLabel: String {
        switch kind {
        case .assetAdded: return String.localized("Asset added")
        case .assetChanged: return String.localized("Asset value changed")
        case .assetRemoved: return String.localized("Asset removed")
        case .liabilityAdded: return String.localized("New liability")
        case .liabilityChanged: return delta >= 0 ? String.localized("Debt repayment") : String.localized("Debt increased")
        case .liabilityRemoved: return String.localized("Debt cleared")
        }
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        WhyDidThisChangeSheet(
            periodLabel: "This month",
            totalDelta: -1875,
            cashFlow: (income: 2450, expenses: 1325),
            balanceChanges: [
                BalanceChangeEvent(label: "Car loan", kind: .liabilityAdded, delta: -3000)
            ]
        )
    }
}
