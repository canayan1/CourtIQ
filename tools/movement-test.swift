// Checks the body-worn movement detector against signals whose answer is known.
//
//   swiftc -O tools/movement-test.swift \
//          CourtIQ/Features/BodySensing/MovementDetector.swift -o /tmp/m && /tmp/m
//
// The hardest thing to get right here is NOT finding split steps — it is not
// finding them everywhere else. Running has a flight phase too, so a detector
// that looks only for "light then heavy" will report a split step for every
// other stride and hand the player a readiness score of 100% while they never
// split stepped once. So the running case is a test, not an afterthought.

import Foundation

var failures = 0
func expect(_ ok: Bool, _ what: String) {
    print((ok ? "  ok   " : "  FAIL ") + what)
    if !ok { failures += 1 }
}

struct Noise {
    var state: UInt64 = 0xD1B54A32D192ED03
    mutating func next() -> Double {
        state ^= state << 13; state ^= state >> 7; state ^= state << 17
        return Double(state % 2000) / 1000.0 - 1.0
    }
}

/// Builds a waist signal. `hops` are split steps: the player gets light, then
/// lands on two feet while otherwise standing still. `runFrom`/`runTo` is a
/// stretch of running, which also has a flight phase but never stops moving
/// sideways.
func synthesise(hops: [Double], running: [(Double, Double)], duration: Double)
    -> [BodyMotionSample] {
    var noise = Noise()
    var out: [BodyMotionSample] = []
    var t = 0.0
    let rate = 100.0
    while t < duration {
        var vert = noise.next() * 0.05
        var horiz = abs(noise.next()) * 0.05

        for h in hops {
            let dt = t - h
            if dt > -0.22 && dt < -0.06 { vert -= 0.55 }        // unloading
            if dt > -0.03 && dt < 0.04 { vert += 1.10 }          // two-footed landing
        }
        for (a, b) in running where t >= a && t <= b {
            // strides at about 2.8 per second, with their own flight phase
            let phase = (t - a).truncatingRemainder(dividingBy: 0.357) / 0.357
            if phase < 0.35 { vert -= 0.50 }
            if phase > 0.45 && phase < 0.55 { vert += 0.75 }
            horiz += 0.9                                          // and always driving
        }

        // gravity down z: vertical is -(acc . grav), so put the signal on -z
        out.append(BodyMotionSample(t: t, accX: horiz, accY: 0, accZ: -vert,
                                    gravX: 0, gravY: 0, gravZ: 1))
        t += 1 / rate
    }
    return out
}

print("split steps, standing:")
let hops = [1.0, 2.5, 4.0, 5.5, 7.0]
let still = synthesise(hops: hops, running: [], duration: 9)
let foundStill = MovementDetector.splitSteps(still)
expect(foundStill.count == hops.count, "five hops in, \(foundStill.count) out")
let err = zip(foundStill.map(\.landing), hops).map { abs($0 - $1) }.max() ?? 99
expect(err < 0.06, String(format: "landings within %.0f ms", err * 1000))

print("\nrunning must not read as split steps:")
let run = synthesise(hops: [], running: [(1.0, 6.0)], duration: 8)
let foundRun = MovementDetector.splitSteps(run)
expect(foundRun.isEmpty, "five seconds of running produced \(foundRun.count) split steps")

print("\nreadiness against the opponent's contacts:")
// Opponent strikes; the player lands a split step just before each one.
let contacts = hops.map { $0 + 0.20 }
if let r = MovementDetector.readiness(splitSteps: foundStill, opponentContacts: contacts) {
    expect(r.share > 0.95, String(format: "split stepping on every ball -> %.0f%%", r.share * 100))
} else { expect(false, "readiness returned nothing") }
// The same hops against contacts that have nothing to do with them.
let unrelated = hops.map { $0 + 0.95 }
if let r = MovementDetector.readiness(splitSteps: foundStill, opponentContacts: unrelated) {
    expect(r.share < 0.25, String(format: "hops unrelated to the ball -> %.0f%%", r.share * 100))
} else { expect(false, "readiness returned nothing") }
expect(MovementDetector.readiness(splitSteps: foundStill, opponentContacts: [1.0, 2.0]) == nil,
       "two contacts is not enough to quote a share")

print("\nefforts and work-rest:")
let mixed = synthesise(hops: [], running: [(1.0, 3.0), (6.0, 8.0)], duration: 12)
let efforts = MovementDetector.efforts(mixed)
expect(!efforts.isEmpty, "running shows up as efforts (\(efforts.count))")
if let wr = MovementDetector.workRest(mixed) {
    expect(wr.workShare > 0.25 && wr.workShare < 0.45,
           String(format: "4 s of work in 12 -> %.0f%% working", wr.workShare * 100))
    expect(wr.longestRest > 2.5,
           String(format: "longest rest %.1f s", wr.longestRest))
} else { expect(false, "workRest returned nothing") }

print(failures == 0 ? "\nall passed" : "\n\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
