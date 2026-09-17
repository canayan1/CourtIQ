import Foundation

/// What one player did, measured once per stroke.
///
/// Per stroke is the whole point. The first version of this pipeline measured
/// per sampled frame, and the headline number — court covered — moved 166%
/// between 12 fps and 6 fps on the same clip, because counting steps answers a
/// question about the sampling rate rather than about the player. An impact is
/// an event in the world; it happens the same number of times however often
/// anybody looked.
struct PlayerMetrics {
    /// Strokes this player was credited with.
    var strokes: Int
    /// Metres behind their own baseline at contact. Negative means inside the
    /// court — the player is taking the ball early.
    var contactDepth: Double
    /// Metres walked, run and scrambled between one of their contacts and the
    /// next.
    var metresPerStroke: Double
    /// How fast they were still moving at the moment of contact. Low is
    /// better: it means they arrived.
    var speedAtContact: Double
    /// Metres from the centre of the court at the midpoint between their own
    /// contacts — how far back towards the middle they actually got.
    var recoveryGap: Double
    /// Width of court used, from the 10th to the 90th percentile, so one
    /// stretched retrieval does not become the headline.
    var lateralSpread: Double
}

/// What one player did TO the other. These are the numbers that answer the
/// question the feature asks, because they measure the quality of a ball
/// through its effect rather than by looking at it — which matters when the
/// ball is a smear three pixels across.
struct PressureMetrics {
    /// Metres the opponent had to travel between this player's contact and
    /// their reply.
    var displacementForced: Double
    /// Seconds between this player's contact and the opponent's reply. Less
    /// is more.
    var timeTakenAway: Double
}

enum DuelMetrics {

    /// Court position at an arbitrary instant, interpolated between samples.
    /// Returns nil outside the track, rather than clamping to its ends — a
    /// stroke the camera did not see should be dropped, not invented.
    static func position(_ track: PlayerTrack, at t: Double) -> CourtPoint? {
        let s = track.samples
        guard let first = s.first, let last = s.last, t >= first.time, t <= last.time else { return nil }
        guard let i = s.firstIndex(where: { $0.time >= t }) else { return nil }
        if i == 0 { return s[0].court }
        let a = s[i - 1], b = s[i]
        let span = b.time - a.time
        guard span > 1e-6 else { return a.court }
        let f = (t - a.time) / span
        return CourtPoint(across: a.court.across + (b.court.across - a.court.across) * f,
                          depth: a.court.depth + (b.court.depth - a.court.depth) * f)
    }

    /// Distance walked along the track between two instants, in metres.
    static func pathLength(_ track: PlayerTrack, from t0: Double, to t1: Double) -> Double {
        let inside = track.samples.filter { $0.time > t0 && $0.time < t1 }.map(\.court)
        var points: [CourtPoint] = []
        if let a = position(track, at: t0) { points.append(a) }
        points.append(contentsOf: inside)
        if let b = position(track, at: t1) { points.append(b) }
        guard points.count > 1 else { return 0 }
        var total = 0.0
        for i in 1..<points.count {
            total += hypot(points[i].across - points[i-1].across, points[i].depth - points[i-1].depth)
        }
        return total
    }

    static func speed(_ track: PlayerTrack, at t: Double, window: Double = 0.3) -> Double? {
        guard let a = position(track, at: t - window), let b = position(track, at: t + window)
        else { return nil }
        return hypot(b.across - a.across, b.depth - a.depth) / (2 * window)
    }

    /// Metres behind this player's OWN baseline. Both ends measured the same
    /// way, which is what calibrating the court bought.
    static func behindBaseline(_ end: PlayerTrack.End, _ p: CourtPoint) -> Double {
        end == .near ? -p.depth : p.depth - CourtSpec.baselineToBaseline
    }

    static func measure(_ raw: PlayerTrack, impacts: [Double]) -> PlayerMetrics? {
        guard raw.isMeasurable else { return nil }
        let track = raw.smoothed()
        let own = impacts.filter { position(track, at: $0) != nil }.sorted()
        guard own.count >= 3 else { return nil }

        var depths: [Double] = [], speeds: [Double] = [], runs: [Double] = [], recoveries: [Double] = []
        for (i, t) in own.enumerated() {
            guard let p = position(track, at: t) else { continue }
            depths.append(behindBaseline(track.end, p))
            if let v = speed(track, at: t) { speeds.append(v) }
            guard i + 1 < own.count else { continue }
            let next = own[i + 1]
            runs.append(pathLength(track, from: t, to: next))
            // The middle of the gap is the closest thing to "after the shot,
            // before the next ball" that needs no opponent to define.
            if let mid = position(track, at: (t + next) / 2) { recoveries.append(abs(mid.across)) }
        }
        let across = track.samples.map(\.court.across).sorted()
        let spread = across.isEmpty ? 0
            : across[min(across.count - 1, across.count * 9 / 10)] - across[across.count / 10]

        return PlayerMetrics(strokes: own.count,
                             contactDepth: median(depths),
                             metresPerStroke: median(runs),
                             speedAtContact: median(speeds),
                             recoveryGap: median(recoveries),
                             lateralSpread: spread)
    }

    /// What this player's ball did to the other one. Needs both tracks and
    /// both players' impacts, so it only exists for a clip that actually
    /// contains a rally.
    static func pressure(by striker: PlayerTrack, strikes: [Double],
                         on rawOpponent: PlayerTrack, replies: [Double]) -> PressureMetrics? {
        guard striker.isMeasurable, rawOpponent.isMeasurable else { return nil }
        let opponent = rawOpponent.smoothed()
        var moved: [Double] = [], gaps: [Double] = []
        for t in strikes.sorted() {
            guard let reply = replies.first(where: { $0 > t + 0.2 }) else { continue }
            guard position(opponent, at: t) != nil, position(opponent, at: reply) != nil else { continue }
            moved.append(pathLength(opponent, from: t, to: reply))
            gaps.append(reply - t)
        }
        guard moved.count >= 3 else { return nil }
        return PressureMetrics(displacementForced: median(moved), timeTakenAway: median(gaps))
    }

    static func median(_ xs: [Double]) -> Double {
        guard !xs.isEmpty else { return .nan }
        let s = xs.sorted()
        return s.count % 2 == 1 ? s[s.count / 2] : (s[s.count / 2 - 1] + s[s.count / 2]) / 2
    }
}
