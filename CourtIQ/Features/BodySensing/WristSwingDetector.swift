import Foundation

/// One accelerometer reading from the wrist, in g.
struct AccelSample {
    var t: Double
    var x, y, z: Double
    var magnitude: Double { (x * x + y * y + z * z).squareRoot() }
}

/// One device-motion reading: rotation rate in rad/s, plus the gravity
/// direction that tells us which way is down.
struct MotionSample {
    var t: Double
    var rotX, rotY, rotZ: Double
    var gravX, gravY, gravZ: Double

    /// How fast the wrist is turning AROUND the gravity axis. A tennis swing
    /// is mostly a rotation in the horizontal plane, so this is the component
    /// that rises through the forward swing and is the cleanest signal for
    /// where a stroke began.
    var rotationAboutGravity: Double {
        rotX * gravX + rotY * gravY + rotZ * gravZ
    }
}

/// One detected stroke.
struct WristSwing {
    /// When the ball met the strings, from the high-rate accelerometer.
    var impact: Double
    /// When the forward swing began, from the rotation signal.
    var start: Double?
    /// How much the strike added ON TOP of the load the swing was already
    /// carrying, in g. Not the raw peak: a forward swing puts a couple of g
    /// through the wrist all by itself, so a raw threshold passes a barely
    /// touched ball at the end of a hard swing and fails a firm block.
    var impactG: Double
    /// Peak rotation rate during the swing, rad/s.
    var peakRotation: Double?
    /// Seconds from the start of the forward swing to contact.
    var swingDuration: Double? {
        guard let s = start else { return nil }
        return impact - s
    }
}

/// Finds strokes in wrist motion.
///
/// The phone hears strokes; the watch feels them, and feels them better. The
/// audio detector works on a 10 ms envelope and over-counts by 20-45% on raw
/// audio because a wall bounce and a racket sound alike. `CMBatchedSensorManager`
/// gives 800 Hz accelerometer and 200 Hz device motion on the wrist, which is
/// what Apple built it for — impact from the fast accelerometer, swing start
/// from rotation about gravity — and the wrist has no opinion about anybody
/// else's shots. That last part matters more than the precision: whose stroke
/// it was is the question the camera pipeline cannot answer at all.
///
/// The peak-picking is deliberately the same shape as `BallImpactAudio`:
/// adaptive threshold at median + K·MAD, then a minimum gap where the
/// strongest peak in each window wins. That algorithm is already calibrated
/// against hand-counted sessions in this project, and reusing its discipline
/// means the two detectors fail in the same understood ways rather than in two
/// new ones.
enum WristSwingDetector {

    /// Strokes come no faster than this, even in a fed drill. Below it we are
    /// looking at one strike ringing, not two strokes.
    static let minGap: Double = 0.45
    static let madK: Double = 6.0
    /// A ball strike is a sharp transient ON TOP of whatever the swing was
    /// already doing. Anything gentler is a ball bounced on the strings, a
    /// racket tapped on a shoe, or a hand gesture.
    static let minImpactG: Double = 2.0
    /// The stretch just before contact whose load counts as "what the swing
    /// was already carrying" — far enough back not to include the strike,
    /// close enough to be the same swing.
    static let baselineWindow: ClosedRange<Double> = 0.015...0.050
    /// How far back from an impact to look for the start of the forward swing.
    static let swingLookback: Double = 0.9

    /// Detects impacts in the accelerometer stream.
    ///
    /// Works on the DIFFERENCE between consecutive magnitudes rather than the
    /// magnitudes themselves. A strike is a step change, while the arm's own
    /// swing is a slow build, and differentiating separates them — the same
    /// reason the audio stage high-passes before taking its envelope.
    static func impacts(accel: [AccelSample]) -> [(t: Double, g: Double)] {
        guard accel.count > 16 else { return [] }
        var jerk: [Double] = []
        jerk.reserveCapacity(accel.count)
        jerk.append(0)
        for i in 1..<accel.count {
            jerk.append(abs(accel[i].magnitude - accel[i - 1].magnitude))
        }

        let threshold = Stats.madThreshold(jerk, k: madK)

        // How much this peak stands out from the load the arm was already
        // under, which is what separates a strike from a swing.
        func prominence(_ i: Int) -> Double {
            let t = accel[i].t
            let window = accel.filter { t - $0.t >= baselineWindow.lowerBound
                                     && t - $0.t <= baselineWindow.upperBound }
            guard !window.isEmpty else { return 0 }
            let loads = window.map(\.magnitude).sorted()
            return accel[i].magnitude - loads[loads.count / 2]
        }

        let above = jerk.indices.filter { jerk[$0] > threshold }
        guard !above.isEmpty else { return [] }

        var kept: [(Int, Double)] = []
        for i in above.sorted(by: { jerk[$0] > jerk[$1] }) {
            guard kept.allSatisfy({ abs(accel[$0.0].t - accel[i].t) >= minGap }) else { continue }
            let p = prominence(i)
            guard p >= minImpactG else { continue }
            kept.append((i, p))
        }
        return kept.sorted { accel[$0.0].t < accel[$1.0].t }.map { (accel[$0.0].t, $0.1) }
    }

    /// Pairs each impact with the moment its forward swing began.
    ///
    /// Walks back from contact through the rotation signal until the wrist
    /// stops turning the way it was turning into the ball. The sign matters:
    /// a forehand and a backhand rotate opposite ways about gravity, so the
    /// search follows whichever direction the swing itself was going rather
    /// than assuming one.
    static func swings(accel: [AccelSample], motion: [MotionSample]) -> [WristSwing] {
        let hits = impacts(accel: accel)
        guard !motion.isEmpty else {
            return hits.map { WristSwing(impact: $0.t, start: nil, impactG: $0.g, peakRotation: nil) }
        }
        let rot = motion.map { (t: $0.t, r: $0.rotationAboutGravity) }

        return hits.map { hit in
            let window = rot.filter { $0.t <= hit.t && $0.t >= hit.t - swingLookback }
            guard window.count > 3 else {
                return WristSwing(impact: hit.t, start: nil, impactG: hit.g, peakRotation: nil)
            }
            // The direction of the swing is the sign of the biggest rotation
            // in the run-up, not a constant.
            let peak = window.max { abs($0.r) < abs($1.r) }!
            let direction: Double = peak.r >= 0 ? 1 : -1
            // The swing began where rotation in that direction last sat near
            // zero before building.
            let quiet = abs(peak.r) * 0.15
            var start: Double? = nil
            for s in window.reversed() where s.t <= peak.t {
                if s.r * direction < quiet { start = s.t; break }
            }
            return WristSwing(impact: hit.t, start: start, impactG: hit.g,
                              peakRotation: abs(peak.r))
        }
    }
}
