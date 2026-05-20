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

/// What the user tapped on a single scenario — recorded so the result
/// screen can replay the heat map.
struct DrillTap: Codable, Hashable {
    let drillID: String
    let tapX: Double                 // normalized court coord
    let tapY: Double
    let zone: DrillZone
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
