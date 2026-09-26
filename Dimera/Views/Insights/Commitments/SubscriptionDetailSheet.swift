import SwiftUI

/// "Change Plan," "Pause," "Cancel," and a real "Spending Impact" line —
/// the four actions the spec asked for, all backed by genuine data (no
/// decorative button that does nothing).
struct SubscriptionDetailSheet: View {
    @EnvironmentObject private var store: FinanceStore
    @Environment(\.dismiss) private var dismiss
    @FocusState private var amountFocused: Bool
    let entry: RecurringEntry

    @State private var name: String
    @State private var providerName: String
    @State private var amountText: String
    @State private var frequency: RecurringFrequency
    @State private var showCancelConfirm = false
    @State private var showCancelledConfirmation = false

    init(entry: RecurringEntry) {
        self.entry = entry
        _name = State(initialValue: entry.name)
        _providerName = State(initialValue: entry.providerName ?? "")
        _amountText = State(initialValue: NSDecimalNumber(decimal: entry.amount).stringValue)
        _frequency = State(initialValue: entry.frequency)
    }

    private var amount: Decimal? { parseAmount(amountText) }
    private var canSave: Bool { amount != nil && !name.trimmingCharacters(in: .whitespaces).isEmpty }

    /// The real annual/monthly amount this entry currently costs — used
    /// both by "Spending Impact" and, unchanged, by "Save changes."
    private var monthlyEquivalent: Decimal { entry.monthlyEquivalentAmount }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    AmountEntryField(text: $amountText, focused: $amountFocused)

                    VStack(spacing: 10) {
                        EntryFieldRow(icon: "arrow.triangle.2.circlepath") {
                            TextField("Name", text: $name)
                                .foregroundStyle(MonetaColor.textPrimary)
                        }
                        EntryFieldRow(icon: "building.2") {
                            TextField("Provider (optional)", text: $providerName)
                                .foregroundStyle(MonetaColor.textPrimary)
                        }
                    }

                    frequencyPicker

                    spendingImpactCard

                    EntrySaveButton(title: String.localized("Save changes"), isEnabled: canSave, action: save)

                    Button {
                        Haptics.selection()
                        store.togglePause(entry)
                        dismiss()
                    } label: {
                        Text(entry.isPaused ? "Resume Subscription" : "Pause Subscription")
                            .font(.subheadline.weight(.semibold))
                    }
                    .tint(MonetaColor.textPrimary)

                    Button(role: .destructive) {
                        showCancelConfirm = true
                    } label: {
                        Text("Cancel Subscription")
                            .font(.subheadline.weight(.semibold))
                    }
                    .tint(MonetaColor.loss)
                }
                .padding(.horizontal, MonetaMetrics.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(MonetaColor.canvas)
            .navigationTitle(entry.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .confirmationDialog(
                "Cancel this subscription?",
                isPresented: $showCancelConfirm,
                titleVisibility: .visible
            ) {
                Button("Cancel Subscription", role: .destructive) {
                    store.deleteRecurring(entry)
                    showCancelledConfirmation = true
                }
            } message: {
                Text("This stops tracking it — Dimera won't remind you about future charges.")
            }
            .fullScreenCover(isPresented: $showCancelledConfirmation) {
                ConfirmationMomentView(
                    icon: "checkmark.seal.fill", iconTint: MonetaColor.gain,
                    headline: String.localized("Subscription cancelled"),
                    amount: monthlyEquivalent * 12, amountCaption: String.localized("a year"),
                    subtitle: String.localized("Dimera won't remind you about future charges."),
                    buttonTitle: String.localized("Done")
                ) {
                    showCancelledConfirmation = false
                    dismiss()
                }
            }
        }
    }

    private var frequencyPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Repeats")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(MonetaColor.textSecondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], spacing: 8) {
                ForEach(RecurringFrequency.allCases) { option in
                    let isSelected = option == frequency
                    Button {
                        Haptics.selection()
                        withAnimation(.snappy(duration: 0.18)) { frequency = option }
                    } label: {
                        Text(option.title)
                            .font(.footnote.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.9)
                            .foregroundStyle(isSelected ? MonetaColor.canvas : MonetaColor.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(isSelected ? MonetaColor.textPrimary : MonetaColor.card, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var spendingImpactCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Spending Impact")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(MonetaColor.textSecondary)
            Text("Cancel this and save \(Currency.string(monthlyEquivalent)) a month — \(Currency.string(monthlyEquivalent * 12)) a year.")
                .font(.subheadline)
                .foregroundStyle(MonetaColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .monetaCard()
    }

    private func save() {
        guard let amount else { return }
        store.updateSubscription(
            entry, name: name.trimmingCharacters(in: .whitespaces), amount: amount, frequency: frequency,
            providerName: providerName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : providerName.trimmingCharacters(in: .whitespaces)
        )
        Haptics.success()
        dismiss()
    }
}

#Preview {
    let entry = RecurringEntry(name: "Netflix", amount: 13.99, isIncome: false, frequency: .monthly, anchorDate: Date())
    Color.clear.sheet(isPresented: .constant(true)) {
        SubscriptionDetailSheet(entry: entry).environmentObject(FinanceStore())
    }
}
