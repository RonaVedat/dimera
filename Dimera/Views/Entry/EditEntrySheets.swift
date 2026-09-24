import SwiftUI

/// The review-and-edit counterpart to `AddEntrySheet` — tapping any row you
/// already logged opens the same minimal form, prefilled, with a delete
/// action instead of a chooser. Matches the HIG expectation set by Reminders,
/// Notes, and Wallet: a logged item is never a dead end, only swipeable away.

// MARK: - Transaction

struct EditTransactionSheet: View {
    @EnvironmentObject private var store: FinanceStore
    @Environment(\.dismiss) private var dismiss
    @FocusState private var amountFocused: Bool
    let transaction: Transaction

    @State private var amountText: String
    @State private var merchant: String
    @State private var category: TransactionCategory
    @State private var date: Date
    @State private var hasReceipt: Bool
    @State private var showDeleteConfirm = false

    init(transaction: Transaction) {
        self.transaction = transaction
        _amountText = State(initialValue: NSDecimalNumber(decimal: transaction.amount).stringValue)
        _merchant = State(initialValue: transaction.merchant)
        _category = State(initialValue: TransactionCategory(rawValue: transaction.category) ?? .other)
        _date = State(initialValue: transaction.date)
        _hasReceipt = State(initialValue: transaction.hasReceipt)
    }

    private var amount: Decimal? { parseAmount(amountText) }
    private var canSave: Bool { amount != nil && !merchant.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    AmountEntryField(text: $amountText, focused: $amountFocused)

                    EntryFieldRow(icon: transaction.isIncome ? "arrow.down.circle" : "storefront") {
                        TextField(transaction.isIncome ? "Source" : "Merchant", text: $merchant)
                            .foregroundStyle(MonetaColor.textPrimary)
                    }

                    if !transaction.isIncome {
                        CategoryChips(selection: $category)
                    }

                    EntryFieldRow(icon: "calendar") {
                        DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date)
                            .labelsHidden()
                            .tint(MonetaColor.accent)
                        Spacer()
                    }

                    if !transaction.isIncome {
                        ReceiptAttachmentSection(transactionID: transaction.id, hasReceipt: $hasReceipt, showsSuggestionBanner: false)
                    }

                    EntrySaveButton(title: String.localized("Save changes"), isEnabled: canSave, action: save)

                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Text(transaction.isIncome ? "Delete income" : "Delete expense")
                            .font(.subheadline.weight(.semibold))
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
            .navigationTitle(transaction.isIncome ? "Edit Income" : "Edit Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .confirmationDialog(
                "Delete this \(transaction.isIncome ? "income" : "expense")?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    store.deleteTransaction(transaction)
                    dismiss()
                }
            } message: {
                if transaction.isIncome {
                    Text("If this was tracked as recurring, that reminder is removed too.")
                }
            }
        }
    }

    private func save() {
        guard let amount else { return }
        store.updateTransaction(
            transaction,
            merchant: merchant.trimmingCharacters(in: .whitespaces),
            category: transaction.isIncome ? "Income" : category.rawValue,
            amount: amount,
            date: date,
            hasReceipt: hasReceipt
        )
        Haptics.success()
        dismiss()
    }
}

// MARK: - Asset

struct EditAssetSheet: View {
    @EnvironmentObject private var store: FinanceStore
    @Environment(\.dismiss) private var dismiss
    @FocusState private var amountFocused: Bool
    let asset: Asset

    @State private var name: String
    @State private var valueText: String
    @State private var kind: AssetKind
    @State private var showDeleteConfirm = false

    init(asset: Asset) {
        self.asset = asset
        _name = State(initialValue: asset.name)
        _valueText = State(initialValue: NSDecimalNumber(decimal: asset.value).stringValue)
        _kind = State(initialValue: asset.kind)
    }

    private var value: Decimal? { parseAmount(valueText) }
    private var canSave: Bool { value != nil && !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    AmountEntryField(text: $valueText, focused: $amountFocused)

                    EntryFieldRow(icon: "tag") {
                        TextField("Name", text: $name)
                            .foregroundStyle(MonetaColor.textPrimary)
                    }

                    HStack(spacing: 8) {
                        ForEach(AssetKind.allCases) { candidate in
                            let isSelected = candidate == kind
                            Button {
                                Haptics.selection()
                                withAnimation(.snappy(duration: 0.18)) { kind = candidate }
                            } label: {
                                Label(candidate.title, systemImage: candidate.systemImage)
                                    .font(.footnote.weight(.semibold))
                                    .lineLimit(1)
                                    .foregroundStyle(isSelected ? MonetaColor.canvas : MonetaColor.textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 9)
                                    .background(isSelected ? MonetaColor.textPrimary : MonetaColor.card, in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                        }
                    }

                    EntrySaveButton(title: String.localized("Save changes"), isEnabled: canSave, action: save)

                    Button(role: .destructive) { showDeleteConfirm = true } label: {
                        Text("Delete asset").font(.subheadline.weight(.semibold))
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
            .navigationTitle("Edit Asset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .confirmationDialog("Delete this asset?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    store.deleteAsset(asset)
                    dismiss()
                }
            }
        }
    }

    private func save() {
        guard let value else { return }
        store.updateAsset(asset, name: name.trimmingCharacters(in: .whitespaces), value: value, kind: kind)
        Haptics.success()
        dismiss()
    }
}

// MARK: - Liability

struct EditLiabilitySheet: View {
    @EnvironmentObject private var store: FinanceStore
    @Environment(\.dismiss) private var dismiss
    @FocusState private var amountFocused: Bool
    let liability: Liability

    @State private var name: String
    @State private var amountText: String
    @State private var monthlyPaymentText: String
    @State private var showDeleteConfirm = false

    init(liability: Liability) {
        self.liability = liability
        _name = State(initialValue: liability.name)
        _amountText = State(initialValue: NSDecimalNumber(decimal: liability.amount).stringValue)
        _monthlyPaymentText = State(initialValue: liability.monthlyPayment.map { NSDecimalNumber(decimal: $0).stringValue } ?? "")
    }

    private var amount: Decimal? { parseAmount(amountText) }
    private var canSave: Bool { amount != nil && !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    AmountEntryField(text: $amountText, focused: $amountFocused)

                    VStack(spacing: 10) {
                        EntryFieldRow(icon: "creditcard") {
                            TextField("Name", text: $name)
                                .foregroundStyle(MonetaColor.textPrimary)
                        }
                        EntryFieldRow(icon: "calendar.badge.clock") {
                            TextField("Monthly payment (optional)", text: $monthlyPaymentText)
                                .keyboardType(.decimalPad)
                                .foregroundStyle(MonetaColor.textPrimary)
                        }
                    }

                    EntrySaveButton(title: String.localized("Save changes"), isEnabled: canSave, action: save)

                    Button(role: .destructive) { showDeleteConfirm = true } label: {
                        Text("Delete liability").font(.subheadline.weight(.semibold))
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
            .navigationTitle("Edit Liability")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .confirmationDialog("Delete this liability?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    store.deleteLiability(liability)
                    dismiss()
                }
            }
        }
    }

    private func save() {
        guard let amount else { return }
        store.updateLiability(liability, name: name.trimmingCharacters(in: .whitespaces), amount: amount, monthlyPayment: parseAmount(monthlyPaymentText))
        Haptics.success()
        dismiss()
    }
}

// MARK: - Recurring

struct EditRecurringSheet: View {
    @EnvironmentObject private var store: FinanceStore
    @Environment(\.dismiss) private var dismiss
    @FocusState private var amountFocused: Bool
    let entry: RecurringEntry

    @State private var name: String
    @State private var amountText: String
    @State private var frequency: RecurringFrequency
    @State private var showDeleteConfirm = false

    init(entry: RecurringEntry) {
        self.entry = entry
        _name = State(initialValue: entry.name)
        _amountText = State(initialValue: NSDecimalNumber(decimal: entry.amount).stringValue)
        _frequency = State(initialValue: entry.frequency)
    }

    private var amount: Decimal? { parseAmount(amountText) }
    private var canSave: Bool { amount != nil && !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    AmountEntryField(text: $amountText, focused: $amountFocused)

                    EntryFieldRow(icon: entry.isIncome ? "arrow.down.circle" : "storefront") {
                        TextField("Name", text: $name)
                            .foregroundStyle(MonetaColor.textPrimary)
                    }

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

                    EntrySaveButton(title: String.localized("Save changes"), isEnabled: canSave, action: save)

                    Button(role: .destructive) { showDeleteConfirm = true } label: {
                        Text("Stop tracking").font(.subheadline.weight(.semibold))
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
            .navigationTitle("Edit Recurring")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .confirmationDialog("Stop tracking \(entry.name)?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Stop Tracking", role: .destructive) {
                    store.deleteRecurring(entry)
                    dismiss()
                }
            } message: {
                Text("This won't affect any past transactions — only future reminders.")
            }
        }
    }

    private func save() {
        guard let amount else { return }
        store.updateRecurring(entry, name: name.trimmingCharacters(in: .whitespaces), amount: amount, frequency: frequency)
        Haptics.success()
        dismiss()
    }
}
