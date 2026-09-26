import Foundation

/// The thing that leaves the app.
///
/// A share that gives away the answer is worth one read; a share that poses
/// the question is worth a reply. So what goes out is the scenario and a
/// week of squares — never which option was right, and never which one the
/// sender chose. The squares are the whole trick: they say *how the week
/// went* without saying anything about today, which is exactly why a Wordle
/// grid could be posted at nine in the morning without ruining anyone's day.
@MainActor
enum DailyOneShare {

    /// `correct` is deliberately not a parameter: today's result is already
    /// in the week strip, and nothing else in the text may depend on it.
    /// A default argument is evaluated outside the actor, so the store is
    /// read in the body rather than in the signature.
    static func text(pick: DailyOne.Pick, streak: Int, lang: LanguageManager,
                     state: DailyOneState? = nil, today: Date = Date()) -> String {
        let state = state ?? DailyOneStore.shared.state
        var lines: [String] = []

        lines.append("\(lang.t("dailyone.share_title")) · \(shortDate(today, lang: lang))")
        lines.append(week(state, today: today))
        if streak > 1 {
            lines.append(String(format: lang.t("dailyone.streak_fmt"), streak))
        }
        lines.append("")
        lines.append("\u{201C}\(pick.question.localizedScenario(for: lang.language))\u{201D}")
        lines.append("")
        lines.append(lang.t("dailyone.share_call"))
        lines.append(AppConfiguration.shareDestination)

        return lines.joined(separator: "\n")
    }

    /// Seven days, oldest first, today last. Played-and-right, played-and-
    /// wrong, and never played are three different things and the strip says
    /// which is which — a blank day is not a failure and should not look like
    /// one.
    static func week(_ state: DailyOneState, today: Date = Date()) -> String {
        (0..<7).reversed().map { back -> String in
            let key = DailyOne.dayKey(for: today.addingTimeInterval(-86_400 * Double(back)))
            guard let entry = state.entries[key] else { return "⬜️" }
            return entry.correct ? "🟩" : "🟥"
        }.joined()
    }

    private static func shortDate(_ date: Date, lang: LanguageManager) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: lang.language.rawValue)
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.setLocalizedDateFormatFromTemplate("dMMM")
        return f.string(from: date)
    }
}
