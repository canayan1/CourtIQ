import SwiftUI

/// The post-session rating: four 1–5 rows and an optional note. Defaults sit
/// at 3 so a player who felt "normal" can confirm in one tap; the sheet is
/// meant to take ten seconds on the way to the car.
struct NutritionRateSheet: View {
    let entry: NutritionEntry

    @EnvironmentObject private var lang: LanguageManager
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var manager = NutritionManager.shared

    @State private var ratings = NutritionRatings.neutral
    @State private var note = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ratingRow(lang.t("nutrition.rate_energy"), $ratings.energy)
                    ratingRow(lang.t("nutrition.rate_legs"), $ratings.legs)
                    ratingRow(lang.t("nutrition.rate_focus"), $ratings.focus)
                    ratingRow(lang.t("nutrition.rate_stomach"), $ratings.stomach)
                    TextField(lang.t("nutrition.after_placeholder"), text: $note, axis: .vertical)
                        .lineLimit(2...4)
                        .padding(12)
                        .background(AppPalette.parchment, in: RoundedRectangle(cornerRadius: 12))
                    PrimaryButton(title: lang.t("nutrition.save"), icon: "checkmark") {
                        manager.rate(entry.id, ratings, afterNote: note)
                        Haptics.celebrate()
                        dismiss()
                    }
                }
                .padding(20)
            }
            .background(AppPalette.cream)
            .navigationTitle(lang.t("nutrition.rate_title"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func ratingRow(_ title: String, _ value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppPalette.ink)
                Spacer()
                Text(lang.t(value.wrappedValue <= 2 ? "nutrition.rate_low" : value.wrappedValue >= 4 ? "nutrition.rate_high" : "nutrition.hydration_ok"))
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
