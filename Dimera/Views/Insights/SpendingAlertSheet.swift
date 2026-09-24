import SwiftUI

/// A lightweight, event-driven nudge — deliberately not a budget. No cap
/// enforcement, no rollover, no category limits elsewhere in the app: just
/// "notify me once if I cross this." Reused from the Insights tab's "Set a
/// [category] limit" CTA, pre-filled with the category's current spend
/// minus €50, matching the recommendation's own math.
struct SpendingAlertSheet: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var amountFocused: Bool

    @State private var category: TransactionCategory
    @State private var thresholdText: String

    init(category: TransactionCategory, prefillThreshold: Decimal) {
        _category = State(initialValue: category)
        _thresholdText = State(initialValue: NSDecimalNumber(decimal: prefillThreshold).stringValue)
    }

    private var threshold: Decimal? { parseAmount(thresholdText) }
    private var canSave: Bool { threshold != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    AmountEntryField(text: $thresholdText, focused: $amountFocused)

                    CategoryChips(selection: $category)

                    EntrySaveButton(title: String.localized("Set limit"), isEnabled: canSave, action: save)
                }
                .padding(.horizontal, MonetaMetrics.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollBounceBehavior(.basedOnSize)
            .onAppear { amountFocused = true }
            .background(MonetaColor.canvas)
            .navigationTitle("Set a Limit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private func save() {
        guard let threshold else { return }
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: ReminderSettingsKey.spendingAlertEnabled)
        defaults.set(category.rawValue, forKey: ReminderSettingsKey.spendingAlertCategory)
        defaults.set(NSDecimalNumber(decimal: threshold).doubleValue, forKey: ReminderSettingsKey.spendingAlertThresholdAmount)
        // A freshly-set limit should be able to fire this month even if an
        // earlier limit already fired once.
        defaults.removeObject(forKey: ReminderSettingsKey.spendingAlertLastFiredMonth)

        Task {
            _ = await NotificationScheduler.shared.requestAuthorizationIfNeeded()
        }
        Haptics.success()
        dismiss()
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        SpendingAlertSheet(category: .food, prefillThreshold: 150)
    }
}
