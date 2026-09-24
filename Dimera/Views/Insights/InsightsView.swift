import SwiftUI

/// Spending analysis and Tax Radar are free — real, computed value that
/// stands on its own. The deeper category breakdown and renewal-review
/// nudges are smaller, scoped Premium upsells rather than a tab-wide gate.
struct InsightsView: View {
    @EnvironmentObject private var store: FinanceStore
    @AppStorage("isPremium") private var isPremium = false
    @State private var barsAppeared = false
    @State private var showSpendingAlertSheet = false
    @State private var alertCategory: TransactionCategory = .other
    @State private var alertPrefill: Decimal = 0
    @State private var showTaxExport = false
    @State private var showTaxExportPaywall = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    spendingCard
                        .padding(.top, 4)

                    SectionLabel(title: String.localized("Commitments"))
                        .padding(.top, 28)
                        .padding(.bottom, 10)
                    CommitmentsSection()

                    SectionLabel(title: String.localized("Category breakdown"))
                        .padding(.top, 28)
                        .padding(.bottom, 10)
                    categoryBreakdownGate

                    SectionLabel(title: String.localized("Tax radar · \(Calendar.current.component(.year, from: Date()), format: .number.grouping(.never))"))
                        .padding(.top, 28)
                        .padding(.bottom, 10)
                    taxCard

                    SectionLabel(title: String.localized("Reports"))
                        .padding(.top, 28)
                        .padding(.bottom, 10)
                    Text("Turn your numbers into something you can share.")
                        .font(.footnote)
                        .foregroundStyle(MonetaColor.textSecondary)
                        .padding(.bottom, 10)
                    ReportsSection()
                }
                .padding(.horizontal, MonetaMetrics.screenPadding)
                .padding(.bottom, 24)
            }
            .background(MonetaColor.canvas)
            .navigationTitle("Insights")
            .onAppear {
                withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
                    barsAppeared = true
                }
            }
            .sheet(isPresented: $showSpendingAlertSheet) {
                SpendingAlertSheet(category: alertCategory, prefillThreshold: alertPrefill)
            }
            .sheet(isPresented: $showTaxExport) {
                TaxExportChoiceView()
            }
            .sheet(isPresented: $showTaxExportPaywall) {
                PaywallView()
            }
        }
    }

    // MARK: - Spending (free)

    private var spendingCard: some View {
        let insight = store.spendingInsight
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(MonetaColor.accent.opacity(0.14))
                    .frame(width: 34, height: 34)
                    .overlay { Image(systemName: "sparkle").foregroundStyle(MonetaColor.accent) }
                Text(store.spendingHeadline ?? String.localized("Not enough activity yet to compare this month."))
                    .font(.headline)
                    .foregroundStyle(MonetaColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if !insight.categoryDeltas.isEmpty {
                    InfoExplainer(explanation: spendingHeadlineExplanation(insight))
                }
            }

            if !insight.categoryDeltas.isEmpty {
                // The count-phrase is its own localized sub-string (with
                // real plural handling via the Catalog) before going into
                // the outer sentence — a plain ternary embedded directly in
                // the interpolation would never get its own translation.
                let categoryCountPhrase = String.localized("\(insight.categoryDeltas.count) categories explain")
                Text("You've spent **\(Currency.string(insight.spentSoFar))** so far — \(Currency.string(insight.aboveAverage)) more than your average month. \(categoryCountPhrase) most of it:")
                    .font(.subheadline)
                    .foregroundStyle(MonetaColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 12) {
                    ForEach(insight.categoryDeltas) { delta in
                        HStack(spacing: 8) {
                            CategoryDeltaBar(
                                delta: delta,
                                maxIncrease: insight.categoryDeltas.map(\.increase).max() ?? 1,
                                appeared: barsAppeared
                            )
                            InfoExplainer(explanation: store.explanation(for: delta))
                        }
                    }
                }

                Divider().overlay(MonetaColor.separator)

                let recommendationCategoryName = TransactionCategory(rawValue: insight.recommendationCategory)?.title ?? insight.recommendationCategory
                Text("Reduce \(recommendationCategoryName) by **\(Currency.string(insight.recommendationMonthlyCut))/month** and you'd save **\(Currency.string(insight.recommendationAnnualSavings)) a year**.")
                    .font(.subheadline)
                    .foregroundStyle(MonetaColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    Haptics.selection()
                    alertCategory = TransactionCategory(rawValue: insight.recommendationCategory) ?? .other
                    alertPrefill = max(0, store.categorySpend(for: insight.recommendationCategory) - 50)
                    showSpendingAlertSheet = true
                } label: {
                    Text("Set a \(recommendationCategoryName) limit")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MonetaColor.canvas)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(MonetaColor.textPrimary, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .monetaCard()
    }

    private func spendingHeadlineExplanation(_ insight: SpendingInsight) -> String {
        String.localized("You've spent \(Currency.string(insight.spentSoFar)) this month, \(Currency.string(insight.aboveAverage)) more than your typical month based on your own history.")
    }

    // MARK: - Category breakdown (Premium, scoped)

    private var categoryBreakdownGate: some View {
        PremiumGate(
            title: String.localized("Unlock Full Breakdown"),
            subtitle: String.localized("See every category, not just the top three, with month-over-month change.")
        ) {
            VStack(spacing: 0) {
                ForEach(store.categoryBreakdown()) { row in
                    HStack {
                        Text(TransactionCategory(rawValue: row.category)?.title ?? row.category)
                            .font(.subheadline)
                            .foregroundStyle(MonetaColor.textPrimary)
                        Spacer()
                        if let delta = row.deltaVsAverage {
                            Text(delta >= 0 ? "+\(Currency.string(delta))" : "-\(Currency.string(abs(delta)))")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(delta >= 0 ? MonetaColor.loss : MonetaColor.gain)
                        }
                        Text(Currency.string(row.total))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(MonetaColor.textPrimary)
                    }
                    .padding(.vertical, 6)
                }
            }
            .padding(16)
            .monetaCard()
        }
    }

    // MARK: - Tax radar (free)

    private var taxCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            if store.taxItems.isEmpty {
                Text("Nothing flagged yet — log a work-related purchase and we'll check it against common deduction categories.")
                    .font(.subheadline)
                    .foregroundStyle(MonetaColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(store.taxItems) { item in
                    HStack(spacing: 6) {
                        Text(item.description) + Text(" · \(item.category)").foregroundStyle(MonetaColor.textSecondary)
                        InfoExplainer(explanation: taxExplanation(for: item))
                        Spacer()
                        Text(Currency.string(item.amount)).monospacedDigit()
                    }
                    .font(.subheadline)
                    .foregroundStyle(MonetaColor.textPrimary)
                    .padding(.vertical, 6)
                }
                HStack {
                    Text("Potentially deductible").font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(Currency.string(store.taxDeductibleTotal))
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(MonetaColor.accent)
                }
                .foregroundStyle(MonetaColor.textPrimary)
                .padding(.top, 8)

                Button {
                    Haptics.selection()
                    if isPremium {
                        showTaxExport = true
                    } else {
                        showTaxExportPaywall = true
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text("Export for tax advisor")
                        if !isPremium {
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MonetaColor.textPrimary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(MonetaColor.cardElevated, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .monetaCard()
    }

    private func taxExplanation(for item: TaxItem) -> String {
        // item.category ("Arbeitsmittel"/"Werbungskosten") is an official
        // German tax term, deliberately left untranslated — see TaxRadarScanner.
        String.localized("Flagged because '\(item.description)' matched a common \(item.category) keyword and was over the \(Currency.string(TaxRadarScanner.minimumAmount)) minimum we use to avoid noise.")
    }
}

private struct CategoryDeltaBar: View {
    let delta: CategoryDelta
    let maxIncrease: Decimal
    let appeared: Bool

    private var fraction: Double {
        guard maxIncrease > 0 else { return 0 }
        return NSDecimalNumber(decimal: delta.increase / maxIncrease).doubleValue
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(TransactionCategory(rawValue: delta.category)?.title ?? delta.category)
                .font(.footnote)
                .foregroundStyle(MonetaColor.textSecondary)
                .frame(width: 88, alignment: .leading)

            GeometryReader { geo in
                Capsule()
                    .fill(MonetaColor.cardElevated)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(MonetaColor.accent)
                            .frame(width: appeared ? geo.size.width * fraction : 0)
                    }
            }
            .frame(height: 6)

            Text("+\(Currency.string(delta.increase))")
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(MonetaColor.textPrimary)
                .frame(width: 58, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let store = FinanceStore()
    InsightsView()
        .environmentObject(store)
        .task { await store.load() }
}
