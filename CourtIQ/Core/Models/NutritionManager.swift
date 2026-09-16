import Foundation
import Combine

// MARK: - Model

/// What a player logs before they play and how they felt after. Kept
/// deliberately coarse — five timing buckets, five meal shapes, three
/// hydration levels — because the point is not a food diary, it is finding
/// out which of *these few choices* leave this player with better legs.
/// Coarse buckets are what make the insights computable from a handful of
/// sessions instead of hundreds.
///
/// Everything here stays on the device. Nothing is synced, nothing is sent
/// anywhere unless the player later opts in to sharing a summary with the
/// AI Coach (a later slice, and a separate switch).

enum NutritionSessionKind: String, Codable, CaseIterable, Identifiable {
    case practice, match, wall
    /// A day the player did not play. Worth logging: what you eat on a rest
    /// day is half of what you bring to the next one, and a rest day next to
    /// a flat session is exactly the comparison the insights are for.
    case rest
    var id: String { rawValue }
    var labelKey: String { "nutrition.kind_\(rawValue)" }
    var didPlay: Bool { self != .rest }
    var symbol: String {
        switch self {
        case .practice: return "figure.tennis"
        case .match:    return "trophy"
        case .wall:     return "rectangle.portrait"
        case .rest:     return "moon.zzz"
        }
    }
}

/// How long before playing the last real meal was.
enum NutritionTiming: String, Codable, CaseIterable, Identifiable {
    case under1h, h1to2, h2to3, over3h, nothing
    var id: String { rawValue }
    var labelKey: String { "nutrition.timing_\(rawValue)" }
}

/// The shape of that meal. One choice, on purpose: a multi-select produces
/// buckets too small to ever say anything.
enum NutritionMealType: String, Codable, CaseIterable, Identifiable {
    case carbHeavy, balanced, proteinHeavy, lightSnack, bigMeal
    var id: String { rawValue }
    var labelKey: String { "nutrition.meal_\(rawValue)" }
}

enum NutritionHydration: String, Codable, CaseIterable, Identifiable {
    case low, ok, high
    var id: String { rawValue }
    var labelKey: String { "nutrition.hydration_\(rawValue)" }
}

/// The four things a tennis player actually notices about fuel. 1–5 each.
struct NutritionRatings: Codable, Hashable {
    var energy: Int
    var legs: Int
    var focus: Int
    var stomach: Int

    /// The single number the insights compare. Equal weights: a player who
    /// felt light but cramped is not "fine on average", and the per-metric
    /// rows next to the headline make that visible.
    var composite: Double { Double(energy + legs + focus + stomach) / 4 }

    static let neutral = NutritionRatings(energy: 3, legs: 3, focus: 3, stomach: 3)
}

struct NutritionEntry: Codable, Identifiable, Hashable {
    let id: String
    var date: Date
    /// `Date.todayKey` of `date` — the unit the streak and the day list use.
    var dayKey: String
    var kind: NutritionSessionKind
    /// How long before playing the last meal was. Nil on a rest day, where
    /// there is no session to be early or late for — storing a timing there
    /// would put a number into the comparisons that means nothing.
    var timing: NutritionTiming?
    /// Nil when `timing == .nothing`.
    var meal: NutritionMealType?
    var hydration: NutritionHydration
    var caffeine: Bool
    var note: String?
    /// Filled in after the session. Nil = still waiting to be rated.
    var ratings: NutritionRatings?
    var ratedAt: Date?
    var afterNote: String?

    var isRated: Bool { ratings != nil }
}

// MARK: - Recall

/// The answers to reuse when the player says "same as last time". Deliberately
/// not the note: the note is about one specific meal and repeating it would be
/// putting words in their mouth.
struct NutritionRecall: Hashable {
    let kind: NutritionSessionKind
    let timing: NutritionTiming?
    let meal: NutritionMealType?
    let hydration: NutritionHydration
    let caffeine: Bool
}

// MARK: - Manager

/// Owns the on-device fuel log. Same shape as the other feature managers
/// (singleton + `@Published` + UserDefaults JSON), no remote sync by design.
@MainActor
final class NutritionManager: ObservableObject {
    static let shared = NutritionManager()

    /// Newest first.
    @Published private(set) var entries: [NutritionEntry] = []

    private let defaults = UserDefaults.standard
    private let key = "CourtIQ.Nutrition.Entries"
    /// How far back the app will chase an unanswered rating. Past this, an
    /// answer is a guess rather than a memory. The Journal uses the same
    /// number (`JournalDigest.recallDays`) so the two screens never disagree
    /// about whether an entry is still worth asking about.
    static let ratingWindowDays = 4
    private let ratingWindow: TimeInterval = TimeInterval(NutritionManager.ratingWindowDays) * 86_400

    private init() {
        if let data = defaults.data(forKey: key),
           let saved = try? JSONDecoder().decode([NutritionEntry].self, from: data) {
            entries = saved.sorted { $0.date > $1.date }
        }
    }

    // MARK: Derived

    /// The entry the app should be asking about right now: the newest one
    /// logged inside the rating window and not yet rated.
    var pendingRating: NutritionEntry? {
        entries.first { !$0.isRated && Date().timeIntervalSince($0.date) < ratingWindow }
    }

    /// The last thing the player answered before `date`, for "same as last
    /// time". Bounded by the day being logged: when filling in a day from
    /// three weeks ago, "last time" has to mean the entry before it, not one
    /// from this morning. Nil until there is one, so the button only appears
    /// when it can do something.
    func recall(before date: Date = .distantFuture) -> NutritionRecall? {
        guard let last = entries.first(where: { $0.date < date }) else { return nil }
        return NutritionRecall(kind: last.kind, timing: last.timing, meal: last.meal,
                               hydration: last.hydration, caffeine: last.caffeine)
    }

    /// Notes the player has actually written before, newest first and
    /// de-duplicated — offered as chips so a repeated breakfast is one tap.
    var recentNotes: [String] {
        var seen = Set<String>()
        return entries.compactMap(\.note).filter { seen.insert($0.lowercased()).inserted }.prefix(6).map { $0 }
    }

    /// Days with a log — logging fuel counts as doing something for the
    /// unified streak, like a quiz or a wall session.
    var activeDayKeys: Set<String> { Set(entries.map(\.dayKey)) }

    /// Only sessions the player actually played: the comparisons ask which
    /// pre-session choice left better legs, and a rest day has no session to
    /// answer for.
    var ratedSessions: [NutritionEntry] { entries.filter { $0.isRated && $0.kind.didPlay } }

    var insights: [NutritionInsight] { NutritionInsights.compute(ratedSessions) }

    /// How the last rated session went, in the three buckets the "what should
    /// I eat today?" picker uses. The log already knows this, so the picker
    /// should not make the player answer it again from memory. Nil until
    /// there is a rated session to read.
    var lastSessionFeel: NutritionLastSession? {
        guard let composite = ratedSessions.first?.ratings?.composite else { return nil }
        if composite <= 2.5 { return .flat }
        if composite >= 3.75 { return .great }
        return .ok
    }

    /// Rated days the player did not play. Kept out of the comparisons — a
    /// rest day has no session to answer for — but shown, because the app
    /// asked for them.
    var ratedRestDays: [NutritionEntry] { entries.filter { $0.isRated && !$0.kind.didPlay } }

    // MARK: Coach summary

    /// What the AI Coach is allowed to see when the player has switched
    /// sharing on: no raw log, no notes — averages, the comparisons that
    /// cleared the evidence bar, and the last five sessions in one line
    /// each. Kept under ~700 characters so it costs little per turn.
    var coachSummary: String? {
        let rated = ratedSessions
        guard let avg = NutritionInsights.averages(rated) else { return nil }
        var lines: [String] = []
        lines.append(String(format: "Fuel log, %d rated sessions. Averages out of 5 — energy %.1f, legs %.1f, focus %.1f, stomach %.1f.",
                            avg.count, avg.energy, avg.legs, avg.focus, avg.stomach))
        for i in insights.prefix(2) {
            lines.append(String(format: "%@: %@ averaged %.1f (n=%d) vs %@ %.1f (n=%d).",
                                Self.plain(i.dimension.labelKey), Self.plain(i.betterLabelKey), i.betterMean, i.betterCount,
                                Self.plain(i.worseLabelKey), i.worseMean, i.worseCount))
        }
        let recent = rated.prefix(5).map { e -> String in
            let r = e.ratings ?? .neutral
            let meal = e.meal.map { Self.plain($0.labelKey) } ?? "nothing"
            let timing = e.timing.map { Self.plain($0.labelKey) } ?? "rest day"
            return "\(Self.shortDate(e.date)) \(e.kind.rawValue): \(timing), \(meal), water \(e.hydration.rawValue)\(e.caffeine ? ", caffeine" : "") → \(r.energy)/\(r.legs)/\(r.focus)/\(r.stomach)"
        }
        if !recent.isEmpty { lines.append("Recent (energy/legs/focus/stomach): " + recent.joined(separator: "; ")) }
        return lines.joined(separator: "\n")
    }

    /// English labels for the prompt, independent of the app language.
    private static func plain(_ key: String) -> String {
        let table: [String: String] = [
            "nutrition.dim_timing": "Meal timing", "nutrition.dim_meal": "Meal type",
            "nutrition.dim_hydration": "Hydration", "nutrition.dim_caffeine": "Caffeine",
            "nutrition.timing_under1h": "under 1h before", "nutrition.timing_h1to2": "1–2h before",
            "nutrition.timing_h2to3": "2–3h before", "nutrition.timing_over3h": "3h+ before",
            "nutrition.timing_nothing": "nothing eaten",
            "nutrition.meal_carbHeavy": "carb-heavy", "nutrition.meal_balanced": "balanced",
            "nutrition.meal_proteinHeavy": "protein-heavy", "nutrition.meal_lightSnack": "light snack",
            "nutrition.meal_bigMeal": "big meal",
            "nutrition.hydration_low": "low water", "nutrition.hydration_ok": "normal water", "nutrition.hydration_high": "plenty of water",
            "nutrition.caffeine_yes": "with caffeine", "nutrition.caffeine_no": "no caffeine",
        ]
        return table[key] ?? key
    }

    private static func shortDate(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "d MMM"; f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: d)
    }

    // MARK: Mutations

    /// `date` is the day being logged, which is not always today: the journal
    /// calendar lets the player fill in a day they missed, exactly as the
    /// match log does. A past day is rated in the same sitting, so `ratings`
    /// may arrive with the entry rather than later.
    @discardableResult
    func log(kind: NutritionSessionKind, timing: NutritionTiming?, meal: NutritionMealType?,
             hydration: NutritionHydration, caffeine: Bool, note: String?,
             on date: Date = Date(), ratings: NutritionRatings? = nil,
             afterNote: String? = nil) -> NutritionEntry {
        let now = date
        let entry = NutritionEntry(
            id: UUID().uuidString, date: now, dayKey: now.todayKey,
            kind: kind, timing: timing, meal: timing == .nothing ? nil : meal,
            hydration: hydration, caffeine: caffeine,
            note: Self.clean(note),
            ratings: ratings, ratedAt: ratings == nil ? nil : now,
            afterNote: Self.clean(afterNote))
        entries.append(entry)
        entries.sort { $0.date > $1.date }
        persist()
        AppAnalytics.shared.log(AnalyticsEvent.nutritionLogged,
                                ["kind": kind.rawValue, "timing": timing?.rawValue ?? "none"])
        return entry
    }

    func rate(_ id: String, _ ratings: NutritionRatings, afterNote: String?) {
        guard let i = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[i].ratings = ratings
        entries[i].ratedAt = Date()
        entries[i].afterNote = Self.clean(afterNote)
        persist()
        AppAnalytics.shared.log(AnalyticsEvent.nutritionRated, ["composite": Int(ratings.composite.rounded())])
    }

    func delete(_ id: String) {
        entries.removeAll { $0.id == id }
        persist()
    }

    /// Account deletion: nothing survives on the device either.
    func resetLocalData() {
        entries = []
        defaults.removeObject(forKey: key)
        defaults.removeObject(forKey: "CourtIQ.Nutrition.RecipeAnswers")
        defaults.removeObject(forKey: "CourtIQ.Nutrition.ShareWithCoach")
        // The "what should I eat today?" picker remembers its answers now.
        defaults.removeObject(forKey: "CourtIQ.Nutrition.Today.Hours")
        defaults.removeObject(forKey: "CourtIQ.Nutrition.Today.Intensity")
        defaults.removeObject(forKey: "CourtIQ.Nutrition.Today.Heat")
    }

    private static func clean(_ text: String?) -> String? {
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(entries) { defaults.set(data, forKey: key) }
    }
}
