import SwiftUI

/// Compact streak indicator for the Matches tab. Mirrors the streak-pill
/// language used elsewhere in the app (snowflake when grace day is in
/// play) but at a smaller, badge-y scale that fits inline next to other
/// stats.
struct LogStreakBadge: View {
    let value: Int
    let graceActive: Bool

    @EnvironmentObject private var lang: LanguageManager

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(AppPalette.clay.opacity(0.12))
                    .frame(width: 56, height: 56)

                VStack(spacing: 0) {
                    Text("\(value)")
                        .appFont(22, weight: .heavy)
                        .foregroundStyle(AppPalette.clay)
                        .monospacedDigit()
                    if graceActive {
                        Image(systemName: "snowflake")
                            .appFont(8, weight: .bold, design: .default)
                            .foregroundStyle(AppPalette.clay)
                    }
                }
            }

            Text(lang.t("matches.streak_label"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppPalette.inkSoft)
                .textCase(.uppercase)
                .tracking(0.6)
        }
        .frame(width: 70)
    }
}
