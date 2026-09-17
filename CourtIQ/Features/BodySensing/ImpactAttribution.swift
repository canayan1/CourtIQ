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
    /// amplitude, not a subtle difference. So rather than a threshold that
    /// would need retuning for every racket, court and belt position, the
    /// impacts are split where the gap between them is widest, and the result
    /// is only accepted if that gap is genuinely large.
    ///
    /// Returns nil when the strokes do not fall into two clear groups. That
    /// happens honestly — a solo wall session has only one player, and a clip
    /// where the phone sat on a bench has neither near nor far. Refusing is
    /// the right answer there; a forced split would hand every metric a
    /// silently wrong denominator.
    static func splitByLoudness(_ impacts: [(t: Double, strength: Double)],
                                minRatio: Double = 2.5) -> Split? {
        guard impacts.count >= 6 else { return nil }
        let sorted = impacts.sorted { $0.strength < $1.strength }
        let strengths = sorted.map(\.strength)

        // The widest RATIO between neighbouring strengths, not the widest
        // difference: loudness spans an order of magnitude, so a gap of 0.5
        // means something different at the quiet end than at the loud end.
        var bestCut = -1
        var bestRatio = 1.0
        for i in 1..<strengths.count {
            guard strengths[i - 1] > 1e-12 else { continue }
            let ratio = strengths[i] / strengths[i - 1]
            if ratio > bestRatio { bestRatio = ratio; bestCut = i }
        }
        guard bestCut > 0, bestRatio >= minRatio else { return nil }
        // Neither group may be a stray: a rally alternates, so a split that
        // leaves one player with a tenth of the strokes is not a rally.
        let quiet = bestCut, loud = strengths.count - bestCut
        guard min(quiet, loud) >= max(2, strengths.count / 6) else { return nil }

        return Split(own: sorted[bestCut...].map(\.t).sorted(),
                     opponent: sorted[..<bestCut].map(\.t).sorted(),
                     basis: .loudness)
    }
}
