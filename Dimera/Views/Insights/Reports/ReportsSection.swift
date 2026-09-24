import SwiftUI

/// "Turn your numbers into something you can share" — not "Export PDF."
/// A plain list of the four report kinds; free ones open straight into
/// `ReportPreviewSheet`, Premium ones open `PaywallView` until unlocked.
/// No settings, no configuration screen — tap a kind, see the document.
struct ReportsSection: View {
    @EnvironmentObject private var store: FinanceStore
    @AppStorage("isPremium") private var isPremium = false

    @State private var activeReport: ReportKind?
    @State private var showPaywall = false

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(ReportKind.allCases.enumerated()), id: \.element.id) { index, kind in
                if index > 0 {
                    Divider().overlay(MonetaColor.separator).padding(.leading, 50)
                }
                reportRow(kind)
            }
        }
        .monetaCard()
        .sheet(item: $activeReport) { kind in
            ReportPreviewSheet(title: kind.title, pages: pages(for: kind))
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    private func reportRow(_ kind: ReportKind) -> some View {
        Button {
            Haptics.selection()
            if kind.isPremium && !isPremium {
                showPaywall = true
            } else {
                activeReport = kind
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(MonetaColor.accent.opacity(0.15)).frame(width: 36, height: 36)
                    Image(systemName: kind.systemImage)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(MonetaColor.accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(kind.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(MonetaColor.textPrimary)
                        if kind.isPremium && !isPremium {
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                                .foregroundStyle(MonetaColor.textTertiary)
                        }
                    }
                    Text(kind.subtitle)
                        .font(.footnote)
                        .foregroundStyle(MonetaColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 6)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MonetaColor.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private func pages(for kind: ReportKind) -> [AnyView] {
        switch kind {
        case .monthlySummary:
            return [AnyView(MonthlySummaryPage(
                month: Date(),
                income: store.monthIncome(),
                expenses: store.monthExpenses(),
                healthScore: store.financialHealth.score,
                keyInsight: store.spendingHeadline,
                categories: store.categoryBreakdown()
            ))]
        case .spendingAnalysis:
            return [AnyView(SpendingAnalysisPage(
                month: Date(),
                categories: store.categoryBreakdown(),
                percentIncrease: store.spendingInsight.percentIncrease
            ))]
        case .commitmentReport:
            return [AnyView(CommitmentReportPage(
                subscriptions: store.subscriptions,
                subscriptionsMonthlyTotal: store.subscriptionsMonthlyTotal,
                contracts: store.contracts
            ))]
        case .goalProgress:
            return [AnyView(GoalProgressPage(entries: store.goals.map { goal in
                GoalProgressEntry(
                    goal: goal,
                    current: store.currentAmount(for: goal),
                    progress: store.progress(for: goal),
                    monthsRemaining: store.monthsRemaining(for: goal)
                )
            }))]
        }
    }
}
