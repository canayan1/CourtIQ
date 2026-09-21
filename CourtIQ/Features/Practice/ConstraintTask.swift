import Foundation

/// A task that only good technique can pass.
///
/// The app never looks at the stroke. It defines a task with a measurable
/// outcome, counts the outcome, and says whether the threshold was met. A
/// short, flat, arm-only forehand cannot land twenty consecutive balls past
/// the service line; the task fails and the player finds the swing that
/// works. Nobody told them to change it. This is the constraints-led route
/// from docs/TEACHING-PLAN.md, and it is the whole of Step 1.
///
/// Tasks are data, not code, so the coach can write them without a build:
/// `constraint_tasks.json`. What each task SHAPES is written for the coach's
/// eyes and never shown to the player — the player is told the task and the
/// score, and the task does the teaching.
struct ConstraintTask: Codable, Identifiable, Equatable {

    /// What the outcome is and how it is measured.
    enum Kind: String, Codable {
        /// Longest unbroken run of strokes. Measured from stroke times.
        case consecutiveRally
        /// Hold a tempo: the spread of intervals inside the run stays under a
        /// limit. Measured from stroke times.
        case tempoHold
        /// Alternate wings, forehand then backhand. Needs the wing of each
        /// stroke — a wrist, or the feeder saying it.
        case alternateWings
        /// Land the ball in a zone. Needs somebody to say where it landed —
        /// the feeder's tap — until there is ball tracking, which there is
        /// not.
        case targetZone
    }

    /// Where the numbers come from, so a task is never offered on a setup
    /// that cannot score it.
    enum Measurement: String, Codable {
        case audioStrokes      // BallImpactAudio + RallyRhythm
        case wing              // wrist swing detector or feeder-declared
        case feederTap
    }

    enum Surface: String, Codable { case wall, court }

    /// How the bar is set. Relative by default: "twenty in a row" is out of
    /// reach for a beginner and meaningless for an advanced player, while
    /// "one and a half times your first attempt" scales to everyone and
    /// defines progress against the player themselves — the same rule the
    /// trends use.
    struct Threshold: Codable, Equatable {
        enum Rule: String, Codable { case relative, absolute }
        var rule: Rule
        /// For `.relative`: multiplier on the player's baseline.
        var factor: Double?
        /// For `.absolute`: the bar itself.
        var value: Double?
        /// Bounds, so a relative bar cannot be trivial or impossible.
        var minimum: Double
        var maximum: Double
    }

    var id: String
    var name: String
    /// Coach-facing: which fault this task makes untenable. Never shown to
    /// the player.
    var shapes: String
    var kind: Kind
    var measurement: Measurement
    var surface: Surface
    /// How many strokes or balls the task runs for.
    var length: Int
    /// For tempoHold: the largest tempo spread that still counts as "held".
    var maxTempoSpread: Double?
    var threshold: Threshold
    /// The player-facing instruction. External focus only — the ball, the
    /// wall, the line, the rhythm. Never a body part.
    var instruction: String
    /// True until a coach has confirmed the task shapes what it claims to.
    var draft: Bool
}

enum ConstraintTaskLibrary {

    /// The bundled library. Falls back to the built-in starter set when the
    /// file is missing, so the feature cannot silently offer nothing.
    static func load(bundle: Bundle = .main) -> [ConstraintTask] {
        let loaded = BundleContentLoader.loadArray([ConstraintTask].self,
                                                   named: "constraint_tasks", bundle: bundle)
        return loaded.isEmpty ? starter : loaded
    }

    /// Tasks a given setup can actually score.
    static func available(_ tasks: [ConstraintTask], surface: ConstraintTask.Surface,
                          canMeasure: Set<ConstraintTask.Measurement>) -> [ConstraintTask] {
        tasks.filter { $0.surface == surface && canMeasure.contains($0.measurement) }
    }

    /// DRAFT. Written to make the engine testable, not to be right about
    /// tennis. What each task shapes is the coach's knowledge and these are
    /// placeholders for it — see the `draft` flag and docs/TEACHING-PLAN.md,
    /// decision 1.
    static let starter: [ConstraintTask] = [
        ConstraintTask(
            id: "wall.rally", name: "Keep it going",
            shapes: "Consistency and footwork. A player who does not recover to a ready base cannot keep a wall rally alive past a handful.",
            kind: .consecutiveRally, measurement: .audioStrokes, surface: .wall,
            length: 30, maxTempoSpread: nil,
            threshold: .init(rule: .relative, factor: 1.5, value: nil, minimum: 6, maximum: 60),
            instruction: "Rally against the wall. Count how many you can keep going before the ball gets away.",
            draft: true),
        ConstraintTask(
            id: "wall.tempo", name: "Hold the rhythm",
            shapes: "Early preparation. A late take-back cannot hold a steady tempo; the player rushes some balls and waits on others.",
            kind: .tempoHold, measurement: .audioStrokes, surface: .wall,
            length: 20, maxTempoSpread: 0.25,
            threshold: .init(rule: .absolute, factor: nil, value: 20, minimum: 8, maximum: 40),
            instruction: "Twenty balls at one steady beat. Same gap between every hit, like a metronome.",
            draft: true),
        ConstraintTask(
            id: "wall.alternate", name: "Both sides",
            shapes: "Recovery and grip change. Alternating wings forces the player back to the middle between every ball.",
            kind: .alternateWings, measurement: .wing, surface: .wall,
            length: 20, maxTempoSpread: nil,
            threshold: .init(rule: .relative, factor: 1.5, value: nil, minimum: 4, maximum: 40),
            instruction: "Forehand, backhand, forehand, backhand. Count how many you can alternate without breaking the pattern.",
            draft: true),
        ConstraintTask(
            id: "court.deep", name: "Past the line",
            shapes: "Length. A short, flat, arm-only swing cannot land balls past the service line; the swing has to lengthen and the weight has to go forward.",
            kind: .targetZone, measurement: .feederTap, surface: .court,
            length: 20, maxTempoSpread: nil,
            threshold: .init(rule: .relative, factor: 1.4, value: nil, minimum: 6, maximum: 20),
            instruction: "Twenty fed balls. Every one has to land past the service line — anything shorter does not count.",
            draft: true),
        ConstraintTask(
            id: "court.crosscourt", name: "Cross-court corridor",
            shapes: "Direction and the contact point. Consistent cross-court needs contact in front; a late contact goes down the line or wide.",
            kind: .targetZone, measurement: .feederTap, surface: .court,
            length: 20, maxTempoSpread: nil,
            threshold: .init(rule: .relative, factor: 1.4, value: nil, minimum: 6, maximum: 20),
            instruction: "Twenty fed balls, all cross-court, inside the singles line and past the service line.",
            draft: true),
    ]
}
