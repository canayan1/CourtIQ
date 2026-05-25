import Foundation
import CoreGraphics

/// One micro-scenario in the Daily Court Tap Game.
///
/// Coordinate convention matches `QuizCourtDiagram`: normalized [0,1],
/// YOU at bottom (y≈0.9), OP at top (y≈0.1), net at 0.5.
struct CourtTapDrill: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    var titleTr: String? = nil
    let surface: String           // "clay" | "grass" | "hard"
    /// Which tactical category this scenario primarily exercises.
    /// Optional in the wire format for backward compatibility — drills
    /// without an explicit category fall through to `.patterns` so
    /// existing user sessions aren't broken if we ship a new drill
    /// before users update the app.
    var category: String? = nil

    /// V2 fields — characterise the INCOMING ball so the user can
    /// reason about how to respond, and define which shot type the
    /// scenario is asking for. All optional so v1 drill JSON keeps
    /// decoding cleanly.
    /// Incoming ball spin: "topspin" | "slice" | "flat" | "kick"
    var incomingSpin: String? = nil
    /// Incoming ball speed: "slow" | "medium" | "fast"
    var incomingSpeed: String? = nil
    /// Incoming ball bounce height: "low" | "mid" | "high"
    var incomingHeight: String? = nil
    /// Best shot type to play: "topspin" | "flat" | "slice" | "drop" | "lob"
    /// When nil (v1 drills) the shot-type axis is skipped and only
    /// location scoring applies, so old sessions don't break.
    var idealShotType: String? = nil
    /// Alternative shot types that score as yellow (partially correct).
    /// E.g. on a defensive recovery the ideal is topspin but flat is
    /// also acceptable. Empty list = only `idealShotType` is yellow+.
    var acceptableShotTypes: [String]? = nil
    let youX: Double
    let youY: Double
    let opponentX: Double?
    let opponentY: Double?
    let ballOriginX: Double?
    let ballOriginY: Double?
    let ballTargetX: Double?      // where the incoming ball will land (your decision starts from here)
    let ballTargetY: Double?
    let scoreChip: String?

    /// Polygons in normalized court space describing the scoring zones.
    /// `greenZone` is the single best decision area. `yellowZones` is an
    /// array because there can be multiple defensible alternatives.
    /// Anything outside both buckets scores red (mistake).
    let greenZone: [[Double]]              // [[x,y], …]
    let yellowZones: [[[Double]]]          // [[[x,y], …], [[x,y], …]]

    let rationale: String
    var rationaleTr: String? = nil

    func localizedTitle(for lang: AppLanguage) -> String {
        lang == .turkish ? (titleTr ?? title) : title
    }

    func localizedRationale(for lang: AppLanguage) -> String {
        lang == .turkish ? (rationaleTr ?? rationale) : rationale
    }

    var greenPolygon: [CGPoint] {
        greenZone.map { CGPoint(x: $0[0], y: $0[1]) }
    }

    var yellowPolygons: [[CGPoint]] {
        yellowZones.map { ring in ring.map { CGPoint(x: $0[0], y: $0[1]) } }
    }
}

/// Result of evaluating a single tap.
enum DrillZone: Codable, Hashable {
    case green
    case yellow
    case red

    var score: Int {
        switch self {
        case .green:  return 20
        case .yellow: return 10
        case .red:    return 0
        }
    }

    var emoji: String {
        switch self {
        case .green:  return "🟢"
        case .yellow: return "🟡"
        case .red:    return "🔴"
        }
    }
}

/// Five shot types the V2 drill picker offers. Lowercase raw values
/// match the strings in `CourtTapDrill.idealShotType` so we can
/// round-trip through JSON cleanly without a custom decoder.
enum ShotType: String, Codable, CaseIterable, Identifiable, Hashable {
    case topspin
    case flat
    case slice
    case drop
    case lob

    var id: String { rawValue }
    var localizationKey: String { "drill.shot.\(rawValue)" }
    /// SF Symbol that visually hints at the trajectory.
    var iconName: String {
        switch self {
        case .topspin: return "arrow.up.right.circle.fill"
        case .flat:    return "arrow.right.circle.fill"
        case .slice:   return "arrow.down.right.circle.fill"
        case .drop:    return "arrow.down.to.line.circle.fill"
        case .lob:     return "arrow.up.to.line.circle.fill"
        }
    }
}

/// What the user committed on a single scenario — location AND
/// (when the scenario asks for it) shot type. `shotType` is optional
/// so v1 drill sessions decode without crashing.
struct DrillTap: Codable, Hashable {
    let drillID: String
    let tapX: Double                 // normalized court coord
    let tapY: Double
    let zone: DrillZone
    var shotType: ShotType? = nil
    /// Whether the chosen shot type matched the scenario's ideal /
    /// acceptable list. nil when the scenario didn't ask for one.
    var shotTypeCorrect: Bool? = nil
}

/// Summary record of one completed Daily Drill session (5 scenarios).
/// Persisted in UserDefaults so the Quiz Ring + history + shareable
/// emoji result can all read from it.
struct DrillSession: Codable, Identifiable, Hashable {
    let id: String                   // ISO date — one session per day
    let date: Date
    let dayNumber: Int               // human-readable "Drill #142" counter
    let taps: [DrillTap]

    var score: Int { taps.map(\.zone.score).reduce(0, +) }
    var maxScore: Int { taps.count * DrillZone.green.score }
    var emojiString: String { taps.map(\.zone.emoji).joined() }
}

extension CourtTapDrill {
    /// Loads the bundled scenario set. Falls back to a single hard-coded
    /// scenario so the app still works if the JSON fails to decode.
    static let allDrills: [CourtTapDrill] = {
        let loaded = BundleContentLoader.loadArray([CourtTapDrill].self, named: "court_tap_drills")
        if !loaded.isEmpty { return loaded }
        return [fallback]
    }()

    private static let fallback = CourtTapDrill(
        id: "fallback-001",
        title: "Open court +1",
        surface: "clay",
        youX: 0.5, youY: 0.96,
        opponentX: 0.20, opponentY: 0.08,
        ballOriginX: 0.20, ballOriginY: 0.18,
        ballTargetX: 0.55, ballTargetY: 0.60,
        scoreChip: "OPEN COURT",
        greenZone: [[0.55, 0.05], [0.85, 0.05], [0.85, 0.35], [0.55, 0.35]],
        yellowZones: [[[0.15, 0.05], [0.45, 0.05], [0.45, 0.25], [0.15, 0.25]]],
        rationale: "Open court FH. Your opponent is stranded wide."
    )
}
