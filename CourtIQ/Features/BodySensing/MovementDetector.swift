import Foundation

/// One device-motion reading from a phone worn on the body.
///
/// `userAcceleration` is what the body did, with gravity already removed by
/// CoreMotion; `gravity` says which way is down, which is what makes a hop
/// separable from a sideways shove no matter how the phone sits in its strap.
struct BodyMotionSample: Equatable {
    var t: Double
    var accX, accY, accZ: Double       // userAcceleration, g
    var gravX, gravY, gravZ: Double

    /// Acceleration along the up axis, in g. Positive is upward.
    var vertical: Double {
        -(accX * gravX + accY * gravY + accZ * gravZ)
    }

    /// Acceleration in the horizontal plane — running, pushing off, checking.
    var horizontal: Double {
        let v = vertical
        let total = (accX * accX + accY * accY + accZ * accZ)
        return max(0, total - v * v).squareRoot()
    }
}

/// A split step: the little hop a player makes as the opponent strikes, so
/// they land loaded and can push off either way.
struct SplitStep {
    /// When the player landed.
    var landing: Double
    /// How far the body unloaded before landing, in g below rest. A real
    /// split step gets light before it gets heavy.
    var unload: Double
    /// The landing spike, in g.
    var landingG: Double
}

/// What the body did, from a phone worn at the waist.
///
/// This is not a worse version of the wrist — it is a different measurement,
/// and the distinction decides what each sensor may claim. A racket strike
/// reaches the waist through arm, shoulder and trunk, by which point it is
/// smaller than the player's own footfalls; a phone on a belt cannot count
/// strokes and should not try. What it can do is the half the wrist is blind
/// to: where the feet went, how hard, and whether they were ready.
///
/// Human movement lives below about 5 Hz, so the phone's 100 Hz device motion
/// is not a compromise here. Nothing about footwork improves by moving the
/// sensor to the wrist, and most of it gets worse.
enum MovementDetector {

    /// A hop unloads the body before it lands. Below this share of resting
    /// load counts as airborne-ish.
    static let unloadFloor: Double = 0.25      // g below rest
    /// And lands harder than this.
    static let landingFloor: Double = 0.45     // g above rest
    /// The whole thing takes about this long. Shorter is a stumble, longer is
    /// a stride.
    static let hopWindow: ClosedRange<Double> = 0.10...0.45
    /// Two landings closer than this are one hop seen twice.
    static let minGap: Double = 0.40
    /// How much sideways drive is allowed at the moment of landing.
    ///
    /// This is what separates a split step from a stride, and without it the
    /// detector is useless: running has a flight phase too, so "light then
    /// heavy" alone reports a split step every other stride and hands the
    /// player a readiness score of 100% for a session in which they never
    /// split stepped once. A split step is made from a set position — the
    /// player is landing, not driving — while a runner is pushing the whole
    /// time. Five seconds of synthetic running went from five false hops to
    /// none on this one condition.
    static let settledHorizontal: Double = 0.35   // g

    /// Finds hops: an unloading followed closely by a landing.
    static func splitSteps(_ motion: [BodyMotionSample]) -> [SplitStep] {
        guard motion.count > 20 else { return [] }
        var found: [SplitStep] = []

        for i in motion.indices {
            let v = motion[i].vertical
            guard v < -unloadFloor else { continue }
            // Look forward for the landing that belongs to this unloading.
            var best: (t: Double, g: Double)? = nil
            for j in i..<motion.count {
                let dt = motion[j].t - motion[i].t
                if dt > hopWindow.upperBound { break }
                guard dt >= hopWindow.lowerBound else { continue }
                let lv = motion[j].vertical
                if lv > landingFloor, best == nil || lv > best!.g {
                    best = (motion[j].t, lv)
                }
            }
            guard let landing = best else { continue }
            // Was the player set, or mid-stride?
            let around = motion.filter { abs($0.t - landing.t) <= 0.20 }
            guard !around.isEmpty else { continue }
            let drive = around.map(\.horizontal).sorted()
            guard drive[drive.count / 2] < settledHorizontal else { continue }
            if let last = found.last, landing.t - last.landing < minGap {
                // Keep whichever landing was firmer.
                if landing.g > last.landingG {
                    found[found.count - 1] = SplitStep(landing: landing.t, unload: -v,
                                                       landingG: landing.g)
                }
                continue
            }
            found.append(SplitStep(landing: landing.t, unload: -v, landingG: landing.g))
        }
        return found
    }

    /// The share of the opponent's strokes the player was ready for.
    ///
    /// This is the measurement the two sensors make possible together and
    /// neither makes alone: the microphone says when the other player struck,
    /// the waist says whether this player was landing a split step at that
    /// moment. Club players are told to split step constantly and mostly do
    /// not, and until now nobody could tell them how often they actually did.
    ///
    /// The window is generous on purpose. A split step is coached to land AS
    /// the opponent strikes, but landing slightly early still leaves the
    /// player loaded, while landing late is the fault worth naming — so the
    /// window is wider before the strike than after it.
    static func readiness(splitSteps: [SplitStep], opponentContacts: [Double],
                          early: Double = 0.45, late: Double = 0.15)
        -> (share: Double, matched: Int, total: Int)? {
        guard opponentContacts.count >= 5 else { return nil }
        var matched = 0
        for contact in opponentContacts {
            if splitSteps.contains(where: { $0.landing > contact - early
                                         && $0.landing < contact + late }) {
                matched += 1
            }
        }
        return (Double(matched) / Double(opponentContacts.count), matched, opponentContacts.count)
    }

    /// Hard changes of direction — the thing that actually tires a player out
    /// and the thing a step count cannot see.
    ///
    /// Counted from horizontal acceleration rather than speed, because on a
    /// court almost every effort is an acceleration: two steps and a stop.
    static func efforts(_ motion: [BodyMotionSample], above: Double = 0.6,
                        minGap: Double = 0.5) -> [Double] {
        var out: [Double] = []
        for s in motion where s.horizontal > above {
            if let last = out.last, s.t - last < minGap { continue }
            out.append(s.t)
        }
        return out
    }

    /// Work and rest, from the movement itself rather than from a timer.
    /// In a match this separates the points from the walking; in a drill it
    /// shows whether the feed is keeping the player honest.
    static func workRest(_ motion: [BodyMotionSample], busy: Double = 0.25)
        -> (workShare: Double, longestRest: Double)? {
        guard motion.count > 40, let first = motion.first, let last = motion.last,
              last.t > first.t else { return nil }
        var working = 0.0, restStart: Double? = nil, longestRest = 0.0
        for i in 1..<motion.count {
            let dt = motion[i].t - motion[i - 1].t
            guard dt > 0, dt < 1 else { continue }
            if motion[i].horizontal > busy {
                working += dt
                if let s = restStart { longestRest = max(longestRest, motion[i].t - s) }
                restStart = nil
            } else if restStart == nil {
                restStart = motion[i].t
            }
        }
        if let s = restStart { longestRest = max(longestRest, last.t - s) }
        return (working / (last.t - first.t), longestRest)
    }
}
