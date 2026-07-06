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
        // Drop any pending "add your result" reminder for this match.
        Task { @MainActor in
            NotificationManager.shared.cancelUpcomingMatchResultReminder(entryID: id)
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

    /// Every aggregate below reads from `committed` rather than `entries`
    /// so in-progress drafts never skew the user's real statistics. A
    /// draft defaults to a `.won` result, surface `.hard`, etc., so
    /// counting it would silently inflate win rate, totals, and streak.
    /// Drafts still live in `entries` so the list can surface them for
    /// editing or deletion.
    private var committed: [MatchEntry] { entries.filter { !$0.isDraft } }

    /// Distinct opponent names from logged matches, most-recent first — powers
    /// the "tap a recent opponent" chips so you rarely retype a name.
    var recentOpponents: [String] {
        var seen = Set<String>()
        var out: [String] = []
        for entry in committed.sorted(by: { $0.date > $1.date }) {
            let name = entry.opponentName.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty, seen.insert(name.lowercased()).inserted else { continue }
            out.append(name)
            if out.count >= 6 { break }
        }
        return out
    }

    /// Completed (played) non-draft matches that carry an actual result.
    /// This is the basis for every W/L / win-rate / streak / rating
    /// aggregate — upcoming (planned) matches are intentionally excluded so
    /// an unplayed match never skews real statistics.
    private var played: [MatchEntry] {
        committed.filter { $0.status == .completed && $0.result != nil }
    }

    /// Drafts only — used by the list to render a "resume / delete" row.
    var drafts: [MatchEntry] { entries.filter(\.isDraft) }

    /// Upcoming (planned) non-draft matches, newest-first.
    var upcoming: [MatchEntry] {
        committed.filter { $0.status == .upcoming }
    }

    var totalEntries: Int { committed.count }

    /// True once the user has 5+ entries with ratings — used to unlock the
    /// trend dashboard.
    /// Trend dashboard opens once the user has logged ANY 5 entries —
    /// not just rated ones. Full Journal entries currently have no
    /// in-UI rating affordance, so requiring `hasRatings` was silently
    /// locking out users who reflected via the long-form path. Chart
    /// rendering still skips rating-less entries internally; we just
    /// no longer hide the whole dashboard from journal-only users.
    var trendDashboardUnlocked: Bool {
        committed.count >= 5
    }

    /// Set of `dayKey` strings for which the user logged at least one
    /// entry. Used by the calendar view to highlight logged days.
    var loggedDayKeys: Set<String> {
        Set(committed.map(\.dayKey))
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
        let values = committed.compactMap { $0[keyPath: keyPath] }
        guard !values.isEmpty else { return nil }
        return Double(values.reduce(0, +)) / Double(values.count)
    }

    /// Average rating restricted to entries from the last `days` days.
    /// Useful for computing "last 30 days" vs "previous 30 days" deltas
    /// in the trend dashboard.
    func averageRating(_ keyPath: KeyPath<MatchEntry, Int?>,
                       inLast days: Int) -> Double? {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let values = committed
            .filter { $0.date >= cutoff }
            .compactMap { $0[keyPath: keyPath] }
        guard !values.isEmpty else { return nil }
        return Double(values.reduce(0, +)) / Double(values.count)
    }

    // MARK: - Richer insight aggregates (Trend dashboard v2)

    /// W-L-Win% summary across all entries. Used by the dashboard
    /// header card so users see a top-line read on their record.
    struct WinRateSummary: Equatable {
        let wins: Int
        let losses: Int
        var total: Int { wins + losses }
        /// 0..1, or nil if no entries.
        var ratio: Double? {
            guard total > 0 else { return nil }
            return Double(wins) / Double(total)
        }
    }

    var winRateSummary: WinRateSummary {
        let wins = played.filter { $0.result == .won }.count
        let losses = played.filter { $0.result == .lost }.count
        return WinRateSummary(wins: wins, losses: losses)
    }

    /// Per-surface breakdown: counts + win rate. Empty surfaces are
    /// included so the dashboard always shows the same row order.
    struct SurfaceBreakdown: Identifiable, Equatable {
        let surface: MatchSurface
        let wins: Int
        let losses: Int
        var id: String { surface.rawValue }
        var total: Int { wins + losses }
        var ratio: Double? {
            guard total > 0 else { return nil }
            return Double(wins) / Double(total)
        }
    }

    var surfaceBreakdown: [SurfaceBreakdown] {
        MatchSurface.allCases.map { surface in
            let group = played.filter { $0.surface == surface }
            let wins = group.filter { $0.result == .won }.count
            let losses = group.filter { $0.result == .lost }.count
            return SurfaceBreakdown(surface: surface, wins: wins, losses: losses)
        }
    }

    /// Average rating per dimension restricted to a single surface.
    /// Nil when no matches on that surface have rated the dimension.
    func averageRating(_ keyPath: KeyPath<MatchEntry, Int?>,
                       on surface: MatchSurface) -> Double? {
        let values = committed
            .filter { $0.surface == surface }
            .compactMap { $0[keyPath: keyPath] }
        guard !values.isEmpty else { return nil }
        return Double(values.reduce(0, +)) / Double(values.count)
    }

    /// "Last N vs prior N" momentum comparison for one rating
    /// dimension. Used by the dashboard's momentum card so users
    /// see whether their game is trending up or down recently.
    /// Returns nil when there aren't 2*N rated entries to compare.
    struct MomentumDelta: Equatable {
        let recent: Double
        let prior: Double
        var delta: Double { recent - prior }
    }

    func momentum(_ keyPath: KeyPath<MatchEntry, Int?>,
                  window: Int = 3) -> MomentumDelta? {
        // entries already sorted newest-first; compactMap rating values
        // in that order so "recent" = first N rated, "prior" = next N.
        let rated = committed.compactMap { entry -> Int? in entry[keyPath: keyPath] }
        guard rated.count >= window * 2 else { return nil }
        let recent = Array(rated.prefix(window))
        let prior = Array(rated.dropFirst(window).prefix(window))
        let recentAvg = Double(recent.reduce(0, +)) / Double(recent.count)
        let priorAvg = Double(prior.reduce(0, +)) / Double(prior.count)
        return MomentumDelta(recent: recentAvg, prior: priorAvg)
    }

    /// Top-N most-mentioned single-word themes in takeaway lines.
    /// Coach Mode and quick logs both feed into this — themes are the
    /// fastest read on what's stuck in the player's head across their
    /// matches.
    func topTakeawayThemes(limit: Int = 3) -> [(word: String, count: Int)] {
        // Tennis-domain stop words: filler that adds no signal even
        // though it appears often (TR + EN). Lowercased compare.
        let stop: Set<String> = [
            "ve", "ile", "için", "ben", "bu", "şu", "o", "a", "an", "the", "and",
            "to", "of", "in", "on", "at", "is", "was", "were", "have", "had",
            "did", "do", "i", "my", "me", "you", "your", "he", "she", "we",
            "they", "it", "be", "with", "for", "but", "or", "so", "than",
            "match", "maç", "set", "game", "gameplay", "play", "playing",
            "today", "bugun", "bugün", "çok", "cok", "iyi", "kötü", "kotu",
            "yine", "tekrar", "yeni", "bir", "daha", "ama", "olmadı", "oldu",
            "biraz", "kadar", "gibi", "her", "hep", "olarak", "gerek"
        ]
        var counts: [String: Int] = [:]
        for entry in committed {
            let words = entry.takeaway
                .lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty && $0.count >= 3 && !stop.contains($0) }
            for w in Set(words) {   // dedupe within one takeaway
                counts[w, default: 0] += 1
            }
        }
        return counts
            .map { (word: $0.key, count: $0.value) }
            .filter { $0.count >= 2 }   // need >=2 different matches mentioning it
            .sorted { $0.count > $1.count }
            .prefix(limit)
            .map { $0 }
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
