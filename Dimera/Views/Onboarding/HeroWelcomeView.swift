import SwiftUI

/// The full-bleed video hero that opens onboarding proper, right after
/// `SplashView`. No progress capsule here — it doesn't belong on a full-bleed
/// media screen, and this is the one moment the flow doesn't need to orient
/// the user (there's nowhere to have come from yet).
struct HeroWelcomeView: View {
    let next: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            HeroVideoBackground()

            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Welcome to Dimera")
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)

                    Text("Understand your money. Automatically.")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.94))
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Financial clarity, every day.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                }

                trustStrip

                Button {
                    onboardingHaptic()
                    next()
                } label: {
                    Text("Get Started")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(HeroButtonPressStyle())
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 28)
        }
        .statusBarHidden(false)
        .preferredColorScheme(.dark)
    }

    private var trustStrip: some View {
        HStack(spacing: 14) {
            trustBadge("lock.shield.fill", String.localized("GDPR-focused"))
            trustBadge("checkmark.shield.fill", String.localized("Encrypted"))
            trustBadge("hand.raised.fill", String.localized("Never sold"))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Private by design: GDPR-focused, encrypted, never sold.")
    }

    private func trustBadge(_ systemImage: String, _ text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.caption2.weight(.semibold))
            Text(text)
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(.white.opacity(0.78))
    }
}

/// A slightly heavier press feedback than the standard opacity dim, since
/// this button sits directly on rich media rather than a flat surface.
private struct HeroButtonPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

#Preview {
    HeroWelcomeView(next: {})
}
