import Foundation

struct BalancePoint: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    let value: Double
}

enum ChartPeriod: String, CaseIterable, Identifiable {
    case week = "1W"
    case month = "1M"
    case year = "1Y"
    case max = "Max"

    var id: String { rawValue }

    /// `rawValue` stays fixed (used as `Identifiable.id`); this is the
    /// localized label the segmented picker actually shows.
    var title: String {
        switch self {
        case .week: return String.localized("1W")
        case .month: return String.localized("1M")
        case .year: return String.localized("1Y")
        case .max: return String.localized("Max")
        }
    }

    var windowLabel: String {
        switch self {
        case .week: return String.localized("this week")
        case .month: return String.localized("this month")
        case .year: return String.localized("this year")
        case .max: return String.localized("since 2024")
        }
    }
}

enum BalanceHistorySampleData {
    /// Endpoints are fixed to today's real balance; intermediate values are
    /// hand-authored sample trends (not randomized) so the chart tells a
    /// consistent, plausible story on every launch.
    private static func series(valuesEndingToday values: [Double], spanDays: Int) -> [BalancePoint] {
        let cal = Calendar.current
        let count = values.count
        return values.enumerated().map { index, value in
            let daysBack = spanDays - Int(Double(spanDays) * Double(index) / Double(count - 1))
            let date = cal.date(byAdding: .day, value: -daysBack, to: Date()) ?? Date()
            return BalancePoint(date: date, value: value)
        }
    }

    static let week: [BalancePoint] = series(
        valuesEndingToday: [4610, 4550, 4690, 4720, 4680, 4790, 4750, 4820.50],
        spanDays: 7
    )

    static let month: [BalancePoint] = series(
        valuesEndingToday: [4480, 4390, 4520, 4610, 4560, 4700, 4650, 4610, 4520, 4600, 4710, 4780, 4740, 4790, 4820.50],
        spanDays: 30
    )

    static let year: [BalancePoint] = series(
        valuesEndingToday: [2900, 3120, 3080, 3340, 3260, 3510, 3680, 3920, 4080, 4260, 4510, 4820.50],
        spanDays: 365
    )

    static let max: [BalancePoint] = series(
        valuesEndingToday: [1400, 1680, 1950, 2260, 2540, 2980, 3350, 3760, 4180, 4820.50],
        spanDays: 900
    )

    static func points(for period: ChartPeriod) -> [BalancePoint] {
        switch period {
        case .week: return week
        case .month: return month
        case .year: return year
        case .max: return max
        }
    }
}

struct ForecastData {
    let past: [BalancePoint]
    let projected: [BalancePoint]
    let afterBills: Double
    let projectedDateLabel: String

    static let empty = ForecastData(past: [], projected: [], afterBills: 0, projectedDateLabel: "")
}
