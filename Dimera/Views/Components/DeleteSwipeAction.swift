import SwiftUI

extension View {
    /// A single icon-only destructive swipe action — the same treatment
    /// Mail, Messages, and Notes use for their own delete row, rather than
    /// SwiftUI's default `.onDelete` affordance, which pairs the trash icon
    /// with "Delete" text and stacks them awkwardly once the row is narrow.
    /// A trash can needs no label to read as "delete" — HIG only requires
    /// a text label where an icon's meaning could be ambiguous — but
    /// VoiceOver still gets one explicitly, since icon-only is a visual
    /// simplification, not an accessibility one.
    func deleteSwipeAction(action: @escaping () -> Void) -> some View {
        swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: action) {
                Image(systemName: "trash")
            }
            // The app sets a global white `.tint()` for the rest of its UI
            // (RootTabView), which otherwise cascades into this button and
            // overrides its automatic destructive red — pin it explicitly
            // rather than leave it to whatever tint happens to be ambient.
            .tint(MonetaColor.loss)
            .accessibilityLabel("Delete")
        }
    }
}
