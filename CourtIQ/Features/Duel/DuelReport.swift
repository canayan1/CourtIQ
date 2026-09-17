import Foundation

/// Which hand the player holds the racket in. Asked, not guessed: nothing in
/// this pipeline can see a grip, and a wrong assumption here does not degrade
/// the report, it mirrors it.
///
/// Deliberately NOT `SwingHandedness`, which the swing-analysis consent screen
/// already defines as right-or-left. That screen makes the player choose
/// before anything runs, so two states are all it can be in. Here the player
/// may never have been asked — the clip is of somebody else, or the question
/// has not come up yet — and "not told" has to be representable, because the
/// whole point is that an unasked question produces no claim about a wing
/// rather than a coin flip. Bridge the two where they meet rather than
/// widening the existing type, which would break every exhaustive switch over
/// it for no gain.
enum RacketHand: String, Codable, CaseIterable {
    case right, left, unknown
}

/// One of the two players in the clip, as the app names them to the user.
///
/// The end of the court is the identity. It is the only thing about a player
/// that is stable for the whole clip and visible without recognising anybody,
/// and it is also the only thing the viewer can verify at a glance — which is
/// why the label says where they were standing rather than just a number.
struct DuelPlayer {
    enum Number: Int { case one = 1, two = 2 }

    var number: Number
    var end: PlayerTrack.End
    var handedness: RacketHand = .unknown
    /// What the user typed, if they bothered.
    var name: String?

    /// Never just "Player 1". A number alone leaves the viewer guessing which
    /// of the two people on their screen is being talked about, and the whole
    /// feature is a comparison between them.
    var label: String {
        let who = name ?? "Player \(number.rawValue)"
        return end == .near ? "\(who), nearest the camera" : "\(who), across the net"
    }

    /// The `across` sign of this player's forehand side of the court.
    ///
    /// Get this wrong and every wing in the report is mirrored, so: `across`
    /// is positive to the RIGHT OF THE IMAGE, always. The near player has
    /// their back to the camera and faces the net, so their right hand is on
    /// the image's right — a right-hander's forehand side is positive. The far
    /// player faces the camera, so their right hand is on the image's LEFT and
    /// the sign flips. Left-handers flip again.
    var forehandSideSign: Double? {
        switch handedness {
        case .unknown: return nil
        case .right:   return end == .near ? 1 : -1
        case .left:    return end == .near ? -1 : 1
        }
    }
}

/// What a player did on one side of their court.
struct WingSplit {
    /// Metrics from the strokes met on the forehand side of the court, and on
    /// the backhand side. Both nil when handedness was never given — the
    /// measurement still exists, it just cannot be named a wing.
    var forehand: PlayerMetrics?
    var backhand: PlayerMetrics?
    /// The same split without naming wings: left and right of the image.
    var imageLeft: PlayerMetrics?
    var imageRight: PlayerMetrics?
    var strokesShort: Bool
}

enum DuelReport {

    /// Below this many strokes on a side, a difference between the sides is
    /// the clip being short rather than the player being lopsided. Eleven
    /// strokes split two ways is five and five, which says nothing.
    static let minStrokesPerSide = 8

    static func wings(_ track: PlayerTrack, impacts: [Double], player: DuelPlayer) -> WingSplit {
        let smooth = track.smoothed()
        var left: [Double] = [], right: [Double] = []
        for t in impacts {
            guard let p = DuelMetrics.position(smooth, at: t), p.across.isFinite else { continue }
            if p.across < 0 { left.append(t) } else { right.append(t) }
        }
        let short = min(left.count, right.count) < minStrokesPerSide
        let lm = DuelMetrics.measure(track, impacts: left)
        let rm = DuelMetrics.measure(track, impacts: right)
        var split = WingSplit(forehand: nil, backhand: nil,
                              imageLeft: lm, imageRight: rm, strokesShort: short)
        if let sign = player.forehandSideSign {
            split.forehand = sign > 0 ? rm : lm
            split.backhand = sign > 0 ? lm : rm
        }
        return split
    }

    /// Sentences the measurement actually supports.
    ///
    /// Two rules hold the line. Nothing is said about a wing unless both sides
    /// carry enough strokes to compare. And nothing is said about technique:
    /// this pipeline sees feet on a court, so it may report WHERE a player met
    /// the ball and how far they had to go to get there, and it may not report
    /// how the stroke looked, how much spin it carried, or which wing is
    /// "better" as a piece of tennis.
    static func sentences(for player: DuelPlayer, wings: WingSplit,
                          precisionCm: Double) -> [String] {
        guard let fh = wings.forehand, let bh = wings.backhand else {
            if wings.imageLeft != nil || wings.imageRight != nil {
                return ["\(player.label): which side is the forehand depends on "
                        + "which hand they play with — tell the app and this "
                        + "splits into wings."]
            }
            return []
        }
        guard !wings.strokesShort else {
            return ["\(player.label): too few strokes on one side to compare "
                    + "the wings — \(minStrokesPerSide) each is the floor."]
        }

        var out: [String] = []
        // A difference has to clear the clip's own resolution before it is
        // worth a sentence. Ten centimetres is generous next to the couple of
        // centimetres a pixel is worth near the camera, and honest next to the
        // forty it is worth at the far baseline.
        let floor = max(0.10, precisionCm / 100 * 3)

        let depthGap = bh.contactDepth - fh.contactDepth
        if abs(depthGap) > floor {
            let deeper = depthGap > 0 ? "backhand" : "forehand"
            out.append(String(format: "%@ meets the ball %.2f m further behind the "
                              + "baseline on the %@ side of the court.",
                              player.label, abs(depthGap), deeper))
        }
        let runGap = bh.metresPerStroke - fh.metresPerStroke
        if abs(runGap) > floor {
            let harder = runGap > 0 ? "backhand" : "forehand"
            out.append(String(format: "They cover %.2f m more per stroke on the %@ side.",
                              abs(runGap), harder))
        }
        let setGap = bh.speedAtContact - fh.speedAtContact
        if abs(setGap) > 0.25 {
            let rushed = setGap > 0 ? "backhand" : "forehand"
            out.append(String(format: "They are still moving %.2f m/s faster at contact on "
                              + "the %@ side — arriving later to those balls.",
                              abs(setGap), rushed))
        }
        if out.isEmpty {
            out.append("\(player.label): the two sides of the court measure the "
                       + "same within what this clip can resolve.")
        }
        return out
    }
}
