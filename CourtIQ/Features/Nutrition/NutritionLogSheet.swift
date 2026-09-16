import SwiftUI

/// The fuel log: a handful of taps and an optional note. Single-choice chips
/// throughout, so every answer lands in a bucket the insights can count.
///
/// Two things make it a journal rather than a form. It accepts a `date`, so a
/// day tapped in the calendar three weeks ago can still be filled in — and
/// when that day is in the past the sheet asks how it went in the same
/// sitting, because there is no later left to ask in. And it can recall the
/// last set of answers, so a player whose pre-practice meal never changes
/// taps once instead of five times.
struct NutritionLogSheet: View {
    /// The day being logged. Defaults to now for the "log before you play"
    /// path; the journal passes the tapped day.
    var date: Date = Date()
    /// Non-nil when correcting an entry that already exists. The sheet then
    /// opens on that entry's answers and saves over it instead of adding a
    /// second row for the same meal.
    var editing: NutritionEntry? = nil

    @EnvironmentObject private var lang: LanguageManager
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var manager = NutritionManager.shared

    @State private var kind: NutritionSessionKind = .practice
    @State private var timing: NutritionTiming = .h1to2
    @State private var meal: NutritionMealType = .balanced
    @State private var hydration: NutritionHydration = .ok
    @State private var caffeine = false
    @State private var note = ""
    @State private var ratings = NutritionRatings.neutral
    /// Whether the player actually answered the four rows. The defaults sit
    /// at 3, so without this a quick backfill of last week would post three
    /// invented "3.0" sessions into the averages — and six of those are
    /// enough to make the app print a comparison nobody answered.
    @State private var ratedIt = false
    @State private var afterNote = ""
    @State private var recalled = false

    /// A past day is rated here and now. "Past" means an earlier calendar
    /// day, not merely an earlier hour: a session logged this morning is
    /// still rated this evening by the usual prompt. An edit never asks —
    /// the rating already exists and belongs to `rate`.
    private var isRetro: Bool {
        editing == nil && !Calendar(identifier: .iso8601).isDateInToday(date)
    }

    /// A rest day has no session to be early or late for, so the timing and
    /// meal-shape questions would be asking about nothing.
    private var playedThatDay: Bool { kind.didPlay }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if isRetro { retroHeader }
                    if editing == nil, let recall = manager.recall(before: date), !recalled {
                        recallButton(recall)
                    }

                    question(lang.t("nutrition.q_kind")) {
                        chips(NutritionSessionKind.allCases, selected: kind) { kind = $0 }
                    }
                    if playedThatDay {
                        question(lang.t(isRetro ? "nutrition.q_timing_past" : "nutrition.q_timing")) {
                            chips(NutritionTiming.allCases, selected: timing) { timing = $0 }
                        }
                    }
                    if !playedThatDay || timing != .nothing {
                        question(lang.t(playedThatDay ? "nutrition.q_meal" : "nutrition.q_meal_rest")) {
                            chips(NutritionMealType.allCases, selected: meal) { meal = $0 }
                        }
                    }
                    question(lang.t(isRetro ? "nutrition.q_hydration_past" : "nutrition.q_hydration")) {
                        chips(NutritionHydration.allCases, selected: hydration) { hydration = $0 }
                    }
                    question(lang.t(isRetro ? "nutrition.q_caffeine_past" : "nutrition.q_caffeine")) {
                        HStack(spacing: 8) {
                            chip(lang.t("nutrition.caffeine_yes"), selected: caffeine) { caffeine = true }
                            chip(lang.t("nutrition.caffeine_no"), selected: !caffeine) { caffeine = false }
                        }
                    }

                    noteField

                    if isRetro { retroRatings }

                    PrimaryButton(title: lang.t("nutrition.save"), icon: "checkmark") {
                        if let editing {
                            manager.update(id: editing.id, kind: kind,
                                           timing: playedThatDay ? timing : nil,
                                           meal: (playedThatDay && timing == .nothing) ? nil : meal,
                                           hydration: hydration, caffeine: caffeine,
                                           note: note, on: editing.date)
                            Haptics.success()
                            dismiss()
                            return
                        }
                        manager.log(kind: kind,
                                    timing: playedThatDay ? timing : nil,
                                    meal: (playedThatDay && timing == .nothing) ? nil : meal,
                                    hydration: hydration, caffeine: caffeine, note: note,
                                    on: date,
                                    ratings: (isRetro && ratedIt) ? ratings : nil,
                                    afterNote: isRetro ? afterNote : nil)
                        Haptics.success()
                        dismiss()
                    }
                }
                .padding(20)
            }
            .background(AppPalette.cream)
            .navigationTitle(lang.t(editing == nil ? "journal.add_fuel" : "nutrition.edit_title"))
            .navigationBarTitleDisplayMode(.inline)
            .trackScreen(editing == nil ? "Nutrition Log" : "Nutrition Edit")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(lang.t("common.cancel")) { dismiss() }
                        .foregroundStyle(AppPalette.inkSoft)
                }
            }
            // An edit opens on what is already there.
            .onAppear {
                guard let e = editing, !recalled else { return }
                recalled = true            // also suppresses the recall card
                kind = e.kind
                if let t = e.timing { timing = t } else if !e.kind.didPlay { timing = .h1to2 }
                if let m = e.meal { meal = m }
                hydration = e.hydration
                caffeine = e.caffeine
                note = e.note ?? ""
            }
            #if DEBUG
            // Headless QC: SIMCTL_CHILD_QC_FUEL_KIND=rest opens straight on a
            // day the player did not play, which is the short form of this
            // sheet and the one that shows the rating card without scrolling.
            .onAppear {
                if let raw = ProcessInfo.processInfo.environment["QC_FUEL_KIND"],
                   let k = NutritionSessionKind(rawValue: raw) { kind = k }
            }
            #endif
        }
    }

    // MARK: Retroactive day

    private var retroHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar")
                .foregroundStyle(AppPalette.clay)
            Text(String(format: lang.t("nutrition.logging_for_fmt"), longDate))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppPalette.parchment, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// The follow-up, asked inline because the day is already over.
    private var retroRatings: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(lang.t(playedThatDay ? "nutrition.q_how_was_it" : "nutrition.q_how_was_it_rest"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
            // Optional on purpose. Leaving it blank saves the meal and
            // nothing else, which is the honest record of a day you can
            // remember eating but not how it felt.
            Text(lang.t("nutrition.rate_optional"))
                .font(.footnote)
                .foregroundStyle(AppPalette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            NutritionRatingRows(ratings: $ratings, onAnswer: { ratedIt = true })
                .environmentObject(lang)
            TextField(lang.t("nutrition.after_placeholder"), text: $afterNote, axis: .vertical)
                .lineLimit(2...4)
                .padding(12)
                .background(AppPalette.parchment, in: RoundedRectangle(cornerRadius: 12))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(fill: AppPalette.goldTint.opacity(0.45), stroke: AppPalette.gold.opacity(0.35), cornerRadius: 16)
    }

    // MARK: Recall

    /// Fills every chip from the last entry. Never the note — that was about
    /// one specific meal, and repeating it would put words in the player's
    /// mouth.
    private func recallButton(_ recall: NutritionRecall) -> some View {
        Button {
            Haptics.tap()
            kind = recall.kind
            if let t = recall.timing { timing = t }
            if let m = recall.meal { meal = m }
            hydration = recall.hydration
            caffeine = recall.caffeine
            recalled = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "arrow.uturn.backward")
                    .foregroundStyle(AppPalette.clay)
                VStack(alignment: .leading, spacing: 2) {
                    Text(lang.t("nutrition.same_as_last"))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppPalette.ink)
                    Text(recallSummary(recall))
                        .font(.caption)
                        .foregroundStyle(AppPalette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 6)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardSurface(cornerRadius: 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableCardStyle())
    }

    /// Only what was actually answered last time. The card used to read
    /// "Didn't play · 1–2 hours ago" after a rest day, which is a meal
    /// timing for a day with no session.
    private func recallSummary(_ r: NutritionRecall) -> String {
        [lang.t(r.kind.labelKey),
         r.timing.map { lang.t($0.labelKey) },
         r.meal.map { lang.t($0.labelKey) },
         lang.t(r.hydration.labelKey)]
            .compactMap { $0 }.joined(separator: " · ")
    }

    // MARK: Note

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(lang.t("nutrition.note_placeholder"), text: $note, axis: .vertical)
                .lineLimit(2...4)
                .padding(12)
                .background(AppPalette.parchment, in: RoundedRectangle(cornerRadius: 12))
            // Notes the player has written before. A breakfast that repeats
            // becomes one tap instead of one more piece of typing.
            let recents = manager.recentNotes
            if !recents.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(recents, id: \.self) { previous in
                        chip(previous, selected: note == previous) { note = previous }
                    }
                }
            }
        }
    }

    // MARK: Chrome

    private var longDate: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: lang.language.rawValue)
        f.setLocalizedDateFormatFromTemplate("EEEE d MMMM")
        return f.string(from: date)
    }

    private func question<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
            content()
        }
    }

    private func chips<T: Identifiable & Hashable>(_ options: [T], selected: T,
                                                   pick: @escaping (T) -> Void) -> some View where T: RawRepresentable, T.RawValue == String {
        FlowLayout(spacing: 8) {
            ForEach(options) { option in
                chip(lang.t(labelKey(option)), selected: option == selected) { pick(option) }
            }
        }
    }

    private func labelKey<T: RawRepresentable>(_ option: T) -> String where T.RawValue == String {
        switch option {
        case let k as NutritionSessionKind: return k.labelKey
        case let t as NutritionTiming:
            return (isRetro && t == .nothing) ? "nutrition.timing_nothing_past" : t.labelKey
        case let m as NutritionMealType:    return m.labelKey
        case let h as NutritionHydration:   return h.labelKey
        default: return option.rawValue
        }
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(selected ? .white : AppPalette.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(selected ? AppPalette.clay : AppPalette.parchment, in: Capsule())
                .overlay(Capsule().stroke(selected ? AppPalette.clay : AppPalette.sand, lineWidth: 1))
        }
        .buttonStyle(PressableCardStyle())
    }
}
