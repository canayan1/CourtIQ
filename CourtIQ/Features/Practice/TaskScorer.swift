import Foundation

/// What one attempt at a task produced.
struct TaskOutcome: Equatable {
    var taskID: String
    /// The number the task is about — longest run, balls in the zone, and so
    /// on. Always in the task's own unit, so the sentence can say it plainly.
    var achieved: Double
    /// The bar this attempt was measured against.
    var target: Double
    var met: Bool
    /// Why the task could not be scored, when it could not. A task that the
    /// setup cannot measure is not failed; it is unscored, and the player is
    /// told which.
    var unscored: String?
}

/// The wing of a stroke, when something can say which it was.
enum StrokeWing: String, Codable { case forehand, backhand }

/// Everything a session might have recorded that a task could be scored on.
/// Each task uses the part it needs and ignores the rest; a missing part
/// makes the task unscored, never zero.
struct TaskEvidence {
    /// Stroke times, from BallImpactAudio through the session recorder.
    var strokeTimes: [Double] = []
    /// The wing of each stroke, in the same order, when known.
    var wings: [StrokeWing]? = nil
    /// Feeder taps: one Bool per ball, true if it landed in the zone.
    var landings: [Bool]? = nil
}

/// Scores a task from evidence. Pure, so it is testable against sessions
/// whose answer is known — the same rule as every detector in this app.
enum TaskScorer {

    static func score(_ task: ConstraintTask, evidence: TaskEvidence, target: Double) -> TaskOutcome {
        switch task.kind {
        case .consecutiveRally:
            guard let rhythm = RallyRhythmReader.read(strokes: evidence.strokeTimes) else {
                return unscored(task, target, "Too few strokes were heard to find a rally.")
            }
            let achieved = Double(rhythm.longestRally)
            return TaskOutcome(taskID: task.id, achieved: achieved, target: target,
                               met: achieved >= target, unscored: nil)

        case .tempoHold:
            guard let rhythm = RallyRhythmReader.read(strokes: evidence.strokeTimes) else {
                return unscored(task, target, "Too few strokes were heard to judge a tempo.")
            }
            // The run has to be long enough to have a tempo, and the tempo
            // has to have held. Achieved is the longest run that held it —
            // zero if the spread was over the limit, which is the honest
            // score for "held the beat for none of them".
            let limit = task.maxTempoSpread ?? 0.25
            let achieved = rhythm.tempoSpread <= limit ? Double(rhythm.longestRally) : 0
            return TaskOutcome(taskID: task.id, achieved: achieved, target: target,
                               met: achieved >= target, unscored: nil)

        case .alternateWings:
            guard let wings = evidence.wings, wings.count >= 4 else {
                return unscored(task, target, "Nothing in this session could tell forehand from backhand.")
            }
            var best = 1, run = 1
            for i in 1..<wings.count {
                if wings[i] != wings[i - 1] { run += 1 } else { run = 1 }
                best = max(best, run)
            }
            let achieved = Double(best)
            return TaskOutcome(taskID: task.id, achieved: achieved, target: target,
                               met: achieved >= target, unscored: nil)

        case .targetZone:
            guard let landings = evidence.landings, !landings.isEmpty else {
                return unscored(task, target, "Nobody marked where the balls landed.")
            }
            let achieved = Double(landings.filter { $0 }.count)
            return TaskOutcome(taskID: task.id, achieved: achieved, target: target,
                               met: achieved >= target, unscored: nil)
        }
    }

    private static func unscored(_ task: ConstraintTask, _ target: Double, _ why: String) -> TaskOutcome {
        TaskOutcome(taskID: task.id, achieved: 0, target: target, met: false, unscored: why)
    }
}
