import Foundation

/// How far ahead of a due date the Upcoming Renewals & Bills reminder fires.
/// Deliberately three options, not a free-form day picker — enough control
/// to matter (a week's notice to cancel a gym membership vs. a day's notice
/// for a subscription) without turning this into a scheduling app.
enum ReminderLeadTime: Int, CaseIterable, Identifiable {
    case oneDay = 1
    case threeDays = 3
    case oneWeek = 7

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .oneDay: return String.localized("1 day before")
        case .threeDays: return String.localized("3 days before")
        case .oneWeek: return String.localized("1 week before")
        }
    }

    /// For notification copy: "Due in 1 day" / "Due in 3 days" / "Due in 1 week".
    var dueInPhrase: String {
        switch self {
        case .oneDay: return String.localized("in 1 day")
        case .threeDays: return String.localized("in 3 days")
        case .oneWeek: return String.localized("in 1 week")
        }
    }
}

/// Flat UserDefaults-backed keys for the Reminders settings screen — same
/// pattern as `appearanceMode`/`paymentRemindersEnabled` elsewhere: no
/// Codable struct, just plain values `@AppStorage` and `NotificationScheduler`
/// both read directly, so the two never need to be kept in sync by hand.
enum ReminderSettingsKey {
    static let dailyReviewEnabled = "dailyReviewEnabled"
    static let dailyReviewHour = "dailyReviewHour"
    static let dailyReviewMinute = "dailyReviewMinute"

    static let weeklyDigestEnabled = "weeklyDigestEnabled"
    static let weeklyDigestWeekday = "weeklyDigestWeekday" // 1 = Sunday ... 7 = Saturday

    static let renewalRemindersEnabled = "paymentRemindersEnabled" // existing key, kept as-is
    static let renewalLeadTimeDays = "renewalLeadTimeDays"

    static let quietHoursEnabled = "quietHoursEnabled"
    static let quietHoursStartHour = "quietHoursStartHour"
    static let quietHoursEndHour = "quietHoursEndHour"

    // Sensible, opinionated defaults — evening for a same-day recap, Sunday
    // morning for a week-in-review, business hours for anything you might
    // need to act on.
    static let defaultDailyReviewHour = 20
    static let defaultWeeklyDigestWeekday = 1 // Sunday
    static let defaultWeeklyDigestHour = 9
    static let defaultRenewalHour = 9
    static let defaultQuietHoursStart = 22
    static let defaultQuietHoursEnd = 8
}
