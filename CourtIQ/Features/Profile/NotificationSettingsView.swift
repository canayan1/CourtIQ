import SwiftUI
import UserNotifications

/// Per-channel toggle screen for DropVolley's local notifications.
/// Shipped with v1.1.C alongside the match-log nudge + weekly digest;
/// also exposes the existing daily quiz reminder so users have one
/// place to manage everything.
///
/// The toggles read the manager's stored state and, when flipped on,
/// both schedule the notification AND make sure system permission is
/// granted (asks if needed). When the OS permission itself is denied,
/// the screen shows a banner pointing at iOS Settings rather than
/// quietly failing.
struct NotificationSettingsView: View {
    @EnvironmentObject private var lang: LanguageManager
    @ObservedObject private var notifications = NotificationManager.shared

    @State private var dailyOn = NotificationManager.shared.dailyReminderEnabled
    @State private var matchLogOn = NotificationManager.shared.matchLogNudgeEnabled
    @State private var weeklyOn = NotificationManager.shared.weeklyDigestEnabled

    var body: some View {
        Form {
            if notifications.authorizationStatus == .denied {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(lang.t("notif.settings.system_disabled"))
                            .font(.subheadline)
                        Button(lang.t("notif.settings.open_settings")) {
                            notifications.openSystemSettings()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppPalette.clay)
                    }
                    .padding(.vertical, 4)
                }
            }

            Section {
                toggleRow(
                    title: lang.t("notif.settings.daily_reminder"),
                    description: lang.t("notif.settings.daily_reminder_desc"),
                    isOn: $dailyOn,
                    enable: { notifications.scheduleDailyReminder() },
                    disable: { notifications.cancelDailyReminder() }
                )

                toggleRow(
                    title: lang.t("notif.settings.match_log"),
                    description: lang.t("notif.settings.match_log_desc"),
                    isOn: $matchLogOn,
                    enable: { notifications.scheduleMatchLogNudge() },
                    disable: { notifications.cancelMatchLogNudge() }
                )

                toggleRow(
                    title: lang.t("notif.settings.weekly"),
                    description: lang.t("notif.settings.weekly_desc"),
                    isOn: $weeklyOn,
                    enable: { notifications.scheduleWeeklyDigest() },
                    disable: { notifications.cancelWeeklyDigest() }
                )
            }
        }
        .navigationTitle(lang.t("notif.settings.title"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await notifications.refreshAuthorizationStatus()
        }
    }

    /// Shared row: title + description + toggle. When the toggle flips
    /// on we ensure permission first; flipping off cancels regardless
    /// of permission state.
    private func toggleRow(
        title: String,
        description: String,
        isOn: Binding<Bool>,
        enable: @escaping () -> Void,
        disable: @escaping () -> Void
    ) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(AppPalette.inkSoft)
            }
        }
        .tint(AppPalette.clay)
        .onChange(of: isOn.wrappedValue) { _, newValue in
            if newValue {
                Task {
                    // Request permission ONLY — no side-effect scheduling.
                    // Each toggle then schedules just its own channel via
                    // `enable()`, so turning on e.g. the match-log nudge
                    // never silently turns on (and schedules) the daily
                    // reminder too.
                    await notifications.requestPermission()
                    if notifications.authorizationStatus == .authorized {
                        enable()
                    } else {
                        isOn.wrappedValue = false
                    }
                }
            } else {
                disable()
            }
        }
    }
}
