// Checks stint cutting and the bench comparison against a match whose shape
// is known.
//
//   swiftc -O tools/stints-test.swift \
//          CourtIQ/Features/BodySensing/{MovementDetector,MatchStints}.swift -o /tmp/s && /tmp/s
//
// The bench card is the thing the player reads sitting down between games,
// and it is judged on two things: it must notice a real drop, and it must not
// invent one from two stints that were the same.

import Foundation

var failures = 0
func expect(_ ok: Bool, _ what: String) {
    print((ok ? "  ok   " : "  FAIL ") + what)
    if !ok { failures += 1 }
}

/// One stint of play: rallies at a tempo, with the player pushing off at a
/// given hardness after each of their own shots.
func stint(from t0: Double, seconds: Double, tempo: Double, push: Double,
           splitStep: Bool, hr: Double?) -> [SensorEvent] {
    var out: [SensorEvent] = []
    var t = t0
    var mine = true
    var contacts: [(Double, Bool)] = []
    while t < t0 + seconds {
        contacts.append((t, mine))
        out.append(.contact(t: t, strength: mine ? 0.8 : 0.07, owner: mine ? .player : .opponent))
        mine.toggle()
        t += tempo
    }
    // motion at 100 Hz: a push after each own contact, a hop before each
    // opponent contact when asked, quiet otherwise
    var m = t0
    while m < t0 + seconds {
        var horiz = 0.02, vert = 0.0
        for (c, isMine) in contacts {
            let dt = m - c
            if isMine, dt > 0.2, dt < 0.6 { horiz = push }
            if !isMine, splitStep {
                if dt > -0.40, dt < -0.25 { vert -= 0.55 }
                if dt > -0.22, dt < -0.16 { vert += 1.10 }
            }
        }
        out.append(.motion(BodyMotionSample(t: m, accX: horiz, accY: 0, accZ: -vert,
                                            gravX: 0, gravY: 0, gravZ: 1)))
        m += 0.01
    }
    if let hr {
        var h = t0
        while h < t0 + seconds { out.append(.heartRate(t: h, bpm: hr)); h += 5 }
    }
    return out
}

print("cutting at marked changeovers:")
var match: [SensorEvent] = []
match += stint(from: 0, seconds: 120, tempo: 1.3, push: 1.2, splitStep: true, hr: 140)
match.append(.changeover(t: 121))
match += stint(from: 122, seconds: 120, tempo: 1.3, push: 1.2, splitStep: true, hr: 141)
match.append(.changeover(t: 243))
match += stint(from: 244, seconds: 120, tempo: 1.3, push: 0.7, splitStep: false, hr: 158)
let marked = StintBuilder.stints(from: match)
expect(marked.count == 3, "\(marked.count) stints from two marks")
if marked.count == 3 {
    expect(marked[0].ownContacts > 40, "stint 0 holds its contacts (\(marked[0].ownContacts))")
    expect(marked[0].readiness ?? 0 > 0.9, String(format: "stint 0 readiness %.0f%%", (marked[0].readiness ?? 0) * 100))
    expect(marked[2].readiness ?? 1 < 0.1, String(format: "stint 2 readiness %.0f%%", (marked[2].readiness ?? 0) * 100))
    expect(marked[0].meanHeartRate == 140, "heart rate carried per stint")
}

print("\ninferring changeovers from the rest pattern when nobody tapped:")
var unmarked: [SensorEvent] = []
unmarked += stint(from: 0, seconds: 100, tempo: 1.3, push: 1.2, splitStep: true, hr: nil)
unmarked += stint(from: 190, seconds: 100, tempo: 1.3, push: 1.2, splitStep: true, hr: nil)   // 90 s gap
unmarked += stint(from: 320, seconds: 100, tempo: 1.3, push: 1.2, splitStep: true, hr: nil)   // 30 s gap: same stint
let inferred = StintBuilder.stints(from: unmarked)
expect(inferred.count == 2, "\(inferred.count) stints: the 90 s gap cuts, the 30 s one does not")

print("\nthe bench card notices a real drop:")
if marked.count == 3 {
    let notes = BenchReport.compare(latest: marked[2], previous: marked[1])
    let topics = Set(notes.map(\.topic))
    expect(topics.contains(.pushes), "softer pushes noticed")
    expect(topics.contains(.readiness), "lost split steps noticed")
    expect(topics.contains(.heartRate), "heart rate rise noticed")
    for n in notes { print("       \(n.sentence)") }
    expect(!notes.contains { $0.sentence.lowercased().contains("carb") || $0.sentence.lowercased().contains("eat") },
           "and says nothing about why")
}

print("\nand says nothing when two stints were the same:")
if marked.count == 3 {
    let same = BenchReport.compare(latest: marked[1], previous: marked[0])
    expect(same.isEmpty, "\(same.count) notes between two identical stints")
}

print("\nrefusals:")
expect(StintBuilder.stints(from: []).isEmpty, "no events, no stints")
let tiny = StintBuilder.stints(from: stint(from: 0, seconds: 4, tempo: 1.3, push: 1, splitStep: false, hr: nil))
expect(tiny.isEmpty, "a few seconds of play is not a stint")

print(failures == 0 ? "\nall passed" : "\n\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
