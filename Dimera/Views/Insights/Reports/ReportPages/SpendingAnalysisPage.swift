import SwiftUI

/// Premium — the same category-breakdown data behind Insights' "Unlock
/// Full Breakdown" gate, just rendered as a document instead of a scoped
/// card.
struct SpendingAnalysisPage: View {
    let month: Date
    let categories: [CategoryBreakdownRow]
    let percentIncrease: Int

    private static func periodLabel(for month: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.current.locale
        formatter.setLocalizedDateFormatFromTemplate("MMMMy")
        return formatter.string(from: month)
    }

    private var sorted: [CategoryBreakdownRow] { categories.sorted { $0.total > $1.total } }

    var body: some View {
        ReportPageChrome(reportTitle: String.localized("Spending Analysis"), period: Self.periodLabel(for: month)) {
            VStack(alignment: .leading, spacing: 24) {
                if !categories.isEmpty {
                    CategoryDonutChart(categories: categories)
                        .frame(height: 200)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(String.localized("Top Categories"))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(ReportColor.textSecondary)

                    if sorted.isEmpty {
                        Text(String.localized("Not enough activity yet to compare this month."))
                            .font(.subheadline)
                            .foregroundStyle(ReportColor.textSecondary)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(sorted) { row in
                                HStack {
                                    Text(TransactionCategory(rawValue: row.category)?.title ?? row.category)
                                        .font(.subheadline)
                                        .foregroundStyle(ReportColor.textPrimary)
                                    Spacer()
                                    if let delta = row.deltaVsAverage {
                                        Text(delta >= 0 ? "+\(Currency.string(delta))" : "-\(Currency.string(abs(delta)))")
                                            .font(.footnote.weight(.semibold))
                                            .foregroundStyle(delta >= 0 ? ReportColor.loss : ReportColor.gain)
                                    }
                                    Text(Currency.string(row.total))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(ReportColor.textPrimary)
                                        .frame(width: 90, alignment: .trailing)
                                }
                                .padding(.vertical, 8)
                                Divider().overlay(ReportColor.separator)
                            }
                        }
                    }
                }

                if percentIncrease != 0 {
                    Text(String.localized("Spending is up \(percentIncrease)% this month"))
                        .font(.subheadline)
                        .foregroundStyle(ReportColor.textSecondary)
                }
            }
        }
    }
}
