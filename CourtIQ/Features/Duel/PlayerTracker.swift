import CoreGraphics
import Foundation

/// One observation of one player.
struct PlayerSample {
    var time: Double
    /// Where the feet are, in metres of court. The feet, not the centroid:
    /// a player's middle rises and falls with every stroke, and the court
    /// plane only knows about things standing on it.
    var court: CourtPoint
    var pixelHeight: Double
    var footPixel: CGPoint
    /// True when the blob was far shorter than the court says a person at
    /// that row should be, so only part of the player registered. Their
    /// lateral position still holds; their depth does not.
    var partial: Bool = false
}

struct PlayerTrack {
    /// A moving average over a fixed span of TIME, not a fixed number of
    /// samples — so a clip read at 5 fps and the same clip read at 10 fps are
    /// smoothed by the same amount, and a metric built on the result does not
    /// secretly depend on how often anybody looked.
    ///
    /// It is needed because the bottom edge of a motion blob is the player's
    /// feet, and feet move: a stride shifts that edge by tens of centimetres
    /// while the player's position barely changes. Integrating the raw track
    /// measures the stride, not the running, which is how the first version
    /// reported nine metres of travel per stroke for someone standing almost
    /// still.
    func smoothed(window: Double = 0.5) -> PlayerTrack {
        guard samples.count > 2 else { return self }
        var out = samples
        for i in samples.indices {
            let t = samples[i].time
            let near = samples.filter { abs($0.time - t) <= window / 2 }
            guard near.count > 1 else { continue }
            out[i].court = CourtPoint(
                across: near.reduce(0) { $0 + $1.court.across } / Double(near.count),
                depth: near.reduce(0) { $0 + $1.court.depth } / Double(near.count))
        }
        return PlayerTrack(end: end, samples: out)
    }

    /// Which end of the court this player lives at. Assigned from the court
    /// itself rather than from who looks bigger, which is the whole point of
    /// calibrating first.
    enum End: String { case near, far }
    var end: End
    var samples: [PlayerSample]

    /// Share of the track where only part of the player registered.
    var partialShare: Double {
        guard !samples.isEmpty else { return 1 }
        return Double(samples.filter(\.partial).count) / Double(samples.count)
    }

    /// Whether this track may carry numbers at all.
    ///
    /// A mostly-partial track is a player the clip can SEE but cannot
    /// MEASURE. Its lowest visible pixel is not a foot, so its depth is
    /// fiction, and everything built on depth inherits that — on the
    /// ground-level clip an unguarded version cheerfully reported the far
    /// player making contact eleven metres in front of their own baseline.
    /// Worse, when every candidate in a half is a fragment there is nothing
    /// to tell the real opponent from the match on the next court, and
    /// continuity will happily follow the wrong one all clip. Seeing somebody
    /// is not the same as measuring them, and the difference has to reach the
    /// user rather than be smoothed over.
    var isMeasurable: Bool { partialShare < 0.5 }
}

/// A rectangle of moved pixels.
struct MotionBlob {
    var x0: Int, y0: Int, x1: Int, y1: Int, pixels: Int
    var footPixel: CGPoint { CGPoint(x: Double(x0 + x1) / 2, y: Double(y1)) }
    var pixelHeight: Double { Double(y1 - y0 + 1) }
}

/// Finds the two players by what moved, not by what a detector recognises.
///
/// This exists because recognition fails exactly where the feature needs it.
/// Vision's person detector never once returned a second box on any real clip
/// — the player across the net is roughly thirty pixels tall from behind a
/// baseline — while background subtraction put a tight box on the near player
/// in 165 of 165 frames of the same clip. Motion does not care how many pixels
/// tall someone is. It cares that the camera did not move, which is why the
/// shooting guide makes a propped phone a requirement rather than a
/// preference.
enum PlayerTracker {

    /// Rows and columns are image space; row 0 is the top of the frame.
    static func blobs(mask: [Bool], width: Int, height: Int,
                      rows: Range<Int>, minPixels: Int = 12) -> [MotionBlob] {
        var seen = [Bool](repeating: false, count: width * height)
        var found: [MotionBlob] = []
        var stack: [Int] = []
        for y in rows {
            for x in 0..<width {
                let start = y * width + x
                guard mask[start], !seen[start] else { continue }
                seen[start] = true
                stack.removeAll(keepingCapacity: true)
                stack.append(start)
                var x0 = x, x1 = x, y0 = y, y1 = y, count = 0
                while let i = stack.popLast() {
                    count += 1
                    let cy = i / width, cx = i % width
                    if cx < x0 { x0 = cx }; if cx > x1 { x1 = cx }
                    if cy < y0 { y0 = cy }; if cy > y1 { y1 = cy }
                    for (dy, dx) in [(-1, 0), (1, 0), (0, -1), (0, 1),
                                     (-1, -1), (-1, 1), (1, -1), (1, 1)] {
                        let ny = cy + dy, nx = cx + dx
                        guard ny >= rows.lowerBound, ny < rows.upperBound,
                              nx >= 0, nx < width else { continue }
                        let j = ny * width + nx
                        guard mask[j], !seen[j] else { continue }
                        seen[j] = true
                        stack.append(j)
                    }
                }
                if count >= minPixels {
                    found.append(MotionBlob(x0: x0, y0: y0, x1: x1, y1: y1, pixels: count))
                }
            }
        }
        return found
    }

    /// Joins the pieces of one person back together.
    ///
    /// Background subtraction only catches what differs from the background,
    /// so a distant player in pale clothing against a pale fence arrives in
    /// fragments: a head here, a leg there. Judged separately, each fragment
    /// is too small to be a person and its lowest pixel is not a foot, which
    /// is how the far player in a real two-player clip got thrown away as
    /// scenery.
    ///
    /// The court decides what "close enough to be the same person" means. It
    /// predicts how many pixels tall someone standing at that row is, so
    /// fragments that overlap horizontally and sit within a body height of
    /// each other belong together — and the rule tightens correctly with
    /// distance instead of needing a constant tuned per clip.
    static func merged(_ blobs: [MotionBlob], calibration: CourtCalibration) -> [MotionBlob] {
        guard calibration.confidence == .full else { return blobs }
        var work = blobs.sorted { $0.y1 < $1.y1 }
        var changed = true
        while changed {
            changed = false
            outer: for i in 0..<work.count {
                for j in (i + 1)..<work.count {
                    let a = work[i], b = work[j]
                    let overlap = min(a.x1, b.x1) - max(a.x0, b.x0)
                    guard overlap > 0,
                          Double(overlap) > 0.3 * Double(min(a.x1 - a.x0, b.x1 - b.x0) + 1)
                    else { continue }
                    let row = CGPoint(x: Double(a.x0 + a.x1) / 2, y: Double(max(a.y1, b.y1)))
                    guard let p = calibration.court(fromPixel: row),
                          let full = calibration.personPixelHeight(atDepth: p.depth) else { continue }
                    let gap = max(0, max(a.y0, b.y0) - min(a.y1, b.y1))
                    guard Double(gap) < full else { continue }
                    work[i] = MotionBlob(x0: min(a.x0, b.x0), y0: min(a.y0, b.y0),
                                         x1: max(a.x1, b.x1), y1: max(a.y1, b.y1),
                                         pixels: a.pixels + b.pixels)
                    work.remove(at: j)
                    changed = true
                    break outer
                }
            }
        }
        return work
    }

    /// Blobs that could be a player standing on this court, and how much of
    /// each one we are actually seeing.
    ///
    /// The court does the rejecting. A banner on the back fence, a bird, and
    /// the doubles match on the next court along are all moving things that a
    /// size threshold cannot tell from a player, and all three land outside
    /// the lines once the pixel is converted to metres.
    ///
    /// What it must NOT do is reject a real player for being faint. So the
    /// calibration's prediction of how tall a person is at that row is used
    /// twice: far too tall is scenery and is dropped, while too short is a
    /// player we are only half seeing — kept, and flagged, because the bottom
    /// of a half-seen player is not their feet and so their depth cannot be
    /// trusted even though their lateral position can.
    static func onCourt(_ blobs: [MotionBlob], calibration: CourtCalibration)
        -> [(blob: MotionBlob, court: CourtPoint, partial: Bool)] {
        let widthLimit = CourtSpec.doublesHalfWidth + 2.5   // room to chase a wide ball
        return blobs.compactMap { blob in
            guard let p = calibration.court(fromPixel: blob.footPixel) else { return nil }
            guard p.depth > -2.5, p.depth < CourtSpec.baselineToBaseline + 3 else { return nil }
            guard calibration.confidence == .full else { return (blob, p, false) }
            guard p.across.isFinite, abs(p.across) < widthLimit else { return nil }
            guard let h = calibration.estimatedHeightMetres(pixelHeight: blob.pixelHeight,
                                                            depth: p.depth) else { return nil }
            guard h < 2.3 else { return nil }
            // A quarter of a person is still a person; a twentieth is a bird.
            guard h > 0.35 else { return nil }
            return (blob, p, h < 1.0)
        }
    }

    /// One track per end of the court, because a singles rally has exactly one
    /// player in each half — so the half does the associating and no
    /// nearest-neighbour rule can drift between two people.
    ///
    /// Within a half it is not always so simple. A whole blob is always
    /// preferred, and where the player only registers in pieces there may be
    /// several partial candidates in the same frame: the far player, the
    /// match on the next court along, a spectator behind the fence. Size
    /// cannot choose between them, so continuity does — the far player's
    /// lateral position moves smoothly from frame to frame while the others
    /// come and go.
    static func tracks(frameMasks: [(time: Double, mask: [Bool])],
                       width: Int, height: Int, rows: Range<Int>,
                       calibration: CourtCalibration,
                       lastNear: inout CourtPoint?, lastFar: inout CourtPoint?) -> [PlayerTrack] {
        var near: [PlayerSample] = [], far: [PlayerSample] = []
        let split = CourtSpec.baselineToNet
        for frame in frameMasks {
            let found = blobs(mask: frame.mask, width: width, height: height, rows: rows)
            let candidates = onCourt(merged(found, calibration: calibration),
                                     calibration: calibration)
            let pick = { (half: [(blob: MotionBlob, court: CourtPoint, partial: Bool)],
                          previous: CourtPoint?) -> PlayerSample? in
                let whole = half.filter { !$0.partial }
                let pool = whole.isEmpty ? half : whole
                let chosen: (blob: MotionBlob, court: CourtPoint, partial: Bool)?
                if whole.isEmpty, let last = previous {
                    // Among pieces, the one that carries on from where the
                    // player was. Lateral only: the depth of a partial blob
                    // is its lowest visible pixel, which is not a foot.
                    chosen = pool.min { abs($0.court.across - last.across)
                                      < abs($1.court.across - last.across) }
                } else {
                    chosen = pool.max { $0.blob.pixels < $1.blob.pixels }
                }
                guard let best = chosen else { return nil }
                return PlayerSample(time: frame.time, court: best.court,
                                    pixelHeight: best.blob.pixelHeight,
                                    footPixel: best.blob.footPixel, partial: best.partial)
            }
            if let s = pick(candidates.filter { $0.court.depth < split }, lastNear) {
                near.append(s); lastNear = s.court
            }
            if let s = pick(candidates.filter { $0.court.depth >= split }, lastFar) {
                far.append(s); lastFar = s.court
            }
        }
        var out: [PlayerTrack] = []
        if !near.isEmpty { out.append(PlayerTrack(end: .near, samples: near)) }
        if !far.isEmpty { out.append(PlayerTrack(end: .far, samples: far)) }
        return out
    }

}
