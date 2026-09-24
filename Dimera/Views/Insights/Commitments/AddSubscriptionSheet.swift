import SwiftUI

/// Adding a subscription directly — reuses the exact form components
/// `AddEntrySheet` already established (`AmountEntryField`, `EntryFieldRow`,
/// `EntrySaveButton`) so this reads as the same app, not a bolted-on flow.
struct AddSubscriptionSheet: View {
    @EnvironmentObject private var store: FinanceStore
    @Environment(\.dismiss) private var dismiss
    @FocusState private var amountFocused: Bool

    @State private var name = ""
    @State private var providerName = ""
    @State private var amountText = ""
    @State private var frequency: RecurringFrequency = .monthly

    private var amount: Decimal? { parseAmount(amountText) }
    private var canSave: Bool { amount != nil && !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    AmountEntryField(text: $amountText, focused: $amountFocused)

                    VStack(spacing: 10) {
                        EntryFieldRow(icon: "arrow.triangle.2.circlepath") {
                            TextField("Name — Netflix Premium…", text: $name)
                                .foregroundStyle(MonetaColor.textPrimary)
                        }
                        EntryFieldRow(icon: "building.2") {
                            TextField("Provider — Netflix (optional)", text: $providerName)
                                .foregroundStyle(MonetaColor.textPrimary)
                        }
                    }

                    frequencyPicker

                    EntrySaveButton(title: String.localized("Save subscription"), isEnabled: canSave, action: save)
                }
                .padding(.horizontal, MonetaMetrics.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(MonetaColor.canvas)
            .navigationTitle("Add Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { amountFocused = true }
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

    private func save() {
        guard let amount else { return }
        store.addSubscription(
            name: name.trimmingCharacters(in: .whitespaces),
            amount: amount,
            frequency: frequency,
            providerName: providerName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : providerName.trimmingCharacters(in: .whitespaces)
        )
        Haptics.success()
        dismiss()
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        AddSubscriptionSheet().environmentObject(FinanceStore())
    }
}
