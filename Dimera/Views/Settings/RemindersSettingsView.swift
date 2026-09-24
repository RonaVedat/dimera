import SwiftUI
import UIKit

/// Three independent reminder toggles plus Quiet Hours, replacing the old
/// single "Upcoming payment reminders" row in Settings. Each toggle owns its
/// own `sync*()` call on `NotificationScheduler` — turning one off just flips
/// its `@AppStorage` bool and re-syncs, since every `sync*()` already checks
/// its own `enabled` flag and clears itself when false.
struct RemindersSettingsView: View {
    @EnvironmentObject private var store: FinanceStore

    @AppStorage(ReminderSettingsKey.dailyReviewEnabled) private var dailyReviewEnabled = false
    @AppStorage(ReminderSettingsKey.dailyReviewHour) private var dailyReviewHour = ReminderSettingsKey.defaultDailyReviewHour
    @AppStorage(ReminderSettingsKey.dailyReviewMinute) private var dailyReviewMinute = 0

    @AppStorage(ReminderSettingsKey.weeklyDigestEnabled) private var weeklyDigestEnabled = false
    @AppStorage(ReminderSettingsKey.weeklyDigestWeekday) private var weeklyDigestWeekday = ReminderSettingsKey.defaultWeeklyDigestWeekday

    @AppStorage(ReminderSettingsKey.renewalRemindersEnabled) private var renewalRemindersEnabled = false
    @AppStorage(ReminderSettingsKey.renewalLeadTimeDays) private var renewalLeadTimeDays = ReminderLeadTime.oneDay.rawValue

    @AppStorage(ReminderSettingsKey.quietHoursEnabled) private var quietHoursEnabled = false
    @AppStorage(ReminderSettingsKey.quietHoursStartHour) private var quietHoursStartHour = ReminderSettingsKey.defaultQuietHoursStart
    @AppStorage(ReminderSettingsKey.quietHoursEndHour) private var quietHoursEndHour = ReminderSettingsKey.defaultQuietHoursEnd

    @AppStorage(ReminderSettingsKey.spendingAlertEnabled) private var spendingAlertEnabled = false
    @AppStorage(ReminderSettingsKey.spendingAlertCategory) private var spendingAlertCategory = ""
    @AppStorage(ReminderSettingsKey.spendingAlertThresholdAmount) private var spendingAlertThresholdAmount = 0.0

    @State private var showPermissionDeniedAlert = false

    /// Built from `AppLanguage.current.locale`, not bare `Calendar.current`
    /// (device locale) — so weekday names follow the in-app language
    /// override too, not just the device's own language setting. A computed
    /// `var`, not `static let`, so it re-evaluates if the language changes.
    private static var weekdaySymbols: [String] {
        var calendar = Calendar.current
        calendar.locale = AppLanguage.current.locale
        return calendar.weekdaySymbols
    }

    var body: some View {
        List {
            routineSection
            contractsSection
            spendingAlertSection
            quietHoursSection
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Reminders")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Notifications are off", isPresented: $showPermissionDeniedAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Dimera needs permission to send reminders. Enable notifications for Dimera in Settings, then try again.")
        }
    }

    // MARK: - Routine

    private var routineSection: some View {
        Section {
            Toggle("Daily Spending Review", isOn: Binding(
                get: { dailyReviewEnabled },
                set: { enable($0, binding: $dailyReviewEnabled) { NotificationScheduler.shared.syncDailyReview() } }
            ))
            .tint(MonetaColor.accent)

            if dailyReviewEnabled {
                DatePicker("Time", selection: dailyReviewTime, displayedComponents: .hourAndMinute)
                    .onChange(of: dailyReviewHour) { _, _ in NotificationScheduler.shared.syncDailyReview() }
                    .onChange(of: dailyReviewMinute) { _, _ in NotificationScheduler.shared.syncDailyReview() }
            }

            Toggle("Weekly Financial Digest", isOn: Binding(
                get: { weeklyDigestEnabled },
                set: { enable($0, binding: $weeklyDigestEnabled) { NotificationScheduler.shared.syncWeeklyDigest() } }
            ))
            .tint(MonetaColor.accent)

            if weeklyDigestEnabled {
                Picker("Day", selection: $weeklyDigestWeekday) {
                    ForEach(1...7, id: \.self) { weekday in
                        Text(Self.weekdaySymbols[weekday - 1]).tag(weekday)
                    }
                }
                .onChange(of: weeklyDigestWeekday) { _, _ in NotificationScheduler.shared.syncWeeklyDigest() }
            }
        } header: {
            Text("Routine")
        } footer: {
            Text(routineFooter)
        }
    }

    private var routineFooter: String {
        var lines: [String] = []
        if dailyReviewEnabled {
            lines.append(String.localized("Reminds you to log today's spending at \(formattedTime(hour: dailyReviewHour, minute: dailyReviewMinute))."))
        }
        if weeklyDigestEnabled {
            lines.append(String.localized("Sends a weekly recap every \(Self.weekdaySymbols[weeklyDigestWeekday - 1]) at \(formattedTime(hour: ReminderSettingsKey.defaultWeeklyDigestHour, minute: 0))."))
        }
        if lines.isEmpty {
            lines.append(String.localized("Nudges to review your spending and see your week at a glance."))
        }
        return lines.joined(separator: " ")
    }

    // MARK: - Contracts

    private var contractsSection: some View {
        Section {
            Toggle("Upcoming Renewals & Bills", isOn: Binding(
                get: { renewalRemindersEnabled },
                set: { enable($0, binding: $renewalRemindersEnabled) { NotificationScheduler.shared.syncSchedule(with: store.recurring) } }
            ))
            .tint(MonetaColor.accent)

            if renewalRemindersEnabled {
                Picker("Remind me", selection: $renewalLeadTimeDays) {
                    ForEach(ReminderLeadTime.allCases) { leadTime in
                        Text(leadTime.title).tag(leadTime.rawValue)
                    }
                }
                .onChange(of: renewalLeadTimeDays) { _, _ in
                    NotificationScheduler.shared.syncSchedule(with: store.recurring)
                }
            }
        } header: {
            Text("Contracts")
        } footer: {
            let leadTime = ReminderLeadTime(rawValue: renewalLeadTimeDays) ?? .oneDay
            Text("A reminder \(leadTime.title) anything in Upcoming is due — bills and paychecks alike.")
        }
    }

    // MARK: - Spending Alert

    private var spendingAlertSection: some View {
        Section {
            Toggle("Spending Alert", isOn: Binding(
                get: { spendingAlertEnabled },
                set: { enable($0, binding: $spendingAlertEnabled) {} }
            ))
            .tint(MonetaColor.accent)
            .disabled(spendingAlertCategory.isEmpty)
        } header: {
            Text("Spending Alert")
        } footer: {
            if spendingAlertCategory.isEmpty {
                Text("Set a limit from the Insights tab to turn this on.")
            } else {
                let categoryName = TransactionCategory(rawValue: spendingAlertCategory)?.title ?? spendingAlertCategory
                Text("Notifies you once if \(categoryName) spending crosses \(Currency.string(Decimal(spendingAlertThresholdAmount))) this month.")
            }
        }
    }

    // MARK: - Quiet Hours

    private var quietHoursSection: some View {
        Section {
            Toggle("Quiet Hours", isOn: $quietHoursEnabled)
                .tint(MonetaColor.accent)
                .onChange(of: quietHoursEnabled) { _, _ in resyncRoutine() }

            if quietHoursEnabled {
                Picker("Start", selection: $quietHoursStartHour) {
                    ForEach(0..<24, id: \.self) { hour in
                        Text(formattedTime(hour: hour, minute: 0)).tag(hour)
                    }
                }
                .onChange(of: quietHoursStartHour) { _, _ in resyncRoutine() }

                Picker("End", selection: $quietHoursEndHour) {
                    ForEach(0..<24, id: \.self) { hour in
                        Text(formattedTime(hour: hour, minute: 0)).tag(hour)
                    }
                }
                .onChange(of: quietHoursEndHour) { _, _ in resyncRoutine() }
            }
        } footer: {
            if quietHoursEnabled {
                Text("Daily Review and Weekly Digest wait until \(formattedTime(hour: quietHoursEndHour, minute: 0)) if they'd otherwise fire between \(formattedTime(hour: quietHoursStartHour, minute: 0)) and \(formattedTime(hour: quietHoursEndHour, minute: 0)). Renewal reminders are unaffected.")
            } else {
                Text("Delays routine reminders until morning if they'd otherwise fire overnight.")
            }
        }
    }

    private func resyncRoutine() {
        NotificationScheduler.shared.syncDailyReview()
        NotificationScheduler.shared.syncWeeklyDigest()
    }

    // MARK: - Helpers

    private var dailyReviewTime: Binding<Date> {
        Binding(
            get: {
                var components = DateComponents()
                components.hour = dailyReviewHour
                components.minute = dailyReviewMinute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newDate in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                dailyReviewHour = components.hour ?? ReminderSettingsKey.defaultDailyReviewHour
                dailyReviewMinute = components.minute ?? 0
            }
        )
    }

    private func formattedTime(hour: Int, minute: Int) -> String {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let date = Calendar.current.date(from: components) ?? Date()
        return date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: AppLanguage.current.locale))
    }

    /// Toggling on requests permission first; toggling off just flips the
    /// flag. Either way, the matching `sync*()` runs afterward — it already
    /// checks its own `enabled` flag internally, so it self-clears when off.
    private func enable(_ newValue: Bool, binding: Binding<Bool>, sync: @escaping () -> Void) {
        if newValue {
            Task {
                let granted = await NotificationScheduler.shared.requestAuthorizationIfNeeded()
                if granted {
                    binding.wrappedValue = true
                    sync()
                } else {
                    binding.wrappedValue = false
                    showPermissionDeniedAlert = true
                }
            }
        } else {
            binding.wrappedValue = false
            sync()
        }
    }
}

#Preview {
    NavigationStack {
        RemindersSettingsView().environmentObject(FinanceStore())
    }
}
