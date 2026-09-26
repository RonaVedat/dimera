import SwiftUI

/// Pure timing for a skeleton's lifetime, driven by elapsed seconds since it
/// appeared — no SwiftUI, so the thresholds are unit-testable on their own.
///
/// NN/g: under about a second, an animated loading indicator is "distracting"
/// rather than helpful, so a skeleton starts still and silent. Past a
/// second, a load is no longer instant, and a moving highlight signals the
/// app is still working rather than stuck. Past ten seconds, a one-line
/// hint answers the question a bare animation can't ("is this stuck?").
struct SkeletonTiming: Equatable {
    let elapsed: TimeInterval

    private static let shimmerDelay: TimeInterval = 1.0
    private static let fadeInDuration: TimeInterval = 0.3
    /// 1.2s travel + 0.6s rest = a 1.8s period, roughly 0.56Hz — comfortably
    /// clear of the ~0.2Hz band Apple's HIG calls out as one people are
    /// unusually sensitive to in sustained, repeating motion.
    private static let sweepTravel: TimeInterval = 1.2
    private static let sweepRest: TimeInterval = 0.6
    private static var sweepPeriod: TimeInterval { sweepTravel + sweepRest }
    static let slowThreshold: TimeInterval = 10.0

    var isShimmering: Bool { elapsed >= Self.shimmerDelay }
    var isSlow: Bool { elapsed >= Self.slowThreshold }

    /// 0 the instant shimmering starts, ramping to 1 over `fadeInDuration` —
    /// avoids the highlight snapping on at full strength.
    var highlightOpacity: Double {
        guard isShimmering else { return 0 }
        return min(1, (elapsed - Self.shimmerDelay) / Self.fadeInDuration)
    }

    /// 0...1 position of the sweep across the skeleton. `nil` before
    /// shimmering starts, and during the rest pause between passes.
    var sweepProgress: Double? {
        guard isShimmering else { return nil }
        let cyclePosition = (elapsed - Self.shimmerDelay).truncatingRemainder(dividingBy: Self.sweepPeriod)
        guard cyclePosition < Self.sweepTravel else { return nil }
        return cyclePosition / Self.sweepTravel
    }
}

/// A placeholder shape for content that's still loading — real layout,
/// static filler, `.redacted(reason: .placeholder)` on top.
struct SkeletonBlock: View {
    /// Where the block sits, so it stays visible against what's under it —
    /// the same distinction `ValueStepView.previewStat` already draws
    /// between its outer `.monetaCard()` and its own `cardElevated` tiles.
    enum Surface {
        /// Directly on the screen background.
        case canvas
        /// Nested inside another `.card`-colored container, which needs the
        /// next shade up to read as a distinct block.
        case card
    }

    var width: CGFloat? = nil
    var height: CGFloat = 16
    var radius: CGFloat = 6
    var surface: Surface = .canvas

    private var fill: Color {
        switch surface {
        case .canvas: return MonetaColor.card
        case .card: return MonetaColor.cardElevated
        }
    }

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(fill)
            .frame(width: width, height: height)
            .redacted(reason: .placeholder)
    }
}

/// Adds the moving highlight to a skeleton, once for the whole container —
/// never per block. The highlight is a soft diagonal band, drawn over the
/// content and then masked by that same content, so light only crosses the
/// gray blocks themselves and never spills into the space between them.
private struct SkeletonShimmerModifier: ViewModifier {
    var slowHint: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var appearedAt: Date?

    func body(content: Content) -> some View {
        TimelineView(.animation) { timeline in
            let elapsed = appearedAt.map { timeline.date.timeIntervalSince($0) } ?? 0
            let timing = SkeletonTiming(elapsed: elapsed)

            VStack(spacing: 10) {
                ZStack {
                    content
                    // Apple HIG: Reduce Motion should cut "automatic and
                    // repetitive animations" — the sweep never renders here,
                    // regardless of how long loading takes.
                    if !reduceMotion, let progress = timing.sweepProgress {
                        shimmerBand(progress: progress)
                            .mask(content)
                            .opacity(timing.highlightOpacity)
                            .allowsHitTesting(false)
                    }
                }

                if timing.isSlow, let slowHint {
                    Text(slowHint)
                        .font(.footnote)
                        .foregroundStyle(MonetaColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: timing.isSlow)
        }
        .onAppear { appearedAt = Date() }
    }

    private func shimmerBand(progress: Double) -> some View {
        GeometryReader { geo in
            let bandWidth = geo.size.width * 0.5
            let travel = geo.size.width + bandWidth * 2
            LinearGradient(colors: [.clear, highlightColor, .clear], startPoint: .top, endPoint: .bottom)
                .frame(width: bandWidth)
                .rotationEffect(.degrees(20))
                .offset(x: -bandWidth + progress * travel)
        }
    }

    /// Light-mode blocks are already close to white, so the highlight needs
    /// real strength to read; dark-mode blocks are close to black, so the
    /// same strength would flash — matching intensity, not the same value.
    private var highlightColor: Color {
        colorScheme == .dark ? .white.opacity(0.08) : .white.opacity(0.6)
    }
}

extension View {
    /// Adds a moving highlight once loading runs past a second, and an
    /// optional one-line hint once it runs past ten. Applied to a whole
    /// skeleton's container, not to individual blocks.
    func skeletonShimmer(slowHint: String? = nil) -> some View {
        modifier(SkeletonShimmerModifier(slowHint: slowHint))
    }
}

/// Home's own shape (header, net-worth headline, period picker, chart,
/// three tiles) shown while `FinanceStore.load()` resolves a genuinely
/// fresh install's sample-data fetch — a returning user's own data comes
/// straight from disk with no loading window at all, so this only appears
/// for a new install or, going forward, real sync latency.
struct HomeSkeletonView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    SkeletonBlock(width: 110, height: 13)
                    SkeletonBlock(width: 90, height: 20)
                }
                Spacer()
                Circle()
                    .fill(MonetaColor.card)
                    .frame(width: 36, height: 36)
                    .redacted(reason: .placeholder)
            }
            .padding(.top, 8)

            VStack(alignment: .leading, spacing: 8) {
                SkeletonBlock(width: 80, height: 13)
                SkeletonBlock(width: 180, height: 34)
                SkeletonBlock(width: 130, height: 16)
            }
            .padding(.top, 24)

            SkeletonBlock(height: 170, radius: MonetaMetrics.tileRadius)
                .padding(.top, 20)

            HStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { _ in
                    SkeletonBlock(height: 28, radius: 14)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 16)

            HStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonBlock(height: 66, radius: MonetaMetrics.tileRadius)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 24)

            SkeletonBlock(height: 44, radius: MonetaMetrics.tileRadius)
                .padding(.top, 10)
        }
        .padding(.horizontal, MonetaMetrics.screenPadding)
        .skeletonShimmer()
        .accessibilityElement()
        .accessibilityLabel("Loading your dashboard")
    }
}

#Preview {
    HomeSkeletonView().background(MonetaColor.canvas)
}
