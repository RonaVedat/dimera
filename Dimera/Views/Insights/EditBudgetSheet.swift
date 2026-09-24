import SwiftUI

/// Category isn't editable here — it's the budget's identity (one per
/// category), so changing it is a delete-and-recreate, not an edit. Only
/// the limit and the alert toggle can change.
struct EditBudgetSheet: View {
    @EnvironmentObject private var store: FinanceStore
    @Environment(\.dismiss) private var dismiss
    @FocusState private var amountFocused: Bool
    let budget: Budget

    @State private var limitText: String
    @State private var alertsEnabled: Bool
    @State private var showDeleteConfirm = false

    init(budget: Budget) {
        self.budget = budget
        _limitText = State(initialValue: NSDecimalNumber(decimal: budget.monthlyLimit).stringValue)
        _alertsEnabled = State(initialValue: budget.alertsEnabled)
    }

    private var category: TransactionCategory? { TransactionCategory(rawValue: budget.category) }
    private var categoryTitle: String { category?.title ?? budget.category }
    private var limit: Decimal? { parseAmount(limitText) }
    private var canSave: Bool { (limit ?? 0) > 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    AmountEntryField(text: $limitText, focused: $amountFocused)

                    EntryFieldRow(icon: category?.systemImage ?? "circle.grid.2x2") {
                        Text(categoryTitle).foregroundStyle(MonetaColor.textPrimary)
                    }

                    Toggle("Notify me when I go over", isOn: $alertsEnabled)
                        .tint(MonetaColor.accent)
                        .padding(.horizontal, 4)

                    EntrySaveButton(title: String.localized("Save changes"), isEnabled: canSave, action: save)

                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Text("Delete Budget").font(.subheadline.weight(.semibold))
                    }
                    .tint(MonetaColor.loss)
                    .padding(.top, 4)
                }
                .padding(.horizontal, MonetaMetrics.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(MonetaColor.canvas)
            .navigationTitle("Edit Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .confirmationDialog("Delete this budget?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    store.deleteBudget(budget)
                    dismiss()
                }
            } message: {
                Text("This stops tracking \(categoryTitle) — nothing else is affected.")
            }
        }
    }

    private func save() {
        guard let limit else { return }
        store.updateBudget(budget, monthlyLimit: limit, alertsEnabled: alertsEnabled)
        Haptics.success()
        dismiss()
    }
}
