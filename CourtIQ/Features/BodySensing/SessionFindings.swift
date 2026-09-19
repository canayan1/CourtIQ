import Foundation

/// One thing the player should have done and did not.
struct Finding: Equatable {
    enum Kind: String {
        /// The opponent struck and no split step landed.
        case noSplitStep
        /// Struck the ball, then stood still until it came back.
        case rootedAfterOwnShot
        /// Still travelling at contact — arrived late and hit on the move.
        case lateToTheBall
        /// Swinging or moving materially less by the end than at the start.
        case fading
        /// A wall rally whose tempo came apart as it went on.
        case tempoDrift
    }

    /// How firmly it is worth saying. Nothing here is a diagnosis; the
    /// difference is only how much of the session backs it up.
    enum Weight: String { case worthNoticing, clear }

    var kind: Kind
    /// How many times it happened, out of how many chances it had to.
    var occurrences: Int
    var opportunities: Int
    /// Exactly when, so the player can be shown the moments rather than a
    /// percentage. A number tells somebody they are bad at something; a list
    /// of times tells them where to look.
    var moments: [Double]
    var weight: Weight

    var rate: Double {
        opportunities > 0 ? Double(occurrences) / Double(opportunities) : 0
    }
}

/// What a session found, and — just as importantly — what it could not look
/// for.
struct SessionFindings: Equatable {
    var findings: [Finding]
    /// Checks that did not run, each with the reason.
    ///
    /// This list is not a footnote. Without it, a session with no flags reads
    /// as a session played well, when it may be a session where the microphone
    /// never heard the opponent and nothing was examined at all. Silence has
    /// to be distinguishable from a clean bill of health, or the whole tool
    /// quietly becomes flattery.
    var notChecked: [String]
}

/// Turns a session's events into the places the player did not do something
/// they should have.
///
/// This is the shape the product is aimed at, and it is not a dashboard. A
/// dashboard reports what happened and leaves the reader to work out what it
/// means; club players do not need to be told they hit 180 balls. What they
/// cannot see for themselves is the moment they stood watching a shot they
/// should have been recovering from — an omission, which by its nature leaves
/// no trace a person would remember.
///
/// Every rule here follows the same shape: find the moments where something
/// was owed, check whether it happened, and report the ones where it did not,
/// with their timestamps. Rates are reported rather than individual slips,
/// because one missed split step is noise and forty is a habit — but the
/// moments are kept so the habit can be shown rather than asserted.
enum SessionAnalyst {

    /// Below this many chances, a rate is the session being short rather than
    /// the player being anything.
    static let minOpportunities = 10

    /// Some sideways drive, at some point, between your shot and their reply.
    /// Not a sprint — just evidence of having moved at all.
    static let movedAtAll: Double = 0.25   // g

    /// Moving faster than this at the moment of contact means the player was
    /// still travelling when they hit, rather than having arrived.
    static let lateContactSpeed: Double = 1.4   // m/s equivalent in g-seconds

    /// `efforts` are the derived push-offs a device wrote to the session file
    /// — time and peak horizontal g. When raw motion is absent they carry the
    /// two rules that need movement, and they carry them with a sharper
    /// definition: recovery IS a push-off, so "rooted" becomes "no push-off
    /// at all between your shot and their reply", and "late" becomes "a hard
    /// push-off within a beat of contact". That is what a wrist or a belt
    /// can promise from a file, and it is what the coach now gets for the
    /// whole session rather than for the tail a buffer happened to keep.
    static func analyse(ownContacts: [Double],
                        opponentContacts: [Double],
                        splitSteps: [SplitStep],
                        motion: [BodyMotionSample],
                        rhythm: RallyRhythm?,
                        isWall: Bool,
                        efforts: [(t: Double, peak: Double)] = []) -> SessionFindings {
        var findings: [Finding] = []
        var notChecked: [String] = []

        // 1. Not splitting. Needs the opponent's contacts, which needs the
        //    microphone to have separated two players.
        if isWall {
            notChecked.append("Split steps: a wall has no contacts of its own to "
                              + "be ready for, so there was nothing to check against.")
        } else if opponentContacts.count < minOpportunities {
            notChecked.append("Split steps: only \(opponentContacts.count) of your "
                              + "opponent's contacts were heard, too few to say anything.")
        } else {
            var missed: [Double] = []
            for contact in opponentContacts {
                let landed = splitSteps.contains {
                    $0.landing > contact - 0.45 && $0.landing < contact + 0.15
                }
                if !landed { missed.append(contact) }
            }
            if let f = make(.noSplitStep, missed, opponentContacts.count, floor: 0.30) {
                findings.append(f)
            }
        }

        // 2. Rooted after your own shot — the one nobody can see in
        //    themselves. You hit, and then nothing happens until the ball is
        //    back. The window is your contact to their reply, which is
        //    precisely the time you had to recover in.
        if isWall {
            notChecked.append("Recovery after your shot: on a wall the ball comes "
                              + "back to where you are standing, so staying put is "
                              + "not a fault.")
        } else if ownContacts.count < minOpportunities || opponentContacts.isEmpty {
            notChecked.append("Recovery after your shot: too few rallies were "
                              + "resolved into two players to check it.")
        } else if motion.count < 40 && efforts.isEmpty {
            notChecked.append("Recovery after your shot: not enough motion data.")
        } else {
            var rooted: [Double] = []
            var chances = 0
            let useMotion = motion.count >= 40
            for hit in ownContacts.sorted() {
                guard let reply = opponentContacts.first(where: { $0 > hit + 0.25 }) else { continue }
                // A window so short there was nothing to do in it is not a
                // chance missed.
                guard reply - hit > 0.6 else { continue }
                chances += 1
                if useMotion {
                    let during = motion.filter { $0.t > hit && $0.t < reply }
                    guard !during.isEmpty else { continue }
                    if during.allSatisfy({ $0.horizontal < movedAtAll }) { rooted.append(hit) }
                } else if !efforts.contains(where: { $0.t > hit && $0.t < reply }) {
                    rooted.append(hit)
                }
            }
            if chances >= minOpportunities {
                if let f = make(.rootedAfterOwnShot, rooted, chances, floor: 0.25) {
                    findings.append(f)
                }
            } else {
                notChecked.append("Recovery after your shot: only \(chances) shots had "
                                  + "a gap long enough to judge.")
            }
        }

        // 3. Arriving late. Measured at the player's own contacts, from how
        //    much they were still travelling as they struck.
        if ownContacts.count < minOpportunities {
            notChecked.append("Arriving in time: too few of your own contacts were "
                              + "identified.")
        } else if motion.count < 40 && efforts.isEmpty {
            notChecked.append("Arriving in time: not enough motion data.")
        } else {
            var late: [Double] = []
            for hit in ownContacts {
                if motion.count >= 40 {
                    let around = motion.filter { abs($0.t - hit) < 0.15 }
                    guard !around.isEmpty else { continue }
                    let peak = around.map(\.horizontal).max() ?? 0
                    if peak > lateContactSpeed { late.append(hit) }
                } else if efforts.contains(where: { abs($0.t - hit) < 0.15 && $0.peak > lateContactSpeed }) {
                    late.append(hit)
                }
            }
            if let f = make(.lateToTheBall, late, ownContacts.count, floor: 0.30) {
                findings.append(f)
            }
        }

        // 4. Fading. Compared against the player's own opening, never against
        //    anybody else — the question is whether they finished the session
        //    they started, not how they rank.
        if let fade = fading(ownContacts: ownContacts, motion: motion) {
            findings.append(fade)
        }

        // 5. A wall rally that came apart.
        if isWall, let rhythm, rhythm.tempoSpread > 0.35, rhythm.totalStrokes >= 20 {
            findings.append(Finding(kind: .tempoDrift,
                                    occurrences: Int(rhythm.tempoSpread * 100),
                                    opportunities: 100,
                                    moments: [],
                                    weight: rhythm.tempoSpread > 0.55 ? .clear : .worthNoticing))
        }

        return SessionFindings(findings: findings.sorted { $0.rate > $1.rate },
                               notChecked: notChecked)
    }

    /// A finding, or nothing when it is too rare to mean anything.
    private static func make(_ kind: Finding.Kind, _ moments: [Double],
                             _ opportunities: Int, floor: Double) -> Finding? {
        guard opportunities >= minOpportunities else { return nil }
        let rate = Double(moments.count) / Double(opportunities)
        guard rate >= floor else { return nil }
        return Finding(kind: kind, occurrences: moments.count, opportunities: opportunities,
                       moments: moments, weight: rate >= floor * 1.8 ? .clear : .worthNoticing)
    }

    /// Did the session fall away? Split in half by TIME rather than by stroke
    /// count: a player who tires hits fewer balls in the second half, so
    /// halving the strokes would hide exactly the thing being looked for.
    private static func fading(ownContacts: [Double], motion: [BodyMotionSample]) -> Finding? {
        guard let first = motion.first, let last = motion.last else { return nil }
        let span = last.t - first.t
        guard span > 240 else { return nil }   // under four minutes, fading means nothing
        let midpoint = first.t + span / 2

        let early = ownContacts.filter { $0 < midpoint }.count
        let lateHalf = ownContacts.filter { $0 >= midpoint }.count
        guard early >= minOpportunities else { return nil }
        let drop = Double(early - lateHalf) / Double(early)
        guard drop > 0.25 else { return nil }
        return Finding(kind: .fading, occurrences: Int(drop * 100), opportunities: 100,
                       moments: [midpoint], weight: drop > 0.4 ? .clear : .worthNoticing)
    }
}

/// The sentences. Kept apart from the rules so that what is measured and what
/// is said can be argued about separately — and so a translation never has to
/// touch a threshold.
extension Finding {
    var sentence: String {
        switch kind {
        case .noSplitStep:
            return String(format: "You were flat-footed for %d of your opponent's %d "
                          + "shots (%.0f%%). A split step as they strike is what lets "
                          + "you push off either way.",
                          occurrences, opportunities, rate * 100)
        case .rootedAfterOwnShot:
            return String(format: "After %d of your %d shots you did not move at all "
                          + "until the ball came back (%.0f%%). That is the gap where "
                          + "recovery happens.",
                          occurrences, opportunities, rate * 100)
        case .lateToTheBall:
            return String(format: "You were still running as you hit %d of your %d "
                          + "shots (%.0f%%) — arriving late rather than early.",
                          occurrences, opportunities, rate * 100)
        case .fading:
            return String(format: "You hit %d%% fewer balls in the second half of the "
                          + "session than the first.", occurrences)
        case .tempoDrift:
            return String(format: "Your wall rally tempo varied by %d%% — the rhythm "
                          + "came apart rather than holding.", occurrences)
        }
    }
}
