import Foundation

/// Whose stroke was that.
///
/// One microphone hears both players, and until this is answered nothing about
/// either of them can be measured: a stroke count that includes the opponent's
/// is not a stroke count, and the readiness metric is meaningless without
/// knowing when the OTHER player struck. The camera pipeline is blocked on
/// exactly this question and has no way to answer it.
///
/// A body-worn sensor does. Two ways, depending on what the player is wearing,
/// and they are not equally good — the first is a fact and the second is an
/// inference, so they are kept apart rather than blended.
enum ImpactAttribution {

    struct Split {
        var own: [Double]
        var opponent: [Double]
        /// How the split was made, so nothing downstream forgets which of
        /// these it is looking at.
        var basis: Basis
        enum Basis: String { case motion, loudness }
    }

    /// With motion available, this is not an inference at all. The wrist felt
    /// the strokes it made; every other impact the microphone heard belonged
    /// to somebody else.
    ///
    /// `tolerance` allows for the two clocks disagreeing and for sound taking
    /// time to travel the metre from strings to microphone.
    static func split(audioImpacts: [Double], ownSwings: [Double],
                      tolerance: Double = 0.12) -> Split {
        var own: [Double] = [], opponent: [Double] = []
        for t in audioImpacts.sorted() {
            if ownSwings.contains(where: { abs($0 - t) <= tolerance }) { own.append(t) }
            else { opponent.append(t) }
        }
        return Split(own: own, opponent: opponent, basis: .motion)
    }

    /// With only a microphone, loudness has to do it.
    ///
    /// The player's own racket is about a metre away and the other end of the
    /// court is twelve to twenty-five, so the two populations sit twenty to
    /// thirty decibels apart — which is a factor of ten to thirty in
    /// amplitude, not a subtle difference.
    ///
    /// Returns nil when the strokes do not fall into two clear groups, which
    /// happens honestly: a clip recorded from across the court hears every
    /// contact at much the same distance and has no near population at all.
    /// Refusing is the right answer there; a forced split would hand every
    /// metric a silently wrong denominator.
    static func splitByLoudness(_ impacts: [(t: Double, strength: Double)],
                                minRatio: Double = 2.5) -> Split? {
        guard let c = cluster(impacts, minRatio: minRatio) else { return nil }
        return Split(own: c.loud, opponent: c.quiet, basis: .loudness)
    }

    /// The same separation, on a wall, where the two populations mean
    /// something else entirely.
    ///
    /// A wall rally makes two sounds per cycle: the racket, and the ball
    /// coming off the wall. Both are the player's, so nothing here is about
    /// whose stroke it was — the quiet population is the REBOUND, and only the
    /// loud one is a stroke to be counted.
    ///
    /// Whether the two separate at all is a question about where the phone is,
    /// and it is worth stating because the answer flips. Measured on a wall
    /// session filmed from about twenty metres, the strengths form one
    /// continuum: the widest gap between neighbouring impacts is 1.64x, which
    /// is no gap at all, because from there the racket and the wall are both
    /// twenty metres away. In a pocket the racket is 0.8 m and the rebound
    /// comes from roughly the standing distance, so at four metres the ratio
    /// is about twenty-five to one in intensity. That is the whole argument
    /// for the pocket, and it is a prediction until a pocket recording is
    /// measured — which is exactly what this returning nil versus not will
    /// settle.
    static func separateWallBounces(_ impacts: [(t: Double, strength: Double)],
                                    minRatio: Double = 2.5)
        -> (strokes: [Double], rebounds: [Double])? {
        guard let c = cluster(impacts, minRatio: minRatio) else { return nil }
        return (strokes: c.loud, rebounds: c.quiet)
    }

    /// Splits impacts into a quiet and a loud population, or declines.
    ///
    /// One primitive with two named wrappers, rather than the algorithm
    /// written twice: what the two groups MEAN depends entirely on the
    /// context, and giving each meaning its own door is what stops a wall
    /// rebound from being reported as an opponent.
    ///
    /// The cut goes where the RATIO between neighbouring strengths is widest,
    /// not the difference: loudness spans an order of magnitude, so a gap of
    /// 0.5 means something different at the quiet end than at the loud end.
    /// Fixed thresholds are avoided on purpose — they would need retuning for
    /// every racket, court, pocket and phone.
    static func cluster(_ impacts: [(t: Double, strength: Double)], minRatio: Double)
        -> (quiet: [Double], loud: [Double])? {
        guard impacts.count >= 6 else { return nil }
        let sorted = impacts.sorted { $0.strength < $1.strength }
        let strengths = sorted.map(\.strength)

        var bestCut = -1
        var bestRatio = 1.0
        for i in 1..<strengths.count {
            guard strengths[i - 1] > 1e-12 else { continue }
            let ratio = strengths[i] / strengths[i - 1]
            if ratio > bestRatio { bestRatio = ratio; bestCut = i }
        }
        guard bestCut > 0, bestRatio >= minRatio else { return nil }
        // Neither group may be a stray: one loud bang among quiet strokes is a
        // dropped racket, not a population.
        let quiet = bestCut, loud = strengths.count - bestCut
        guard min(quiet, loud) >= max(2, strengths.count / 6) else { return nil }

        return (quiet: sorted[..<bestCut].map(\.t).sorted(),
                loud: sorted[bestCut...].map(\.t).sorted())
    }
}
