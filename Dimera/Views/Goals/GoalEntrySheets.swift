import SwiftUI

/// Add/edit forms for goals — the hybrid tracking choice is the one thing
/// that makes this form richer than a plain Asset/Liability entry: link an
/// existing account for progress that never needs updating by hand, or
/// track manually for money this app doesn't otherwise model (cash, an
/// external account).

// MARK: - Add

struct AddGoalSheet: View {
    @EnvironmentObject private var store: FinanceStore
    @Environment(\.dismiss) private var dismiss
    @FocusState private var amountFocused: Bool

    @State private var name = ""
    @State private var targetText = ""
    @State private var trackingMode: GoalTrackingMode = .manual
    @State private var linkedAssetID: Asset.ID?
    @State private var manualAmountText = ""
    @State private var monthlyContributionText = ""
    @State private var showGoalReachedConfirmation = false
    @State private var reachedGoalName = ""
    @State private var reachedGoalAmount: Decimal = 0

    private var targetAmount: Decimal? { parseAmount(targetText) }
    private var canSave: Bool {
        guard let targetAmount, targetAmount > 0 else { return false }
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        if trackingMode == .linked && linkedAssetID == nil { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    AmountEntryField(text: $targetText, focused: $amountFocused)

                    EntryFieldRow(icon: "flag") {
                        TextField("Goal — New car, Emergency fund…", text: $name)
                            .foregroundStyle(MonetaColor.textPrimary)
                    }

                    GoalTrackingSection(
                        assets: store.assets,
                        trackingMode: $trackingMode,
                        linkedAssetID: $linkedAssetID,
                        manualAmountText: $manualAmountText
                    )

                    EntryFieldRow(icon: "calendar.badge.clock") {
                        TextField("Monthly contribution (optional)", text: $monthlyContributionText)
                            .keyboardType(.decimalPad)
                            .foregroundStyle(MonetaColor.textPrimary)
                    }

                    EntrySaveButton(title: String.localized("Save goal"), isEnabled: canSave, action: save)
                }
                .padding(.horizontal, MonetaMetrics.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollBounceBehavior(.basedOnSize)
            .onAppear {
                amountFocused = true
                if store.assets.isEmpty { trackingMode = .manual }
                if monthlyContributionText.isEmpty, store.monthSaved() > 0 {
                    monthlyContributionText = NSDecimalNumber(decimal: store.monthSaved()).stringValue
                }
            }
            .background(MonetaColor.canvas)
            .navigationTitle("Add Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .fullScreenCover(isPresented: $showGoalReachedConfirmation) {
                ConfirmationMomentView(
                    icon: "target", iconTint: MonetaColor.accent,
                    headline: String.localized("Goal reached!"),
                    amount: reachedGoalAmount, amountCaption: reachedGoalName,
                    subtitle: String.localized("You did it — fully funded."),
                    buttonTitle: String.localized("Nice!")
                ) {
                    showGoalReachedConfirmation = false
                    dismiss()
                }
            }
        }
    }

    private func save() {
        guard let targetAmount else { return }
        let manualCurrentAmount = trackingMode == .manual ? parseNonNegativeAmount(manualAmountText) : 0
        store.addGoal(
            name: name.trimmingCharacters(in: .whitespaces),
            targetAmount: targetAmount,
            monthlyContribution: parseNonNegativeAmount(monthlyContributionText),
            trackingMode: trackingMode,
            linkedAssetID: trackingMode == .linked ? linkedAssetID : nil,
            manualCurrentAmount: manualCurrentAmount
        )
        Haptics.success()

        // A goal can start already funded, e.g. a manual current amount
        // typed in at or above the target — celebrate that too, not just
        // a later edit that happens to cross 100%.
        if trackingMode == .manual, goalProgress(current: manualCurrentAmount, target: targetAmount) >= 1.0 {
            reachedGoalName = name.trimmingCharacters(in: .whitespaces)
            reachedGoalAmount = targetAmount
            showGoalReachedConfirmation = true
        } else {
            dismiss()
        }
    }
}

// MARK: - Edit

struct EditGoalSheet: View {
    @EnvironmentObject private var store: FinanceStore
    @Environment(\.dismiss) private var dismiss
    @FocusState private var amountFocused: Bool
    let goal: Goal

    @State private var name: String
    @State private var targetText: String
    @State private var trackingMode: GoalTrackingMode
    @State private var linkedAssetID: Asset.ID?
    @State private var manualAmountText: String
    @State private var monthlyContributionText: String
    @State private var showDeleteConfirm = false
    @State private var showGoalReachedConfirmation = false
    @State private var reachedGoalAmount: Decimal = 0

    init(goal: Goal) {
        self.goal = goal
        _name = State(initialValue: goal.name)
        _targetText = State(initialValue: NSDecimalNumber(decimal: goal.targetAmount).stringValue)
        _trackingMode = State(initialValue: goal.trackingMode)
        _linkedAssetID = State(initialValue: goal.linkedAssetID)
        _manualAmountText = State(initialValue: NSDecimalNumber(decimal: goal.manualCurrentAmount).stringValue)
        _monthlyContributionText = State(initialValue: NSDecimalNumber(decimal: goal.monthlyContribution).stringValue)
    }

    private var targetAmount: Decimal? { parseAmount(targetText) }
    private var canSave: Bool {
        guard let targetAmount, targetAmount > 0 else { return false }
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        if trackingMode == .linked && linkedAssetID == nil { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    AmountEntryField(text: $targetText, focused: $amountFocused)

                    EntryFieldRow(icon: "flag") {
                        TextField("Goal name", text: $name)
                            .foregroundStyle(MonetaColor.textPrimary)
                    }

                    GoalTrackingSection(
                        assets: store.assets,
                        trackingMode: $trackingMode,
                        linkedAssetID: $linkedAssetID,
                        manualAmountText: $manualAmountText,
                        // Preserve the live linked value at the moment of
                        // switching, so progress doesn't visually jump.
                        onSwitchToManual: { manualAmountText = NSDecimalNumber(decimal: store.currentAmount(for: goal)).stringValue }
                    )

                    EntryFieldRow(icon: "calendar.badge.clock") {
                        TextField("Monthly contribution (optional)", text: $monthlyContributionText)
                            .keyboardType(.decimalPad)
                            .foregroundStyle(MonetaColor.textPrimary)
                    }

                    EntrySaveButton(title: String.localized("Save changes"), isEnabled: canSave, action: save)

                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Text("Delete goal").font(.subheadline.weight(.semibold))
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
            .navigationTitle("Edit Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .confirmationDialog("Delete this goal?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    store.deleteGoal(goal)
                    dismiss()
                }
            }
            .fullScreenCover(isPresented: $showGoalReachedConfirmation) {
                ConfirmationMomentView(
                    icon: "target", iconTint: MonetaColor.accent,
                    headline: String.localized("Goal reached!"),
                    amount: reachedGoalAmount, amountCaption: name,
                    subtitle: String.localized("You did it — fully funded."),
                    buttonTitle: String.localized("Nice!")
                ) {
                    showGoalReachedConfirmation = false
                    dismiss()
                }
            }
        }
    }

    private func save() {
        guard let targetAmount else { return }
        let newManualAmount = trackingMode == .manual ? parseNonNegativeAmount(manualAmountText) : 0
        let wasReached = goal.trackingMode == .manual
            && goalProgress(current: goal.manualCurrentAmount, target: goal.targetAmount) >= 1.0
        let isReached = trackingMode == .manual && goalProgress(current: newManualAmount, target: targetAmount) >= 1.0

        store.updateGoal(
            goal,
            name: name.trimmingCharacters(in: .whitespaces),
            targetAmount: targetAmount,
            monthlyContribution: parseNonNegativeAmount(monthlyContributionText),
            trackingMode: trackingMode,
            linkedAssetID: trackingMode == .linked ? linkedAssetID : nil,
            manualCurrentAmount: newManualAmount
        )
        Haptics.success()

        if !wasReached && isReached {
            reachedGoalAmount = targetAmount
            showGoalReachedConfirmation = true
        } else {
            dismiss()
        }
    }
}

// MARK: - Shared tracking-mode section

private struct GoalTrackingSection: View {
    let assets: [Asset]
    @Binding var trackingMode: GoalTrackingMode
    @Binding var linkedAssetID: Asset.ID?
    @Binding var manualAmountText: String
    var onSwitchToManual: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How would you like to track your progress?")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(MonetaColor.textSecondary)

            VStack(spacing: 10) {
                TrackingModeOption(
                    title: String.localized("Link an account"),
                    caption: String.localized("Automatically update your progress whenever your balance changes."),
                    systemImage: "link",
                    isSelected: trackingMode == .linked,
                    isDisabled: assets.isEmpty
                ) {
                    Haptics.selection()
                    withAnimation(.snappy(duration: 0.2)) { trackingMode = .linked }
                }

                if assets.isEmpty {
                    Text("Add an asset first to link a goal to it.")
                        .font(.caption2)
                        .foregroundStyle(MonetaColor.textTertiary)
                        .padding(.leading, 4)
                }

                TrackingModeOption(
                    title: String.localized("Update manually"),
                    caption: String.localized("Perfect for cash savings or accounts outside this app."),
                    systemImage: "pencil",
                    isSelected: trackingMode == .manual,
                    isDisabled: false
                ) {
                    Haptics.selection()
                    if trackingMode != .manual { onSwitchToManual() }
                    withAnimation(.snappy(duration: 0.2)) { trackingMode = .manual }
                }
            }

            if trackingMode == .linked {
                VStack(spacing: 8) {
                    ForEach(assets) { asset in
                        AssetPickerRow(asset: asset, isSelected: linkedAssetID == asset.id) {
                            Haptics.selection()
                            linkedAssetID = asset.id
                        }
                    }
                }
                .padding(.top, 2)
            } else {
                EntryFieldRow(icon: "banknote") {
                    TextField("Current amount", text: $manualAmountText)
                        .keyboardType(.decimalPad)
                        .foregroundStyle(MonetaColor.textPrimary)
                }
                .padding(.top, 2)
            }
        }
    }
}

private struct TrackingModeOption: View {
    let title: String
    let caption: String
    let systemImage: String
    let isSelected: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(MonetaColor.accent.opacity(0.15)).frame(width: 36, height: 36)
                    Image(systemName: systemImage)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MonetaColor.accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MonetaColor.textPrimary)
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(MonetaColor.textSecondary)
                }
                Spacer(minLength: 8)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? MonetaColor.accent : MonetaColor.textTertiary)
            }
            .padding(14)
            .background(MonetaColor.card, in: RoundedRectangle(cornerRadius: MonetaMetrics.tileRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: MonetaMetrics.tileRadius, style: .continuous)
                    .stroke(isSelected ? MonetaColor.accent : .clear, lineWidth: 1.5)
            )
            .opacity(isDisabled ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

private struct AssetPickerRow: View {
    let asset: Asset
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: asset.kind.systemImage)
                    .font(.subheadline)
                    .foregroundStyle(MonetaColor.textSecondary)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text(asset.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(MonetaColor.textPrimary)
                    Text(Currency.string(asset.value))
                        .font(.caption)
                        .foregroundStyle(MonetaColor.textSecondary)
                        .monospacedDigit()
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? MonetaColor.accent : MonetaColor.textTertiary)
            }
            .padding(14)
            .monetaCard(radius: MonetaMetrics.tileRadius)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

/// Unlike `parseAmount`, allows zero and blank input — a goal's starting
/// progress or monthly contribution can legitimately be zero.
private func parseNonNegativeAmount(_ text: String) -> Decimal {
    guard !text.isEmpty else { return 0 }
    let normalized = text.replacingOccurrences(of: ",", with: ".")
    return Decimal(string: normalized) ?? 0
}

/// Mirrors `FinanceStore.progress(for:)`'s formula exactly, for a
/// manually-tracked goal's raw current/target — used to detect "just
/// crossed 100%" around a save, before the store has the new values.
/// Linked-goal progress is derived live from asset value with no discrete
/// "just changed" moment anywhere in `FinanceStore`, so detecting a crossing
/// there isn't covered by this first pass.
private func goalProgress(current: Decimal, target: Decimal) -> Double {
    guard target > 0 else { return 0 }
    return min(1, max(0, NSDecimalNumber(decimal: current / target).doubleValue))
}

#Preview("Add") {
    Color.clear.sheet(isPresented: .constant(true)) {
        AddGoalSheet().environmentObject(FinanceStore())
    }
}
