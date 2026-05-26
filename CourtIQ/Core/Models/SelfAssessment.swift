import Foundation

// MARK: - Self assessment
//
// First-time-launch psychometric baseline. The user rates themselves
// 1-5 across the six TacticalCategory dimensions before any drill
// or quiz signal exists. The AI Coach + Profile card use this as
// a "baseline profile" until enough real performance data
// accumulates to override it (≥3 samples in a category).
//
// Why we keep this AND the drill/quiz signal:
//   • Drill / quiz signal is OBJECTIVE (did the user pick the right
//     answer?) but slow to accumulate. A user with 3 days of play
//     has rich signal on 1-2 categories, sparse on the others.
//   • Self-assessment is SUBJECTIVE (what does the user think their
//     own game looks like?) but instant. Useful both as a baseline
//     and as a delta indicator — when the objective score later
//     diverges sharply from the self-rating, the AI Coach can call
//     that out ("you rated your defence 4/5 but it's actually
//     showing as 2.3/5 across your real reps — let's tighten it").

/// User-rated 1-5 score per TacticalCategory. Persisted in
/// UserDefaults so it survives reinstalls when the cache migrates.
struct SelfAssessment: Codable, Equatable {
    /// Per-category 1-5 rating. Map raw values are
    /// `TacticalCategory.rawValue` strings; missing keys are
    /// treated as "not rated".
    var scoresByCategory: [String: Int]
    /// When the user completed (or last updated) the assessment.
    var completedAt: Date

    /// Default empty assessment — all categories nil.
    static let empty = SelfAssessment(scoresByCategory: [:], completedAt: Date())

    /// Returns the 1-5 score for a category, nil if not rated.
    func score(for category: TacticalCategory) -> Int? {
        scoresByCategory[category.rawValue]
    }

    /// True when the user has rated at least 4 of the 6 categories.
    /// Used as the "is this assessment usable" gate.
    var isComplete: Bool {
        scoresByCategory.count >= 4
    }
}

// MARK: - Storage

/// Thin singleton wrapper around UserDefaults so the assessment is
/// reachable from anywhere without an environment object — the
/// Profile card, the AI Coach context builder, and the onboarding
/// flow all read/write the same row.
@MainActor
final class SelfAssessmentStore {
    static let shared = SelfAssessmentStore()
    private let key = "CourtIQ.SelfAssessment.v1"
    private let defaults = UserDefaults.standard

    private init() {}

    func load() -> SelfAssessment? {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(SelfAssessment.self, from: data)
        else { return nil }
        return decoded
    }

    func save(_ assessment: SelfAssessment) {
        guard let data = try? JSONEncoder().encode(assessment) else { return }
        defaults.set(data, forKey: key)
    }

    /// Wipe — used by the session-reset / account-delete flows.
    func reset() {
        defaults.removeObject(forKey: key)
    }
}
