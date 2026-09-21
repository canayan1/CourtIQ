import Foundation

/// One scored attempt, kept.
struct TaskAttempt: Codable, Equatable {
    var taskID: String
    var date: Date
    var achieved: Double
    var target: Double
    var met: Bool
}

/// Where a player stands on each task, and what the bar is next time.
///
/// The bar is the player's own. A first attempt sets the baseline; the
/// threshold is a multiple of it, clamped to the task's bounds; meeting it
/// raises it, missing it leaves it where it was. Nothing here compares one
/// player with another, and nothing here mentions the stroke — the task and
/// the score are the whole conversation.
final class TaskProgressionStore: ObservableObject {
    static let shared = TaskProgressionStore()

    @Published private(set) var attempts: [TaskAttempt] = []
    private let key = "practice.taskAttempts.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([TaskAttempt].self, from: data) {
            attempts = decoded
        }
    }

    func attempts(for task: ConstraintTask) -> [TaskAttempt] {
        attempts.filter { $0.taskID == task.id }.sorted { $0.date < $1.date }
    }

    /// The bar for the next attempt.
    ///
    /// Relative tasks: no history means there is no bar yet — the first
    /// attempt is the baseline and is never failed. After that, the bar is
    /// factor × the best of the first attempt and the last bar met, so a
    /// player who has a bad day is measured against their own established
    /// level rather than punished for it, and a player who has a great day
    /// moves the bar up rather than being told they already passed.
    func target(for task: ConstraintTask) -> Double? {
        let history = attempts(for: task)
        switch task.threshold.rule {
        case .absolute:
            return task.threshold.value
        case .relative:
            guard let first = history.first else { return nil }
            let factor = task.threshold.factor ?? 1.5
            let bestMet = history.filter(\.met).map(\.achieved).max() ?? first.achieved
            let raw = max(first.achieved, bestMet) * factor
            return min(task.threshold.maximum, max(task.threshold.minimum, raw.rounded()))
        }
    }

    /// Records an outcome. An unscored attempt is not recorded: it is not a
    /// result, and it must not become a baseline.
    @discardableResult
    func record(_ outcome: TaskOutcome, for task: ConstraintTask, at date: Date = Date()) -> TaskAttempt? {
        guard outcome.unscored == nil else { return nil }
        let attempt = TaskAttempt(taskID: task.id, date: date, achieved: outcome.achieved,
                                  target: outcome.target, met: outcome.met)
        attempts.append(attempt)
        if let data = try? JSONEncoder().encode(attempts) { defaults.set(data, forKey: key) }
        return attempt
    }

    func reset() {
        attempts.removeAll()
        defaults.removeObject(forKey: key)
    }
}

/// What the player is told after the set.
///
/// The outcome, the bar, and what happens next. Never the stroke: the task
/// did the teaching, and telling the player what to change would undo it
/// (and would be an internal-focus cue, which is the wrong kind). An
/// unscored task says why it was unscored rather than pretending to a zero.
enum TaskReport {
    static func sentence(for outcome: TaskOutcome, task: ConstraintTask, wasBaseline: Bool) -> String {
        if let why = outcome.unscored {
            return "\(task.name): not scored — \(why)"
        }
        let unit = unitWord(task)
        if wasBaseline {
            return String(format: "%@: %.0f %@. That is your baseline; next time the bar is set from it.",
                          task.name, outcome.achieved, unit)
        }
        if outcome.met {
            return String(format: "%@: %.0f %@ — bar was %.0f. Met. The bar moves up.",
                          task.name, outcome.achieved, unit, outcome.target)
        }
        return String(format: "%@: %.0f %@ — bar was %.0f. Same task next time.",
                      task.name, outcome.achieved, unit, outcome.target)
    }

    private static func unitWord(_ task: ConstraintTask) -> String {
        switch task.kind {
        case .consecutiveRally, .tempoHold, .alternateWings: return "in a row"
        case .targetZone: return "in the zone of \(task.length)"
        }
    }
}

/// Picks the session's tasks.
///
/// Three, interleaved, in a random order — because blocked practice feels
/// productive and transfers badly, and interleaved practice is what the
/// retention research supports (contextual interference). Deterministic for
/// a given seed so a test can check it and a day's plan does not reshuffle
/// every time the screen redraws.
enum PracticePlanner {
    static let tasksPerSession = 3

    static func plan(from available: [ConstraintTask], seed: UInt64) -> [ConstraintTask] {
        guard !available.isEmpty else { return [] }
        var g = SplitMix64(seed: seed)
        var pool = available
        var out: [ConstraintTask] = []
        while out.count < tasksPerSession, !pool.isEmpty {
            let i = Int(g.next() % UInt64(pool.count))
            out.append(pool.remove(at: i))
        }
        return out
    }

    /// A seed for "today", so the plan is stable within a day and different
    /// tomorrow.
    static func daySeed(_ date: Date = Date()) -> UInt64 {
        UInt64(Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0)
    }
}

/// Small, deterministic, and not for anything cryptographic.
struct SplitMix64 {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
