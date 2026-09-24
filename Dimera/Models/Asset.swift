import Foundation

enum AssetKind: String, CaseIterable, Identifiable, Codable {
    case savings = "Savings"
    case investment = "Investment"
    case other = "Other"

    var id: String { rawValue }

    /// `rawValue` stays a fixed English key (it's `Codable`, persisted in
    /// `FinancialSnapshotStorage`); this is what the UI actually shows.
    var title: String {
        switch self {
        case .savings: return String.localized("Savings")
        case .investment: return String.localized("Investment")
        case .other: return String.localized("Other")
        }
    }

    var systemImage: String {
        switch self {
        case .savings: return "banknote"
        case .investment: return "chart.line.uptrend.xyaxis"
        case .other: return "shippingbox"
        }
    }
}

/// Something the user owns that isn't spendable cash — a savings account,
/// an ETF portfolio, crypto. Positive side of net worth, separate from
/// day-to-day cash flow.
struct Asset: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var value: Decimal
    var kind: AssetKind

    init(id: UUID = UUID(), name: String, value: Decimal, kind: AssetKind) {
        self.id = id
        self.name = name
        self.value = value
        self.kind = kind
    }
}

enum AssetSampleData {
    static var all: [Asset] {
        [
            Asset(name: String.localized("Savings account"), value: 850, kind: .savings),
            Asset(name: String.localized("ETF portfolio"), value: 1_820, kind: .investment)
        ]
    }
}
