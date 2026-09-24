import SwiftUI

/// A hand-built ring (the same technique behind Apple's own Activity rings)
/// rather than `Gauge`, so the size and reveal animation are fully controlled.
struct HealthRing: View {
    let score: Int
    var diameter: CGFloat = 92

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatedProgress: CGFloat = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(MonetaColor.cardElevated, lineWidth: 7)
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(MonetaColor.gain, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .easeOut(duration: 0.8), value: animatedProgress)

            VStack(spacing: -2) {
                Text("\(score)")
                    .font(.title2.weight(.bold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("of 100")
                    .font(.caption2)
                    .foregroundStyle(MonetaColor.textSecondary)
            }
            .foregroundStyle(MonetaColor.textPrimary)
        }
        .frame(width: diameter, height: diameter)
        .onAppear { animatedProgress = CGFloat(score) / 100 }
        // Keyed to the score itself (not a one-shot "have I appeared yet"
        // flag) so the ring always animates its fill, whether the real
        // value is ready immediately or arrives later, and re-fills
        // smoothly if the score changes again afterward.
        .onChange(of: score) { _, newValue in
            animatedProgress = CGFloat(newValue) / 100
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Financial health score")
        .accessibilityValue("\(score) out of 100")
    }
}
