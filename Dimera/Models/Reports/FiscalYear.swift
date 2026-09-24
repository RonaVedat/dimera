import Foundation

/// Computes the default tax-export date range from the device's actual
/// region (`Locale.current.region`, not `AppLanguage.current.locale` —
/// that's this app's own display-language override, a different setting
/// than "what tax year does my country use"). Most countries run a
/// calendar tax year; a small, deliberately conservative list of
/// well-established exceptions for personal income tax is handled
/// explicitly rather than guessed at.
enum FiscalYear {
    struct Range {
        let start: Date
        let end: Date
    }

    /// (month, day) the fiscal year starts on, 1-indexed month. Only
    /// includes exceptions that are unambiguous and well-documented —
    /// everything else (Germany, Spain, Greece, France, the US, and most
    /// of the world) is a calendar year.
    private static func startMonthDay(for regionCode: String?) -> (month: Int, day: Int) {
        switch regionCode {
        case "GB": return (4, 6) // UK: 6 April – 5 April
        case "AU": return (7, 1) // Australia: 1 July – 30 June
        case "NZ": return (4, 1) // New Zealand: 1 April – 31 March
        default: return (1, 1) // calendar year
        }
    }

    /// The most recently *completed* fiscal year as of today — the one
    /// someone is actually about to file for, not the still-in-progress
    /// current one.
    static func defaultRange(regionCode: String? = Locale.current.region?.identifier) -> Range {
        let calendar = Calendar(identifier: .gregorian)
        let (month, day) = startMonthDay(for: regionCode)
        let today = Date()
        let currentCalendarYear = calendar.component(.year, from: today)

        var components = DateComponents()
        components.year = currentCalendarYear
        components.month = month
        components.day = day
        let thisYearsStart = calendar.date(from: components) ?? today

        // Whichever fiscal-year start has already happened is the one
        // currently in progress; the completed year is one full period
        // before that.
        let currentPeriodStart = today >= thisYearsStart
            ? thisYearsStart
            : (calendar.date(byAdding: .year, value: -1, to: thisYearsStart) ?? thisYearsStart)
        let completedStart = calendar.date(byAdding: .year, value: -1, to: currentPeriodStart) ?? currentPeriodStart
        // One second before the next period starts — not one *day* before,
        // which would land at the start (00:00:00) of the last day rather
        // than its end, silently excluding that whole day's transactions
        // from a range filter that compares full `Date` values (date +
        // time-of-day), not just calendar dates.
        let completedEnd = calendar.date(byAdding: .second, value: -1, to: currentPeriodStart) ?? currentPeriodStart

        return Range(start: completedStart, end: completedEnd)
    }
}
