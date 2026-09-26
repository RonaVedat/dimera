import Testing
@testable import Dimera

/// `SkeletonTiming` is pure elapsed-time math, so every boundary from the
/// loading-UX strategy is checked directly rather than through a live
/// `TimelineView` — the still/shimmer/slow thresholds, the fade-in ramp,
/// and the sweep's rest pause between passes.
struct SkeletonTimingTests {
    @Test func stillBeforeOneSecond() {
        for elapsed in [0, 0.5, 0.99] {
            let timing = SkeletonTiming(elapsed: elapsed)
            #expect(!timing.isShimmering)
            #expect(timing.highlightOpacity == 0)
            #expect(timing.sweepProgress == nil)
        }
    }

    @Test func shimmerStartsAtOneSecond() {
        #expect(SkeletonTiming(elapsed: 1.0).isShimmering)
        #expect(SkeletonTiming(elapsed: 1.0).highlightOpacity == 0)
    }

    @Test func highlightFadesInOverPointThreeSeconds() {
        #expect(abs(SkeletonTiming(elapsed: 1.15).highlightOpacity - 0.5) < 0.001)
        #expect(SkeletonTiming(elapsed: 1.3).highlightOpacity == 1)
        #expect(SkeletonTiming(elapsed: 5.0).highlightOpacity == 1)
    }

    @Test func sweepTravelsThenRests() {
        // Travel: first 1.2s of each 1.8s cycle.
        #expect(SkeletonTiming(elapsed: 1.0).sweepProgress == 0)
        #expect(abs((SkeletonTiming(elapsed: 1.6).sweepProgress ?? -1) - 0.5) < 0.001)
        // Rest: the remaining 0.6s of the cycle.
        #expect(SkeletonTiming(elapsed: 2.2).sweepProgress == nil)
        #expect(SkeletonTiming(elapsed: 2.7).sweepProgress == nil)
        // Second cycle starts fresh.
        #expect(SkeletonTiming(elapsed: 2.8).sweepProgress == 0)
    }

    @Test func notSlowBeforeTenSeconds() {
        #expect(!SkeletonTiming(elapsed: 9.99).isSlow)
    }

    @Test func slowAtTenSeconds() {
        #expect(SkeletonTiming(elapsed: 10.0).isSlow)
        #expect(SkeletonTiming(elapsed: 30.0).isSlow)
    }
}
