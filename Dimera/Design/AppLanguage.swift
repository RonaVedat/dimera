import SwiftUI

/// Lets someone pick Dimera's language independent of the device's system
/// language — the same convenience Revolut/N26 offer in their own Settings,
/// on top of (not instead of) standard iOS localization via the device's
/// own Language & Region setting. `.system` (the default) defers entirely
/// to iOS; picking an explicit language pins `.environment(\.locale)` at
/// the app root, which the whole view tree — and `Currency`'s number
/// formatting — reads from.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "System"
    case english = "en"
    case german = "de"
    case french = "fr"
    case russian = "ru"
    case chinese = "zh-Hans"
    case italian = "it"
    case portugueseBrazil = "pt-BR"
    case spanishSpain = "es"
    case spanishLatam = "es-419"
    case turkish = "tr"
    case indonesian = "id"

    var id: String { rawValue }

    /// Each language's own name for itself, not translated into whatever
    /// language is currently active — how every language picker in a
    /// serious app works, so you can always find your way back.
    var title: String {
        switch self {
        case .system: return "System"
        case .english: return "English"
        case .german: return "Deutsch"
        case .french: return "Français"
        case .russian: return "Русский"
        case .chinese: return "简体中文"
        case .italian: return "Italiano"
        case .portugueseBrazil: return "Português (Brasil)"
        case .spanishSpain: return "Español (España)"
        case .spanishLatam: return "Español (Latinoamérica)"
        case .turkish: return "Türkçe"
        case .indonesian: return "Bahasa Indonesia"
        }
    }

    /// A region is paired with each language (not just a bare language
    /// tag) so number grouping/decimal punctuation read naturally for a
    /// real audience, not a generic default.
    var locale: Locale {
        switch self {
        case .system: return .autoupdatingCurrent
        case .english: return Locale(identifier: "en_IE")
        case .german: return Locale(identifier: "de_DE")
        case .french: return Locale(identifier: "fr_FR")
        case .russian: return Locale(identifier: "ru_RU")
        case .chinese: return Locale(identifier: "zh_Hans_CN")
        case .italian: return Locale(identifier: "it_IT")
        case .portugueseBrazil: return Locale(identifier: "pt_BR")
        case .spanishSpain: return Locale(identifier: "es_ES")
        case .spanishLatam: return Locale(identifier: "es_419")
        case .turkish: return Locale(identifier: "tr_TR")
        case .indonesian: return Locale(identifier: "id_ID")
        }
    }

    static let storageKey = "appLanguage"

    /// Read directly from `UserDefaults`, not `@AppStorage` — needed from
    /// plain model code (`Currency`, date formatting) that isn't a View
    /// and doesn't need reactive updates, only the current value.
    static var current: AppLanguage {
        guard let raw = UserDefaults.standard.string(forKey: storageKey) else { return .system }
        return AppLanguage(rawValue: raw) ?? .system
    }
}
