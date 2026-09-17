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
}

struct PlayerTrack {
    /// Which end of the court this player lives at. Assigned from the court
    /// itself rather than from who looks bigger, which is the whole point of
    /// calibrating first.
    enum End: String { case near, far }
    var end: End
    var samples: [PlayerSample]
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

    /// Blobs that could be a player standing on this court.
    ///
    /// The court does the rejecting. A banner on the back fence, a bird, and
    /// the doubles match on the next court along are all moving things that a
    /// size threshold cannot tell from a player, and all three land outside
    /// the lines once the pixel is converted to metres.
    static func onCourt(_ blobs: [MotionBlob], calibration: CourtCalibration)
        -> [(blob: MotionBlob, court: CourtPoint)] {
        let widthLimit = CourtSpec.doublesHalfWidth + 2.5   // room to chase a wide ball
        return blobs.compactMap { blob in
            guard let p = calibration.court(fromPixel: blob.footPixel) else { return nil }
            guard p.depth > -2.5, p.depth < CourtSpec.baselineToBaseline + 3 else { return nil }
            if calibration.confidence == .full {
                guard p.across.isFinite, abs(p.across) < widthLimit else { return nil }
                // And it has to be person-sized where it stands. This is what
                // rejects the banners on the back fence and the doubles match
                // on the next court, which sit at plausible depths and moved
                // like anything else: at that distance they work out barely
                // half a metre tall.
                guard let h = calibration.estimatedHeightMetres(pixelHeight: blob.pixelHeight,
                                                                depth: p.depth),
                      h > 1.0, h < 2.3 else { return nil }
            }
            return (blob, p)
        }
    }

    /// One track per end of the court. Per frame, the largest candidate in
    /// each half wins; there is exactly one player per half in a singles
    /// rally, so this needs no association heuristic and cannot drift between
    /// two people the way a nearest-neighbour rule does.
    static func tracks(frameMasks: [(time: Double, mask: [Bool])],
                       width: Int, height: Int, rows: Range<Int>,
                       calibration: CourtCalibration) -> [PlayerTrack] {
        var near: [PlayerSample] = [], far: [PlayerSample] = []
        let split = CourtSpec.baselineToNet
        for frame in frameMasks {
            let candidates = onCourt(blobs(mask: frame.mask, width: width, height: height, rows: rows),
                                     calibration: calibration)
            let biggest = { (half: [(blob: MotionBlob, court: CourtPoint)]) -> PlayerSample? in
                guard let best = half.max(by: { $0.blob.pixels < $1.blob.pixels }) else { return nil }
                return PlayerSample(time: frame.time, court: best.court,
                                    pixelHeight: best.blob.pixelHeight,
                                    footPixel: best.blob.footPixel)
            }
            if let s = biggest(candidates.filter { $0.court.depth < split }) { near.append(s) }
            if let s = biggest(candidates.filter { $0.court.depth >= split }) { far.append(s) }
        }
        var out: [PlayerTrack] = []
        if !near.isEmpty { out.append(PlayerTrack(end: .near, samples: near)) }
        if !far.isEmpty { out.append(PlayerTrack(end: .far, samples: far)) }
        return out
    }

}
