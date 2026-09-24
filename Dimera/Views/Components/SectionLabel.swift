import SwiftUI

/// Small uppercase-weight section header used above grouped content,
/// e.g. "Recent", "Your goals". Uses a Dynamic Type text style (not a fixed
/// point size) so it scales with the user's preferred text size.
struct SectionLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(MonetaColor.textSecondary)
            .accessibilityAddTraits(.isHeader)
    }
}
