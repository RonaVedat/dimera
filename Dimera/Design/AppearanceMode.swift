import SwiftUI

/// Dimera is dark-first by design — the Trade Republic-style identity this
/// whole app is built around — but HIG expects every app to let people
/// override that. Defaults to `.dark` regardless of the system setting;
/// `.system` opts back into following the device.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }

    /// `rawValue` stays fixed (persisted via `@AppStorage`); this is the
    /// localized label the segmented picker actually shows.
    var title: String {
        switch self {
        case .system: return String.localized("System")
        case .light: return String.localized("Light")
        case .dark: return String.localized("Dark")
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var systemImage: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }
}
