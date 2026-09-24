import SwiftUI

/// Reused from the Insights spending-insight card's "Set a [category]
/// limit" CTA (pre-filled with current spend minus €50, matching the
/// recommendation's own math) as well as `BudgetsSection`'s own "Add
/// Budget" entry point. `excludedCategories`/`initialCategory` are computed
/// by the caller, which already has `store` in scope — a budget is
/// one-per-category, so a category already budgeted can't be picked again.
struct AddBudgetSheet: View {
    @EnvironmentObject private var store: FinanceStore
    @Environment(\.dismiss) private var dismiss
    @FocusState private var amountFocused: Bool

    let excludedCategories: Set<TransactionCategory>
    @State private var category: TransactionCategory
    @State private var limitText: String
    @State private var alertsEnabled = true

    init(excludedCategories: Set<TransactionCategory>, initialCategory: TransactionCategory, prefillLimit: Decimal = 0) {
        self.excludedCategories = excludedCategories
        _category = State(initialValue: initialCategory)
        _limitText = State(initialValue: prefillLimit > 0 ? NSDecimalNumber(decimal: prefillLimit).stringValue : "")
    }

    private var limit: Decimal? { parseAmount(limitText) }
    private var canSave: Bool { (limit ?? 0) > 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    AmountEntryField(text: $limitText, focused: $amountFocused)

                    CategoryChips(selection: $category, excluding: excludedCategories)

                    Toggle("Notify me when I go over", isOn: $alertsEnabled)
                        .tint(MonetaColor.accent)
                        .padding(.horizontal, 4)

                    EntrySaveButton(title: String.localized("Add Budget"), isEnabled: canSave, action: save)
                }
                .padding(.horizontal, MonetaMetrics.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollBounceBehavior(.basedOnSize)
            .onAppear { amountFocused = true }
            .background(MonetaColor.canvas)
            .navigationTitle("Add Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private func save() {
        guard let limit else { return }
        store.addBudget(category: category.rawValue, monthlyLimit: limit, alertsEnabled: alertsEnabled)
        if alertsEnabled {
            Task { _ = await NotificationScheduler.shared.requestAuthorizationIfNeeded() }
        }
        Haptics.success()
        dismiss()
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        AddBudgetSheet(excludedCategories: [], initialCategory: .food, prefillLimit: 150)
            .environmentObject(FinanceStore())
    }
}
