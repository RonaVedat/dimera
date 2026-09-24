import SwiftUI
import UIKit

/// The single "+" entry point: a medium-height chooser that expands into
/// one of four minimal forms (2–4 fields each, never a full screen).
/// Data entry stays a quick detour — see status, act, return to status.
struct AddEntrySheet: View {
    enum Kind: String, Identifiable {
        case expense, income, asset, liability
        var id: String { rawValue }
    }

    @Environment(\.dismiss) private var dismiss
    @State private var kind: Kind?
    @State private var detent: PresentationDetent = .medium

    /// Jump straight to a specific form (e.g. an "Add expense" empty-state
    /// button) instead of showing the chooser first.
    init(kind: Kind? = nil) {
        _kind = State(initialValue: kind)
        _detent = State(initialValue: kind == nil ? .medium : .large)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch kind {
                case nil: chooser
                case .expense: AddExpenseForm(onDone: { dismiss() })
                case .income: AddIncomeForm(onDone: { dismiss() })
                case .asset: AddAssetForm(onDone: { dismiss() })
                case .liability: AddLiabilityForm(onDone: { dismiss() })
                }
            }
            .background(MonetaColor.canvas)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if kind != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            withAnimation(.snappy(duration: 0.25)) {
                                kind = nil
                                detent = .medium
                            }
                        } label: {
                            Image(systemName: "chevron.backward")
                        }
                        .accessibilityLabel("Back")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
    }

    private var title: String {
        switch kind {
        case nil: return String.localized("Add")
        case .expense: return String.localized("Add Expense")
        case .income: return String.localized("Add Income")
        case .asset: return String.localized("Add Asset")
        case .liability: return String.localized("Add Liability")
        }
    }

    private var chooser: some View {
        VStack(spacing: 10) {
            chooserRow(.expense, icon: "minus", tint: MonetaColor.loss,
                       title: String.localized("Expense"), subtitle: String.localized("Money you spent"))
            chooserRow(.income, icon: "arrow.down", tint: MonetaColor.gain,
                       title: String.localized("Income"), subtitle: String.localized("Money you received"))
            chooserRow(.asset, icon: "chart.line.uptrend.xyaxis", tint: MonetaColor.accent,
                       title: String.localized("Asset"), subtitle: String.localized("Something you own — savings, ETFs"))
            chooserRow(.liability, icon: "creditcard", tint: MonetaColor.textSecondary,
                       title: String.localized("Liability"), subtitle: String.localized("Something you owe — a loan, a card"))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, MonetaMetrics.screenPadding)
        .padding(.top, 12)
    }

    private func chooserRow(_ target: Kind, icon: String, tint: Color, title: String, subtitle: String) -> some View {
        Button {
            Haptics.selection()
            withAnimation(.snappy(duration: 0.25)) {
                kind = target
                detent = .large
            }
        } label: {
            HStack(spacing: 13) {
                Circle()
                    .fill(tint.opacity(0.15))
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: icon)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(tint)
                    }
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MonetaColor.textPrimary)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(MonetaColor.textSecondary)
                }
                Spacer(minLength: 6)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(MonetaColor.textTertiary)
            }
            .padding(13)
            .monetaCard(radius: MonetaMetrics.tileRadius)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Expense

private struct AddExpenseForm: View {
    @EnvironmentObject private var store: FinanceStore
    @FocusState private var amountFocused: Bool
    let onDone: () -> Void

    @State private var amountText = ""
    @State private var merchant = ""
    @State private var category: TransactionCategory = .food
    @State private var showRecurringPrompt = false
    @State private var savedTransactionID: UUID?

    /// Generated up front so a receipt can be captured and processed in the
    /// background *before* Save is tapped — the same id becomes the actual
    /// transaction's id if the user saves, or gets cleaned up in
    /// `ReceiptAttachmentSection`/`onDisappear` if they back out instead.
    @State private var pendingID = UUID()
    @State private var hasReceipt = false
    @State private var receiptSuggestedDate: Date?
    @State private var didSave = false

    /// Names that usually mean a monthly payment — enough signal for a
    /// one-tap prompt, without pretending to be real detection.
    private static let recurringHints = [
        "netflix", "spotify", "telekom", "vodafone", "o2", "disney", "prime",
        "gym", "fitx", "mcfit", "urban sports", "insurance", "versicherung",
        "miete", "rent", "sky", "dazn", "youtube", "icloud", "apple one"
    ]

    private var amount: Decimal? { parseAmount(amountText) }
    private var canSave: Bool { amount != nil && !merchant.trimmingCharacters(in: .whitespaces).isEmpty }

    private var looksRecurring: Bool {
        let name = merchant.lowercased()
        return category == .subscriptions || Self.recurringHints.contains { name.contains($0) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                AmountEntryField(text: $amountText, focused: $amountFocused)

                EntryFieldRow(icon: "storefront") {
                    TextField("Merchant — REWE, Amazon…", text: $merchant)
                        .foregroundStyle(MonetaColor.textPrimary)
                }

                CategoryChips(selection: $category)

                ReceiptAttachmentSection(transactionID: pendingID, hasReceipt: $hasReceipt, onSuggestion: applySuggestion)

                EntrySaveButton(title: String.localized("Save expense"), isEnabled: canSave, action: save)
            }
            .padding(.horizontal, MonetaMetrics.screenPadding)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .onAppear { amountFocused = true }
        .onDisappear {
            guard !didSave else { return }
            Task { await ReceiptStore.shared.delete(for: pendingID) }
        }
        .confirmationDialog(
            "Looks like a recurring payment. Track it automatically?",
            isPresented: $showRecurringPrompt,
            titleVisibility: .visible
        ) {
            ForEach(RecurringFrequency.allCases) { frequency in
                Button(frequency.title) {
                    if let amount, let savedTransactionID {
                        store.addRecurring(
                            name: merchant.trimmingCharacters(in: .whitespaces),
                            amount: amount,
                            isIncome: false,
                            frequency: frequency,
                            originTransactionID: savedTransactionID
                        )
                    }
                    finish()
                }
            }
            Button("Just once", role: .cancel) { finish() }
        }
    }

    private func applySuggestion(_ result: ReceiptProcessingResult) {
        // Only fills fields the user hasn't already touched — a receipt
        // finishing processing mid-typing should never stomp on real input.
        if merchant.trimmingCharacters(in: .whitespaces).isEmpty, let suggestedMerchant = result.suggestedMerchant {
            merchant = suggestedMerchant
        }
        if amountText.isEmpty, let suggestedAmount = result.suggestedAmount {
            amountText = NSDecimalNumber(decimal: suggestedAmount).stringValue
        }
        if let suggestedDate = result.suggestedDate {
            receiptSuggestedDate = suggestedDate
        }
    }

    private func save() {
        guard let amount else { return }
        let transaction = store.addExpense(
            merchant: merchant.trimmingCharacters(in: .whitespaces),
            category: category.rawValue,
            amount: amount,
            date: receiptSuggestedDate ?? Date(),
            id: pendingID,
            hasReceipt: hasReceipt
        )
        didSave = true
        savedTransactionID = transaction.id
        if looksRecurring {
            showRecurringPrompt = true
        } else {
            finish()
        }
    }

    private func finish() {
        Haptics.success()
        onDone()
    }
}

// MARK: - Income

private struct AddIncomeForm: View {
    @EnvironmentObject private var store: FinanceStore
    @FocusState private var amountFocused: Bool
    let onDone: () -> Void

    @State private var amountText = ""
    @State private var source = "Salary"
    @State private var date = Date()
    @State private var frequency: RecurringFrequency? = .monthly

    private var amount: Decimal? { parseAmount(amountText) }
    private var canSave: Bool { amount != nil && !source.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                AmountEntryField(text: $amountText, focused: $amountFocused)

                VStack(spacing: 10) {
                    EntryFieldRow(icon: "arrow.down.circle") {
                        TextField("Source", text: $source)
                            .foregroundStyle(MonetaColor.textPrimary)
                    }
                    EntryFieldRow(icon: "calendar") {
                        DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date)
                            .labelsHidden()
                            .tint(MonetaColor.accent)
                        Spacer()
                    }
                }

                frequencyPicker

                EntrySaveButton(title: String.localized("Save income"), isEnabled: canSave, action: save)
            }
            .padding(.horizontal, MonetaMetrics.screenPadding)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .onAppear { amountFocused = true }
    }

    private var frequencyPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Does this repeat?")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(MonetaColor.textSecondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], spacing: 8) {
                frequencyChip(title: String.localized("One time"), selected: frequency == nil) { frequency = nil }
                ForEach(RecurringFrequency.allCases) { option in
                    frequencyChip(title: option.title, selected: frequency == option) { frequency = option }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func frequencyChip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            withAnimation(.snappy(duration: 0.18)) { action() }
        } label: {
            Text(title)
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.9)
                .foregroundStyle(selected ? MonetaColor.canvas : MonetaColor.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(selected ? MonetaColor.textPrimary : MonetaColor.card, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private func save() {
        guard let amount else { return }
        store.addIncome(
            source: source.trimmingCharacters(in: .whitespaces),
            amount: amount,
            date: date,
            frequency: frequency
        )
        Haptics.success()
        onDone()
    }
}

// MARK: - Asset

private struct AddAssetForm: View {
    @EnvironmentObject private var store: FinanceStore
    @FocusState private var amountFocused: Bool
    let onDone: () -> Void

    @State private var name = ""
    @State private var valueText = ""
    @State private var kind: AssetKind = .savings

    private var value: Decimal? { parseAmount(valueText) }
    private var canSave: Bool { value != nil && !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                AmountEntryField(text: $valueText, focused: $amountFocused)

                EntryFieldRow(icon: "tag") {
                    TextField("Name — ETF portfolio, crypto…", text: $name)
                        .foregroundStyle(MonetaColor.textPrimary)
                }

                kindPicker

                EntrySaveButton(title: String.localized("Add to net worth"), isEnabled: canSave, action: save)
            }
            .padding(.horizontal, MonetaMetrics.screenPadding)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .onAppear { amountFocused = true }
    }

    private var kindPicker: some View {
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
    }

    private func save() {
        guard let value else { return }
        store.addAsset(name: name.trimmingCharacters(in: .whitespaces), value: value, kind: kind)
        Haptics.success()
        onDone()
    }
}

// MARK: - Liability

private struct AddLiabilityForm: View {
    @EnvironmentObject private var store: FinanceStore
    @FocusState private var amountFocused: Bool
    let onDone: () -> Void

    @State private var name = ""
    @State private var amountText = ""
    @State private var monthlyPaymentText = ""

    private var amount: Decimal? { parseAmount(amountText) }
    private var canSave: Bool { amount != nil && !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                AmountEntryField(text: $amountText, focused: $amountFocused)

                VStack(spacing: 10) {
                    EntryFieldRow(icon: "creditcard") {
                        TextField("Name — car loan, credit card…", text: $name)
                            .foregroundStyle(MonetaColor.textPrimary)
                    }
                    EntryFieldRow(icon: "calendar.badge.clock") {
                        TextField("Monthly payment (optional)", text: $monthlyPaymentText)
                            .keyboardType(.decimalPad)
                            .foregroundStyle(MonetaColor.textPrimary)
                    }
                }

                EntrySaveButton(title: String.localized("Save liability"), isEnabled: canSave, action: save)
            }
            .padding(.horizontal, MonetaMetrics.screenPadding)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .onAppear { amountFocused = true }
    }

    private func save() {
        guard let amount else { return }
        store.addLiability(
            name: name.trimmingCharacters(in: .whitespaces),
            amount: amount,
            monthlyPayment: parseAmount(monthlyPaymentText)
        )
        Haptics.success()
        onDone()
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        AddEntrySheet().environmentObject(FinanceStore())
    }
}
