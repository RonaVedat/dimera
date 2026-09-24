import UIKit

/// Thin wrapper around the three feedback generators. The Simulator has no
/// haptics hardware and its `hapticpatternlibrary.plist` genuinely doesn't
/// exist in that environment — harmless on a real device, but it floods the
/// console there, drowning out real errors while testing. No-op on
/// Simulator; unchanged behavior on device.
enum Haptics {
    static func selection() {
        #if !targetEnvironment(simulator)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        #if !targetEnvironment(simulator)
        UIImpactFeedbackGenerator(style: style).impactOccurred()
        #endif
    }

    static func success() {
        #if !targetEnvironment(simulator)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
}
