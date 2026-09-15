import SwiftUI

/// One calendar day, named in the player's own timezone.
///
/// The app has two older day-key conventions and they disagree by a day in
/// any timezone east of UTC: `MatchEntry.dayKey` formats the raw timestamp
/// in UTC, while `Date.todayKey` floors to local midnight *and then* formats
/// in UTC. The match calendar compared a local-midnight cell date against
/// raw-formatted entries, so in Dublin summer time a match played on the
/// 15th ticked the 16th's cell. The journal sidesteps both by deriving every
/// key from the timestamp in the local calendar, which is what a person
/// means when they point at a square and say "that day".
enum JournalDay {
    static func key(_ date: Date) -> String { formatter.string(from: date) }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

/// What one day cell has to say. A journal day can hold a match, a fuel
/// entry, or both, so the cell carries two independent marks rather than one
/// boolean — that is the whole reason this grid was pulled out of
/// `MatchCalendarView`, which only ever knew about matches.
struct DayMark: Hashable {
    /// A logged match. Drawn in clay, the app's primary colour.
    var match: Bool = false
    /// A logged fuel entry. Drawn in moss, so a day with both still reads as
    /// a match day with something extra rather than a third mystery colour.
    var fuel: Bool = false

    var isEmpty: Bool { !match && !fuel }
    static let none = DayMark()
}

/// Compact trailing-weeks calendar grid. No labels beyond the weekday
/// letters: cells, colours, and a tap target big enough to hit.
///
/// The caller decides what a day means (`mark`) and what a screen reader
/// should say about it (`accessibility`), which is what lets the same grid
/// serve the match log and the journal without either one guessing about the
/// other's data.
struct DayGridCalendar: View {
    @EnvironmentObject private var lang: LanguageManager

    /// How many trailing weeks to display, ending on the week containing today.
    var weeksToShow: Int = 7
    var mark: (Date) -> DayMark
    var accessibility: (Date, DayMark) -> String
    /// Fired when the user taps a day cell. Nil makes the grid read-only.
    var onSelectDay: ((Date) -> Void)? = nil

    private let calendar = Calendar(identifier: .iso8601)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 0) {
                ForEach(Array(weekdayLetters.enumerated()), id: \.offset) { _, letter in
                    Text(letter)
                        .appFont(10, weight: .heavy)
                        .tracking(0.4)
                        .foregroundStyle(AppPalette.inkSoft)
                        .frame(maxWidth: .infinity)
                }
            }

            let dates = trailingDates()
            VStack(spacing: 6) {
                ForEach(0..<weeksToShow, id: \.self) { week in
                    HStack(spacing: 6) {
                        ForEach(0..<7, id: \.self) { day in
                            let date = dates[week * 7 + day]
                            if let onSelectDay {
                                Button {
                                    Haptics.tap()
                                    onSelectDay(date)
                                } label: {
                                    dayCell(date: date)
                                }
                                .buttonStyle(.plain)
                                // Keep the 30pt visual but guarantee a ≥44pt
                                // tappable target via an invisible content shape.
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 44)
                                .contentShape(Rectangle())
                            } else {
                                dayCell(date: date)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func dayCell(date: Date) -> some View {
        let m = mark(date)
        let isToday = calendar.isDateInToday(date)
        let inFuture = date > Date()

        return ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(fillColor(mark: m, isToday: isToday, inFuture: inFuture))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(isToday ? AppPalette.clay : Color.clear, lineWidth: 1.5)
                )

            if m.match {
                Image(systemName: "checkmark")
                    .appFont(9, weight: .heavy)
                    .foregroundStyle(.white)
            } else if m.fuel {
                Image(systemName: "fork.knife")
                    .appFont(9, weight: .heavy)
                    .foregroundStyle(.white)
            }

            // A day that holds both gets the match fill plus a moss corner
            // dot: one glance says "played, and logged what I ate".
            if m.match && m.fuel {
                Circle()
                    .fill(AppPalette.mossDeep)
                    .overlay(Circle().stroke(AppPalette.parchment, lineWidth: 1.5))
                    .frame(width: 9, height: 9)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .offset(x: 2, y: 2)
            }
        }
        .frame(height: 30)
        .accessibilityLabel(accessibility(date, m))
    }

    private func fillColor(mark m: DayMark, isToday: Bool, inFuture: Bool) -> Color {
        if m.match { return AppPalette.clay }
        if m.fuel { return AppPalette.moss }
        if inFuture { return AppPalette.sand.opacity(0.25) }
        if isToday { return AppPalette.sand.opacity(0.65) }
        return AppPalette.sand.opacity(0.45)
    }

    /// All dates for the grid — rows are weeks, last row contains today.
    private func trailingDates() -> [Date] {
        let today = calendar.startOfDay(for: Date())
        // Weekday position of today within an iso8601 week (Monday = 0).
        let weekday = (calendar.component(.weekday, from: today) + 5) % 7
        let earliest = calendar.date(
            byAdding: .day,
            value: -(weekday + (weeksToShow - 1) * 7),
            to: today
        ) ?? today

        return (0..<(weeksToShow * 7)).compactMap {
            calendar.date(byAdding: .day, value: $0, to: earliest)
        }
    }

    private var weekdayLetters: [String] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: lang.language == .turkish ? "tr_TR" : "en_US")
        let veryShort = formatter.veryShortWeekdaySymbols ?? ["M", "T", "W", "T", "F", "S", "S"]
        // veryShortWeekdaySymbols is Sun-first; rotate to Mon-first.
        guard veryShort.count == 7 else { return ["M", "T", "W", "T", "F", "S", "S"] }
        return Array(veryShort.dropFirst()) + [veryShort.first ?? "S"]
    }
}
