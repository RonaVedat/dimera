import SwiftUI

/// Central palette — every case maps to an Apple system color, so the app
/// inherits the platform's light/dark and accessibility behavior (Increase
/// Contrast, Reduce Transparency) automatically, with no bespoke assets.
enum MonetaColor {
    static let canvas = Color(.systemBackground)
    static let card = Color(.secondarySystemBackground)
    static let cardElevated = Color(.tertiarySystemBackground)
    static let separator = Color(.separator)

    static let textPrimary = Color(.label)
    static let textSecondary = Color(.secondaryLabel)
    static let textTertiary = Color(.tertiaryLabel)

    static let gain = Color(.systemGreen)
    static let loss = Color(.systemRed)
    static let warning = Color(.systemOrange)
    static let accent = Color(.systemIndigo)
}

enum MonetaMetrics {
    static let cardRadius: CGFloat = 20
    static let tileRadius: CGFloat = 16
    static let rowSpacing: CGFloat = 14
    static let screenPadding: CGFloat = 20
    /// A comfortable reading width for a single column of content — on
    /// iPhone and in compact-width iPad multitasking this is wider than the
    /// screen and never binds; at iPad's regular width it stops a phone
    /// layout from stretching edge-to-edge across the whole screen.
    static let contentMaxWidth: CGFloat = 700
}

extension View {
    /// Standard elevated card surface used across Home, Insights, and Goals.
    func monetaCard(radius: CGFloat = MonetaMetrics.cardRadius) -> some View {
        self
            .background(MonetaColor.card, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    /// Caps a screen's content to `MonetaMetrics.contentMaxWidth` and
    /// centers it — a no-op wherever the available width is already
    /// narrower than the cap (iPhone, portrait iPad's own detail column, or
    /// iPad in a compact-width multitasking split). It only visibly binds
    /// in wider containers, e.g. a freely-resized Stage Manager window.
    ///
    /// A flexible `HStack`, not `.frame(maxWidth:).frame(maxWidth: .infinity)`
    /// — that pairing depends on the wrapped view reporting its own ideal
    /// width back up so the outer frame can re-center it. The `HStack` gives
    /// the content at most `cap` and takes the rest itself, so it centers
    /// reliably regardless of what the wrapped view reports.
    func adaptiveContentWidth() -> some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            self.frame(maxWidth: MonetaMetrics.contentMaxWidth)
            Spacer(minLength: 0)
        }
    }
}
