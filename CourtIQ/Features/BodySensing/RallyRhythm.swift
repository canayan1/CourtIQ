import Foundation

/// How a rally actually went, from nothing but the times of the strokes.
struct RallyRhythm: Equatable {
    /// Unbroken runs, longest first, as stroke counts.
    var rallies: [Int]
    /// Typical time between strokes inside a rally.
    var medianInterval: Double
    /// How steady that tempo was: the interquartile spread of the intervals
    /// as a share of the median. Small is metronomic.
    ///
    /// Quartiles rather than a standard deviation because one chased ball
    /// would dominate a variance and say nothing about the other forty
    /// strokes.
    var tempoSpread: Double

    var longestRally: Int { rallies.first ?? 0 }
    var totalStrokes: Int { rallies.reduce(0, +) }
}

/// Reads the shape of a session out of the stroke times.
///
/// This is the whole of what a wall session needs and the part the camera was
/// never good at. The shipped pose counter records its own measured accuracy
/// in `WallSwingDetector` — ten counted out of about thirteen on a real
/// session — because from behind the player a swing moves mostly toward the
/// wall, which is depth a single camera cannot see. Stroke times do not have
/// that problem: a rally is a rhythm, and rhythm is exactly what a series of
/// timestamps is.
enum RallyRhythmReader {

    /// A rally is over when the ball has to be fetched. Rather than a fixed
    /// number of seconds — which would be wrong for a player standing two
    /// metres from the wall and wrong again for one standing eight — the break
    /// is defined relative to the player's own tempo.
    static let breakMultiple: Double = 2.5
    /// With a floor, because early in a session the median is built from very
    /// few intervals and a small one would chop a good rally into pieces.
    static let minBreak: Double = 2.0

    static func read(strokes: [Double]) -> RallyRhythm? {
        let times = strokes.sorted()
        guard times.count >= 4 else { return nil }
        var intervals: [Double] = []
        for i in 1..<times.count { intervals.append(times[i] - times[i - 1]) }

        let sorted = intervals.sorted()
        let median = sorted[sorted.count / 2]
        guard median > 0 else { return nil }
        let q1 = sorted[sorted.count / 4]
        let q3 = sorted[min(sorted.count - 1, sorted.count * 3 / 4)]

        let breakAt = max(minBreak, median * breakMultiple)
        var rallies: [Int] = []
        var run = 1
        for gap in intervals {
            if gap > breakAt { rallies.append(run); run = 1 } else { run += 1 }
        }
        rallies.append(run)
        rallies.sort(by: >)

        // The spread is measured over the intervals INSIDE rallies only. The
        // gap where the player walked to fetch the ball is not a wobble in
        // their tempo, and counting it as one would make every session look
        // erratic no matter how cleanly it was struck.
        let inside = intervals.filter { $0 <= breakAt }.sorted()
        let spread: Double
        if inside.count >= 4 {
            let a = inside[inside.count / 4]
            let b = inside[min(inside.count - 1, inside.count * 3 / 4)]
            let m = inside[inside.count / 2]
            spread = m > 0 ? (b - a) / m : 0
        } else {
            spread = median > 0 ? (q3 - q1) / median : 0
        }

        return RallyRhythm(rallies: rallies, medianInterval: median, tempoSpread: spread)
    }
}
