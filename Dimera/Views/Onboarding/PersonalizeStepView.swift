import SwiftUI

/// Merges what used to be two separate steps (goals, then profile) into one
/// screen with two sections. Goals get full-width rows since they matter
/// more and are multi-select; Profile is a single optional tag, so it's a
/// compact horizontal chip strip rather than another stack of rows — the
/// density difference communicates "this one matters more" without needing
/// separate headline copy to say so.
struct PersonalizeStepView: View {
    @Binding var selectedGoals: Set<FinancialGoal>
    @Binding var selectedProfile: FinancialProfile?
    let next: () -> Void
    var progress: Double?
    var stepLabel: String?
    var onBack: (() -> Void)?

    var body: some View {
        OnboardingScaffold(
            progress: progress,
            stepLabel: stepLabel,
            onBack: onBack,
            primaryTitle: (selectedGoals.isEmpty && selectedProfile == nil) ? String.localized("Skip for now") : String.localized("Continue"),
            primaryAction: next
        ) {
            VStack(alignment: .leading, spacing: 28) {
                Spacer(minLength: 12)

                Text("Let's personalize Dimera.")
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(MonetaColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                goalsSection
                profileSection
            }
        }
    }

    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(String.localized("What do you want to achieve?"), subtitle: String.localized("Pick as many as apply."))

            VStack(spacing: 10) {
                ForEach(FinancialGoal.allCases) { goal in
                    SelectableCard(
                        title: goal.title,
                        systemImage: goal.systemImage,
                        isSelected: selectedGoals.contains(goal)
                    ) {
                        if selectedGoals.contains(goal) {
                            selectedGoals.remove(goal)
                        } else {
                            selectedGoals.insert(goal)
                        }
                    }
                }
            }
        }
    }

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(String.localized("What describes you?"), subtitle: String.localized("Optional — helps tailor tips to you."))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(FinancialProfile.allCases) { profile in
                        ProfileChip(
                            title: profile.title,
                            systemImage: profile.systemImage,
                            isSelected: selectedProfile == profile
                        ) {
                            selectedProfile = (selectedProfile == profile) ? nil : profile
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func sectionHeader(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MonetaColor.textPrimary)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(MonetaColor.textSecondary)
        }
    }
}

/// A compact single-select pill, distinct from `SelectableCard`'s full-width
/// row — used here because Profile is one optional tag among five, not a
/// primary decision worth a whole row each.
private struct ProfileChip: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? MonetaColor.canvas : MonetaColor.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isSelected ? MonetaColor.accent : MonetaColor.cardElevated, in: Capsule())
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview {
    PersonalizeStepView(
        selectedGoals: .constant([.saveMore]),
        selectedProfile: .constant(.employee),
        next: {}, progress: 1 / 4, stepLabel: "Step 2 of 5", onBack: {}
    )
}
