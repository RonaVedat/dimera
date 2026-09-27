import SwiftUI

/// The Apple Card-style monthly statement: one month at a time, paged with
/// chevrons rather than a scrolling transaction log — "what happened in
/// July" as a single readable answer, not an archive to dig through. The
/// commentary line is genuinely computed from this month vs. your other
/// months (see `FinanceStore.monthlyInsight`) — free, same as the Insights
/// tab's own real, computed commentary.
struct MonthlyHistoryView: View {
    @EnvironmentObject private var store: FinanceStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMonth = Date()

    private var months: [Date] { store.monthsWithActivity }

    private var currentIndex: Int {
        let cal = Calendar.current
        return months.firstIndex { cal.isDate($0, equalTo: selectedMonth, toGranularity: .month) } ?? 0
    }

    private var canGoNewer: Bool { currentIndex > 0 }
    private var canGoOlder: Bool { currentIndex < months.count - 1 }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.current.locale
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter.string(from: selectedMonth)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    monthNavigator
                        .padding(.top, 8)

                    summaryCard

                    if !store.topSpending(for: selectedMonth).isEmpty {
                        topSpendingCard
                    }

                    insightCard

                    if months.count <= 1 {
                        Text("Your history builds up as you log more months.")
                            .font(.footnote)
                            .foregroundStyle(MonetaColor.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal, MonetaMetrics.screenPadding)
                .padding(.bottom, 24)
            }
            .background(MonetaColor.canvas)
            .navigationTitle("Monthly History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var monthNavigator: some View {
        HStack {
            navButton(systemImage: "chevron.left", enabled: canGoOlder) {
                move(by: 1)
            }
            Spacer()
            Text(monthTitle)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(MonetaColor.textPrimary)
                .contentTransition(.opacity)
                .animation(.snappy(duration: 0.2), value: selectedMonth)
            Spacer()
            navButton(systemImage: "chevron.right", enabled: canGoNewer) {
                move(by: -1)
            }
        }
    }

    private func navButton(systemImage: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(enabled ? MonetaColor.textPrimary : MonetaColor.textTertiary)
                .frame(width: 34, height: 34)
                .background(MonetaColor.card, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(systemImage == "chevron.left" ? "Previous month" : "Next month")
    }

    private func move(by offset: Int) {
        let newIndex = currentIndex + offset
        guard months.indices.contains(newIndex) else { return }
        Haptics.selection()
        selectedMonth = months[newIndex]
    }

    private var summaryCard: some View {
        let saved = store.monthSaved(for: selectedMonth)
        return HStack(spacing: 10) {
            summaryStat(title: String.localized("Income"), amount: store.monthIncome(for: selectedMonth), tint: MonetaColor.gain)
            summaryStat(title: String.localized("Spent"), amount: store.monthExpenses(for: selectedMonth), tint: MonetaColor.textPrimary)
            summaryStat(title: String.localized("Saved"), amount: saved, tint: saved >= 0 ? MonetaColor.accent : MonetaColor.loss)
        }
        .padding(16)
        .monetaCard()
    }

    private func summaryStat(title: String, amount: Decimal, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(MonetaColor.textSecondary)
            Text(Currency.string(amount))
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var topSpendingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Top spending")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(MonetaColor.textSecondary)
            VStack(spacing: 8) {
                ForEach(store.topSpending(for: selectedMonth), id: \.category) { item in
                    HStack {
                        Text(TransactionCategory(rawValue: item.category)?.title ?? item.category)
                            .font(.subheadline)
                            .foregroundStyle(MonetaColor.textPrimary)
                        Spacer()
                        Text(Currency.string(item.total))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(MonetaColor.textPrimary)
                    }
                }
            }
        }
        .padding(16)
        .monetaCard()
    }

    private var insightCard: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(MonetaColor.accent.opacity(0.14))
                .frame(width: 34, height: 34)
                .overlay {
                    Image(systemName: "sparkle")
                        .foregroundStyle(MonetaColor.accent)
                }
            Text(store.monthlyInsight(for: selectedMonth) ?? String.localized("Not enough activity yet to compare this month."))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(MonetaColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(16)
        .monetaCard()
    }
}

#Preview {
    let store = FinanceStore()
    Color.clear.sheet(isPresented: .constant(true)) {
        MonthlyHistoryView()
            .environmentObject(store)
            .task { await store.load() }
    }
}
