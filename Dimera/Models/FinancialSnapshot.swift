import Foundation

/// The four numbers captured by first-time setup ("Let's create your
/// financial picture"). Persisted so the user's position survives a
/// relaunch even before full ledger persistence exists.
struct FinancialSnapshot: Codable, Equatable {
    var cash: Decimal
    var savings: Decimal
    var investments: Decimal
    var debt: Decimal
}

enum FinancialSnapshotStorage {
    private static let key = "financialSnapshot"

    static var current: FinancialSnapshot? {
        get {
            guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
            return try? JSONDecoder().decode(FinancialSnapshot.self, from: data)
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
