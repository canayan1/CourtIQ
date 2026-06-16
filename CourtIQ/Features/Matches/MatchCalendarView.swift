import SwiftUI

/// Compact 7-week calendar grid showing which days the user logged a
/// match. Used inside the Matches tab (and possibly the Profile tab) to
/// surface streak gaps and create the "log today to fill the dot"
/// motivation pattern Strava and Duolingo use.
///
/// Design rule: no labels. Just day cells, weekday letters across the
/// top, and color states that speak for themselves.
struct MatchCalendarView: View {
    @EnvironmentObject private var matches: MatchEntryManager
    @EnvironmentObject private var lang: LanguageManager

    /// How many trailing weeks to display, ending on today.
    var weeksToShow: Int = 7

    /// Fired when the user taps a day cell, passing that cell's date.
    /// Optional so existing call sites (e.g. Profile) keep working unchanged.
    var onSelectDay: ((Date) -> Void)? = nil

    private let calendar = Calendar(identifier: .iso8601)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Weekday header — 1-letter SUN-SAT row.
            HStack(spacing: 0) {
                ForEach(weekdayLetters, id: \.self) { letter in
                    Text(letter)
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .tracking(0.4)
                        .foregroundStyle(AppPalette.inkSoft)
                        .frame(maxWidth: .infinity)
                }
            }

            // Grid of weeks × 7 days.
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
        let key = MatchEntry.dayKeyFormatter.string(from: date)
        let logged = matches.loggedDayKeys.contains(key)
        let isToday = calendar.isDateInToday(date)
        let inFuture = date > Date()

        return ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(fillColor(logged: logged, isToday: isToday, inFuture: inFuture))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(
                            isToday ? AppPalette.clay : Color.clear,
                            lineWidth: 1.5
                        )
                )

            if logged {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .frame(height: 30)
        .accessibilityLabel(accessibilityLabel(date: date, logged: logged))
    }

    private func fillColor(logged: Bool, isToday: Bool, inFuture: Bool) -> Color {
        if logged { return AppPalette.clay }
        if inFuture { return AppPalette.sand.opacity(0.25) }
        if isToday { return AppPalette.sand.opacity(0.65) }
        return AppPalette.sand.opacity(0.45)
    }

    /// All dates for the grid — rows are weeks, last row ends on today.
    /// Order: oldest week first, today is in the last row.
    private func trailingDates() -> [Date] {
        let today = calendar.startOfDay(for: Date())
        // Find the weekday position of today within an iso8601 week
        // (Monday = 0, Sunday = 6).
        let weekday = (calendar.component(.weekday, from: today) + 5) % 7
        // Earliest date in grid: weeksToShow - 1 weeks before today's week start.
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
        // Locale-aware single-letter weekday symbols (Mon → Sun).
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: lang.language == .turkish ? "tr_TR" : "en_US")
        let veryShort = formatter.veryShortWeekdaySymbols ?? ["M", "T", "W", "T", "F", "S", "S"]
        // veryShortWeekdaySymbols is Sun-first; rotate to Mon-first.
        guard veryShort.count == 7 else { return ["M","T","W","T","F","S","S"] }
        return Array(veryShort.dropFirst()) + [veryShort.first ?? "S"]
    }

    private func accessibilityLabel(date: Date, logged: Bool) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let dateStr = formatter.string(from: date)
        let suffix = logged ? lang.t("matches.calendar_logged") : lang.t("matches.calendar_not_logged")
        return "\(dateStr), \(suffix)"
    }
}
