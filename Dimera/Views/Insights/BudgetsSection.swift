import SwiftUI

/// One row per budget, modeled directly on `GoalCard`'s "spent / limit +
/// progress bar" idiom (`Views/Goals/GoalsView.swift`) applied to a category
/// limit instead of a savings goal. Lives right below the spending-insight
/// card in Insights — the most actionable, most-checked surface gets the
/// prime slot, and the insight card's own "Set a [category] limit" CTA
/// feeds straight into it.
struct BudgetsSection: View {
    @EnvironmentObject private var store: FinanceStore
    @State private var showAddSheet = false
    @State private var editingBudget: Budget?

    private var budgetedCategories: Set<TransactionCategory> {
        Set(store.budgets.compactMap { TransactionCategory(rawValue: $0.category) })
    }

    private var hasRoomForMore: Bool {
        budgetedCategories.count < TransactionCategory.allCases.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if store.budgets.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    ForEach(store.budgets) { budget in
                        BudgetRow(budget: budget)
                            .contentShape(Rectangle())
                            .onTapGesture { editingBudget = budget }
                        if budget.id != store.budgets.last?.id {
                            Divider().overlay(MonetaColor.separator).padding(.leading, 16)
                        }
                    }
                }
                .monetaCard()

                if hasRoomForMore {
                    Button {
                        Haptics.selection()
                        showAddSheet = true
                    } label: {
                        Label(String.localized("Add Budget"), systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(MonetaColor.accent)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddBudgetSheet(
                excludedCategories: budgetedCategories,
                initialCategory: TransactionCategory.allCases.first { !budgetedCategories.contains($0) } ?? .food
            )
        }
        .sheet(item: $editingBudget) { budget in
            EditBudgetSheet(budget: budget)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(MonetaColor.accent.opacity(0.15)).frame(width: 48, height: 48)
                Image(systemName: "chart.pie")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(MonetaColor.accent)
            }
            VStack(spacing: 4) {
                Text("No budgets yet")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MonetaColor.textPrimary)
                Text("Set a monthly limit for a category and track it automatically.")
                    .font(.footnote)
                    .foregroundStyle(MonetaColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button {
                Haptics.selection()
                showAddSheet = true
            } label: {
                Text("Add Budget")
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
}

private struct BudgetRow: View {
    @EnvironmentObject private var store: FinanceStore
    let budget: Budget

    private var category: TransactionCategory? { TransactionCategory(rawValue: budget.category) }
    private var spend: Decimal { store.budgetSpend(for: budget) }
    private var progress: Double { store.budgetProgress(for: budget) }
    private var status: BudgetStatus { store.budgetStatus(for: budget) }

    private var tint: Color {
        switch status {
        case .onTrack: return MonetaColor.gain
        case .nearLimit: return MonetaColor.warning
        case .overBudget: return MonetaColor.loss
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(MonetaColor.accent.opacity(0.15)).frame(width: 32, height: 32)
                    Image(systemName: category?.systemImage ?? "circle.grid.2x2")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(MonetaColor.accent)
                }
                Text(category?.title ?? budget.category)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MonetaColor.textPrimary)
                Spacer()
                Text("\(Currency.string(spend)) / \(Currency.string(budget.monthlyLimit))")
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(MonetaColor.textSecondary)
            }
            ProgressView(value: min(progress, 1.0))
                .tint(tint)
            HStack {
                Spacer()
                Text(progress, format: .percent.precision(.fractionLength(0)))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(tint)
            }
        }
        .padding(16)
        .accessibilityElement(children: .combine)
    }
}
