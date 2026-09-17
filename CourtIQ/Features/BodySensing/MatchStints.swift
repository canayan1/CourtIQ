import Foundation

/// The one stream everything downstream is built on, whatever produced it.
///
/// A phone on a belt, an Apple Watch, and one day a Garmin all differ in what
/// they can sense and how well. They are made interchangeable here, at the
/// event, not further down: a contact is a contact whether the wrist felt it
/// at 800 Hz or the microphone heard it, and a changeover is a changeover
/// whether the player tapped the watch or the rest pattern gave it away.
/// Nothing below this line knows which device it is looking at, which is the
/// only way "works with the phone and with an external device" stays true
/// instead of becoming two products.
enum SensorEvent: Equatable {
    enum ContactOwner: Equatable { case player, opponent, unknown }
    case contact(t: Double, strength: Double, owner: ContactOwner)
    case motion(BodyMotionSample)
    /// Beats per minute. Only a wearable produces these; the phone never does.
    case heartRate(t: Double, bpm: Double)
    /// The player marked a changeover. One tap on the wrist, which is what
    /// players already do with a scoring app, and it beats any inference.
    case changeover(t: Double)

    // Derived motion. Raw samples never leave the device that sensed them —
    // 100 to 200 Hz for an hour is megabytes with no use on the far side,
    // since every detector already ran where the data was. What travels is
    // what the detectors concluded, in the same vocabulary the phone's own
    // recorder produces from its raw stream, so a stint built from a watch
    // and a stint built from a belt phone are the same object.
    case splitStep(t: Double, landingG: Double)
    case effort(t: Double, peakPush: Double)
    /// Share of the last slice spent moving, reported once per tick.
    case activity(t: Double, movingShare: Double)
}

/// A stretch of play between changeovers — one or two games.
///
/// Tennis changes ends after odd games, so what a player sits down from is
/// usually a pair. "In these two games" is exactly the unit the bench
/// summary is asked for, and it is also the unit a comparison can be fair
/// over: long enough to hold a few dozen movements, short enough that a
/// fading player fades within it.
struct Stint: Equatable {
    var index: Int
    var start: Double
    var end: Double
    var ownContacts: Int
    var opponentContacts: Int
    /// Changes of direction and pushes off — the efforts that actually cost.
    var efforts: Int
    /// The strongest pushes, so a stint where the player still moved but
    /// moved softly is separable from one where they moved less.
    var medianPeakPush: Double
    var movingShare: Double
    /// Split steps landed per opponent contact. Nil when there were too few
    /// opponent contacts to say.
    var readiness: Double?
    var meanHeartRate: Double?

    var duration: Double { end - start }
    var effortsPerMinute: Double { duration > 0 ? Double(efforts) / duration * 60 : 0 }
}

enum StintBuilder {

    /// A between-point rest is twenty-odd seconds; a changeover is ninety.
    /// Anything quiet for longer than this and shorter than a set break is a
    /// changeover the player did not mark.
    static let inferredChangeover: Double = 55
    /// The same stint should have had play in it.
    static let minContacts = 6

    /// Cuts a session into stints, at marked changeovers first and inferred
    /// ones where there are none.
    ///
    /// Marks win. When the player has tapped the wrist, no gap heuristic is
    /// consulted at all, because a long medical timeout or a chat at the net
    /// would otherwise be read as a changeover and the comparison would be
    /// made across the wrong boundary.
    static func stints(from events: [SensorEvent]) -> [Stint] {
        let sorted = events.sorted { $0.time < $1.time }
        guard let first = sorted.first?.time, let last = sorted.last?.time, last > first else { return [] }

        var boundaries: [Double] = sorted.compactMap {
            if case .changeover(let t) = $0 { return t } else { return nil }
        }
        if boundaries.isEmpty {
            let contacts = sorted.compactMap { e -> Double? in
                if case .contact(let t, _, _) = e { return t } else { return nil }
            }
            for i in 1..<max(1, contacts.count)
            where contacts[i] - contacts[i - 1] > inferredChangeover {
                boundaries.append((contacts[i] + contacts[i - 1]) / 2)
            }
        }

        var edges = [first] + boundaries.sorted() + [last]
        edges = edges.filter { $0 >= first && $0 <= last }

        var out: [Stint] = []
        for i in 1..<edges.count {
            let a = edges[i - 1], b = edges[i]
            let inside = sorted.filter { $0.time >= a && $0.time < b }
            guard let stint = build(inside, index: out.count, start: a, end: b) else { continue }
            out.append(stint)
        }
        return out
    }

    private static func build(_ events: [SensorEvent], index: Int,
                              start: Double, end: Double) -> Stint? {
        var own = 0, opp = 0
        var motion: [BodyMotionSample] = []
        var hr: [Double] = []
        var opponentTimes: [Double] = []
        var derivedHops: [SplitStep] = []
        var derivedPeaks: [Double] = []
        var activity: [Double] = []
        for e in events {
            switch e {
            case .contact(let t, _, let owner):
                if owner == .player { own += 1 }
                if owner == .opponent { opp += 1; opponentTimes.append(t) }
            case .motion(let m): motion.append(m)
            case .heartRate(_, let bpm): hr.append(bpm)
            case .changeover: break
            case .splitStep(let t, let g): derivedHops.append(SplitStep(landing: t, unload: 0, landingG: g))
            case .effort(_, let peak): derivedPeaks.append(peak)
            case .activity(_, let share): activity.append(share)
            }
        }
        guard own + opp >= minContacts else { return nil }

        // Raw motion when we have it (the phone's own recorder, the tests);
        // otherwise the derived events a watch sent. Same detectors either
        // way, so the two paths cannot disagree about what a hop is.
        let hops: [SplitStep]
        let peaks: [Double]
        let movingShare: Double
        if motion.count > 40 {
            let efforts = MovementDetector.efforts(motion)
            peaks = pushPeaks(motion, at: efforts).sorted()
            hops = MovementDetector.splitSteps(motion)
            movingShare = MovementDetector.workRest(motion)?.workShare ?? 0
        } else {
            peaks = derivedPeaks.sorted()
            hops = derivedHops
            movingShare = activity.isEmpty ? 0 : activity.reduce(0, +) / Double(activity.count)
        }
        let readiness = MovementDetector.readiness(splitSteps: hops,
                                                   opponentContacts: opponentTimes)?.share

        return Stint(index: index, start: start, end: end,
                     ownContacts: own, opponentContacts: opp,
                     efforts: peaks.count,
                     medianPeakPush: peaks.isEmpty ? 0 : peaks[peaks.count / 2],
                     movingShare: movingShare,
                     readiness: readiness,
                     meanHeartRate: hr.isEmpty ? nil : hr.reduce(0, +) / Double(hr.count))
    }

    /// The hardest push in a short window around each effort.
    private static func pushPeaks(_ motion: [BodyMotionSample], at efforts: [Double]) -> [Double] {
        efforts.map { t in
            motion.filter { abs($0.t - t) < 0.25 }.map(\.horizontal).max() ?? 0
        }
    }
}

extension SensorEvent {
    var time: Double {
        switch self {
        case .contact(let t, _, _): return t
        case .motion(let m): return m.t
        case .heartRate(let t, _): return t
        case .changeover(let t): return t
        case .splitStep(let t, _): return t
        case .effort(let t, _): return t
        case .activity(let t, _): return t
        }
    }
}

/// What the bench card says.
struct BenchNote: Equatable {
    enum Topic: String { case movement, pushes, readiness, heartRate }
    var topic: Topic
    /// Change from the previous stint, as a fraction. Negative is less.
    var change: Double
    var sentence: String
}

/// Compares the stint just played with the one before it, and says only what
/// changed and by how much.
///
/// Only what changed, and never why. A drop in movement between two stints is
/// consistent with tiredness, heat, dehydration, an opponent who stopped
/// making the player run, a deliberate change of pace, and fuel — and nothing
/// on a wrist or a belt can tell those apart. The temptation is to write "you
/// may need carbohydrate", and it has to be resisted twice over: once because
/// the app's nutrition rules forbid unsourced dietary advice, and once because
/// it would be a guess dressed as a reading. The bench card reports the
/// observation. The Journal already holds what the player logged eating; the
/// two can sit side by side and the player can draw the line themselves.
enum BenchReport {

    /// Smaller changes than this are the noise between any two stints.
    static let noticeable: Double = 0.15

    static func compare(latest: Stint, previous: Stint) -> [BenchNote] {
        var notes: [BenchNote] = []

        // Movement: efforts per minute, so a shorter stint is not "less".
        if previous.effortsPerMinute > 0 {
            let d = (latest.effortsPerMinute - previous.effortsPerMinute) / previous.effortsPerMinute
            if abs(d) >= noticeable {
                notes.append(BenchNote(topic: .movement, change: d, sentence: String(
                    format: "You made %.0f%% %@ movements per minute in this stint than the last one.",
                    abs(d) * 100, d < 0 ? "fewer" : "more")))
            }
        }

        // Pushes: were the movements that did happen as sharp?
        if previous.medianPeakPush > 0 {
            let d = (latest.medianPeakPush - previous.medianPeakPush) / previous.medianPeakPush
            if abs(d) >= noticeable {
                notes.append(BenchNote(topic: .pushes, change: d, sentence: String(
                    format: "Your pushes off were %.0f%% %@ than last stint.",
                    abs(d) * 100, d < 0 ? "softer" : "sharper")))
            }
        }

        if let a = latest.readiness, let b = previous.readiness, b > 0 {
            let d = (a - b) / b
            if abs(d) >= noticeable {
                notes.append(BenchNote(topic: .readiness, change: d, sentence: String(
                    format: "You split stepped on %.0f%% of their shots, down from %.0f%%.",
                    a * 100, b * 100)))
                if d > 0 { notes[notes.count - 1].sentence = String(
                    format: "You split stepped on %.0f%% of their shots, up from %.0f%%.",
                    a * 100, b * 100) }
            }
        }

        if let a = latest.meanHeartRate, let b = previous.meanHeartRate, b > 0 {
            let d = (a - b) / b
            if abs(d) >= 0.08 {
                notes.append(BenchNote(topic: .heartRate, change: d, sentence: String(
                    format: "Average heart rate %.0f, from %.0f last stint.", a, b)))
            }
        }

        return notes
    }
}
