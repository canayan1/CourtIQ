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
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Name what is being rated. On a rest day the question is
                    // "how did the day feel", not "how did the session go".
                    Text(String(format: lang.t(entry.kind.didPlay ? "nutrition.rate_about_fmt"
                                                                  : "nutrition.rate_about_rest_fmt"),
                                dayLabel))
                        .font(.subheadline)
                        .foregroundStyle(AppPalette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)

                    NutritionRatingRows(ratings: $ratings)
                        .environmentObject(lang)

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
            .trackScreen("Nutrition Rate")
            // Re-rating starts from what was said last time, not from the
            // neutral defaults — otherwise correcting one row silently resets
            // the other three.
            .onAppear {
                guard !loaded else { return }
                loaded = true
                if let existing = entry.ratings { ratings = existing }
                if let existing = entry.afterNote { note = existing }
            }
        }
    }

    private var dayLabel: String {
        let cal = Calendar(identifier: .iso8601)
        if cal.isDateInToday(entry.date) { return lang.t("journal.day_today") }
        if cal.isDateInYesterday(entry.date) { return lang.t("journal.day_yesterday") }
        let f = DateFormatter()
        f.locale = Locale(identifier: lang.language.rawValue)
        f.setLocalizedDateFormatFromTemplate("EEEE d MMMM")
        return f.string(from: entry.date)
    }
}
