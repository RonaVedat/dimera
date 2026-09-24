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
}

extension View {
    /// Standard elevated card surface used across Home, Insights, and Goals.
    func monetaCard(radius: CGFloat = MonetaMetrics.cardRadius) -> some View {
        self
            .background(MonetaColor.card, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}
