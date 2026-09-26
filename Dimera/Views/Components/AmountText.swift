import SwiftUI

/// A currency figure that rolls to its new value instead of snapping —
/// `.monospacedDigit()` plus `.contentTransition(.numericText())` in one
/// reusable place, so every call site gets both instead of duplicating
/// (or forgetting) either.
///
/// The animation is short (0.2s) on purpose: a financial figure is
/// information, not decoration. It should read as "this number just
/// changed," never make someone wait to find out what the number actually
/// is. 0.2s sits between the two related durations already in this
/// codebase — `FinancialSnapshotView`'s existing `.numericText` (0.25s) and
/// `HomeView`'s scrub-release snap-back (0.15s) — rather than introducing a
/// slower, unfamiliar pace.
struct AmountText: View {
    private let text: String
    private let doubleValue: Double
    private let isTransient: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// - Parameters:
    ///   - signed: shows a leading "+" for a positive value and "-" for a
    ///     negative one (e.g. a month-over-month delta). Omit for a plain
    ///     magnitude, which never gets a sign.
    ///   - isTransient: true while the value is changing many times per
    ///     second for a reason other than the underlying data changing —
    ///     e.g. `HomeView` dragging across its chart. Forces an instant
    ///     snap instead of a roll, the same way `displayedLabel` already
    ///     uses `.contentTransition(.identity)` above this figure for the
    ///     same reason.
    init(_ value: Decimal, signed: Bool = false, isTransient: Bool = false) {
        self.doubleValue = NSDecimalNumber(decimal: value).doubleValue
        self.text = Self.format(value, signed: signed)
        self.isTransient = isTransient
    }

    init(_ value: Double, signed: Bool = false, isTransient: Bool = false) {
        self.doubleValue = value
        self.text = Self.format(Decimal(value), signed: signed)
        self.isTransient = isTransient
    }

    var body: some View {
        Text(text)
            .monospacedDigit()
            .contentTransition(reduceMotion || isTransient ? .identity : .numericText(value: doubleValue))
            .animation(reduceMotion || isTransient ? nil : .snappy(duration: 0.2), value: text)
    }

    private static func format(_ value: Decimal, signed: Bool) -> String {
        guard signed else { return Currency.string(value) }
        return value >= 0 ? "+\(Currency.string(value))" : "-\(Currency.string(abs(value)))"
    }
}
