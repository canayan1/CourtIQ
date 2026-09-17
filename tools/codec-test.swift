// Checks the wrist-to-phone codec and the stint path a watch actually uses.
//
//   swiftc -O tools/codec-test.swift \
//          CourtIQ/Features/BodySensing/{MovementDetector,MatchStints,SensorEventCodec}.swift -o /tmp/c && /tmp/c
//
// Two promises are checked here that nothing else checks. Raw motion must be
// REFUSED at the codec, not dropped, so a caller that tries to ship it finds
// out. And a stint built from derived events — what a watch sends — must come
// out with the same fields as one built from raw motion, because otherwise
// "the same data from phone and watch" is a sentence and not a fact.

import Foundation

var failures = 0
func expect(_ ok: Bool, _ what: String) {
    print((ok ? "  ok   " : "  FAIL ") + what)
    if !ok { failures += 1 }
}

print("round trip, every kind that may travel:")
let travel: [SensorEvent] = [
    .contact(t: 1.25, strength: 0.8, owner: .player),
    .contact(t: 2.5, strength: 0.07, owner: .opponent),
    .contact(t: 3.0, strength: 0.3, owner: .unknown),
    .heartRate(t: 4.0, bpm: 142),
    .changeover(t: 120.5),
    .splitStep(t: 2.3, landingG: 1.1),
    .effort(t: 1.6, peakPush: 1.3),
    .activity(t: 20, movingShare: 0.42),
]
do {
    let data = try SensorEventCodec.encode(travel)
    let back = try SensorEventCodec.decode(data)
    expect(back == travel, "\(back.count) of \(travel.count) events survive encode/decode unchanged")
    expect(data.count < 700, "\(data.count) bytes for eight events — small enough to queue for an hour")
} catch { expect(false, "codec threw: \(error)") }

print("\nraw motion is refused, not dropped:")
let raw: [SensorEvent] = [.contact(t: 1, strength: 0.5, owner: .player),
                          .motion(BodyMotionSample(t: 1, accX: 0, accY: 0, accZ: 0, gravX: 0, gravY: 0, gravZ: 1))]
do { _ = try SensorEventCodec.encode(raw); expect(false, "encoding raw motion should throw") }
catch { expect(true, "encode threw rather than quietly shipping motion") }

print("\na stint from derived events — the watch path — carries the same fields:")
// Two stints. Nothing in either is raw motion; everything is what the wrist concluded.
func derivedStint(from t0: Double, hops: Bool, push: Double, hr: Double) -> [SensorEvent] {
    var e: [SensorEvent] = []
    var t = t0
    var mine = true
    while t < t0 + 100 {
        e.append(.contact(t: t, strength: mine ? 0.8 : 0.07, owner: mine ? .player : .opponent))
        if mine { e.append(.effort(t: t + 0.4, peakPush: push)) }
        else if hops { e.append(.splitStep(t: t - 0.2, landingG: 1.1)) }
        mine.toggle(); t += 1.3
    }
    for k in 0..<5 { e.append(.activity(t: t0 + Double(k) * 20, movingShare: 0.5)); e.append(.heartRate(t: t0 + Double(k) * 20, bpm: hr)) }
    return e
}
var events = derivedStint(from: 0, hops: true, push: 1.2, hr: 140)
events.append(.changeover(t: 101))
events += derivedStint(from: 102, hops: false, push: 0.7, hr: 156)
let stints = StintBuilder.stints(from: events)
expect(stints.count == 2, "\(stints.count) stints from a marked changeover")
if stints.count == 2 {
    expect(stints[0].efforts > 30, "efforts counted from .effort events (\(stints[0].efforts))")
    expect(abs(stints[0].medianPeakPush - 1.2) < 0.01, "push peak read from events (\(stints[0].medianPeakPush))")
    expect(abs(stints[0].movingShare - 0.5) < 0.01, "moving share read from .activity (\(stints[0].movingShare))")
    expect((stints[0].readiness ?? 0) > 0.9, String(format: "readiness from .splitStep events %.0f%%", (stints[0].readiness ?? 0) * 100))
    expect((stints[1].readiness ?? 1) < 0.1, String(format: "and %.0f%% when the hops stop", (stints[1].readiness ?? 0) * 100))
    let notes = BenchReport.compare(latest: stints[1], previous: stints[0])
    expect(notes.contains { $0.topic == .pushes } && notes.contains { $0.topic == .readiness } && notes.contains { $0.topic == .heartRate },
           "bench card reads a watch session exactly as it reads a phone one (\(notes.count) notes)")
    for n in notes { print("       \(n.sentence)") }
}

print(failures == 0 ? "\nall passed" : "\n\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
