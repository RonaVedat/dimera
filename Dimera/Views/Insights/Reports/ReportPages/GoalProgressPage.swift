import SwiftUI

/// Premium — the same data behind Goals' "Unlock Forecasting" gate.
/// One entry per goal; used both for the all-goals Reports-section report
/// and the single-goal report opened from a `GoalCard`'s context menu.
struct GoalProgressEntry: Identifiable {
    let goal: Goal
    let current: Decimal
    let progress: Double
    let monthsRemaining: Int?

    var id: Goal.ID { goal.id }

    var estimatedCompletionLabel: String? {
        guard let monthsRemaining, let date = Calendar.current.date(byAdding: .month, value: monthsRemaining, to: Date()) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.current.locale
        formatter.setLocalizedDateFormatFromTemplate("MMMMy")
        return formatter.string(from: date)
    }
}

struct GoalProgressPage: View {
    let entries: [GoalProgressEntry]

    private static var todayLabel: String {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.current.locale
        formatter.setLocalizedDateFormatFromTemplate("MMMMy")
        return formatter.string(from: Date())
    }

    var body: some View {
        ReportPageChrome(reportTitle: String.localized("Goal Progress"), period: Self.todayLabel) {
            if entries.isEmpty {
                Text(String.localized("No goals yet"))
                    .font(.subheadline)
                    .foregroundStyle(ReportColor.textSecondary)
            } else {
                VStack(alignment: .leading, spacing: 28) {
                    ForEach(entries) { entry in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(entry.goal.name)
                                .font(.headline)
                                .foregroundStyle(ReportColor.textPrimary)

                            HStack(alignment: .firstTextBaseline) {
                                Text(entry.progress, format: .percent.precision(.fractionLength(0)))
                                    .font(.system(size: 30, weight: .bold, design: .rounded))
                                    .foregroundStyle(ReportColor.accent)
                                Spacer()
                                Text("\(Currency.string(entry.current)) / \(Currency.string(entry.goal.targetAmount))")
                                    .font(.subheadline)
                                    .foregroundStyle(ReportColor.textSecondary)
                                    .monospacedDigit()
                            }

                            GeometryReader { geo in
                                Capsule()
                                    .fill(ReportColor.separator)
                                    .overlay(alignment: .leading) {
                                        Capsule()
                                            .fill(ReportColor.accent)
                                            .frame(width: geo.size.width * min(1, max(0, entry.progress)))
                                    }
                            }
                            .frame(height: 8)

                            if let label = entry.estimatedCompletionLabel {
                                Text(String.localized("Estimated completion: \(label)"))
                                    .font(.footnote)
                                    .foregroundStyle(ReportColor.textSecondary)
                            }
                        }
                        Divider().overlay(ReportColor.separator)
                    }
                }
            }
        }
    }
}
