import Foundation
@preconcurrency import UserNotifications

/// Four independent local-reminder types, each opt-in on its own:
///
/// - **Renewals & bills** — the day (or lead time of your choosing) before
///   anything in Upcoming is due. Same idiom as Apple Card's bill reminders.
/// - **Daily Spending Review** — a repeating daily nudge to log today's
///   activity, at a time you set.
/// - **Weekly Financial Digest** — a repeating weekly recap, on a day you set.
/// - **Spending alert** — a lightweight, event-driven nudge the moment a
///   category's spend crosses a threshold you set. Not a budget: no cap,
///   no enforcement, no rollover, just a one-time notice.
///
/// Quiet Hours delays the two *routine* reminders (never the time-sensitive
/// renewal ones) rather than dropping them, and a lightweight same-minute
/// check nudges a renewal reminder a minute later if it would otherwise fire
/// in the same instant as the Daily Review. Permission is requested only
/// when a toggle is first turned on, never on launch, per HIG's "ask in
/// context" guidance — and nothing here ever hardcodes a timezone; every
/// trigger is built from `Calendar.current`, so it's correct wherever the
/// device currently is without a setting to get wrong.
@MainActor
final class NotificationScheduler {
    static let shared = NotificationScheduler()
    private init() {}

    private static let recurringPrefix = "moneta.recurring."
    private static let dailyReviewID = "moneta.dailyReview"
    private static let weeklyDigestID = "moneta.weeklyDigest"

    private let center = UNUserNotificationCenter.current()
    private var defaults: UserDefaults { .standard }

    // MARK: - Permission

    /// Call when a toggle is first turned on. Returns whether notifications
    /// can actually be scheduled — `false` means they denied (or previously
    /// denied) permission, so the caller can point to system Settings
    /// instead of silently doing nothing.
    func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        default:
            return false
        }
    }

    private func hasPermission() async -> Bool {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }

    // MARK: - Renewals & bills

    /// Re-syncs every scheduled renewal reminder against the current
    /// recurring list. Cheap enough to call after every add/edit/delete
    /// rather than diffing — there are only ever a handful of entries.
    func syncSchedule(with entries: [RecurringEntry]) {
        guard defaults.bool(forKey: ReminderSettingsKey.renewalRemindersEnabled) else {
            removeRequests(withPrefix: Self.recurringPrefix)
            return
        }
        Task {
            guard await hasPermission() else { return }
            removeRequests(withPrefix: Self.recurringPrefix)
            for entry in entries {
                scheduleRenewal(entry)
            }
        }
    }

    private func scheduleRenewal(_ entry: RecurringEntry) {
        let cal = Calendar.current
        let leadTime = ReminderLeadTime(
            rawValue: defaults.object(forKey: ReminderSettingsKey.renewalLeadTimeDays) as? Int ?? ReminderLeadTime.oneDay.rawValue
        ) ?? .oneDay

        guard let reminderDay = cal.date(byAdding: .day, value: -leadTime.rawValue, to: entry.nextDate) else { return }
        var components = cal.dateComponents([.year, .month, .day], from: reminderDay)
        components.hour = ReminderSettingsKey.defaultRenewalHour
        components.minute = 0

        // Best-effort overlap avoidance: if this would land in the exact
        // same minute as the Daily Review, nudge a minute later rather than
        // firing two notifications at once.
        if defaults.bool(forKey: ReminderSettingsKey.dailyReviewEnabled) {
            let reviewHour = defaults.object(forKey: ReminderSettingsKey.dailyReviewHour) as? Int ?? ReminderSettingsKey.defaultDailyReviewHour
            let reviewMinute = defaults.object(forKey: ReminderSettingsKey.dailyReviewMinute) as? Int ?? 0
            if components.hour == reviewHour && (components.minute ?? 0) == reviewMinute {
                components.minute = reviewMinute + 1
            }
        }

        guard let fireDate = cal.date(from: components), fireDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = entry.isIncome ? String.localized("Expected \(leadTime.dueInPhrase)") : String.localized("Due \(leadTime.dueInPhrase)")
        content.body = String.localized("\(entry.name) — \(Currency.string(entry.amount))")
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        center.add(UNNotificationRequest(
            identifier: Self.recurringPrefix + entry.id.uuidString,
            content: content,
            trigger: trigger
        ))
    }

    // MARK: - Daily Spending Review

    func syncDailyReview() {
        guard defaults.bool(forKey: ReminderSettingsKey.dailyReviewEnabled) else {
            removeRequests(withPrefix: Self.dailyReviewID)
            return
        }
        Task {
            guard await hasPermission() else { return }
            removeRequests(withPrefix: Self.dailyReviewID)

            let hour = adjustedForQuietHours(
                defaults.object(forKey: ReminderSettingsKey.dailyReviewHour) as? Int ?? ReminderSettingsKey.defaultDailyReviewHour
            )
            let minute = defaults.object(forKey: ReminderSettingsKey.dailyReviewMinute) as? Int ?? 0

            var components = DateComponents()
            components.hour = hour
            components.minute = minute

            let content = UNMutableNotificationContent()
            content.title = String.localized("Log today's spending")
            content.body = String.localized("A minute now keeps your dashboard honest.")
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            try? await center.add(UNNotificationRequest(identifier: Self.dailyReviewID, content: content, trigger: trigger))
        }
    }

    // MARK: - Weekly Financial Digest

    func syncWeeklyDigest() {
        guard defaults.bool(forKey: ReminderSettingsKey.weeklyDigestEnabled) else {
            removeRequests(withPrefix: Self.weeklyDigestID)
            return
        }
        Task {
            guard await hasPermission() else { return }
            removeRequests(withPrefix: Self.weeklyDigestID)

            let weekday = defaults.object(forKey: ReminderSettingsKey.weeklyDigestWeekday) as? Int
                ?? ReminderSettingsKey.defaultWeeklyDigestWeekday
            let hour = adjustedForQuietHours(ReminderSettingsKey.defaultWeeklyDigestHour)

            var components = DateComponents()
            components.weekday = weekday
            components.hour = hour
            components.minute = 0

            let content = UNMutableNotificationContent()
            content.title = String.localized("Your week, at a glance")
            content.body = String.localized("See what you saved, spent, and how your net worth moved.")
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            try? await center.add(UNNotificationRequest(identifier: Self.weeklyDigestID, content: content, trigger: trigger))
        }
    }

    // MARK: - Spending alert

    private static let spendingAlertID = "moneta.spendingAlert"

    /// The one event-driven reminder in this file — everything else above
    /// is calendar-scheduled ahead of time; this fires in direct response
    /// to a transaction crossing a threshold, checked by `FinanceStore`
    /// right after a spend is logged. Fires at most once per calendar
    /// month per category, guarded by `spendingAlertLastFiredMonth`, so a
    /// second qualifying expense doesn't re-notify.
    func checkSpendingAlert(category: String, currentTotal: Decimal, threshold: Decimal) {
        guard defaults.bool(forKey: ReminderSettingsKey.spendingAlertEnabled),
              defaults.string(forKey: ReminderSettingsKey.spendingAlertCategory) == category,
              threshold > 0, currentTotal >= threshold else { return }

        let monthKey = Self.monthKey(for: Date())
        guard defaults.string(forKey: ReminderSettingsKey.spendingAlertLastFiredMonth) != monthKey else { return }

        Task {
            guard await hasPermission() else { return }
            defaults.set(monthKey, forKey: ReminderSettingsKey.spendingAlertLastFiredMonth)

            // `category` is the raw stored key (TransactionCategory.rawValue,
            // always English) — mapped to its localized display name for
            // the notification text, same as everywhere else it's shown.
            let categoryName = TransactionCategory(rawValue: category)?.title ?? category

            let content = UNMutableNotificationContent()
            content.title = String.localized("\(categoryName) limit reached")
            content.body = String.localized("You've spent \(Currency.string(currentTotal)) on \(categoryName) this month — your limit was \(Currency.string(threshold)).")
            content.sound = .default

            try? await center.add(UNNotificationRequest(
                identifier: Self.spendingAlertID,
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            ))
        }
    }

    private static func monthKey(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)"
    }

    // MARK: - Contract reminder

    private static let contractReminderPrefix = "moneta.contractReminder."

    /// A custom, one-time reminder for a single contract — the date the
    /// user themselves chose, independent of the global renewal lead-time
    /// setting (`syncSchedule`), which still fires uniformly off every
    /// entry's own `nextDate`. This is one specific date for one specific
    /// contract, on top of that.
    func scheduleContractReminder(id: UUID, name: String, date: Date) {
        cancelContractReminder(id: id)
        guard date > Date() else { return }
        Task {
            guard await hasPermission() else { return }

            var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
            components.hour = ReminderSettingsKey.defaultRenewalHour
            components.minute = 0

            let content = UNMutableNotificationContent()
            content.title = String.localized("Contract Reminder")
            content.body = String.localized("You set a reminder for \(name) today.")
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            try? await center.add(UNNotificationRequest(
                identifier: Self.contractReminderPrefix + id.uuidString,
                content: content,
                trigger: trigger
            ))
        }
    }

    func cancelContractReminder(id: UUID) {
        removeRequests(withPrefix: Self.contractReminderPrefix + id.uuidString)
    }

    // MARK: - Quiet Hours

    /// If `hour` falls inside the quiet-hours window, returns the hour
    /// quiet hours end instead — a routine reminder waits, it doesn't get
    /// silently dropped. Renewal reminders never pass through this: they're
    /// time-sensitive, not routine, per the settings screen's own framing.
    private func adjustedForQuietHours(_ hour: Int) -> Int {
        guard defaults.bool(forKey: ReminderSettingsKey.quietHoursEnabled) else { return hour }
        let start = defaults.object(forKey: ReminderSettingsKey.quietHoursStartHour) as? Int
            ?? ReminderSettingsKey.defaultQuietHoursStart
        let end = defaults.object(forKey: ReminderSettingsKey.quietHoursEndHour) as? Int
            ?? ReminderSettingsKey.defaultQuietHoursEnd

        let inQuietHours = start > end
            ? (hour >= start || hour < end)   // wraps midnight, e.g. 22 -> 8
            : (hour >= start && hour < end)
        return inQuietHours ? end : hour
    }

    // MARK: - Cleanup

    private func removeRequests(withPrefix prefix: String) {
        center.getPendingNotificationRequests { [center] requests in
            let ids = requests.map(\.identifier).filter { $0.hasPrefix(prefix) }
            guard !ids.isEmpty else { return }
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }
}
