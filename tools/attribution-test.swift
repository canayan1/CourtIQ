// Checks whose-stroke-was-that against cases whose answer is known.
//
//   swiftc -O tools/attribution-test.swift \
//          CourtIQ/Features/BodySensing/ImpactAttribution.swift -o /tmp/a && /tmp/a
//
// The refusals matter more than the splits. A forced two-way split on a solo
// session hands every metric a silently wrong denominator — half the strokes
// credited to an opponent who was never there — and nothing downstream would
// look wrong enough to notice.

import Foundation

var failures = 0
func expect(_ ok: Bool, _ what: String) {
    print((ok ? "  ok   " : "  FAIL ") + what)
    if !ok { failures += 1 }
}

print("with motion, it is not a guess:")
// A rally: strokes alternate. The wrist felt every other one.
let rally = stride(from: 1.0, through: 13.0, by: 1.2).map { $0 }
let mine = rally.enumerated().filter { $0.offset % 2 == 0 }.map { $0.element }
// The microphone's clock is a little behind the motion clock.
let heard = rally.map { $0 + 0.04 }
let s1 = ImpactAttribution.split(audioImpacts: heard, ownSwings: mine)
expect(s1.own.count == mine.count, "\(s1.own.count) of \(rally.count) strokes are mine")
expect(s1.opponent.count == rally.count - mine.count, "the rest are the opponent's")
expect(s1.basis == .motion, "recorded as a fact, not an inference")

// A stroke the wrist felt but the microphone missed must not become the
// opponent's.
let s2 = ImpactAttribution.split(audioImpacts: Array(heard.dropFirst(2)), ownSwings: mine)
expect(s2.opponent.allSatisfy { t in !mine.contains { abs($0 - t) < 0.12 } },
       "no stroke of mine is filed under the opponent")

print("\nwith only a microphone, loudness does it:")
// Near racket about a metre away, far one across the court: an order of
// magnitude apart in amplitude.
var loud: [(t: Double, strength: Double)] = []
for t in mine {
    let jitter: Double = Double(Int(t) % 3) * 0.04
    loud.append((t: t, strength: 0.80 + jitter))
}
var quiet: [(t: Double, strength: Double)] = []
for t in rally where !mine.contains(t) {
    let jitter: Double = Double(Int(t) % 3) * 0.004
    quiet.append((t: t, strength: 0.06 + jitter))
}
guard let s3 = ImpactAttribution.splitByLoudness(loud + quiet) else {
    expect(false, "a clear rally split by loudness"); exit(1)
}
expect(Set(s3.own) == Set(loud.map(\.t)), "the near strokes are mine")
expect(Set(s3.opponent) == Set(quiet.map(\.t)), "the far ones are the opponent's")
expect(s3.basis == .loudness, "recorded as an inference")

print("\nand refuses when it cannot tell:")
// A wall session: one player, every strike the same distance away.
var wall: [(t: Double, strength: Double)] = []
for i in 0..<14 {
    let jitter: Double = Double(i % 4) * 0.03
    wall.append((t: Double(i) * 1.1, strength: 0.7 + jitter))
}
expect(ImpactAttribution.splitByLoudness(wall) == nil,
       "one player at one distance -> no split invented")

// Too few strokes to see a population at all.
let sparse = [(t: 1.0, strength: 0.8), (t: 2.0, strength: 0.05), (t: 3.0, strength: 0.79)]
expect(ImpactAttribution.splitByLoudness(sparse) == nil, "three strokes -> no split")

// One stray loud bang among quiet strokes is a dropped racket, not a player.
var stray: [(t: Double, strength: Double)] = []
for i in 0..<12 {
    let jitter: Double = Double(i % 3) * 0.004
    stray.append((t: Double(i) * 1.1, strength: 0.06 + jitter))
}
stray.append((t: 13.5, strength: 0.95))
expect(ImpactAttribution.splitByLoudness(stray) == nil,
       "a single outlier does not become a second player")

print(failures == 0 ? "\nall passed" : "\n\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
