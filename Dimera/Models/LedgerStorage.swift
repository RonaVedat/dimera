import Foundation

/// The user's real, live position — everything `FinancialSnapshot` doesn't
/// cover. `FinancialSnapshot` only ever holds the four onboarding numbers;
/// this is what actually survives a relaunch once the user starts using the
/// app for real. Same storage shape as `FinancialSnapshotStorage`, just a
/// second key, so a fresh install (nothing here yet) is indistinguishable
/// from "hasn't finished onboarding."
struct Ledger: Codable {
    var cash: Decimal
    var monthDelta: Decimal
    var assets: [Asset]
    var liabilities: [Liability]
    var transactions: [Transaction]
    var recurring: [RecurringEntry]
    var goals: [Goal]
}

enum LedgerStorage {
    private static let key = "ledgerV1"

    static var current: Ledger? {
        get {
            guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
            return try? JSONDecoder().decode(Ledger.self, from: data)
        }
        set {
            guard let newValue, let data = try? JSONEncoder().encode(newValue) else {
                UserDefaults.standard.removeObject(forKey: key)
                return
            }
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
