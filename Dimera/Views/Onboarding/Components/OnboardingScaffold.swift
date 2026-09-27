import SwiftUI

/// Shared page layout for every onboarding step: a top bar with back
/// navigation and a progress capsule (HIG: people should always know where
/// they are in a multi-step flow and be able to revise earlier answers),
/// scrollable content, and one or two actions pinned to the bottom.
struct OnboardingScaffold<Content: View>: View {
    var progress: Double?
    var stepLabel: String?
    var onBack: (() -> Void)?
    var primaryTitle: String? = nil
    var isPrimaryEnabled: Bool = true
    var primaryAction: (() -> Void)? = nil
    var secondaryTitle: String?
    var secondaryAction: (() -> Void)?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            topBar

            ScrollView {
                content
                    .padding(.horizontal, 28)
                    .padding(.top, 20)
                    .padding(.bottom, 24)
            }
            .scrollBounceBehavior(.basedOnSize)

            if primaryTitle != nil || secondaryTitle != nil {
                VStack(spacing: 4) {
                    if let primaryTitle, let primaryAction {
                        Button {
                            onboardingHaptic()
                            primaryAction()
                        } label: {
                            Text(primaryTitle)
                        }
                        .buttonStyle(OnboardingPrimaryButtonStyle(isEnabled: isPrimaryEnabled))
                        .disabled(!isPrimaryEnabled)
                    }

                    if let secondaryTitle, let secondaryAction {
                        Button(action: secondaryAction) {
                            Text(secondaryTitle)
                        }
                        .buttonStyle(OnboardingSecondaryButtonStyle())
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 16)
            }
        }
        .background(MonetaColor.canvas)
    }

    private var topBar: some View {
        ZStack {
            if let progress {
                Capsule()
                    .fill(MonetaColor.cardElevated)
                    .frame(width: 140, height: 4)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(MonetaColor.accent)
                            .frame(width: 140 * min(max(progress, 0), 1))
                    }
                    .animation(.snappy(duration: 0.35), value: progress)
                    .accessibilityElement()
                    .accessibilityLabel("Progress")
                    .accessibilityValue(stepLabel ?? "")
            }

            HStack {
                if let onBack {
                    Button {
                        onboardingHaptic()
                        onBack()
                    } label: {
                        Image(systemName: "chevron.backward")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(MonetaColor.textPrimary)
                            .frame(width: 38, height: 38)
                            .background(MonetaColor.card, in: Circle())
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back")
                }
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .frame(minHeight: 50)
    }
}
