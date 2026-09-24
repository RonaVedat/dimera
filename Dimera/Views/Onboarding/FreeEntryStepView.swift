import SwiftUI

struct FreeEntryStepView: View {
    let createDashboard: () -> Void
    let connectBankNow: () -> Void
    var progress: Double?
    var stepLabel: String?
    var onBack: (() -> Void)?

    var body: some View {
        OnboardingScaffold(
            progress: progress,
            stepLabel: stepLabel,
            onBack: onBack,
            primaryTitle: String.localized("Create my dashboard"),
            primaryAction: createDashboard,
            secondaryTitle: String.localized("Connect bank now"),
            secondaryAction: {
                onboardingHaptic()
                connectBankNow()
            }
        ) {
            VStack(alignment: .leading, spacing: 20) {
                Spacer(minLength: 40)

                Image(systemName: "square.and.pencil")
                    .font(.system(size: 44))
                    .foregroundStyle(MonetaColor.accent)
                    .accessibilityHidden(true)

                Text("Start manually.")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .foregroundStyle(MonetaColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Add your first transaction.")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(MonetaColor.textPrimary)
                    Text("You can connect your bank anytime later.")
                        .font(.subheadline)
                        .foregroundStyle(MonetaColor.textSecondary)
                }
            }
        }
    }
}

#Preview {
    FreeEntryStepView(createDashboard: {}, connectBankNow: {}, progress: 4 / 7, stepLabel: "Step 5 of 8", onBack: {})
}
