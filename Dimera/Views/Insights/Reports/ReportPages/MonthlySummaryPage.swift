import SwiftUI
import Charts

/// Page 1 of the free Monthly Summary report — the headline numbers plus a
/// category donut, all reusing data `FinanceStore` already computes for the
/// Home/Insights tabs. Nothing here is a new calculation.
struct MonthlySummaryPage: View {
    let month: Date
    let income: Decimal
    let expenses: Decimal
    let healthScore: Int
    let keyInsight: String?
    let categories: [CategoryBreakdownRow]

    private var savings: Decimal { income - expenses }

    private static func periodLabel(for month: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.current.locale
        formatter.setLocalizedDateFormatFromTemplate("MMMMy")
        return formatter.string(from: month)
    }

    var body: some View {
        ReportPageChrome(reportTitle: String.localized("Financial Summary"), period: Self.periodLabel(for: month)) {
            VStack(alignment: .leading, spacing: 28) {
                HStack(spacing: 16) {
                    ReportStatTile(title: String.localized("Total Income"), value: Currency.string(income))
                    ReportStatTile(title: String.localized("Total Expenses"), value: Currency.string(expenses))
                    ReportStatTile(title: String.localized("Savings"), value: Currency.string(savings), tint: ReportColor.accent)
                }

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String.localized("Spending Score"))
                            .font(.footnote)
                            .foregroundStyle(ReportColor.textSecondary)
                        Text("\(healthScore)/100")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(ReportColor.textPrimary)
                    }
                    Spacer()
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(ReportColor.separator))

                if let keyInsight {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String.localized("Key Insight"))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(ReportColor.accent)
                        Text(keyInsight)
                            .font(.subheadline)
                            .foregroundStyle(ReportColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if !categories.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(String.localized("Where it went"))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(ReportColor.textSecondary)
                        CategoryDonutChart(categories: categories)
                            .frame(height: 220)
                    }
                }
            }
        }
    }
}

/// A plain stat block — deliberately not `StatTile` (that component's
/// colors are `MonetaColor`-adaptive; report pages force a fixed light
/// appearance, see `ReportPageChrome`).
struct ReportStatTile: View {
    let title: String
    let value: String
    var tint: Color = ReportColor.textPrimary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(ReportColor.textSecondary)
            Text(value)
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A large, clean donut — few colors, generous whitespace, matching the
/// "Apple style" brief. Shared by Monthly Summary and Spending Analysis.
struct CategoryDonutChart: View {
    let categories: [CategoryBreakdownRow]

    private var top: [CategoryBreakdownRow] {
        Array(categories.sorted { $0.total > $1.total }.prefix(ReportColor.chartPalette.count))
    }

    var body: some View {
        Chart(Array(top.enumerated()), id: \.element.id) { index, row in
            SectorMark(angle: .value("Total", NSDecimalNumber(decimal: row.total).doubleValue), innerRadius: .ratio(0.62), angularInset: 1.5)
                .foregroundStyle(ReportColor.chartPalette[index % ReportColor.chartPalette.count])
                .cornerRadius(3)
        }
        .chartLegend(position: .bottom, alignment: .center, spacing: 12) {
            HStack(spacing: 16) {
                ForEach(Array(top.enumerated()), id: \.element.id) { index, row in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(ReportColor.chartPalette[index % ReportColor.chartPalette.count])
                            .frame(width: 8, height: 8)
                        Text(TransactionCategory(rawValue: row.category)?.title ?? row.category)
                            .font(.caption)
                            .foregroundStyle(ReportColor.textSecondary)
                    }
                }
            }
        }
    }
}
