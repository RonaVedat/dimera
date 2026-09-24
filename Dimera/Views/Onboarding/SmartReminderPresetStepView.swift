import SwiftUI

/// "One decision. Many settings configured automatically." — instead of
/// making someone answer four separate questions about reminders (like
/// `RemindersSettingsView` in Settings does for people who want to fine-tune
/// later), onboarding asks a single question and applies a whole preset via
/// `ReminderPreset.apply()`. Tapping a card *is* the confirmation — no
/// separate Continue button — the same "pick a card, move on" idiom Apple
/// uses for Health's data-source setup.
struct SmartReminderPresetStepView: View {
    @EnvironmentObject private var store: FinanceStore
    let next: () -> Void
    var progress: Double?
    var stepLabel: String?
    var onBack: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedPreset: ReminderPreset?

    var body: some View {
        OnboardingScaffold(
            progress: progress,
            stepLabel: stepLabel,
            onBack: onBack,
            secondaryTitle: String.localized("Skip for now"),
            secondaryAction: next
        ) {
            VStack(alignment: .leading, spacing: 24) {
                Spacer(minLength: 12)

                VStack(alignment: .leading, spacing: 8) {
                    Text("How involved do you want to be?")
                        .font(.system(.title, design: .rounded).weight(.bold))
                        .foregroundStyle(MonetaColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text("One tap sets up reminders. Change anytime in Settings.")
                        .font(.subheadline)
                        .foregroundStyle(MonetaColor.textSecondary)
                }

                VStack(spacing: 12) {
                    ForEach(ReminderPreset.allCases) { preset in
                        ReminderPresetCard(
                            preset: preset,
                            isChosen: selectedPreset == preset,
                            isApplying: selectedPreset == preset
                        ) {
                            choose(preset)
                        }
                        .disabled(selectedPreset != nil)
                    }
                }
            }
        }
    }

    private func choose(_ preset: ReminderPreset) {
        guard selectedPreset == nil else { return }
        Haptics.selection()
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) {
            selectedPreset = preset
        }
        Task {
            await preset.apply(recurring: store.recurring)
            try? await Task.sleep(nanoseconds: reduceMotion ? 0 : 220_000_000)
            next()
        }
    }
}

private struct ReminderPresetCard: View {
    let preset: ReminderPreset
    let isChosen: Bool
    let isApplying: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(MonetaColor.accent.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: preset.systemImage)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(MonetaColor.accent)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(preset.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(MonetaColor.textPrimary)
                            Text(preset.subtitle)
                                .font(.caption)
                                .foregroundStyle(MonetaColor.textSecondary)
                        }
                        Spacer(minLength: 8)
                        if isApplying {
                            ProgressView()
                                .tint(MonetaColor.accent)
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(MonetaColor.textTertiary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(preset.bullets, id: \.self) { bullet in
                            Text("·  \(bullet)")
                                .font(.caption)
                                .foregroundStyle(MonetaColor.textSecondary)
                        }
                    }
                }
            }
            .padding(16)
            .background(MonetaColor.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isChosen ? MonetaColor.accent : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(preset.title). \(preset.subtitle)")
        .accessibilityHint("Configures \(preset.bullets.joined(separator: ", ")).")
    }
}

#Preview {
    SmartReminderPresetStepView(next: {}, progress: 2 / 4, stepLabel: "Step 3 of 5", onBack: {})
        .environmentObject(FinanceStore())
}
