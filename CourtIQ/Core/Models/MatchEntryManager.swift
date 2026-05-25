import Foundation
import Combine

/// Owns the user's logged match history. Mirrors the storage pattern used
/// by `DailyQuizManager` and `TrainingProgressManager` (UserDefaults +
/// Codable JSON), so it slots into the existing manager architecture
/// without introducing a new persistence stack.
@MainActor
final class MatchEntryManager: ObservableObject {
    static let shared = MatchEntryManager()

    @Published private(set) var entries: [MatchEntry] = []

    private let defaultsKey = "CourtIQ.matchEntries.v1"
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.entries = Self.load(from: userDefaults, key: defaultsKey)
    }

    // MARK: - CRUD

    /// Insert a new entry or update an existing one (matched by `id`).
    func save(_ entry: MatchEntry) {
        let isNew = !entries.contains { $0.id == entry.id }
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
        } else {
            entries.append(entry)
        }
        entries.sort { $0.date > $1.date }
        persist()
        // Fan-out: avatar unlocks may depend on log streak + total matches.
        AvatarManager.shared.checkMilestones(
            logStreak: currentStreak,
            totalDrillsCompleted: CourtTapDrillManager.shared.sessions.count,
            totalMatches: totalEntries,
            tripleRingDays: TripleRingTracker.shared.count
        )
        // v1.1.C: an entry today means we don't need to nag the user
        // about logging today. The repeats:true rule keeps tomorrow's
        // nudge queued automatically.
        Task { @MainActor in
            NotificationManager.shared.cancelTodaysMatchLogNudgeIfLoggedAlready()
        }
        // Background hint to UI that the pre-ask sheet is now warranted
        // — the post-3rd-entry threshold avoids nagging brand-new users.
        if isNew && totalEntries == 3 {
            NotificationCenter.default.post(name: .courtiqShouldOfferNotificationPreAsk, object: nil)
        }
    }

    /// Remove an entry by id. Safe no-op if id is unknown. Also cleans
    /// up any attached voice notes and photos so orphaned media doesn't
    /// slowly fill the user's storage.
    func delete(_ id: String) {
        if let doomed = entries.first(where: { $0.id == id }) {
            MatchMediaStore.removeAudio(named: [
                doomed.preMatchAudioFile,
                doomed.postMatchAudioFile
            ])
            MatchMediaStore.removeAllPhotos(forEntry: doomed.id)
        }
        entries.removeAll { $0.id == id }
        persist()
    }

    func entry(withID id: String) -> MatchEntry? {
        entries.first { $0.id == id }
    }

    /// Wipe all entries. Used by the session-reset flow.
    func resetLocalData() {
        entries = []
        userDefaults.removeObject(forKey: defaultsKey)
    }

    // MARK: - Aggregations

    var totalEntries: Int { entries.count }
    var quickLogCount: Int { entries.filter(\.isQuickLog).count }
    var journalCount: Int { entries.filter { !$0.isQuickLog }.count }

    /// True once the user has 5+ entries with ratings — used to unlock the
    /// trend dashboard.
    /// Trend dashboard opens once the user has logged ANY 5 entries —
    /// not just rated ones. Full Journal entries currently have no
    /// in-UI rating affordance, so requiring `hasRatings` was silently
    /// locking out users who reflected via the long-form path. Chart
    /// rendering still skips rating-less entries internally; we just
    /// no longer hide the whole dashboard from journal-only users.
    var trendDashboardUnlocked: Bool {
        entries.count >= 5
    }

    /// Set of `dayKey` strings for which the user logged at least one
    /// entry. Used by the calendar view to highlight logged days.
    var loggedDayKeys: Set<String> {
        Set(entries.map(\.dayKey))
    }

    /// True if the user has logged at least one match today.
    var loggedToday: Bool {
        loggedDayKeys.contains(MatchEntry.dayKeyFormatter.string(from: Date()))
    }

    /// Current log streak — consecutive days with at least one logged
    /// match, walked backwards from today (or yesterday if today has no
    /// entry yet). Tolerates **one** missed day anywhere in the chain —
    /// the same grace-day pattern used for the daily-quiz streak. A
    /// second consecutive missed day breaks the streak.
    var currentStreak: Int {
        streakComputation.streak
    }

    var streakGraceActive: Bool {
        streakComputation.usedGrace
    }

    private var streakComputation: (streak: Int, usedGrace: Bool) {
        let logged = loggedDayKeys
        let calendar = Calendar(identifier: .iso8601)
        var streak = 0
        var usedGrace = false
        var date = Date()

        if !loggedToday {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: date) else {
                return (0, false)
            }
            date = yesterday
        }

        while true {
            let key = MatchEntry.dayKeyFormatter.string(from: date)
            if logged.contains(key) {
                streak += 1
                guard let previous = calendar.date(byAdding: .day, value: -1, to: date) else {
                    break
                }
                date = previous
            } else if !usedGrace && streak > 0 {
                usedGrace = true
                guard let previous = calendar.date(byAdding: .day, value: -1, to: date) else {
                    break
                }
                date = previous
            } else {
                break
            }
        }
        return (streak, usedGrace)
    }

    /// Average rating across all rated entries for a given dimension.
    /// `nil` when no entry has rated that dimension.
    func averageRating(_ keyPath: KeyPath<MatchEntry, Int?>) -> Double? {
        let values = entries.compactMap { $0[keyPath: keyPath] }
        guard !values.isEmpty else { return nil }
        return Double(values.reduce(0, +)) / Double(values.count)
    }

    /// Average rating restricted to entries from the last `days` days.
    /// Useful for computing "last 30 days" vs "previous 30 days" deltas
    /// in the trend dashboard.
    func averageRating(_ keyPath: KeyPath<MatchEntry, Int?>,
                       inLast days: Int) -> Double? {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let values = entries
            .filter { $0.date >= cutoff }
            .compactMap { $0[keyPath: keyPath] }
        guard !values.isEmpty else { return nil }
        return Double(values.reduce(0, +)) / Double(values.count)
    }

    // MARK: - Persistence

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        userDefaults.set(data, forKey: defaultsKey)
    }

    private static func load(from defaults: UserDefaults, key: String) -> [MatchEntry] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([MatchEntry].self, from: data)
        else {
            return []
        }
        return decoded.sorted { $0.date > $1.date }
    }
}
