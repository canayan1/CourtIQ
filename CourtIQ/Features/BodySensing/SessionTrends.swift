import Foundation

/// One session against the player's own history.
struct TrendNote: Equatable {
    enum Topic: String { case readiness, movement, pushes, tempo }
    var topic: Topic
    var current: Double
    var baseline: Double
    var sentence: String
}

struct TrendResult: Equatable {
    var notes: [TrendNote]
    var baselineCount: Int
    /// Why nothing was compared, when nothing was.
    var notCompared: String?
}

/// The analytics half of the plan: this session against the last several of
/// the same kind, never against anybody else.
///
/// Three rules keep it honest. The baseline is the player's own median over
/// at least three previous sessions of the same drill — a match is not
/// compared with a wall session, and one previous session is an anecdote.
/// Only differences that clear the same 15% floor the bench card uses are
/// mentioned, so a player who is the same as usual gets an empty list rather
/// than an invented one. And it says what changed, never why — the same rule
/// as everywhere else in this folder, for the same reason.
enum SessionTrends {

    static let minHistory = 3
    static let noticeable: Double = 0.15

    struct Aggregate {
        var readiness: Double?
        var movesPerMinute: Double?
        var medianPush: Double?
        var tempoSpread: Double?
    }

    static func aggregate(_ session: SensingSession) -> Aggregate {
        let events = session.decodedEvents
        var own: [Double] = [], opp: [Double] = [], hops: [SplitStep] = [], peaks: [Double] = []
        var last = 0.0
        for e in events {
            last = max(last, e.time)
            switch e {
            case .contact(let t, _, .player): own.append(t)
            case .contact(let t, _, .opponent): opp.append(t)
            case .splitStep(let t, let g): hops.append(SplitStep(landing: t, unload: 0, landingG: g))
            case .effort(_, let p): peaks.append(p)
            default: break
            }
        }
        let readiness = MovementDetector.readiness(splitSteps: hops, opponentContacts: opp)?.share
        let minutes = last / 60
        let sorted = peaks.sorted()
        return Aggregate(
            readiness: readiness,
            movesPerMinute: minutes > 1 && !peaks.isEmpty ? Double(peaks.count) / minutes : nil,
            medianPush: sorted.isEmpty ? nil : sorted[sorted.count / 2],
            tempoSpread: RallyRhythmReader.read(strokes: own)?.tempoSpread)
    }

    static func compare(current: SensingSession, history: [SensingSession]) -> TrendResult {
        let same = history.filter { $0.drill == current.drill && $0.id != current.id }
        guard same.count >= minHistory else {
            return TrendResult(notes: [], baselineCount: same.count,
                               notCompared: "fewer than \(minHistory) previous \(current.drill) sessions to compare with.")
        }
        let now = aggregate(current)
        let past = same.map(aggregate)
        func median(_ xs: [Double]) -> Double? { xs.isEmpty ? nil : Stats.median(xs) }
        var notes: [TrendNote] = []

        if let a = now.readiness, let b = median(past.compactMap(\.readiness)), b > 0 {
            let d = a - b     // readiness moves in points, not ratios
            if abs(d) >= 0.10 {
                notes.append(TrendNote(topic: .readiness, current: a, baseline: b, sentence: String(
                    format: "Split stepped on %.0f%% of their shots; your usual is %.0f%%.", a * 100, b * 100)))
            }
        }
        if let a = now.movesPerMinute, let b = median(past.compactMap(\.movesPerMinute)), b > 0 {
            let d = (a - b) / b
            if abs(d) >= noticeable {
                notes.append(TrendNote(topic: .movement, current: a, baseline: b, sentence: String(
                    format: "%.0f movements a minute, %.0f%% %@ than your usual %.0f.",
                    a, abs(d) * 100, d < 0 ? "fewer" : "more", b)))
            }
        }
        if let a = now.medianPush, let b = median(past.compactMap(\.medianPush)), b > 0 {
            let d = (a - b) / b
            if abs(d) >= noticeable {
                notes.append(TrendNote(topic: .pushes, current: a, baseline: b, sentence: String(
                    format: "Pushes off %.0f%% %@ than your usual.", abs(d) * 100, d < 0 ? "softer" : "sharper")))
            }
        }
        if let a = now.tempoSpread, let b = median(past.compactMap(\.tempoSpread)), b > 0 {
            let d = (a - b) / b
            if abs(d) >= noticeable {
                notes.append(TrendNote(topic: .tempo, current: a, baseline: b, sentence: String(
                    format: "Rally tempo %.0f%% %@ steady than your usual.", abs(d) * 100, d > 0 ? "less" : "more")))
            }
        }
        return TrendResult(notes: notes, baselineCount: same.count, notCompared: nil)
    }
}
