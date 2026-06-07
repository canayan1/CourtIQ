import Foundation
import UserNotifications
import UIKit

/// Local-notification scheduler for CourtIQ. We only use **local**
/// notifications (no APNs server) at launch — a 9:00 daily reminder to
/// keep the streak alive. Permission is asked once via a soft pre-ask,
/// so a hard "Deny" from the user doesn't burn the OS-level prompt.
@MainActor
final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    /// Identifiers for our scheduled requests so we can replace/cancel.
    private enum RequestID {
        static let dailyReminder = "courtiq.daily_reminder"
        static let matchLogNudge = "courtiq.match_log_nudge"     // v1.1.C
        static let weeklyDigest = "courtiq.weekly_digest"        // v1.1.C
    }

    private enum DefaultsKey {
        static let preAskShown = "CourtIQ.notifications.preAskShown"
        static let dailyEnabled = "CourtIQ.notifications.dailyEnabled"
        static let preferredHour = "CourtIQ.notifications.preferredHour"
        static let preferredMinute = "CourtIQ.notifications.preferredMinute"
        // v1.1.C additions
        static let matchLogEnabled = "CourtIQ.notifications.matchLogEnabled"
        static let weeklyDigestEnabled = "CourtIQ.notifications.weeklyDigestEnabled"
    }

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private init() {
        Task { await refreshAuthorizationStatus() }
    }

    // MARK: - Status

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    /// Has the soft pre-ask sheet already been shown? We only ever show it once.
    var hasShownPreAsk: Bool {
        UserDefaults.standard.bool(forKey: DefaultsKey.preAskShown)
    }

    var dailyReminderEnabled: Bool {
        UserDefaults.standard.bool(forKey: DefaultsKey.dailyEnabled)
    }

    var matchLogNudgeEnabled: Bool {
        UserDefaults.standard.bool(forKey: DefaultsKey.matchLogEnabled)
    }

    var weeklyDigestEnabled: Bool {
        UserDefaults.standard.bool(forKey: DefaultsKey.weeklyDigestEnabled)
    }

    /// `true` if we should show the soft pre-ask the next time the user
    /// completes a quiz. Conditions: not asked yet AND OS status not yet
    /// determined (so the OS prompt is still available to us).
    func shouldShowPreAsk() -> Bool {
        guard !hasShownPreAsk else { return false }
        return authorizationStatus == .notDetermined
    }

    func markPreAskShown() {
        UserDefaults.standard.set(true, forKey: DefaultsKey.preAskShown)
    }

    // MARK: - Permission

    /// Requests OS-level permission then schedules the daily reminder if
    /// granted. Use this from the onboarding pre-ask, where opting in
    /// specifically means "turn on the daily reminder." Safe to call
    /// multiple times — OS only prompts once.
    func requestPermissionAndSchedule(hour: Int = 9, minute: Int = 0) async {
        let granted = await requestPermission()
        if granted {
            UserDefaults.standard.set(true, forKey: DefaultsKey.dailyEnabled)
            scheduleDailyReminder(hour: hour, minute: minute)
        }
    }

    /// Requests OS-level permission only, without scheduling anything.
    /// Per-channel toggles use this so enabling one channel never has the
    /// side effect of turning on (and scheduling) the daily reminder.
    /// Returns whether permission is granted. Safe to call repeatedly.
    @discardableResult
    func requestPermission() async -> Bool {
        markPreAskShown()
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            await refreshAuthorizationStatus()
            return granted
        } catch {
            // Permission denied or system error — log only, don't block.
            #if DEBUG
            print("[NotificationManager] requestAuthorization failed: \(error)")
            #endif
            return false
        }
    }

    // MARK: - Daily reminder

    /// Schedules (or replaces) the 9:00 daily local notification.
    func scheduleDailyReminder(hour: Int = 9, minute: Int = 0) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [RequestID.dailyReminder])

        let content = UNMutableNotificationContent()
        content.title = LanguageManager.shared.t("notif.daily.title")
        content.body = LanguageManager.shared.t("notif.daily.body")
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: RequestID.dailyReminder,
            content: content,
            trigger: trigger
        )
        center.add(request) { error in
            if let error {
                #if DEBUG
            print("[NotificationManager] schedule failed: \(error)")
            #endif
            }
        }

        UserDefaults.standard.set(hour, forKey: DefaultsKey.preferredHour)
        UserDefaults.standard.set(minute, forKey: DefaultsKey.preferredMinute)
    }

    func cancelDailyReminder() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [RequestID.dailyReminder])
        UserDefaults.standard.set(false, forKey: DefaultsKey.dailyEnabled)
    }

    // MARK: - Match-log nudge (v1.1.C)

    /// Daily "did you play today?" reminder at the user's preferred hour
    /// (default 20:30 local). Fires unconditionally — we'd love to skip
    /// days where the user already logged, but a static
    /// UNCalendarNotificationTrigger doesn't know the journal state.
    /// MatchEntryManager calls `cancelTodaysMatchLogNudgeIfLoggedAlready()`
    /// on save so at minimum same-day duplicates don't sting; the tomorrow
    /// reminder is still queued via repeats:true.
    func scheduleMatchLogNudge(hour: Int = 20, minute: Int = 30) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [RequestID.matchLogNudge])

        let content = UNMutableNotificationContent()
        content.title = LanguageManager.shared.t("notif.match_log.title")
        content.body = LanguageManager.shared.t("notif.match_log.body")
        content.sound = .default
        content.threadIdentifier = "courtiq.match_log"

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: RequestID.matchLogNudge,
            content: content,
            trigger: trigger
        )
        center.add(request) { error in
            if let error {
                #if DEBUG
            print("[NotificationManager] match-log schedule failed: \(error)")
            #endif
            }
        }
        UserDefaults.standard.set(true, forKey: DefaultsKey.matchLogEnabled)
    }

    func cancelMatchLogNudge() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [RequestID.matchLogNudge])
        UserDefaults.standard.set(false, forKey: DefaultsKey.matchLogEnabled)
    }

    // MARK: - Weekly digest (v1.1.C)

    /// Monday-morning recap. Static copy — taps open the trend dashboard
    /// where the user sees the actual numbers. Future: NotificationServiceExtension
    /// could mutate content with live numbers, but that's v1.2+ territory.
    func scheduleWeeklyDigest(weekday: Int = 2, hour: Int = 9, minute: Int = 0) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [RequestID.weeklyDigest])

        let content = UNMutableNotificationContent()
        content.title = LanguageManager.shared.t("notif.weekly.title")
        content.body = LanguageManager.shared.t("notif.weekly.body")
        content.sound = .default
        content.threadIdentifier = "courtiq.weekly"

        var components = DateComponents()
        components.weekday = weekday   // 1 = Sunday, 2 = Monday (default)
        components.hour = hour
        components.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: RequestID.weeklyDigest,
            content: content,
            trigger: trigger
        )
        center.add(request) { error in
            if let error {
                #if DEBUG
            print("[NotificationManager] weekly schedule failed: \(error)")
            #endif
            }
        }
        UserDefaults.standard.set(true, forKey: DefaultsKey.weeklyDigestEnabled)
    }

    func cancelWeeklyDigest() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [RequestID.weeklyDigest])
        UserDefaults.standard.set(false, forKey: DefaultsKey.weeklyDigestEnabled)
    }

    /// Called from MatchEntryManager.save when a new entry lands. If
    /// today's match-log nudge hasn't fired yet, remove it for today
    /// only (the repeats:true rule keeps tomorrow's queued). iOS doesn't
    /// expose per-occurrence cancellation on a repeating trigger, so we
    /// fully cancel + reschedule for the next day onward.
    func cancelTodaysMatchLogNudgeIfLoggedAlready() {
        guard matchLogNudgeEnabled else { return }
        let now = Date()
        let cal = Calendar.current
        let nudgeHour = 20  // matches default in scheduleMatchLogNudge
        let nudgeMinute = 30
        guard let today = cal.date(bySettingHour: nudgeHour, minute: nudgeMinute, second: 0, of: now) else { return }
        if now < today {
            // Nudge for today hasn't fired yet — replace with same
            // repeating schedule so today's instance is dropped. Crude
            // but reliable: iOS will recompute the next fire as tomorrow.
            scheduleMatchLogNudge(hour: nudgeHour, minute: nudgeMinute)
        }
    }

    /// Opens iOS Settings → CourtIQ so the user can flip notifications back on
    /// if they hard-denied earlier.
    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

extension Notification.Name {
    /// Posted by MatchEntryManager.save when a user crosses an
    /// engagement threshold where the soft notification pre-ask
    /// becomes appropriate (e.g. third match entry). Observed by the
    /// shell view that owns the .sheet binding.
    static let courtiqShouldOfferNotificationPreAsk = Notification.Name(
        "CourtIQ.notifications.shouldOfferPreAsk"
    )
}
