import SwiftUI

/// Drives the hero screen's background: the real video when a clip has been
/// added to the bundle and motion is appropriate, otherwise a dark gradient
/// that alone still reads as premium rather than "broken."
///
/// To add the real clip: drop a slow, quiet nature/abstract loop (a few
/// seconds, no audio needed since it plays muted) into
/// `Dimera/Resources/onboarding_hero.mp4`, then run `xcodegen generate`
/// again so Xcode picks up the new bundle resource. Nothing else changes —
/// this view finds it automatically and swaps the gradient out for it.
struct HeroVideoBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var videoURL: URL? {
        Bundle.main.url(forResource: "onboarding_hero", withExtension: "mp4")
            ?? Bundle.main.url(forResource: "onboarding_hero", withExtension: "mov")
    }

    private var shouldPlayVideo: Bool {
        !reduceMotion && !ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    var body: some View {
        ZStack {
            fallbackGradient

            if shouldPlayVideo, let videoURL {
                VideoBackground(url: videoURL)
                    .transition(.opacity)
            }

            LinearGradient(
                colors: [.black.opacity(0.1), .black.opacity(0.25), .black.opacity(0.62)],
                startPoint: .top, endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }

    private var fallbackGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.03, green: 0.09, blue: 0.07),
                Color(red: 0.01, green: 0.03, blue: 0.03),
                .black
            ],
            startPoint: .top, endPoint: .bottom
        )
    }
}
