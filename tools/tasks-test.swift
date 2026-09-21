// Checks the constraint-task engine against sessions whose answer is known.
//
//   swiftc -O tools/tasks-test.swift CourtIQ/Features/BodySensing/RallyRhythm.swift \
//          CourtIQ/Core/Models/BundleContentLoader.swift \
//          CourtIQ/Features/Practice/{ConstraintTask,TaskScorer,TaskProgression}.swift -o /tmp/k && /tmp/k
//
// The engine's two promises: a task the setup cannot measure is UNSCORED
// and never becomes a zero or a baseline; and the bar is the player's own —
// first attempt sets it, meeting it raises it, missing it leaves it.

import Foundation

var failures = 0
func expect(_ ok: Bool, _ what: String) {
    print((ok ? "  ok   " : "  FAIL ") + what)
    if !ok { failures += 1 }
}

let lib = ConstraintTaskLibrary.starter
func task(_ id: String) -> ConstraintTask { lib.first { $0.id == id }! }
func strokes(runs: [Int], tempo: Double, wobble: Double = 0) -> [Double] {
    var t = 0.0, out: [Double] = []
    for (i, n) in runs.enumerated() {
        for k in 0..<n { out.append(t); t += tempo + wobble * (Double((k * 7) % 5) / 4 - 0.5) }
        if i < runs.count - 1 { t += 8 }
    }
    return out
}

// An isolated store, so a test never touches the real one.
let suite = UserDefaults(suiteName: "tasks-test-\(UUID().uuidString)")!
let store = TaskProgressionStore(defaults: suite)

print("scoring:")
let rally = task("wall.rally")
let s1 = TaskScorer.score(rally, evidence: TaskEvidence(strokeTimes: strokes(runs: [7, 12, 5], tempo: 1.2)), target: 10)
expect(s1.achieved == 12 && s1.met, "longest rally 12 against a bar of 10 — met")
let s2 = TaskScorer.score(rally, evidence: TaskEvidence(strokeTimes: [1, 2]), target: 10)
expect(s2.unscored != nil && !s2.met, "two strokes: unscored, not failed")

let tempo = task("wall.tempo")
let steady = TaskScorer.score(tempo, evidence: TaskEvidence(strokeTimes: strokes(runs: [24], tempo: 1.2)), target: 20)
expect(steady.achieved == 24 && steady.met, "a metronomic 24 holds the rhythm")
let ragged = TaskScorer.score(tempo, evidence: TaskEvidence(strokeTimes: strokes(runs: [24], tempo: 1.2, wobble: 0.9)), target: 20)
expect(ragged.achieved == 0 && !ragged.met, "a ragged 24 holds it for none of them")

let alt = task("wall.alternate")
let wings: [StrokeWing] = [.forehand, .backhand, .forehand, .backhand, .forehand, .forehand, .backhand]
let a1 = TaskScorer.score(alt, evidence: TaskEvidence(strokeTimes: [], wings: wings), target: 4)
expect(a1.achieved == 5 && a1.met, "longest alternating run is 5")
let a2 = TaskScorer.score(alt, evidence: TaskEvidence(strokeTimes: strokes(runs: [20], tempo: 1.2)), target: 4)
expect(a2.unscored != nil, "no wings known: unscored, with the reason")

let deep = task("court.deep")
let d1 = TaskScorer.score(deep, evidence: TaskEvidence(landings: Array(repeating: true, count: 14) + Array(repeating: false, count: 6)), target: 12)
expect(d1.achieved == 14 && d1.met, "14 of 20 past the line")
let d2 = TaskScorer.score(deep, evidence: TaskEvidence(strokeTimes: strokes(runs: [20], tempo: 1.2)), target: 12)
expect(d2.unscored != nil, "no feeder taps: unscored")

print("\nthe bar is the player's own:")
expect(store.target(for: rally) == nil, "no history: no bar — the first attempt is the baseline")
let first = TaskScorer.score(rally, evidence: TaskEvidence(strokeTimes: strokes(runs: [8], tempo: 1.2)), target: 0)
store.record(first, for: rally)
expect(store.target(for: rally) == 12, "baseline 8 × 1.5 = bar of 12 (\(store.target(for: rally) ?? -1))")
let miss = TaskScorer.score(rally, evidence: TaskEvidence(strokeTimes: strokes(runs: [9], tempo: 1.2)), target: 12)
store.record(miss, for: rally)
expect(store.target(for: rally) == 12, "a miss leaves the bar where it was")
let hit = TaskScorer.score(rally, evidence: TaskEvidence(strokeTimes: strokes(runs: [14], tempo: 1.2)), target: 12)
store.record(hit, for: rally)
expect(store.target(for: rally) == 21, "met with 14 → bar 21 (\(store.target(for: rally) ?? -1))")
expect(store.record(s2, for: rally) == nil, "an unscored attempt is never recorded")
expect(store.target(for: tempo) == 20, "an absolute task's bar is its value")

print("\nsentences never mention the stroke:")
let lines = [TaskReport.sentence(for: first, task: rally, wasBaseline: true),
             TaskReport.sentence(for: hit, task: rally, wasBaseline: false),
             TaskReport.sentence(for: miss, task: rally, wasBaseline: false),
             TaskReport.sentence(for: a2, task: alt, wasBaseline: false)]
for l in lines { print("       " + l) }
let banned = ["elbow", "wrist", "swing", "racket", "shoulder", "hip", "technique"]
expect(!lines.contains { l in banned.contains { l.lowercased().contains($0) } }, "no body part, no technique word")
expect(lines[0].contains("baseline"), "first attempt is told it is the baseline")
expect(lines[3].contains("not scored"), "unscored says so")

print("\nplanner:")
let wall = ConstraintTaskLibrary.available(lib, surface: .wall, canMeasure: [.audioStrokes])
expect(wall.map(\.id).sorted() == ["wall.rally", "wall.tempo"], "a pocket phone on a wall can score two tasks (\(wall.map(\.id)))")
let court = ConstraintTaskLibrary.available(lib, surface: .court, canMeasure: [.audioStrokes, .feederTap])
expect(court.count == 2, "court with a feeder: the two zone tasks")
let p1 = PracticePlanner.plan(from: lib, seed: 7), p2 = PracticePlanner.plan(from: lib, seed: 7), p3 = PracticePlanner.plan(from: lib, seed: 8)
expect(p1.count == 3 && Set(p1.map(\.id)).count == 3, "three distinct tasks")
expect(p1 == p2, "same seed, same plan")
expect(p1 != p3, "different day, different order")

store.reset()
print(failures == 0 ? "\nall passed" : "\n\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
