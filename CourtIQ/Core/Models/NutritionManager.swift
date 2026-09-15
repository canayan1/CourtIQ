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
    var id: String { rawValue }
    var labelKey: String { "nutrition.kind_\(rawValue)" }
    var symbol: String {
        switch self {
        case .practice: return "figure.tennis"
        case .match:    return "trophy"
        case .wall:     return "rectangle.portrait"
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
    var timing: NutritionTiming
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
    /// An unrated entry older than this is treated as abandoned — the player
    /// is not asked about a session from last week.
    private let ratingWindow: TimeInterval = 18 * 3600

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

    var ratedEntries: [NutritionEntry] { entries.filter(\.isRated) }

    /// Days with a log — logging fuel counts as doing something for the
    /// unified streak, like a quiz or a wall session.
    var activeDayKeys: Set<String> { Set(entries.map(\.dayKey)) }

    var insights: [NutritionInsight] { NutritionInsights.compute(ratedEntries) }

    // MARK: Mutations

    @discardableResult
    func log(kind: NutritionSessionKind, timing: NutritionTiming, meal: NutritionMealType?,
             hydration: NutritionHydration, caffeine: Bool, note: String?) -> NutritionEntry {
        let now = Date()
        let entry = NutritionEntry(
            id: UUID().uuidString, date: now, dayKey: now.todayKey,
            kind: kind, timing: timing, meal: timing == .nothing ? nil : meal,
            hydration: hydration, caffeine: caffeine,
            note: Self.clean(note),
            ratings: nil, ratedAt: nil, afterNote: nil)
        entries.insert(entry, at: 0)
        persist()
        AppAnalytics.shared.log(AnalyticsEvent.nutritionLogged, ["kind": kind.rawValue, "timing": timing.rawValue])
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

    private static func clean(_ text: String?) -> String? {
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(entries) { defaults.set(data, forKey: key) }
    }
}
