import Foundation

// MARK: - Tactical categories
//
// CourtIQ's Daily Court Drill measures six distinct flavours of
// tactical decision-making. Every drill in `court_tap_drills.json`
// belongs to exactly one category (via the `category` field). As the
// user works through drills over time, their per-category running
// average becomes their "tactical profile" — a 0–5 score per
// dimension that says "you're good at X, weak at Y".
//
// The profile feeds three surfaces:
//   • Profile → Tactical Insights card (radar / bar chart UI)
//   • AI Coach context (so the coach can reference numbers)
//   • Future v1.x → adaptive drill selection (over-serve the weakest
//     category when the user opens today's session)
//
// Why six and not more / fewer:
//   - Fewer than 5 hides real signal (everything collapses to
//     "you're balanced").
//   - More than 7 dilutes signal because most users never play enough
//     drills to fill all buckets — half show "no data".
//   - Six aligns with the actual decision archetypes that show up in
//     bundled drill content and in coaching literature.

enum TacticalCategory: String, CaseIterable, Identifiable, Codable {
    case openCourt = "open_court"
    case defense   = "defense"
    case approach  = "approach"
    case patterns  = "patterns"
    case netGame   = "net_game"
    case `return`  = "return"

    var id: String { rawValue }

    /// Best-effort key for a localisable display name. Localisation
    /// strings live under `drill.cat.<rawValue>` in the bundle.
    var localizationKey: String { "drill.cat.\(rawValue)" }

    /// One-line description of what this category measures. Also
    /// localisable; used in the AI Coach context block + the
    /// Tactical Insights card tooltip.
    var summaryKey: String { "drill.cat.\(rawValue).summary" }

    /// Fallback for any drill that decodes without a category field
    /// (older JSON, hand-crafted entries during dev).
    static let fallback: TacticalCategory = .patterns
}

// MARK: - Profile aggregation

/// Per-category snapshot of the user's drill performance. A score is
/// only non-nil when the user has at least one tap in that category;
/// the count tells the UI how much data backs the number so it can
/// fade a fresh / sparse category to a "needs more reps" affordance.
struct TacticalProfileEntry: Equatable, Identifiable {
    let category: TacticalCategory
    /// 0...5 rating, nil when no drills attempted in this category yet.
    let score: Double?
    /// How many drill taps fed this score. < 3 = still sparse.
    let sampleCount: Int

    var id: String { category.rawValue }

    /// Convenience read for "is this category established yet" — three
    /// or more taps is the threshold we use before the AI Coach is
    /// allowed to assert "your <category> is weak".
    var isEstablished: Bool { sampleCount >= 3 }
}

extension TacticalProfileEntry {
    /// Default "no data" entry for a category the user hasn't seen yet.
    static func empty(_ category: TacticalCategory) -> TacticalProfileEntry {
        TacticalProfileEntry(category: category, score: nil, sampleCount: 0)
    }
}
