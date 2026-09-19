// Checks that the drill decides which rules are fair, and that a rule that
// does not apply says so in the drill's own terms instead of vanishing.
//
//   swiftc -O tools/drills-test.swift \
//          CourtIQ/Features/BodySensing/{MovementDetector,RallyRhythm,SessionModels,SessionFindings}.swift -o /tmp/d && /tmp/d

import Foundation

var failures = 0
func expect(_ ok: Bool, _ what: String) {
    print((ok ? "  ok   " : "  FAIL ") + what)
    if !ok { failures += 1 }
}

let beat = 1.4
let mine = (0..<20).map { Double($0) * beat * 2 + 1.0 }
let theirs = (0..<20).map { Double($0) * beat * 2 + 1.0 + beat }
let noHops: [SplitStep] = []
// Hard pushes at the moment of every own contact, and nothing between shots.
let pushesAtContact = mine.map { (t: $0, peak: 2.2) }

func run(_ drill: DrillContext.Kind, opp: [Double] = theirs, hops: [SplitStep] = noHops,
         efforts: [(t: Double, peak: Double)] = [], rhythm: RallyRhythm? = nil) -> SessionFindings {
    SessionAnalyst.analyse(ownContacts: mine, opponentContacts: opp, splitSteps: hops,
                           motion: [], rhythm: rhythm, drill: drill, efforts: efforts)
}
func kinds(_ f: SessionFindings) -> Set<Finding.Kind> { Set(f.findings.map(\.kind)) }

print("a match checks everything a rally can be judged on:")
let match = run(.match, efforts: pushesAtContact)
expect(kinds(match).contains(.noSplitStep), "flat-footed flagged")
expect(kinds(match).contains(.rootedAfterOwnShot), "rooted flagged (pushes only at contact, none between)")
expect(kinds(match).contains(.lateToTheBall), "late flagged")
expect(!kinds(match).contains(.tempoDrift), "tempo drift NOT judged in a match — rallies vary by design")

print("\na serving session:")
let ragged = RallyRhythm(rallies: [40], medianInterval: 8, tempoSpread: 0.6)
let serve = run(.serve, opp: [], efforts: pushesAtContact, rhythm: ragged)
expect(!kinds(serve).contains(.noSplitStep) && !kinds(serve).contains(.rootedAfterOwnShot)
       && !kinds(serve).contains(.lateToTheBall), "no rally rule fires")
expect(serve.notChecked.contains { $0.contains("no opponent's shot") }, "split step: reason names the drill")
expect(serve.notChecked.contains { $0.contains("nothing comes back") }, "recovery: reason names the drill")
expect(serve.notChecked.contains { $0.contains("standstill") }, "late: reason names the drill")
expect(kinds(serve).contains(.tempoDrift), "but a ragged serving rhythm IS flagged")

print("\nvolleys:")
let volley = run(.volley, efforts: pushesAtContact)
expect(kinds(volley).contains(.noSplitStep), "split step still judged at the net")
expect(!kinds(volley).contains(.lateToTheBall), "moving into the ball is not lateness")
expect(volley.notChecked.contains { $0.contains("INTO the ball") }, "and the reason says so")
expect(!kinds(volley).contains(.rootedAfterOwnShot), "no recovery verdict between volleys")

print("\ncross-court forehands with a feeder:")
let xfh = run(.crossCourtForehand, efforts: pushesAtContact, rhythm: ragged)
expect(kinds(xfh).contains(.rootedAfterOwnShot), "recovery judged — the feeder's ball comes back")
expect(kinds(xfh).contains(.tempoDrift), "one wing: a ragged tempo is flagged")

print("\nthe wall behaves as before, now from the table:")
let wall = run(.wall, opp: [], rhythm: ragged)
expect(wall.notChecked.contains { $0.contains("wall has no contacts") }, "split step excused")
expect(wall.notChecked.contains { $0.contains("comes back to where you are standing") }, "recovery excused")
expect(kinds(wall).contains(.tempoDrift), "tempo judged")

print("\nthe old isWall entry point still means what it meant:")
let viaOld = SessionAnalyst.analyse(ownContacts: mine, opponentContacts: theirs, splitSteps: noHops,
                                    motion: [], rhythm: nil, isWall: false, efforts: pushesAtContact)
expect(kinds(viaOld) == kinds(match), "isWall: false == .freePlay == a match's rules")

print(failures == 0 ? "\nall passed" : "\n\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
