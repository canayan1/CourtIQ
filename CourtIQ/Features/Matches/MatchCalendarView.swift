import SwiftUI

/// The match-log view of the shared day grid: one mark per day the user
/// logged a match. Kept as its own type because Matches and Profile both
/// call it and neither should have to know about the journal's second
/// data source.
struct MatchCalendarView: View {
    @EnvironmentObject private var matches: MatchEntryManager
    @EnvironmentObject private var lang: LanguageManager

    var weeksToShow: Int = 7
    var onSelectDay: ((Date) -> Void)? = nil

    /// Built once per render rather than per cell. Keys are local-calendar
    /// days on both sides — see `JournalDay` for why the old UTC comparison
    /// ticked the wrong square east of UTC.
    private var playedDays: Set<String> {
        Set(matches.entries.filter { !$0.isDraft }.map { JournalDay.key($0.date) })
    }

    var body: some View {
        let played = playedDays
        DayGridCalendar(
            weeksToShow: weeksToShow,
            mark: { DayMark(match: played.contains(JournalDay.key($0))) },
            accessibility: { date, mark in
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                let suffix = mark.match ? lang.t("matches.calendar_logged") : lang.t("matches.calendar_not_logged")
                return "\(formatter.string(from: date)), \(suffix)"
            },
            onSelectDay: onSelectDay
        )
    }
}
