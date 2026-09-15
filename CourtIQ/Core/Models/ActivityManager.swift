import Foundation

/// The single, UNIFIED daily-habit streak. A day counts as "active" if the
/// player did *anything* that matters — a Tennis-IQ quiz, a logged match, a
/// court-tap drill, or a wall session. This fixes the old behaviour where the
/// Home streak read only the quiz manager, so someone who logged matches or hit
/// the wall every day still saw "0".
///
/// There is **no separate store and nothing to migrate**: it reads each
/// feature's own `activeDayKeys` (its existing source of truth) and unions
/// them, so the streak is always correct and can never drift from the data.
/// Same grace-day algorithm as the per-feature streaks so it feels consistent.
@MainActor
final class ActivityManager {
    static let shared = ActivityManager()
    private init() {}

    /// Every `Date.todayKey` on which the player did something that counts.
    var activeDays: Set<String> {
        var days = DailyQuizManager.shared.activeDayKeys
        days.formUnion(MatchEntryManager.shared.activeDayKeys)
        days.formUnion(CourtTapDrillManager.shared.activeDayKeys)
        days.formUnion(WallProgressManager.shared.activeDayKeys)
        days.formUnion(NutritionManager.shared.activeDayKeys)
        return days
    }

    var isActiveToday: Bool { activeDays.contains(Date.todayKey) }
    var currentStreak: Int { computation.streak }
    var streakGraceActive: Bool { computation.usedGrace }

    /// Active days within the trailing 7 days (for the "x/7 this week" pill).
    var completedThisWeek: Int {
        let days = activeDays
        let cal = Calendar.current
        return (0..<7).reduce(0) { acc, offset in
            guard let d = cal.date(byAdding: .day, value: -offset, to: Date()) else { return acc }
            return acc + (days.contains(d.todayKey) ? 1 : 0)
        }
    }

    /// Walks back from today (or yesterday if today isn't active yet) counting
    /// consecutive active days, tolerating exactly one missed "grace" day.
    private var computation: (streak: Int, usedGrace: Bool) {
        let days = activeDays
        let cal = Calendar.current
        var streak = 0
        var usedGrace = false
        var date = Date()

        if !days.contains(Date.todayKey) {
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: date) else {
                return (0, false)
            }
            date = yesterday
        }

        while true {
            if days.contains(date.todayKey) {
                streak += 1
                guard let previous = cal.date(byAdding: .day, value: -1, to: date) else { break }
                date = previous
            } else if !usedGrace && streak > 0 {
                usedGrace = true
                guard let previous = cal.date(byAdding: .day, value: -1, to: date) else { break }
                date = previous
            } else {
                break
            }
        }
        return (streak, usedGrace)
    }
}
