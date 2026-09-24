import Foundation

/// "How involved do you want to be?" — one onboarding decision that
/// configures the entire Reminders system at once, rather than making
/// someone answer four separate questions in Settings. Each tier maps onto
/// the reminder types that actually exist and fire (`ReminderSettingsKey`/
/// `NotificationScheduler`) — no fabricated "budget" or "goal" categories,
/// since this app deliberately has no budgets and Goals has no live data
/// to alert on yet.
enum ReminderPreset: String, CaseIterable, Identifiable {
    case minimal, balanced, pro

    var id: String { rawValue }

    var title: String {
        switch self {
        case .minimal: return String.localized("Minimal")
        case .balanced: return String.localized("Balanced")
        case .pro: return String.localized("Pro")
        }
    }

    var subtitle: String {
        switch self {
        case .minimal: return String.localized("Just the essentials.")
        case .balanced: return String.localized("A steady rhythm.")
        case .pro: return String.localized("Stay ahead of everything.")
        }
    }

    var systemImage: String {
        switch self {
        case .minimal: return "moon.zzz.fill"
        case .balanced: return "scale.3d"
        case .pro: return "bolt.fill"
        }
    }

    private var dailyReviewEnabled: Bool {
        switch self {
        case .minimal: return false
        case .balanced, .pro: return true
        }
    }

    private var leadTime: ReminderLeadTime {
        switch self {
        case .minimal: return .oneWeek
        case .balanced: return .threeDays
        case .pro: return .oneDay
        }
    }

    private var quietHoursEnabled: Bool {
        switch self {
        case .minimal, .balanced: return true
        case .pro: return false
        }
    }

    var bullets: [String] {
        var lines = [String.localized("Weekly summary"), String.localized("Renewal reminders \(leadTime.dueInPhrase)")]
        if dailyReviewEnabled {
            lines.insert(String.localized("Daily spending review"), at: 0)
        }
        if quietHoursEnabled {
            lines.append(String.localized("Quiet overnight"))
        }
        return lines
    }

    /// Writes every mapped setting, requests notification permission once,
    /// and re-syncs the scheduler. Uses `UserDefaults.standard` directly
    /// (not `@AppStorage`, since this runs from a plain model type) with the
    /// exact keys `RemindersSettingsView` reads, so Settings reflects the
    /// choice immediately if the user opens it later. A denied or skipped
    /// permission degrades silently — each `sync*()` call already checks its
    /// own permission state internally — this is a nice-to-have onboarding
    /// moment, not a decision that should block finishing setup.
    @MainActor
    func apply(recurring: [RecurringEntry]) async {
        let defaults = UserDefaults.standard
        defaults.set(dailyReviewEnabled, forKey: ReminderSettingsKey.dailyReviewEnabled)
        defaults.set(ReminderSettingsKey.defaultDailyReviewHour, forKey: ReminderSettingsKey.dailyReviewHour)
        defaults.set(0, forKey: ReminderSettingsKey.dailyReviewMinute)

        defaults.set(true, forKey: ReminderSettingsKey.weeklyDigestEnabled)
        defaults.set(ReminderSettingsKey.defaultWeeklyDigestWeekday, forKey: ReminderSettingsKey.weeklyDigestWeekday)

        defaults.set(true, forKey: ReminderSettingsKey.renewalRemindersEnabled)
        defaults.set(leadTime.rawValue, forKey: ReminderSettingsKey.renewalLeadTimeDays)

        defaults.set(quietHoursEnabled, forKey: ReminderSettingsKey.quietHoursEnabled)
        defaults.set(ReminderSettingsKey.defaultQuietHoursStart, forKey: ReminderSettingsKey.quietHoursStartHour)
        defaults.set(ReminderSettingsKey.defaultQuietHoursEnd, forKey: ReminderSettingsKey.quietHoursEndHour)

        _ = await NotificationScheduler.shared.requestAuthorizationIfNeeded()
        NotificationScheduler.shared.syncDailyReview()
        NotificationScheduler.shared.syncWeeklyDigest()
        NotificationScheduler.shared.syncSchedule(with: recurring)
    }
}
