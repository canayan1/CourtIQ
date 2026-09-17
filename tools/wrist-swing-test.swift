// Checks the wrist stroke detector against signals whose answer is known.
//
//   swiftc -O tools/wrist-swing-test.swift \
//          CourtIQ/Features/WatchSession/WristSwingDetector.swift -o /tmp/t && /tmp/t
//
// Written before any watch hardware is involved, because the algorithm can be
// wrong in ways a real session would hide: a detector that fires on every
// footfall still produces a plausible-looking stroke count, and a detector
// that misses the swing start still returns an impact. Synthetic strokes have
// a known time, a known wing and a known count, so each of those fails loudly.
//
// This does NOT replace calibrating against a hand-counted session. It only
// means that when the real numbers disagree, the algorithm is not the first
// suspect.

import Foundation

var failures = 0
func expect(_ ok: Bool, _ what: String) {
    print((ok ? "  ok   " : "  FAIL ") + what)
    if !ok { failures += 1 }
}

/// Deterministic noise, so a failure is reproducible.
struct Noise {
    var state: UInt64 = 0x9E3779B97F4A7C15
    mutating func next() -> Double {
        state ^= state << 13; state ^= state >> 7; state ^= state << 17
        return Double(state % 2000) / 1000.0 - 1.0     // -1 ... 1
    }
}

/// Builds a session: strokes at the given times, each a build of rotation into
/// a sharp contact spike. `wing` is +1 for one side and -1 for the other, the
/// way a forehand and a backhand turn the wrist opposite ways about gravity.
func synthesise(strokes: [(t: Double, wing: Double, peakG: Double)], duration: Double)
    -> ([AccelSample], [MotionSample]) {
    var noise = Noise()
    var accel: [AccelSample] = [], motion: [MotionSample] = []

    let accelRate = 800.0, motionRate = 200.0
    let swingBuild = 0.30          // seconds of forward swing before contact
    let contactWidth = 0.006       // a strike rings for about six milliseconds

    var t = 0.0
    while t < duration {
        var g = 1.0 + noise.next() * 0.03
        for s in strokes {
            let dt = t - s.t
            if dt > -swingBuild && dt <= 0 {
                // centripetal load building through the forward swing
                g += 1.6 * (1 + dt / swingBuild)
            }
            if abs(dt) < contactWidth {
                g += s.peakG * (1 - abs(dt) / contactWidth)
            }
        }
        accel.append(AccelSample(t: t, x: g, y: 0, z: 0))
        t += 1 / accelRate
    }

    t = 0
    while t < duration {
        var rot = noise.next() * 0.2
        var wing = 0.0
        for s in strokes {
            let dt = t - s.t
            if dt > -swingBuild && dt <= 0.05 {
                rot += s.wing * 22 * (1 + min(dt, 0) / swingBuild)
                wing = s.wing
            }
        }
        _ = wing
        // gravity down the z axis, so rotationAboutGravity reads the z term
        motion.append(MotionSample(t: t, rotX: 0, rotY: 0, rotZ: rot,
                                   gravX: 0, gravY: 0, gravZ: 1))
        t += 1 / motionRate
    }
    return (accel, motion)
}

print("counting:")
let times = [1.0, 2.4, 3.9, 5.2, 6.8, 8.1]
let (a1, m1) = synthesise(strokes: times.enumerated().map {
    ($0.element, $0.offset % 2 == 0 ? 1.0 : -1.0, 9.0) }, duration: 10)
let found = WristSwingDetector.swings(accel: a1, motion: m1)
expect(found.count == times.count, "six strokes in, \(found.count) out")
let drift = zip(found.map(\.impact), times).map { abs($0 - $1) }.max() ?? 99
expect(drift < 0.01, String(format: "contact times within %.0f ms", drift * 1000))

print("\nswing start:")
let starts = found.compactMap(\.swingDuration)
expect(starts.count == found.count, "every stroke got a start")
if !starts.isEmpty {
    let lo = starts.min()!, hi = starts.max()!
    expect(lo > 0.12 && hi < 0.55,
           String(format: "forward swing measured %.2f-%.2f s (built as 0.30)", lo, hi))
}
let bothWings = Set(found.compactMap { $0.peakRotation.map { $0 > 15 } })
expect(bothWings == [true], "both wings found, despite turning opposite ways")

print("\nrejections:")
// Bouncing a ball on the strings: real motion, but nothing like a strike.
let (a2, m2) = synthesise(strokes: [(1.0, 1.0, 0.8), (2.0, 1.0, 0.9)], duration: 4)
expect(WristSwingDetector.swings(accel: a2, motion: m2).isEmpty,
       "soft taps below the impact floor are not strokes")

// One strike ringing must not read as two.
let (a3, m3) = synthesise(strokes: [(1.0, 1.0, 9.0), (1.12, 1.0, 7.0)], duration: 3)
expect(WristSwingDetector.swings(accel: a3, motion: m3).count == 1,
       "two peaks 120 ms apart collapse to one stroke")

// A session with no strokes at all must not manufacture any from noise.
let (a4, m4) = synthesise(strokes: [], duration: 6)
expect(WristSwingDetector.swings(accel: a4, motion: m4).isEmpty,
       "still arm produces no strokes")

print("\nmissing sensors:")
let noMotion = WristSwingDetector.swings(accel: a1, motion: [])
expect(noMotion.count == times.count && noMotion.allSatisfy { $0.start == nil },
       "without the gyroscope, contacts still count and starts are nil, not guessed")

print(failures == 0 ? "\nall passed" : "\n\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
