import Foundation

/// The personal Tennis Profile self-assessment. Grounded in the USTA NTRP
/// descriptor-based self-rating method (level from background + a plain-language
/// self-placement, with an upward nudge because players reliably UNDER-rate
/// themselves), NTRP stroke dimensions, and TSQT-style tactical/mental items.
/// Pure value types — no UI deps — so the scorer is deterministic and testable.

// MARK: - Answers

/// How long the player has played. Anchors a minimum level (USTA Experienced
/// Player guidance: background sets a floor).
enum TennisExperience: String, Codable, CaseIterable {
    case justStarting      // weeks / first lessons
    case underOneYear
    case oneToThreeYears
    case threeToTenYears
    case tenPlusYears
}

enum PlayFrequency: String, Codable, CaseIterable {
    case rarely            // a few times a year
    case monthly
    case weekly
    case twiceThrice       // 2–3× / week
    case fourPlus          // 4+ / week
}

/// Match / competitive experience — a strong level signal.
enum MatchExperience: String, Codable, CaseIterable {
    case never             // only hitting, no matches
    case socialHits        // casual hits, occasional points
    case casualMatches     // friendly matches
    case leagueMatches     // club / league
    case tournaments
}

/// Plain-language NTRP self-placement (the descriptor the player most
/// identifies with). Mapped to an NTRP band in the scorer.
enum LevelSelfPlacement: String, Codable, CaseIterable {
    case learningBasics    // ~1.5–2.0  — getting the ball in play
    case keepRallyGoing    // ~2.5      — slow rally, inconsistent in matches
    case consistentMedium  // ~3.0      — medium-pace rallies, lacks control/depth
    case dependableDirected// ~3.5      — dependable strokes, direction, lobs, net
    case depthControlSpin  // ~4.0      — reliable with depth, control, some pace/spin
}

/// One of the six NTRP stroke/movement dimensions, self-rated 1–5.
enum TennisDimension: String, Codable, CaseIterable, Identifiable {
    case forehand
    case backhand
    case serve
    case ret               // return ("return" is reserved)
    case net               // volleys / net play
    case movement          // footwork, court coverage, recovery
    var id: String { rawValue }
}

/// TSQT-style response under pressure (decision-making + composure).
enum PressureResponse: String, Codable, CaseIterable {
    case rushErrors        // go for too much, make errors
    case playSafe          // get tentative / just keep it in
    case patientPick       // stay patient, pick the right moment
    case goForIt           // back myself, hit through it
}

/// What the player wants from tennis right now — drives goal suggestions.
enum TennisWant: String, Codable, CaseIterable {
    case compete           // win more matches
    case technique         // sharper strokes
    case fitness           // get fitter / move better
    case consistency       // fewer errors, more in play
    case fun               // enjoy it / social
}

/// A completed (or in-progress) set of answers.
struct TennisProfileAnswers: Codable, Equatable, Hashable {
    var experience: TennisExperience
    var frequency: PlayFrequency
    var matchExperience: MatchExperience
    var levelSelf: LevelSelfPlacement
    /// 1...5 per dimension.
    var ratings: [TennisDimension: Int]
    var pressure: PressureResponse
    var want: TennisWant

    func rating(_ d: TennisDimension) -> Int { ratings[d] ?? 3 }
}

// MARK: - Derived profile

/// Plain-language level tier with an NTRP reference range. Order matters
/// (rawValue index used for nudging).
enum TennisLevel: Int, Codable, CaseIterable {
    case new = 0           // NTRP ~1.5–2.0
    case improver          // NTRP ~2.5
    case intermediate      // NTRP ~3.0
    case solidClub         // NTRP ~3.5
    case advancedClub      // NTRP ~4.0+
}

/// Club-relevant play-style archetype derived from strokes + net comfort +
/// pressure response. Framed positively (no "pusher").
enum TennisArchetype: String, Codable {
    case developing        // early level — building the basics
    case aggressiveBaseliner
    case counterpuncher    // steady retriever: movement + consistency
    case allCourt
    case serveVolleyer
}

/// A suggested, trackable development goal tied to a dimension.
struct TennisGoal: Codable, Equatable, Hashable, Identifiable {
    let id: String         // stable key (e.g. "serve.second_serve")
    let dimension: TennisDimension?
    // Title/detail are language-neutral keys resolved by TennisProfileCopy.
    let titleKey: String
    let detailKey: String
    var isSelected: Bool = false
}

/// The computed profile: level, archetype, ranked strengths/growth areas,
/// and the suggested goal set. Derived deterministically by the scorer.
struct TennisProfileResult: Codable, Equatable, Hashable {
    let level: TennisLevel
    let archetype: TennisArchetype
    let strengths: [TennisDimension]     // top dimensions (highest self-rating)
    let growthAreas: [TennisDimension]   // lowest dimensions
    let suggestedGoals: [TennisGoal]
}

/// A saved profile (answers + the goals the user adopted + when taken).
struct TennisProfile: Codable, Equatable, Identifiable {
    let id: String
    var takenAt: Date
    var answers: TennisProfileAnswers
    /// Goals the user chose to adopt (subset of the suggestions, editable).
    var adoptedGoals: [TennisGoal]

    init(id: String = UUID().uuidString,
         takenAt: Date = Date(),
         answers: TennisProfileAnswers,
         adoptedGoals: [TennisGoal] = []) {
        self.id = id
        self.takenAt = takenAt
        self.answers = answers
        self.adoptedGoals = adoptedGoals
    }

    /// Deterministic derived result from the answers.
    var result: TennisProfileResult { TennisProfileScoring.evaluate(answers) }
}
