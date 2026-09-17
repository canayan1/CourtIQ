import CoreGraphics
import Foundation

/// A position on the court, in metres, from the camera's own baseline.
/// `across` is 0 on the centre line and positive to the right; `depth` is 0 at
/// the near baseline and 23.77 at the far one.
struct CourtPoint: Equatable {
    var across: Double
    var depth: Double
}

/// The fixed dimensions every tennis court shares. These are what make a
/// clip measurable at all: the court is the ruler, so nothing depends on how
/// tall a player is or how far away they stood.
enum CourtSpec {
    static let baselineToNet = 11.885
    static let baselineToBaseline = 23.77
    static let baselineToServiceLine = 5.485
    static let singlesHalfWidth = 4.115
    static let doublesHalfWidth = 5.485

    /// Depths of every line that runs across the court, near to far.
    static let acrossDepths: [(name: String, depth: Double)] = [
        ("near baseline", 0),
        ("near service line", baselineToServiceLine),
        ("net", baselineToNet),
        ("far service line", baselineToBaseline - baselineToServiceLine),
        ("far baseline", baselineToBaseline),
    ]
}

/// One near-horizontal white line found in the frame, with the extent of the
/// pixels that actually supported it — the ends matter as much as the line,
/// because the service line's ends ARE the singles sidelines.
struct AcrossLine {
    var yAtCentre: Double
    var slope: Double
    var xStart: Int
    var xEnd: Int
    var support: Int
}

/// Maps pixels to metres of court and back.
///
/// Both halves are projective but they are solved separately, because they
/// fail separately. Depth comes from the lines running across the court, whose
/// real spacing is fixed and known, so three of them pin the map down and the
/// rest test it. Width comes from the span of the service line, whose ends sit
/// on the singles sidelines exactly 8.23 m apart.
///
/// This matters more than it sounds. Measuring players in body heights makes
/// the near player — always several times larger on a camera behind one
/// baseline — score differently from the far one for reasons that have nothing
/// to do with tennis. Court metres are the same metres at both ends.
struct CourtCalibration {
    /// What the clip actually supported. The caller is expected to degrade
    /// rather than pretend: a clip that only yields depth can still say who
    /// stood further behind their baseline, and one that yields nothing falls
    /// back to body-height normalisation, labelled as such.
    enum Confidence: String {
        case full          // metres across and metres deep
        case depthOnly     // metres deep; nothing lateral
        case none
    }

    let confidence: Confidence
    /// Depth to image row: y = (a·d + b) / (c·d + 1).
    let a: Double, b: Double, c: Double
    /// Image column of the court's centre line, and pixels per metre across at
    /// the near baseline.
    let centreX: Double
    let lateralScale: Double
    /// Which detected lines the fit was built on, for the report.
    let anchors: [(name: String, y: Double)]
    /// Support-weighted mean miss, in pixels, over every line the model explains.
    let residual: Double

    func imageY(atDepth d: Double) -> Double { (a * d + b) / (c * d + 1) }

    func imageX(across: Double, depth d: Double) -> Double {
        centreX + lateralScale * across / (c * d + 1)
    }

    func pixel(for p: CourtPoint) -> CGPoint {
        CGPoint(x: imageX(across: p.across, depth: p.depth), y: imageY(atDepth: p.depth))
    }

    /// Where on the court a pixel is. Feed it the bottom-centre of a player's
    /// box — the feet — not the centroid.
    func court(fromPixel p: CGPoint) -> CourtPoint? {
        let denom = c * Double(p.y) - a
        guard abs(denom) > 1e-9 else { return nil }
        let depth = (b - Double(p.y)) / denom
        guard depth > -3, depth < CourtSpec.baselineToBaseline + 3 else { return nil }
        guard confidence == .full else { return CourtPoint(across: .nan, depth: depth) }
        let across = (Double(p.x) - centreX) * (c * depth + 1) / lateralScale
        return CourtPoint(across: across, depth: depth)
    }

    /// Roughly how tall, in metres, something that many pixels high at that
    /// depth would be. The court gives a scale perpendicular to the view, and
    /// a standing person is perpendicular to the view too, so the lateral
    /// scale carries over — approximately, and the further the camera tilts
    /// down the more approximately. It is quite good enough for its one job:
    /// telling a player from a fence banner or a match on the next court,
    /// which differ from a person by a factor of three or four, not by ten
    /// per cent.
    func estimatedHeightMetres(pixelHeight: Double, depth: Double) -> Double? {
        guard confidence == .full else { return nil }
        let pxPerMetre = lateralScale / (c * depth + 1)
        guard pxPerMetre > 0.5 else { return nil }
        return pixelHeight / pxPerMetre
    }

    /// How many pixels tall a standing adult at that depth should be. The
    /// inverse of `estimatedHeightMetres`, and the yardstick for deciding
    /// whether a blob is a whole person, a piece of one, or scenery.
    func personPixelHeight(atDepth d: Double, metres: Double = 1.7) -> Double? {
        guard confidence == .full else { return nil }
        let pxPerMetre = lateralScale / (c * d + 1)
        guard pxPerMetre > 0.5 else { return nil }
        return metres * pxPerMetre
    }

    /// How many centimetres of court one pixel is worth at a given depth —
    /// the honest error bar to put on any number quoted from this clip.
    func precisionCm(atDepth d: Double) -> (across: Double, deep: Double) {
        let across = abs(imageX(across: 0.5, depth: d) - imageX(across: -0.5, depth: d))
        let deep = abs(imageY(atDepth: d + 0.5) - imageY(atDepth: d - 0.5))
        return (across > 0 ? 100 / across : .infinity, deep > 0 ? 100 / deep : .infinity)
    }
}

extension CourtCalibration {

    /// The test that stops this from inventing a court.
    ///
    /// The sidelines are never detected — they are derived from the service
    /// line's ends — so they are free evidence: if the model is right they
    /// land on white paint, and if it is wrong they land on grass. Without
    /// this check the solver fits a confident court to a clip of somebody
    /// hitting against a wall, and reports a tighter residual than it does on
    /// a real court, because three roughly parallel edges are easy to find
    /// anywhere.
    ///
    /// Returns the share of the near half where paint was actually found under
    /// the two best sidelines.
    func sidelineSupport(mask: [Bool], width: Int, height: Int) -> Double {
        guard confidence == .full else { return 0 }
        let candidates = [-CourtSpec.doublesHalfWidth, -CourtSpec.singlesHalfWidth,
                          CourtSpec.singlesHalfWidth, CourtSpec.doublesHalfWidth]
        var scores: [Double] = []
        for across in candidates {
            var seen = 0, hit = 0
            var d = 0.0
            while d <= CourtSpec.baselineToNet {
                defer { d += 0.25 }
                let p = pixel(for: CourtPoint(across: across, depth: d))
                let y = Int(p.y.rounded()), x = Int(p.x.rounded())
                guard y >= 0, y < height, x >= 0, x < width else { continue }
                seen += 1
                // A few pixels of slack: the paint is a couple of pixels wide
                // and the fit is allowed to be a couple of pixels off.
                for dx in -3...3 where x + dx >= 0 && x + dx < width {
                    if mask[y * width + x + dx] { hit += 1; break }
                }
            }
            scores.append(seen > 8 ? Double(hit) / Double(seen) : 0)
        }
        scores.sort(by: >)
        return (scores[0] + scores[1]) / 2
    }

    /// The same evidence test, applied to depth. The model names a row for
    /// every line that crosses the court; a real court has paint on all of
    /// them. A wall does not, which is what stops a depth-only answer from
    /// being the same fabrication wearing a smaller hat.
    func acrossSupport(mask: [Bool], width: Int, height: Int) -> Double {
        var scores: [Double] = []
        for (_, d) in CourtSpec.acrossDepths {
            let row = Int(imageY(atDepth: d).rounded())
            guard row >= 0, row < height else { continue }
            var seen = 0, hit = 0
            for x in stride(from: 0, to: width, by: 2) {
                seen += 1
                for dy in -3...3 where row + dy >= 0 && row + dy < height {
                    if mask[(row + dy) * width + x] { hit += 1; break }
                }
            }
            if seen > 8 { scores.append(Double(hit) / Double(seen)) }
        }
        guard scores.count >= 3 else { return 0 }
        // The far lines are compressed to nothing on a low camera, so judge on
        // the better half rather than demanding all five.
        scores.sort(by: >)
        return scores.prefix(3).reduce(0, +) / 3
    }

    /// Demote the calibration to what the evidence supports. A clip with no
    /// paint under its sidelines still has usable depth if the across-lines
    /// were strong, and a clip with neither gets nothing rather than a guess.
    func verified(mask: [Bool], width: Int, height: Int,
                  minSidelineSupport: Double = 0.55,
                  minAcrossSupport: Double = 0.55,
                  maxMeanMiss: Double = 6) -> CourtCalibration {
        guard residual <= maxMeanMiss,
              acrossSupport(mask: mask, width: width, height: height) >= minAcrossSupport else {
            return CourtCalibration(confidence: .none, a: a, b: b, c: c, centreX: 0,
                                    lateralScale: 0, anchors: anchors, residual: residual)
        }
        let support = sidelineSupport(mask: mask, width: width, height: height)
        guard support >= minSidelineSupport else {
            return CourtCalibration(confidence: .depthOnly, a: a, b: b, c: c, centreX: 0,
                                    lateralScale: 0, anchors: anchors, residual: residual)
        }
        return self
    }

    /// Solve from the lines found in one frame. Returns nil only when not even
    /// depth could be established.
    static func solve(from lines: [AcrossLine]) -> CourtCalibration? {
        let candidates = lines.sorted { $0.yAtCentre > $1.yAtCentre }   // nearest first
        guard candidates.count >= 3 else { return nil }

        var best: (score: Int, err: Double, cal: CourtCalibration)? = nil
        let depths = CourtSpec.acrossDepths
        let depths_all = depths.map(\.depth)

        for triple in combinations(candidates.count, 3) {
            let ys = triple.map { candidates[$0].yAtCentre }
            // Image rows must decrease as the court recedes; anything else is
            // three unrelated lines that happen to be horizontal.
            guard ys[0] > ys[1], ys[1] > ys[2] else { continue }
            for names in combinations(depths.count, 3) {
                let ds = names.map { depths[$0].depth }
                guard let p = fitDepth(depths: ds, rows: ys) else { continue }
                let cal0 = CourtCalibration(confidence: .depthOnly, a: p.0, b: p.1, c: p.2,
                                            centreX: 0, lateralScale: 0,
                                            anchors: zip(names.map { depths[$0].name }, ys).map { ($0, $1) },
                                            residual: 0)
                // Score every detected line, not just the ones outside the
                // triple, and weight by how many pixels supported each. A
                // court model that misses the brightest line in the frame is
                // wrong however many faint ones it happens to explain — which
                // is exactly the assignment an unweighted count first chose.
                var score = 0
                var weightedError = 0.0
                for line in candidates {
                    let e = depths_all.map { abs(cal0.imageY(atDepth: $0) - line.yAtCentre) }.min() ?? .infinity
                    guard e < 12 else { continue }
                    score += line.support
                    weightedError += e * Double(line.support)
                }
                guard score > 0 else { continue }
                if best == nil || score > best!.score
                    || (score == best!.score && weightedError < best!.err) {
                    best = (score, weightedError, cal0)
                }
            }
        }
        guard let found = best else { return nil }
        // Report the support-weighted mean miss, in pixels — a number that
        // means something — rather than the raw score the search ranked on.
        let meanMiss = found.err / Double(max(found.score, 1))

        // Lateral scale, if any line's span can be trusted. The service line is
        // the one to use: its ends are the singles sidelines, and unlike the
        // baseline it is short enough to stay inside the frame.
        let depthOf = { (row: Double) -> Double in
            let denom = found.cal.c * row - found.cal.a
            return abs(denom) > 1e-9 ? (found.cal.b - row) / denom : .nan
        }
        var lateral: (centre: Double, scale: Double)? = nil
        for line in candidates {
            let d = depthOf(line.yAtCentre)
            guard abs(d - CourtSpec.baselineToServiceLine) < 1.2 else { continue }
            let span = Double(line.xEnd - line.xStart)
            guard span > 40 else { continue }
            let centre = Double(line.xStart + line.xEnd) / 2
            let scale = (Double(line.xEnd) - centre) * (found.cal.c * d + 1) / CourtSpec.singlesHalfWidth
            guard scale > 1 else { continue }
            lateral = (centre, scale)
            break
        }

        guard let lat = lateral else {
            return CourtCalibration(confidence: .depthOnly, a: found.cal.a, b: found.cal.b, c: found.cal.c,
                                    centreX: 0, lateralScale: 0,
                                    anchors: found.cal.anchors, residual: meanMiss)
        }
        return CourtCalibration(confidence: .full, a: found.cal.a, b: found.cal.b, c: found.cal.c,
                                centreX: lat.centre, lateralScale: lat.scale,
                                anchors: found.cal.anchors, residual: meanMiss)
    }

    /// Least squares on y·(c·d + 1) = a·d + b, which is linear in (a, b, c).
    private static func fitDepth(depths: [Double], rows: [Double]) -> (Double, Double, Double)? {
        var ata = [Double](repeating: 0, count: 9)
        var atb = [Double](repeating: 0, count: 3)
        for (d, y) in zip(depths, rows) {
            let r = [d, 1, -y * d]
            for i in 0..<3 {
                for j in 0..<3 { ata[i * 3 + j] += r[i] * r[j] }
                atb[i] += r[i] * y
            }
        }
        guard let x = solve3x3(ata, atb) else { return nil }
        guard x.2 != 0, x.0.isFinite, x.1.isFinite, x.2.isFinite else { return nil }
        return x
    }

    private static func solve3x3(_ m: [Double], _ v: [Double]) -> (Double, Double, Double)? {
        var a = m, b = v
        for col in 0..<3 {
            var piv = col
            for r in (col + 1)..<3 where abs(a[r * 3 + col]) > abs(a[piv * 3 + col]) { piv = r }
            guard abs(a[piv * 3 + col]) > 1e-12 else { return nil }
            if piv != col {
                for k in 0..<3 { a.swapAt(col * 3 + k, piv * 3 + k) }
                b.swapAt(col, piv)
            }
            for r in 0..<3 where r != col {
                let f = a[r * 3 + col] / a[col * 3 + col]
                guard f != 0 else { continue }
                for k in 0..<3 { a[r * 3 + k] -= f * a[col * 3 + k] }
                b[r] -= f * b[col]
            }
        }
        return (b[0] / a[0], b[1] / a[4], b[2] / a[8])
    }
}

/// Index combinations, smallest first — small n, so plainly written.
private func combinations(_ n: Int, _ k: Int) -> [[Int]] {
    guard k <= n else { return [] }
    var out: [[Int]] = []
    var cur = [Int]()
    func walk(_ start: Int) {
        if cur.count == k { out.append(cur); return }
        guard start < n else { return }
        for i in start..<n {
            cur.append(i); walk(i + 1); cur.removeLast()
        }
    }
    walk(0)
    return out
}
