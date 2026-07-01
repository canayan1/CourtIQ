import SwiftUI

/// Soft pre-ask shown before the OS permission prompt. Apple's HIG strongly
/// suggests this pattern — a user who taps "Enable reminders" here is much
/// more likely to grant the OS prompt than one who gets cold-called.
struct NotificationPreAskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var lang: LanguageManager
    @ObservedObject private var notifications = NotificationManager.shared

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 24)

            ZStack {
                Circle()
                    .fill(AppPalette.clay.opacity(0.12))
                    .frame(width: 88, height: 88)
                Image(systemName: "bell.badge.fill")
                    .appFont(38, weight: .medium, design: .default)
                    .foregroundStyle(AppPalette.clay)
            }
            .padding(.bottom, 22)

            Text(lang.t("notif.permission.title"))
                .appFont(22, weight: .heavy)
                .foregroundStyle(AppPalette.ink)
                .multilineTextAlignment(.center)
                .padding(.bottom, 10)

            Text(lang.t("notif.permission.body"))
                .font(.subheadline)
                .foregroundStyle(AppPalette.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            VStack(spacing: 10) {
                Button(action: enableTapped) {
                    Text(lang.t("notif.permission.enable"))
                        .appFont(17, weight: .bold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppPalette.clay)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)

                Button(lang.t("notif.permission.later"), action: laterTapped)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppPalette.inkSoft)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 36)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppPalette.cream)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func enableTapped() {
        Task {
            await notifications.requestPermissionAndSchedule()
            dismiss()
        }
    }

    private func laterTapped() {
        notifications.markPreAskShown()
        dismiss()
    }
}
