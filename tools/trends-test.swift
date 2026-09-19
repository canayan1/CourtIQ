// Checks the cross-session comparison against a history whose shape is known,
// and the two rules that now run from derived efforts.
//
//   swiftc -O tools/trends-test.swift CourtIQ/Features/BodySensing/{MovementDetector,RallyRhythm,\
//          SessionFindings,MatchStints,SensorEventCodec,SensingSessionStore,SessionTrends}.swift -o /tmp/t && /tmp/t

import Foundation

var failures = 0
func expect(_ ok: Bool, _ what: String) {
    print((ok ? "  ok   " : "  FAIL ") + what)
    if !ok { failures += 1 }
}

/// A session of `minutes`, rallying every 1.3 s, with the given readiness,
/// push hardness and whether the player pushes off after their own shots.
func session(id: String, drill: String, minutes: Double, readiness: Double,
             push: Double, recovers: Bool, day: Double) -> SensingSession {
    var events: [SensorEvent] = []
    var t = 0.0, mine = true, k = 0
    while t < minutes * 60 {
        events.append(.contact(t: t, strength: mine ? 0.8 : 0.07, owner: mine ? .player : .opponent))
        if mine, recovers { events.append(.effort(t: t + 0.5, peakPush: push)) }
        if !mine, Double(k % 10) < readiness * 10 { events.append(.splitStep(t: t - 0.2, landingG: 1.1)) }
        if !mine { k += 1 }
        mine.toggle(); t += 1.3
    }
    let dtos = events.compactMap { try? SensorEventCodec.dto($0) }
    return SensingSession(id: id, startedAt: Date(timeIntervalSince1970: day * 86400),
                          drill: drill, highRateMotion: false, events: dtos)
}

print("rules from derived efforts (the file path):")
let good = session(id: "g", drill: "match", minutes: 8, readiness: 1.0, push: 1.2, recovers: true, day: 1)
let ev = good.decodedEvents
let own = ev.compactMap { if case .contact(let t, _, .player) = $0 { return t }; return nil as Double? }
let opp = ev.compactMap { if case .contact(let t, _, .opponent) = $0 { return t }; return nil as Double? }
let hops = ev.compactMap { if case .splitStep(let t, let g) = $0 { return SplitStep(landing: t, unload: 0, landingG: g) }; return nil as SplitStep? }
let eff = ev.compactMap { if case .effort(let t, let p) = $0 { return (t: t, peak: p) }; return nil as (t: Double, peak: Double)? }
let f1 = SessionAnalyst.analyse(ownContacts: own, opponentContacts: opp, splitSteps: hops, motion: [], rhythm: nil, isWall: false, efforts: eff)
expect(!f1.notChecked.contains { $0.contains("Recovery") }, "recovery is CHECKED from efforts, not skipped")
expect(!f1.findings.contains { $0.kind == .rootedAfterOwnShot }, "and a player who pushes off is not flagged")
let rootedS = session(id: "r", drill: "match", minutes: 8, readiness: 1.0, push: 1.2, recovers: false, day: 1)
let ev2 = rootedS.decodedEvents
let own2 = ev2.compactMap { if case .contact(let t, _, .player) = $0 { return t }; return nil as Double? }
let f2 = SessionAnalyst.analyse(ownContacts: own2, opponentContacts: opp, splitSteps: hops, motion: [], rhythm: nil, isWall: false, efforts: [])
expect(f2.notChecked.contains { $0.contains("Recovery") }, "with neither motion nor efforts it says so")
let f3 = SessionAnalyst.analyse(ownContacts: own2, opponentContacts: opp, splitSteps: hops, motion: [], rhythm: nil, isWall: false,
                                efforts: [(t: 0.1, peak: 1.0)])   // one push, at the very start
expect(f3.findings.contains { $0.kind == .rootedAfterOwnShot && $0.weight == .clear }, "a player who never pushes off is flagged clearly")

print("\ntrend against the player's own history:")
let history = (1...4).map { session(id: "h\($0)", drill: "match", minutes: 8, readiness: 0.7, push: 1.2, recovers: true, day: Double($0)) }
let worse = session(id: "now", drill: "match", minutes: 8, readiness: 0.4, push: 0.8, recovers: true, day: 9)
let r = SessionTrends.compare(current: worse, history: history)
expect(r.baselineCount == 4, "baseline of \(r.baselineCount) same-drill sessions")
expect(r.notes.contains { $0.topic == .readiness }, "readiness drop noticed")
expect(r.notes.contains { $0.topic == .pushes }, "softer pushes noticed")
for n in r.notes { print("       \(n.sentence)") }
expect(!r.notes.contains { $0.sentence.lowercased().contains("carb") || $0.sentence.lowercased().contains("tired") },
       "and nothing about why")

let same = session(id: "same", drill: "match", minutes: 8, readiness: 0.7, push: 1.2, recovers: true, day: 9)
expect(SessionTrends.compare(current: same, history: history).notes.isEmpty, "a session like the usual produces no notes")

print("\nrefusals:")
let thin = SessionTrends.compare(current: worse, history: Array(history.prefix(2)))
expect(thin.notes.isEmpty && thin.notCompared != nil, "two previous sessions: not compared, and it says why")
let wallHist = (1...4).map { session(id: "w\($0)", drill: "wall", minutes: 8, readiness: 0.7, push: 1.2, recovers: true, day: Double($0)) }
let cross = SessionTrends.compare(current: worse, history: wallHist)
expect(cross.notCompared != nil, "a match is not compared with wall sessions")

print(failures == 0 ? "\nall passed" : "\n\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
