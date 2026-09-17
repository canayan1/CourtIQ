// Checks the rally reader against sessions whose shape is known.
//
//   swiftc -O tools/rhythm-test.swift \
//          CourtIQ/Features/BodySensing/RallyRhythm.swift -o /tmp/r && /tmp/r

import Foundation

var failures = 0
func expect(_ ok: Bool, _ what: String) {
    print((ok ? "  ok   " : "  FAIL ") + what)
    if !ok { failures += 1 }
}

/// Strokes every `tempo` seconds, in runs of the given lengths, with a fetch
/// between runs.
func session(runs: [Int], tempo: Double, fetch: Double = 6, wobble: Double = 0) -> [Double] {
    var t = 0.0
    var out: [Double] = []
    for (i, n) in runs.enumerated() {
        for k in 0..<n {
            out.append(t)
            let jitter: Double = wobble * (Double((k * 7) % 5) / 4 - 0.5)
            t += tempo + jitter
        }
        if i < runs.count - 1 { t += fetch }
    }
    return out
}

print("rally structure:")
let s1 = session(runs: [12, 5, 21, 3], tempo: 1.2, fetch: 7)
guard let r1 = RallyRhythmReader.read(strokes: s1) else { expect(false, "read"); exit(1) }
expect(r1.longestRally == 21, "longest rally \(r1.longestRally), built as 21")
expect(r1.rallies.count == 4, "\(r1.rallies.count) rallies, built as 4")
expect(r1.totalStrokes == 41, "\(r1.totalStrokes) strokes, built as 41")
expect(abs(r1.medianInterval - 1.2) < 0.05,
       String(format: "tempo %.2f s, built as 1.20", r1.medianInterval))

print("\ntempo steadiness:")
let steady = RallyRhythmReader.read(strokes: session(runs: [30], tempo: 1.2))!
let ragged = RallyRhythmReader.read(strokes: session(runs: [30], tempo: 1.2, fetch: 0, wobble: 0.8))!
expect(steady.tempoSpread < 0.05, String(format: "metronomic -> %.2f", steady.tempoSpread))
expect(ragged.tempoSpread > steady.tempoSpread * 3,
       String(format: "ragged -> %.2f, clearly worse", ragged.tempoSpread))

print("\nfetching the ball is not a wobble:")
// Same striking, but the player fetches four times. Tempo must read the same.
let withFetches = RallyRhythmReader.read(strokes: session(runs: [8, 8, 8, 8], tempo: 1.2, fetch: 9))!
expect(abs(withFetches.tempoSpread - steady.tempoSpread) < 0.08,
       String(format: "spread %.2f vs %.2f with no fetches",
              withFetches.tempoSpread, steady.tempoSpread))

print("\nrefusals:")
expect(RallyRhythmReader.read(strokes: [1, 2, 3]) == nil, "three strokes is not a session")
expect(RallyRhythmReader.read(strokes: []) == nil, "nothing in, nothing out")

print("\na close stance and a far one both read as rallies:")
// Two metres from the wall: fast. Eight metres: slow. Neither should have its
// rallies chopped up by a fixed number of seconds.
let close = RallyRhythmReader.read(strokes: session(runs: [20], tempo: 0.55))!
let far = RallyRhythmReader.read(strokes: session(runs: [20], tempo: 2.4))!
expect(close.longestRally == 20, "fast rally stays whole (\(close.longestRally))")
expect(far.longestRally == 20, "slow rally stays whole (\(far.longestRally))")

print(failures == 0 ? "\nall passed" : "\n\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
