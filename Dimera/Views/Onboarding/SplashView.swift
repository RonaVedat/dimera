import SwiftUI

/// The very first thing a new install shows: black background, white
/// wordmark, gone in just over a second — the same beat as Revolut's plain
/// logo screen, in Dimera's own dark-first identity. Always tappable through
/// (HIG: never strand someone on a timed, non-interactive screen).
struct SplashView: View {
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var opacity = 0.0
    @State private var scale = 0.94
    @State private var hasFinished = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            HStack(spacing: 2) {
                Text("Dimera")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(".")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(MonetaColor.accent)
            }
            .opacity(opacity)
            .scaleEffect(scale)
        }
        .contentShape(Rectangle())
        .onTapGesture { finish() }
        .onAppear {
            if reduceMotion {
                opacity = 1
                scale = 1
            } else {
                withAnimation(.easeOut(duration: 0.5)) {
                    opacity = 1
                    scale = 1
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) { finish() }
        }
        .accessibilityElement()
        .accessibilityLabel("Dimera")
        .accessibilityAddTraits(.isHeader)
    }

    private func finish() {
        guard !hasFinished else { return }
        hasFinished = true
        onFinished()
    }
}

#Preview {
    SplashView(onFinished: {})
}
