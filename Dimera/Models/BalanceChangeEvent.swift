import Foundation

/// A timestamped record of a balance-sheet mutation — an asset or liability
/// being added, changed, or removed. This is what a plain net-worth delta
/// can't distinguish on its own: a €25,000 car loan and a €25,000 bad
/// spending month move the same chart line by the same amount, but they are
/// not the same kind of event. Real transactions already carry their own
/// date via `Transaction`, so only the balance-sheet side needed a new,
/// deliberately small log — not a new transaction model, not a database.
struct BalanceChangeEvent: Identifiable, Hashable, Codable {
    enum Kind: String, Codable {
        case assetAdded, assetChanged, assetRemoved
        case liabilityAdded, liabilityChanged, liabilityRemoved
    }

    let id: UUID
    let date: Date
    /// The asset/liability's name at the time of the change.
    let label: String
    let kind: Kind
    /// Signed net-worth impact — matches the delta already passed into
    /// `FinanceStore.registerNetWorthChange` at the call site, never
    /// recomputed separately.
    let delta: Decimal

    init(id: UUID = UUID(), date: Date = Date(), label: String, kind: Kind, delta: Decimal) {
        self.id = id
        self.date = date
        self.label = label
        self.kind = kind
        self.delta = delta
    }
}
