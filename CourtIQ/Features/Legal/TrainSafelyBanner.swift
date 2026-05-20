import SwiftUI

/// Small persistent reminder shown at the top of any screen that prescribes
/// physical activity (training programs, mobility flows). Reinforces the
/// assumption-of-risk acknowledged on first launch without being intrusive.
struct TrainSafelyBanner: View {
    @EnvironmentObject private var lang: LanguageManager

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppPalette.clay)
                .frame(width: 24, alignment: .center)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(lang.t("health.banner_title"))
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .tracking(0.4)
                    .foregroundStyle(AppPalette.clay)

                Text(lang.t("health.banner_body"))
                    .font(.caption)
                    .foregroundStyle(AppPalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppPalette.clay.opacity(0.07))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppPalette.clay.opacity(0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
