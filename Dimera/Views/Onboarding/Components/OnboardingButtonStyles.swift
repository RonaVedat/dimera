import SwiftUI

/// Full-width filled pill — the sole focus of each onboarding step, distinct
/// from the smaller in-content capsule buttons used elsewhere in the app.
struct OnboardingPrimaryButtonStyle: ButtonStyle {
    var isEnabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(MonetaColor.canvas)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                isEnabled ? MonetaColor.textPrimary : MonetaColor.textTertiary,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Plain text button for the deferrable second choice ("Maybe later", "Not now").
struct OnboardingSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(MonetaColor.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

/// Called from a button's action closure (not chained as a view modifier) —
/// a light tap on each step-advancing action.
func onboardingHaptic() {
    Haptics.impact()
}
