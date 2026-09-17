// Checks the omission detector against sessions whose faults are known.
//
//   swiftc -O tools/findings-test.swift \
//          CourtIQ/Features/BodySensing/{MovementDetector,RallyRhythm,SessionFindings}.swift \
//          -o /tmp/f && /tmp/f
//
// Two failure modes matter here and they pull in opposite directions. Flagging
// a player who did nothing wrong destroys trust in one session. But silently
// checking nothing — because the microphone never heard the opponent — and
// showing a clean sheet is worse, because it reads as praise. So the clean
// session and the unmeasurable session must come out clearly different.

import Foundation

var failures = 0
func expect(_ ok: Bool, _ what: String) {
    print((ok ? "  ok   " : "  FAIL ") + what)
    if !ok { failures += 1 }
}

/// Motion where the player moves during every window given, and is still the
/// rest of the time.
func motion(duration: Double, movingDuring: [(Double, Double)],
            spikesAt: [Double] = []) -> [BodyMotionSample] {
    var out: [BodyMotionSample] = []
    var t = 0.0
    while t < duration {
        var horiz = 0.02
        for (a, b) in movingDuring where t >= a && t <= b { horiz = 0.9 }
        for s in spikesAt where abs(t - s) < 0.10 { horiz = 2.2 }
        out.append(BodyMotionSample(t: t, accX: horiz, accY: 0, accZ: 0,
                                    gravX: 0, gravY: 0, gravZ: 1))
        t += 0.01
    }
    return out
}

func hops(at times: [Double]) -> [SplitStep] {
    times.map { SplitStep(landing: $0, unload: 0.6, landingG: 1.1) }
}

// A rally: the player hits on the even beats, the opponent on the odd ones.
let beat = 1.4
let mine = (0..<20).map { Double($0) * beat * 2 + 1.0 }
let theirs = (0..<20).map { Double($0) * beat * 2 + 1.0 + beat }

print("a player who does everything right:")
// Moves after every one of their own shots, and split steps on every reply.
let goodWindows = mine.map { ($0 + 0.2, $0 + 0.9) }
let good = SessionAnalyst.analyse(
    ownContacts: mine, opponentContacts: theirs,
    splitSteps: hops(at: theirs.map { $0 - 0.2 }),
    motion: motion(duration: 60, movingDuring: goodWindows),
    rhythm: nil, isWall: false)
expect(good.findings.isEmpty, "no flags raised (\(good.findings.map(\.kind.rawValue)))")
expect(good.notChecked.isEmpty, "and nothing went unchecked")

print("\na player who never split steps:")
let flat = SessionAnalyst.analyse(
    ownContacts: mine, opponentContacts: theirs, splitSteps: [],
    motion: motion(duration: 60, movingDuring: goodWindows),
    rhythm: nil, isWall: false)
expect(flat.findings.contains { $0.kind == .noSplitStep }, "flagged")
if let f = flat.findings.first(where: { $0.kind == .noSplitStep }) {
    expect(f.occurrences == theirs.count, "all \(f.occurrences) of them")
    expect(f.weight == .clear, "and reported as clear rather than a hint")
    expect(f.moments.count == f.occurrences, "with a timestamp for each")
    print("       \(f.sentence)")
}

print("\na player who hits and then watches:")
let rooted = SessionAnalyst.analyse(
    ownContacts: mine, opponentContacts: theirs,
    splitSteps: hops(at: theirs.map { $0 - 0.2 }),
    motion: motion(duration: 60, movingDuring: []),   // never moves
    rhythm: nil, isWall: false)
expect(rooted.findings.contains { $0.kind == .rootedAfterOwnShot }, "flagged")
if let f = rooted.findings.first(where: { $0.kind == .rootedAfterOwnShot }) {
    print("       \(f.sentence)")
}

print("\na player still running as they hit:")
let late = SessionAnalyst.analyse(
    ownContacts: mine, opponentContacts: theirs,
    splitSteps: hops(at: theirs.map { $0 - 0.2 }),
    motion: motion(duration: 60, movingDuring: goodWindows, spikesAt: mine),
    rhythm: nil, isWall: false)
expect(late.findings.contains { $0.kind == .lateToTheBall }, "flagged")

print("\nthe part that matters most — silence must not read as praise:")
// The microphone never separated two players, so the opponent's contacts are
// unknown. Nothing can be checked; nothing may be implied.
let deaf = SessionAnalyst.analyse(
    ownContacts: mine, opponentContacts: [], splitSteps: [],
    motion: motion(duration: 60, movingDuring: []),
    rhythm: nil, isWall: false)
expect(deaf.findings.allSatisfy { $0.kind != .noSplitStep },
       "no split-step verdict without the opponent's contacts")
expect(deaf.notChecked.contains { $0.contains("Split steps") },
       "and it says so out loud")
expect(deaf.notChecked.contains { $0.contains("Recovery") },
       "recovery too")
expect(!deaf.notChecked.isEmpty && deaf.notChecked.count >= 2,
       "\(deaf.notChecked.count) checks reported as not run")

print("\na wall session is judged differently, not judged less:")
let wallRhythm = RallyRhythm(rallies: [30], medianInterval: 1.1, tempoSpread: 0.62)
let wall = SessionAnalyst.analyse(
    ownContacts: mine, opponentContacts: [], splitSteps: [],
    motion: motion(duration: 60, movingDuring: []),
    rhythm: wallRhythm, isWall: true)
expect(wall.findings.contains { $0.kind == .tempoDrift }, "ragged tempo flagged")
expect(!wall.findings.contains { $0.kind == .rootedAfterOwnShot },
       "standing still on a wall is not a fault")
expect(wall.notChecked.contains { $0.contains("wall has no contacts") },
       "and the reason is given rather than the check silently skipped")

print("\nshort sessions do not get verdicts:")
let short = SessionAnalyst.analyse(
    ownContacts: Array(mine.prefix(4)), opponentContacts: Array(theirs.prefix(4)),
    splitSteps: [], motion: motion(duration: 20, movingDuring: []),
    rhythm: nil, isWall: false)
expect(short.findings.isEmpty, "four rallies produce no findings")
expect(!short.notChecked.isEmpty, "but do produce reasons")

print(failures == 0 ? "\nall passed" : "\n\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
