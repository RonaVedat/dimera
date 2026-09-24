import SwiftUI

/// The "Consolidated Statement" — a clean, human-readable summary of a
/// chosen tax period, for the user's own records or to hand to an
/// advisor who just wants an overview. Deliberately does **not** compute
/// a tax bill or a capital-gains figure: this app has no cost-basis
/// tracking on assets, so that number doesn't exist honestly — it
/// categorizes real income, expenses, and recurring commitments only.
struct AnnualConsolidatedReportPage: View {
    let range: FiscalYear.Range
    let income: Decimal
    let expenses: Decimal
    let categories: [CategoryBreakdownRow]
    let legalNote: String

    private var savings: Decimal { income - expenses }

    private var periodLabel: String {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.current.locale
        formatter.dateStyle = .medium
        return "\(formatter.string(from: range.start)) – \(formatter.string(from: range.end))"
    }

    var body: some View {
        ReportPageChrome(reportTitle: String.localized("Annual Consolidated Report"), period: periodLabel, legalNote: legalNote) {
            VStack(alignment: .leading, spacing: 28) {
                HStack(spacing: 16) {
                    ReportStatTile(title: String.localized("Total Income"), value: Currency.string(income))
                    ReportStatTile(title: String.localized("Total Expenses"), value: Currency.string(expenses))
                    ReportStatTile(title: String.localized("Savings"), value: Currency.string(savings), tint: ReportColor.accent)
                }

                if !categories.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(String.localized("Where it went"))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(ReportColor.textSecondary)
                        CategoryDonutChart(categories: categories)
                            .frame(height: 200)
                    }

                    VStack(spacing: 0) {
                        ForEach(categories) { row in
                            HStack {
                                Text(TransactionCategory(rawValue: row.category)?.title ?? row.category)
                                    .font(.subheadline)
                                    .foregroundStyle(ReportColor.textPrimary)
                                Spacer()
                                Text(Currency.string(row.total))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(ReportColor.textPrimary)
                            }
                            .padding(.vertical, 8)
                            Divider().overlay(ReportColor.separator)
                        }
                    }
                } else {
                    Text(String.localized("No transactions in this period."))
                        .font(.subheadline)
                        .foregroundStyle(ReportColor.textSecondary)
                }
            }
        }
    }
}
