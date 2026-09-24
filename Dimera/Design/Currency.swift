import Foundation

/// Formats amounts in euros, grouping and decimal punctuation following the
/// app's current language (period-decimal for English/Chinese, comma-decimal
/// for German/French/Russian) — the currency itself stays EUR regardless of
/// language, since this app's own financial position is euro-denominated,
/// but *how a number reads* follows the reader, the way Revolut/N26 do it.
enum Currency {
    /// Rebuilt on every call rather than cached, since `AppLanguage` can
    /// change the effective locale at runtime without relaunching the app.
    private static func formatter() -> NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = AppLanguage.current.locale
        f.currencyCode = "EUR"
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }

    static func string(_ amount: Decimal) -> String {
        formatter().string(from: amount as NSDecimalNumber) ?? "€0.00"
    }

    static func signedString(_ amount: Decimal) -> String {
        let magnitude = string(abs(amount))
        return amount < 0 ? "-\(magnitude)" : magnitude
    }

    static func string(_ amount: Double) -> String {
        string(Decimal(amount))
    }
}
