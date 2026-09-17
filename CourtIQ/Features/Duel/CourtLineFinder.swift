import Foundation

/// Finds the white lines running across a tennis court in a single grey frame.
///
/// Two things keep this honest on a clip somebody actually shot. It searches
/// only where play happened — the accumulated motion of the clip, which lands
/// on the court by definition — so the fence, the clubhouse and the sky never
/// get a vote. And it keeps the extent of the pixels supporting each line,
/// because a court line is a segment, and its ends carry the court's width.
enum CourtLineFinder {

    /// Pixels that sit on a bright ridge: brighter than what lies a line's
    /// width away on BOTH sides. Perspective makes the far lines thin and the
    /// near ones fat, so several widths are tried and any win counts.
    static func ridgeMask(gray: [Float], width: Int, height: Int,
                          rows: Range<Int>, threshold: Float = 14) -> [Bool] {
        var mask = [Bool](repeating: false, count: width * height)
        let widths = [2, 3, 4, 6, 9, 13]
        for w in widths {
            // vertical neighbours — finds lines running across the frame
            for y in max(rows.lowerBound, w)..<min(rows.upperBound, height - w) {
                let row = y * width
                for x in 0..<width {
                    let v = gray[row + x]
                    if v - gray[row - w * width + x] > threshold,
                       v - gray[row + w * width + x] > threshold { mask[row + x] = true }
                }
            }
            // horizontal neighbours — finds lines running away from the camera
            for y in rows {
                let row = y * width
                for x in w..<(width - w) {
                    let v = gray[row + x]
                    if v - gray[row + x - w] > threshold,
                       v - gray[row + x + w] > threshold { mask[row + x] = true }
                }
            }
        }
        return mask
    }

    /// Near-horizontal lines, strongest first, suppressed so two candidates
    /// never describe the same white line.
    ///
    /// A full Hough transform is the textbook answer and the wrong one here: a
    /// phone propped against a fence is never rotated much, so sweeping a small
    /// band of slopes directly is both cheaper and keeps each line's supporting
    /// columns, which is what the ends are read from.
    static func acrossLines(mask: [Bool], width: Int, height: Int,
                            rows: Range<Int>, limit: Int = 8) -> [AcrossLine] {
        var found: [AcrossLine] = []
        let slopes = stride(from: -0.12, through: 0.121, by: 0.005).map { $0 }
        let halfW = Double(width) / 2

        for slope in slopes {
            var offsets = [Int](repeating: 0, count: width)
            for x in 0..<width { offsets[x] = Int((slope * (Double(x) - halfW)).rounded()) }
            for y in rows {
                var support = 0, first = -1, last = -1
                for x in 0..<width {
                    let yy = y + offsets[x]
                    guard yy >= 0, yy < height, mask[yy * width + x] else { continue }
                    support += 1
                    if first < 0 { first = x }
                    last = x
                }
                guard support > 60 else { continue }
                found.append(AcrossLine(yAtCentre: Double(y), slope: slope,
                                        xStart: first, xEnd: last, support: support))
            }
        }

        found.sort { $0.support > $1.support }
        var kept: [AcrossLine] = []
        for line in found {
            guard kept.allSatisfy({ abs($0.yAtCentre - line.yAtCentre) > 14 }) else { continue }
            kept.append(line)
            if kept.count >= limit { break }
        }
        return kept.sorted { $0.yAtCentre > $1.yAtCentre }
    }

    /// The rows worth searching, taken from where the clip's motion landed.
    /// Percentiles rather than extremes, so a bird or the next court along
    /// cannot stretch the band open.
    static func playBand(motionCount: [Int], width: Int, height: Int,
                         minFrames: Int = 3) -> Range<Int> {
        var rowsWithPlay: [Int] = []
        for y in 0..<height {
            let row = y * width
            var n = 0
            for x in 0..<width where motionCount[row + x] >= minFrames { n += 1 }
            if n > 0 { rowsWithPlay.append(contentsOf: repeatElement(y, count: n)) }
        }
        guard rowsWithPlay.count > 20 else { return 0..<height }
        let lo = Double(rowsWithPlay[rowsWithPlay.count * 2 / 100])
        let hi = Double(rowsWithPlay[min(rowsWithPlay.count - 1, rowsWithPlay.count * 98 / 100)])
        let pad = (hi - lo) * 0.30
        return max(0, Int(lo - pad))..<min(height, Int(hi + pad) + 1)
    }
}
