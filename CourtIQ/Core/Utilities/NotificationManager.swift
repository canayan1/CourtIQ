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
    }

    private enum DefaultsKey {
        static let preAskShown = "CourtIQ.notifications.preAskShown"
        static let dailyEnabled = "CourtIQ.notifications.dailyEnabled"
        static let preferredHour = "CourtIQ.notifications.preferredHour"
        static let preferredMinute = "CourtIQ.notifications.preferredMinute"
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
    /// granted. Safe to call multiple times — OS only prompts once.
    func requestPermissionAndSchedule(hour: Int = 9, minute: Int = 0) async {
        markPreAskShown()
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            await refreshAuthorizationStatus()
            if granted {
                UserDefaults.standard.set(true, forKey: DefaultsKey.dailyEnabled)
                scheduleDailyReminder(hour: hour, minute: minute)
            }
        } catch {
            // Permission denied or system error — log only, don't block.
            print("[NotificationManager] requestAuthorization failed: \(error)")
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
                print("[NotificationManager] schedule failed: \(error)")
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

    /// Opens iOS Settings → CourtIQ so the user can flip notifications back on
    /// if they hard-denied earlier.
    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
