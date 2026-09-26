import SwiftUI

/// A dedicated full-screen beat for a meaningful state change — a contract
/// cancelled, a goal reached, a tax export ready — instead of a toast that
/// dismisses itself and is easy to miss. Presented with `.fullScreenCover`,
/// not `.sheet`: a sheet still shows a card with rounded corners and a
/// swipe-to-dismiss handle on iPhone, which reads as "a bigger toast." Edge
/// to edge with no accidental dismiss is what makes this read as its own
/// screen, the same idiom Trade Republic uses after a trade completes.
///
/// Reserved for genuinely meaningful transitions — logging an expense or
/// editing a budget should stay instant, not gain a forced pause.
struct ConfirmationMomentView: View {
    let icon: String
    let iconTint: Color
    let headline: String
    var amount: Decimal? = nil
    var amountCaption: String? = nil
    let subtitle: String
    let buttonTitle: String
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var badgeScale: CGFloat = 0.5
    @State private var iconScale: CGFloat = 0.4
    @State private var contentOpacity: Double = 0

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 22) {
                ZStack {
                    Circle()
                        .fill(iconTint.opacity(0.15))
                        .frame(width: 104, height: 104)
                        .scaleEffect(badgeScale)
                    Image(systemName: icon)
                        .font(.system(size: 42, weight: .bold))
                        .foregroundStyle(iconTint)
                        .scaleEffect(iconScale)
                }

                VStack(spacing: 10) {
                    Text(headline)
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(MonetaColor.textPrimary)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)

                    if let amount {
                        VStack(spacing: 2) {
                            AmountText(amount)
                                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                                .foregroundStyle(iconTint)
                            if let amountCaption {
                                Text(amountCaption)
                                    .font(.footnote)
                                    .foregroundStyle(MonetaColor.textSecondary)
                            }
                        }
                    }

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(MonetaColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .opacity(contentOpacity)
            }

            Spacer()

            Button(buttonTitle) { onFinish() }
                .buttonStyle(OnboardingPrimaryButtonStyle())
                .opacity(contentOpacity)
        }
        .padding(.horizontal, MonetaMetrics.screenPadding)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MonetaColor.canvas)
        .accessibilityElement(children: .combine)
        .onAppear { animateIn() }
    }

    private func animateIn() {
        Haptics.success()

        if reduceMotion {
            badgeScale = 1
            iconScale = 1
            contentOpacity = 1
        } else {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.62)) {
                badgeScale = 1
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.55).delay(0.08)) {
                iconScale = 1
            }
            withAnimation(.easeOut(duration: 0.35).delay(0.25)) {
                contentOpacity = 1
            }
        }
    }
}

#Preview {
    ConfirmationMomentView(
        icon: "checkmark.seal.fill", iconTint: MonetaColor.gain, headline: "Contract cancelled",
        amount: 167.88, amountCaption: "a year", subtitle: "It stays in your list, marked Cancelled.",
        buttonTitle: "Done", onFinish: {}
    )
}
