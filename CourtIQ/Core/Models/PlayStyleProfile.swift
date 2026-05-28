import Foundation

// MARK: - Play style profile
//
// Where TacticalProfile reads the user's *accuracy* per category,
// PlayStyleProfile reads their *preferences*. As the user works
// through Daily Drills they're not just being scored — every shot
// type they pick is a vote for "this is how I see tennis". Over
// 20-30 drills the votes converge into a play-style fingerprint:
// topspin-heavy vs flat-aggressive vs slice-and-dice vs all-court.
//
// The AI Coach reads this fingerprint and can say things like
// "You're a 73% topspin player — on hard court you should flatten
//  out more, you're not getting through the ball when you need to."
// That's a level of personalization a generic LLM can't replicate
// without the data.

/// Counts + percentages of each shot type the user has chosen across
/// every drill they've ever completed.
struct PlayStyleProfile: Equatable {
    /// Total number of v2 drill taps (drills with a shot-type axis).
    let totalShots: Int

    /// Counts per shot type — preserved alongside percentages so the
    /// UI can render confidence as well as preference.
    let counts: [ShotType: Int]

    /// Percentages 0–1, sum to 1 across all shot types with data.
    let percentages: [ShotType: Double]

    /// Accuracy rate (0–1): of all shot-type choices, how many were
    /// the ideal (or acceptable) call for the scenario. Distinct
    /// from preference — a user could prefer slice 60% of the time
    /// and still be 80% correct because slice is often the right call
    /// when they pick it.
    let shotTypeAccuracy: Double?

    /// Coarse-grained label derived from preference distribution.
    /// Used by the AI Coach to anchor a one-line player archetype
    /// ("you play like a counter-puncher").
    let archetype: PlayStyleArchetype?

    static let empty = PlayStyleProfile(
        totalShots: 0,
        counts: [:],
        percentages: [:],
        shotTypeAccuracy: nil,
        archetype: nil
    )
}

/// Six coarse archetypes the profile can map to. The thresholds are
/// deliberately wide — most rec players don't land cleanly in one
/// bucket until 20-30 drills in, so we keep `nil` (unclassified) as
/// a normal state during early use. A label is only assigned once the
/// user has logged 30+ shot-type votes (see CourtTapDrillManager) so
/// the archetype reflects a stable pattern, not early noise.
enum PlayStyleArchetype: String, Codable {
    case topspinBaseliner      // ≥55% topspin
    case flatAggressor         // ≥45% flat
    case sliceArtist           // ≥30% slice (high for tennis)
    case allCourt              // mix with no single shot ≥40%
    case netRusher             // ≥20% drop + lob combined
    case defensiveCounter      // ≥40% topspin + ≥20% slice

    /// Lookup key for the localizable display string.
    var localizationKey: String { "drill.archetype.\(rawValue)" }

    /// One-sentence description (localizable) that the Coach can pull
    /// when explaining the user's classification.
    var summaryKey: String { "drill.archetype.\(rawValue).summary" }

    /// Classify a percentage map into the most-fitting archetype.
    /// Order matters — we test the most specific patterns first
    /// (defensive counter, net rusher) before the broad ones.
    static func classify(_ p: [ShotType: Double]) -> PlayStyleArchetype? {
        let top = p[.topspin] ?? 0
        let flat = p[.flat] ?? 0
        let slice = p[.slice] ?? 0
        let drop = p[.drop] ?? 0
        let lob = p[.lob] ?? 0

        if drop + lob >= 0.20 { return .netRusher }
        if top >= 0.40 && slice >= 0.20 { return .defensiveCounter }
        if slice >= 0.30 { return .sliceArtist }
        if top >= 0.55 { return .topspinBaseliner }
        if flat >= 0.45 { return .flatAggressor }
        // Mixed distribution — no single shot dominant.
        if top < 0.40 && flat < 0.40 && slice < 0.30 {
            return .allCourt
        }
        return nil
    }
}
