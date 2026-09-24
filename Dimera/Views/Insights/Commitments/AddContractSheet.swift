import SwiftUI

/// Adding a contract directly — always entered up front, since a contract
/// isn't discovered from a logged transaction the way "looks recurring"
/// catches a subscription. The three date fields are the whole point of
/// treating contracts differently: a subscription form has none of them.
struct AddContractSheet: View {
    @EnvironmentObject private var store: FinanceStore
    @Environment(\.dismiss) private var dismiss
    @FocusState private var amountFocused: Bool

    @State private var name = ""
    @State private var providerName = ""
    @State private var amountText = ""
    @State private var frequency: RecurringFrequency = .monthly
    @State private var hasEndDate = false
    @State private var contractEndDate = Date()
    @State private var hasCancellationDeadline = false
    @State private var cancellationDeadline = Date()
    @State private var hasReminder = false
    @State private var reminderDate = Date()
    @State private var providerNotes = ""

    private var amount: Decimal? { parseAmount(amountText) }
    private var canSave: Bool { amount != nil && !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    AmountEntryField(text: $amountText, focused: $amountFocused)

                    VStack(spacing: 10) {
                        EntryFieldRow(icon: "doc.text") {
                            TextField("Name — Vodafone Internet…", text: $name)
                                .foregroundStyle(MonetaColor.textPrimary)
                        }
                        EntryFieldRow(icon: "building.2") {
                            TextField("Provider — Vodafone (optional)", text: $providerName)
                                .foregroundStyle(MonetaColor.textPrimary)
                        }
                    }

                    frequencyPicker

                    VStack(spacing: 10) {
                        optionalDateRow(title: String.localized("Contract Ends"), isOn: $hasEndDate, date: $contractEndDate)
                        optionalDateRow(title: String.localized("Cancellation Deadline"), isOn: $hasCancellationDeadline, date: $cancellationDeadline)
                        optionalDateRow(title: String.localized("Set Reminder"), isOn: $hasReminder, date: $reminderDate)
                    }

                    EntryFieldRow(icon: "note.text") {
                        TextField("Provider details — account number, terms…", text: $providerNotes, axis: .vertical)
                            .foregroundStyle(MonetaColor.textPrimary)
                            .lineLimit(3...6)
                    }

                    EntrySaveButton(title: String.localized("Save contract"), isEnabled: canSave, action: save)
                }
                .padding(.horizontal, MonetaMetrics.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(MonetaColor.canvas)
            .navigationTitle("Add Contract")
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

    private func optionalDateRow(title: String, isOn: Binding<Bool>, date: Binding<Date>) -> some View {
        VStack(spacing: 0) {
            Toggle(title, isOn: isOn.animation(.snappy(duration: 0.18)))
                .tint(MonetaColor.accent)
            if isOn.wrappedValue {
                DatePicker(title, selection: date, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.graphical)
                    .padding(.top, 8)
            }
        }
        .padding(14)
        .monetaCard(radius: MonetaMetrics.tileRadius)
    }

    private func save() {
        guard let amount else { return }
        store.addContract(
            name: name.trimmingCharacters(in: .whitespaces), amount: amount, frequency: frequency, anchorDate: Date(),
            providerName: providerName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : providerName.trimmingCharacters(in: .whitespaces),
            contractEndDate: hasEndDate ? contractEndDate : nil,
            cancellationDeadline: hasCancellationDeadline ? cancellationDeadline : nil,
            reminderDate: hasReminder ? reminderDate : nil,
            providerNotes: providerNotes.trimmingCharacters(in: .whitespaces).isEmpty ? nil : providerNotes
        )
        Haptics.success()
        dismiss()
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        AddContractSheet().environmentObject(FinanceStore())
    }
}
