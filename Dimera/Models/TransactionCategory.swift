import Foundation

/// The chip set offered when logging an expense — deliberately small and
/// jargon-free (one tap, no subcategories). A closed set keeps the
/// spending-by-category summary clean without needing NLP categorization,
/// the way a real bank-feed integration would provide it.
enum TransactionCategory: String, CaseIterable, Identifiable {
    case food = "Food"
    case transport = "Transport"
    case housing = "Housing"
    case shopping = "Shopping"
    case health = "Health"
    case entertainment = "Entertainment"
    case subscriptions = "Subscriptions"
    case other = "Other"

    var id: String { rawValue }

    /// The localized label shown in the UI — `rawValue` stays a fixed
    /// English key, since it's what's actually stored on `Transaction` and
    /// matched against elsewhere (Tax Radar, category totals); translating
    /// it directly would silently break every stored transaction's category
    /// the moment the app's language changed.
    var title: String {
        switch self {
        case .food: return String.localized("Food")
        case .transport: return String.localized("Transport")
        case .housing: return String.localized("Housing")
        case .shopping: return String.localized("Shopping")
        case .health: return String.localized("Health")
        case .entertainment: return String.localized("Entertainment")
        case .subscriptions: return String.localized("Subscriptions")
        case .other: return String.localized("Other")
        }
    }

    var systemImage: String {
        switch self {
        case .food: return "fork.knife"
        case .transport: return "tram"
        case .housing: return "house"
        case .shopping: return "bag"
        case .health: return "heart"
        case .entertainment: return "popcorn"
        case .subscriptions: return "arrow.triangle.2.circlepath"
        case .other: return "circle.grid.2x2"
        }
    }
}
