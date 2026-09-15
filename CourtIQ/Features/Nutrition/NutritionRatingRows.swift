import SwiftUI

/// The four things a tennis player actually notices about fuel, each on a
/// 1–5 row. Shared by the post-session rating sheet and by the log sheet
/// when a past day is being filled in, so the same question never gets asked
/// two different ways.
struct NutritionRatingRows: View {
    @Binding var ratings: NutritionRatings
    @EnvironmentObject private var lang: LanguageManager

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            row(lang.t("nutrition.rate_energy"), $ratings.energy)
            row(lang.t("nutrition.rate_legs"), $ratings.legs)
            row(lang.t("nutrition.rate_focus"), $ratings.focus)
            row(lang.t("nutrition.rate_stomach"), $ratings.stomach)
        }
    }

    private func row(_ title: String, _ value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppPalette.ink)
                Spacer()
                Text(lang.t(value.wrappedValue <= 2 ? "nutrition.rate_low"
                            : value.wrappedValue >= 4 ? "nutrition.rate_high"
                            : "nutrition.hydration_ok"))
                    .font(.caption)
                    .foregroundStyle(AppPalette.inkSoft)
            }
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { n in
                    Button {
                        Haptics.tap()
                        value.wrappedValue = n
                    } label: {
                        Text("\(n)")
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .foregroundStyle(n == value.wrappedValue ? .white : AppPalette.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(n == value.wrappedValue ? AppPalette.clay : AppPalette.parchment,
                                        in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12)
                                .stroke(n == value.wrappedValue ? AppPalette.clay : AppPalette.sand, lineWidth: 1))
                    }
                    .buttonStyle(PressableCardStyle())
                    .accessibilityLabel("\(title) \(n)")
                }
            }
        }
    }
}
