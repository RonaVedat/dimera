import SwiftUI

struct BankConnectionStepView: View {
    let finish: () -> Void
    var progress: Double?
    var stepLabel: String?
    var onBack: (() -> Void)?
    @State private var showComingSoon = false

    private let cannotDo = [
        String.localized("Make payments"),
        String.localized("Transfer money"),
        String.localized("Access your password")
    ]

    var body: some View {
        OnboardingScaffold(
            progress: progress,
            stepLabel: stepLabel,
            onBack: onBack,
            primaryTitle: String.localized("Connect bank"),
            primaryAction: { showComingSoon = true },
            secondaryTitle: String.localized("Maybe later"),
            secondaryAction: finish
        ) {
            VStack(alignment: .leading, spacing: 24) {
                Spacer(minLength: 20)

                Image(systemName: "building.columns.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(MonetaColor.accent)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Connect your bank securely.")
                        .font(.system(.title, design: .rounded).weight(.bold))
                        .foregroundStyle(MonetaColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text("Your login stays with your bank.")
                        .font(.subheadline)
                        .foregroundStyle(MonetaColor.textSecondary)
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text("We cannot")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(MonetaColor.textSecondary)
                    ForEach(cannotDo, id: \.self) { item in
                        Label {
                            Text(item)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(MonetaColor.textPrimary)
                        } icon: {
                            Image(systemName: "xmark.circle")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(MonetaColor.textSecondary)
                        }
                    }
                }
                .padding(16)
                .monetaCard()
            }
        }
        .alert("Bank connections are coming soon", isPresented: $showComingSoon) {
            Button("Continue Manually") { finish() }
        } message: {
            Text("We're finishing our secure banking partnership. For now, add transactions manually — you can connect a real account the moment it's ready.")
        }
    }
}

#Preview {
    BankConnectionStepView(finish: {})
}
