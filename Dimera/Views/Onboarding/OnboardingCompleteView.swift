import SwiftUI
import UIKit

/// The one-beat celebration that closes onboarding — the same idiom Apple
/// uses to end Apple Watch pairing or Screen Time setup: a checkmark that
/// springs in, a success haptic, then it gets out of the way on its own.
/// Not a game-score moment (finance shouldn't feel like a game) — just the
/// quiet satisfaction of a completed checklist.
struct OnboardingCompleteView: View {
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var ringScale: CGFloat = 0.5
    @State private var checkScale: CGFloat = 0.4
    @State private var contentOpacity: Double = 0

    var body: some View {
        VStack(spacing: 22) {
            ZStack {
                Circle()
                    .fill(MonetaColor.gain.opacity(0.15))
                    .frame(width: 104, height: 104)
                    .scaleEffect(ringScale)

                Image(systemName: "checkmark")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(MonetaColor.gain)
                    .scaleEffect(checkScale)
            }

            VStack(spacing: 6) {
                Text("You're all set")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(MonetaColor.textPrimary)
                Text("Welcome to Dimera.")
                    .font(.subheadline)
                    .foregroundStyle(MonetaColor.textSecondary)
            }
            .opacity(contentOpacity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MonetaColor.canvas)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("You're all set. Welcome to Dimera.")
        .onAppear { animateIn() }
    }

    private func animateIn() {
        Haptics.success()

        if reduceMotion {
            ringScale = 1
            checkScale = 1
            contentOpacity = 1
        } else {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.62)) {
                ringScale = 1
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.55).delay(0.08)) {
                checkScale = 1
            }
            withAnimation(.easeOut(duration: 0.35).delay(0.25)) {
                contentOpacity = 1
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            onFinish()
        }
    }
}

#Preview {
    OnboardingCompleteView(onFinish: {})
}
