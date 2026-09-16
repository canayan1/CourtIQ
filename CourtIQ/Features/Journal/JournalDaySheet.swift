import SwiftUI

/// One day, opened from the calendar. Shows what is already written for that
/// day and offers to add the rest — which is the whole point of tapping a
/// square from three weeks ago.
struct JournalDaySheet: View {
    let date: Date
    var onLogFuel: (Date) -> Void
    var onLogMatch: (Date) -> Void
    var onRateFuel: (NutritionEntry) -> Void
    var onEditFuel: (NutritionEntry) -> Void
    var onOpenMatch: (MatchEntry) -> Void

    @EnvironmentObject private var lang: LanguageManager
    @EnvironmentObject private var matches: MatchEntryManager
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var nutrition = NutritionManager.shared

    private var items: [JournalItem] {
        JournalDigest(matches: matches.entries.filter { !$0.isDraft }, fuel: nutrition.entries)
            .items(on: date)
    }

    private var hasFuel: Bool {
        items.contains { if case .fuel = $0 { return true } else { return false } }
    }

    private var isFuture: Bool {
        Calendar(identifier: .iso8601).startOfDay(for: date) >
            Calendar(identifier: .iso8601).startOfDay(for: Date())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(title)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(AppPalette.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    if items.isEmpty {
                        Text(lang.t(isFuture ? "journal.day_empty_future" : "journal.day_empty"))
                            .font(.subheadline)
                            .foregroundStyle(AppPalette.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        ForEach(items) { item in
                            JournalItemRow(item: item,
                                           showsDate: false,
                                           onRateFuel: { entry in dismiss(); onRateFuel(entry) },
                                           onEditFuel: { entry in dismiss(); onEditFuel(entry) },
                                           onOpenMatch: { m in dismiss(); onOpenMatch(m) })
                                .environmentObject(lang)
                        }
                    }

                    VStack(spacing: 10) {
                        // A day that has not happened yet can hold a planned
                        // match but not a meal you have eaten.
                        if !isFuture {
                            // Naming the second one stops an accidental
                            // duplicate: two meals on a match day is real, two
                            // identical rows because you forgot is not.
                            PrimaryButton(title: lang.t(hasFuel ? "journal.add_another_meal" : "journal.add_fuel"),
                                          icon: "fork.knife") {
                                dismiss()
                                onLogFuel(date)
                            }
                        }
                        PrimaryButton(title: lang.t("journal.add_match"), icon: "figure.tennis",
                                      tint: AppPalette.mossDeep) {
                            dismiss()
                            onLogMatch(date)
                        }
                    }
                }
                .padding(20)
            }
            .background(AppPalette.cream)
            .navigationTitle(lang.t("journal.day_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(lang.t("common.done")) { dismiss() }
                        .foregroundStyle(AppPalette.clay)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var title: String {
        let cal = Calendar(identifier: .iso8601)
        if cal.isDateInToday(date) { return lang.t("journal.day_today") }
        if cal.isDateInYesterday(date) { return lang.t("journal.day_yesterday") }
        let f = DateFormatter()
        f.locale = Locale(identifier: lang.language.rawValue)
        f.setLocalizedDateFormatFromTemplate("EEEE d MMMM")
        return f.string(from: date)
    }
}
