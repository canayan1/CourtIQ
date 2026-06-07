import Foundation

/// Output of the deterministic compatibility scorer. Language-neutral:
/// it carries stable KEYS + ratings + recommendation slots, not display
/// strings, so the UI layer localizes (EN/TR) by key. This keeps the
/// scorer pure and identical on both devices.

enum CompatBand: String, Codable {
    case strong       // >= 80
    case workable     // 60...79
    case needsPlan    // < 60
}

enum DimensionRating: String, Codable {
    case green        // synergy / strength
    case yellow       // manageable / worth a note
    case red          // clash / liability
}

/// Which of the two players a recommendation refers to. `a` is the host /
/// the player whose device computed the result; `b` is the partner.
enum PlayerSlot: String, Codable {
    case a = "A"
    case b = "B"
}

/// Stable dimension identifiers (UI maps these to localized titles/notes).
enum DoublesDimension: String, Codable, CaseIterable {
    case courtSide
    case netBaseline
    case comms
    case pressure
    case formation
    case handedness
    case serve
}

enum StartingFormation: String, Codable {
    case bothUp              // both net-lovers
    case oneUpOneBackPoach   // balanced
    case startBackApproach   // both baseline-leaning
}

struct DimensionScore: Codable, Equatable {
    let dimension: DoublesDimension
    let rating: DimensionRating
    /// 0...1 contribution before weighting (kept for transparency/tests).
    let sub: Double
}

struct DoublesResult: Codable, Equatable {
    let score: Int                       // 0...100
    let band: CompatBand
    let dimensions: [DimensionScore]     // one per DoublesDimension, scored order

    // Derived team setup (not part of the score).
    let serveFirst: PlayerSlot
    let deuceReturner: PlayerSlot
    let adReturner: PlayerSlot
    let startingFormation: StartingFormation

    // Keys into the dimensions above, for the UI to surface as
    // "Strengths" (greens) and "Watch-outs" (reds/yellows), localized.
    let strengthKeys: [DoublesDimension]
    let watchOutKeys: [DoublesDimension]
}
