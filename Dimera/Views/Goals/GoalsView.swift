import SwiftUI

struct GoalsView: View {
    @EnvironmentObject private var store: FinanceStore
    @State private var showAddGoal = false
    @State private var editingGoal: Goal?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    healthCard
                        .listRowBackground(Color.clear)
                        .listRowInsets(rowInsets)
                        .listRowSeparator(.hidden)
                } header: {
                    Text("Financial health")
                }

                Section {
                    if store.goals.isEmpty {
                        goalsEmptyState
                            .listRowBackground(Color.clear)
                            .listRowInsets(rowInsets)
                            .listRowSeparator(.hidden)
                    } else {
                        ForEach(store.goals) { goal in
                            GoalCard(goal: goal)
                                .listRowBackground(Color.clear)
                                .listRowInsets(rowInsets)
                                .listRowSeparator(.hidden)
                                .contentShape(Rectangle())
                                .onTapGesture { editingGoal = goal }
                                .deleteSwipeAction { store.deleteGoal(goal) }
                        }
                    }
                } header: {
                    Text("Your goals")
                }

                Section {
                    PremiumGate(
                        title: String.localized("Unlock Forecasting"),
                        subtitle: String.localized("See where your balance is headed before the month ends.")
                    ) {
                        VStack(alignment: .leading, spacing: 0) {
                            forecastStats

                            ForecastChart(data: store.forecast)
                                .frame(height: 130)
                                .padding(.top, 14)

                            forecastLegend
                                .padding(.top, 10)

                            if let narrative = store.forecastNarrative {
                                Text(narrative)
                                    .font(.footnote)
                                    .foregroundStyle(MonetaColor.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.top, 12)
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(rowInsets)
                    .listRowSeparator(.hidden)
                } header: {
                    Text("30-day forecast")
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(MonetaColor.canvas)
            .navigationTitle("Goals")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.selection()
                        showAddGoal = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .accessibilityLabel("Add goal")
                }
            }
            .sheet(isPresented: $showAddGoal) {
                AddGoalSheet()
            }
            .sheet(item: $editingGoal) { goal in
                EditGoalSheet(goal: goal)
            }
        }
    }

    private var rowInsets: EdgeInsets {
        EdgeInsets(top: 6, leading: MonetaMetrics.screenPadding, bottom: 6, trailing: MonetaMetrics.screenPadding)
    }

    // MARK: - Financial health

    private var healthCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 18) {
                HealthRing(score: store.financialHealth.score)
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.financialHealth.grade)
                        .font(.headline)
                        .foregroundStyle(healthGradeColor)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(store.financialHealth.strengths, id: \.self) { strength in
                    HStack(alignment: .top, spacing: 10) {
                        ZStack {
                            Circle().fill(MonetaColor.gain.opacity(0.15)).frame(width: 22, height: 22)
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(MonetaColor.gain)
                        }
                        Text(strength)
                            .font(.footnote)
                            .foregroundStyle(MonetaColor.textSecondary)
                    }
                }
            }
        }
        .padding(16)
        .monetaCard()
        .accessibilityElement(children: .combine)
    }

    private var healthGradeColor: Color {
        switch store.financialHealth.tier {
        case .strong: return MonetaColor.gain
        case .attention: return MonetaColor.warning
        case .building: return MonetaColor.textSecondary
        }
    }

    // MARK: - Goals empty state

    private var goalsEmptyState: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(MonetaColor.accent.opacity(0.15)).frame(width: 48, height: 48)
                Image(systemName: "target")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(MonetaColor.accent)
            }
            VStack(spacing: 4) {
                Text("No goals yet")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MonetaColor.textPrimary)
                Text("Set a target and we'll track your progress automatically.")
                    .font(.footnote)
                    .foregroundStyle(MonetaColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button {
                Haptics.selection()
                showAddGoal = true
            } label: {
                Text("Add your first goal")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(MonetaColor.canvas)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(MonetaColor.textPrimary, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .monetaCard()
        .accessibilityElement(children: .combine)
    }

    // MARK: - Forecast

    private var forecastStats: some View {
        HStack(spacing: 10) {
            StatTile(title: String.localized("Today"), amount: store.forecast.past.last.map { Decimal($0.value) } ?? 0)
            StatTile(title: store.forecast.projectedDateLabel, amount: store.forecast.projected.last.map { Decimal($0.value) } ?? 0)
            StatTile(title: String.localized("After bills"), amount: Decimal(store.forecast.afterBills), tint: MonetaColor.accent)
        }
    }

    private var forecastLegend: some View {
        HStack(spacing: 16) {
            HStack(spacing: 6) {
                Rectangle().fill(MonetaColor.textPrimary).frame(width: 14, height: 2)
                Text("Last 30 days").font(.caption).foregroundStyle(MonetaColor.textSecondary)
            }
            HStack(spacing: 6) {
                Rectangle().fill(MonetaColor.accent).frame(width: 14, height: 2)
                Text("Projected").font(.caption).foregroundStyle(MonetaColor.textSecondary)
            }
        }
    }
}

private struct GoalCard: View {
    @EnvironmentObject private var store: FinanceStore
    let goal: Goal

    @State private var showReport = false

    private var current: Decimal { store.currentAmount(for: goal) }
    private var progress: Double { store.progress(for: goal) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 5) {
                    Text(goal.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MonetaColor.textPrimary)
                    if goal.trackingMode == .linked {
                        Image(systemName: "link")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(MonetaColor.textTertiary)
                    }
                }
                Spacer()
                Text("\(Currency.string(current)) / \(Currency.string(goal.targetAmount))")
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(MonetaColor.textSecondary)
            }
            ProgressView(value: progress)
                .tint(MonetaColor.accent)
            HStack {
                Text(caption)
                    .font(.footnote)
                    .foregroundStyle(MonetaColor.textSecondary)
                Spacer()
                Text(progress, format: .percent.precision(.fractionLength(0)))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(MonetaColor.accent)
            }
        }
        .padding(16)
        .monetaCard()
        .accessibilityElement(children: .combine)
        .contextMenu {
            Button {
                Haptics.selection()
                showReport = true
            } label: {
                Label("Export Progress Report", systemImage: "doc.text")
            }
        }
        .sheet(isPresented: $showReport) {
            ReportPreviewSheet(
                title: goal.name,
                pages: [AnyView(GoalProgressPage(entries: [
                    GoalProgressEntry(goal: goal, current: current, progress: progress, monthsRemaining: store.monthsRemaining(for: goal))
                ]))]
            )
        }
    }

    private var caption: String {
        if let monthsRemaining = store.monthsRemaining(for: goal) {
            return String.localized("On track · \(monthsRemaining) months to go at \(Currency.string(goal.monthlyContribution))/mo")
        }
        return String.localized("No monthly contribution set")
    }
}

#Preview {
    let store = FinanceStore()
    GoalsView()
        .environmentObject(store)
        .task { await store.load() }
}
