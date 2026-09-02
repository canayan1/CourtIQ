import Foundation
import AVFoundation
import CoreVideo

/// Finds WHERE on the wall a ball hit, at a moment the microphone already told
/// us about.
///
/// This is deliberately not ball tracking. Continuous tracking was tried here
/// with `VNDetectTrajectoriesRequest` and abandoned — it fits parabolic paths,
/// and a ball rebounding off a wall toward the camera isn't one. The mic
/// already solves the hard half by giving an exact impact time, which leaves a
/// far smaller problem: on a camera that isn't moving, what moved in the two or
/// three frames around that instant?
///
/// Everything here is on-device, runs only when an impact fires, and answers
/// `nil` rather than guessing. A rep with no reading is still a rep — the
/// streak is counted by the mic and this never overrides it.
///
/// ⚠️ Unverifiable in the Simulator: there is no camera and no ball. The
/// thresholds below are first-pass values and want tuning against real footage.
final class WallBallLocator {

    struct Reading {
        /// 0 = top of the frame, 1 = bottom, in the same space as the band lines.
        let normalizedY: CGFloat
        let normalizedX: CGFloat
        /// Rough 0–1 trust in the blob. Low readings are reported as unknown.
        let confidence: Float
    }

    // MARK: Tuning

    /// Working resolution. Small on purpose: we need a ball's height to within
    /// a few percent of frame, not its outline.
    private static let w = 120
    private static let h = 160
    private static let pixelCount = w * h

    /// The mic reports an impact slightly after the sound is made — buffering
    /// plus the threshold crossing. We look a touch further back than the
    /// reported time to catch the ball while it is still at the wall.
    private static let audioLatency: TimeInterval = 0.045
    /// How far around the corrected time to consider frames.
    private static let searchWindow: TimeInterval = 0.05
    /// Frames this far back stand in for "the scene without the ball".
    private static let backgroundLag: TimeInterval = 0.35

    /// A blob bigger than this share of the frame is the player, or the whole
    /// scene shifting because the phone was bumped. Never the ball.
    private static let maxBlobShare = 0.05
    /// Below this many pixels it is sensor noise.
    private static let minBlobArea = 3
    /// Floor for the difference threshold, on a 0–255 luma scale.
    private static let minDiffThreshold = 22

    // MARK: Frame ring

    private struct Frame {
        let t: TimeInterval
        let luma: [UInt8]
    }

    /// ~1 second at 30fps. 120×160 bytes a frame, so under 600 KB in total.
    private var ring: [Frame] = []
    private let ringCapacity = 32
    private let lock = NSLock()

    // MARK: Ingest

    /// Downscale the luma plane and keep it. Call from the capture queue.
    ///
    /// Luma alone is the right signal: a tennis ball against a wall is a
    /// brightness event, and skipping chroma keeps this cheap enough to run on
    /// every frame without warming the phone.
    func store(_ pixelBuffer: CVPixelBuffer, at t: TimeInterval) {
        guard let luma = Self.downscaleLuma(pixelBuffer) else { return }
        lock.lock()
        ring.append(Frame(t: t, luma: luma))
        if ring.count > ringCapacity { ring.removeFirst(ring.count - ringCapacity) }
        lock.unlock()
    }

    func reset() {
        lock.lock(); ring.removeAll(); lock.unlock()
    }

    // MARK: Locate

    /// Where was the ball when the mic heard `impactTime`? `nil` means we could
    /// not tell — which is a real answer, not a failure.
    func locate(impactTime: TimeInterval) -> Reading? {
        lock.lock()
        let frames = ring
        lock.unlock()
        guard frames.count >= 6 else { return nil }

        let target = impactTime - Self.audioLatency

        // Candidate frames: the ones bracketing the corrected impact time.
        let candidates = frames.filter { abs($0.t - target) <= Self.searchWindow }
        guard !candidates.isEmpty else { return nil }

        // Background: a few frames from before the ball arrived, combined with a
        // per-pixel median so one twitch of the player doesn't become the model.
        let older = frames.filter { $0.t <= target - Self.backgroundLag + 0.12
                                 && $0.t >= target - Self.backgroundLag - 0.12 }
        guard older.count >= 3 else { return nil }
        let background = Self.medianOfThree(older.suffix(3).map(\.luma))

        // Score every candidate and keep the most convincing one.
        var best: Reading?
        for frame in candidates {
            guard let reading = Self.findBall(frame: frame.luma, background: background) else { continue }
            if best == nil || reading.confidence > best!.confidence { best = reading }
        }
        return best
    }

    // MARK: Locate — anchored to a swing

    /// Where did the ball meet the wall, given the player swung at `t0`?
    ///
    /// This is the anchor the microphone version got wrong. Reading at "the
    /// loudest sound" meant reading at racquet contact — with the ball still
    /// in the player's hand, low in frame — and everything came out NET. A
    /// swing time is unambiguous: the ball leaves the racquet at `t0`, reaches
    /// the wall 0.1–0.5s later, and in a camera behind the player it climbs
    /// the frame on the way there and falls on the way back. Its highest
    /// point in that window IS the wall contact. No sound involved.
    func locateWallImpact(afterSwingAt t0: TimeInterval) -> Reading? {
        lock.lock()
        let frames = ring
        lock.unlock()
        guard frames.count >= 6 else { return nil }

        let window = frames.filter { $0.t >= t0 + 0.10 && $0.t <= t0 + 0.50 }
        guard window.count >= 2 else { return nil }

        // Background from just before the swing — the racquet is still back
        // and the ball hasn't left, so the wall region is quiet.
        let older = frames.filter { $0.t <= t0 - 0.15 && $0.t >= t0 - 0.45 }
        guard older.count >= 3 else { return nil }
        let background = Self.medianOfThree(older.suffix(3).map(\.luma))

        // The apex: the confident reading highest in frame.
        var best: Reading?
        for frame in window {
            guard let r = Self.findBall(frame: frame.luma, background: background),
                  r.confidence >= 0.25 else { continue }
            if best == nil || r.normalizedY < best!.normalizedY { best = r }
        }
        return best
    }

    // MARK: - Pixels

    /// Nearest-neighbour sample of the luma plane down to `w`×`h`.
    private static func downscaleLuma(_ pixelBuffer: CVPixelBuffer) -> [UInt8]? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        // Bi-planar YUV: plane 0 is luma. A BGRA buffer has no planes, so bail
        // rather than reinterpret bytes as brightness.
        guard CVPixelBufferGetPlaneCount(pixelBuffer) >= 1,
              let base = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) else { return nil }
        let srcW = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
        let srcH = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
        let stride = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
        guard srcW > 0, srcH > 0 else { return nil }

        let src = base.assumingMemoryBound(to: UInt8.self)
        var out = [UInt8](repeating: 0, count: pixelCount)
        for y in 0..<h {
            let sy = y * srcH / h
            let row = sy * stride
            for x in 0..<w {
                out[y * w + x] = src[row + (x * srcW / w)]
            }
        }
        return out
    }

    private static func medianOfThree(_ frames: [[UInt8]]) -> [UInt8] {
        guard frames.count == 3 else { return frames.first ?? [] }
        let (a, b, c) = (frames[0], frames[1], frames[2])
        var out = [UInt8](repeating: 0, count: pixelCount)
        for i in 0..<pixelCount {
            let x = a[i], y = b[i], z = c[i]
            out[i] = max(min(x, y), min(max(x, y), z))
        }
        return out
    }

    /// Threshold the difference, group what survives, and pick the blob that
    /// behaves like a ball: small, compact, and not the player.
    private static func findBall(frame: [UInt8], background: [UInt8]) -> Reading? {
        guard frame.count == pixelCount, background.count == pixelCount else { return nil }

        var diff = [UInt8](repeating: 0, count: pixelCount)
        var total = 0
        for i in 0..<pixelCount {
            let d = abs(Int(frame[i]) - Int(background[i]))
            diff[i] = UInt8(min(255, d))
            total += d
        }
        let mean = total / pixelCount
        let threshold = max(minDiffThreshold, mean * 3)

        var mask = [Bool](repeating: false, count: pixelCount)
        var lit = 0
        for i in 0..<pixelCount where Int(diff[i]) >= threshold {
            mask[i] = true
            lit += 1
        }
        // A frame where a third of the pixels changed is a lighting shift or a
        // bumped phone, not a ball.
        guard lit >= minBlobArea, lit < pixelCount / 3 else { return nil }

        let maxArea = Int(Double(pixelCount) * maxBlobShare)
        var visited = [Bool](repeating: false, count: pixelCount)
        var bestArea = 0
        var bestSumX = 0, bestSumY = 0

        var stack: [Int] = []
        stack.reserveCapacity(256)

        for start in 0..<pixelCount where mask[start] && !visited[start] {
            stack.removeAll(keepingCapacity: true)
            stack.append(start)
            visited[start] = true

            var area = 0, sumX = 0, sumY = 0
            var minX = w, maxX = 0, minY = h, maxY = 0

            while let idx = stack.popLast() {
                area += 1
                let x = idx % w, y = idx / w
                sumX += x; sumY += y
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)

                // 4-connected is enough at this resolution and avoids threading
                // two blobs together through a diagonal.
                if x > 0,     mask[idx - 1], !visited[idx - 1]     { visited[idx - 1] = true;     stack.append(idx - 1) }
                if x < w - 1, mask[idx + 1], !visited[idx + 1]     { visited[idx + 1] = true;     stack.append(idx + 1) }
                if y > 0,     mask[idx - w], !visited[idx - w]     { visited[idx - w] = true;     stack.append(idx - w) }
                if y < h - 1, mask[idx + w], !visited[idx + w]     { visited[idx + w] = true;     stack.append(idx + w) }
            }

            guard area >= minBlobArea, area <= maxArea else { continue }

            // Motion blur stretches the ball, so allow a streak — but a blob
            // ten times longer than it is wide is an arm or a shadow edge.
            let bw = maxX - minX + 1, bh = maxY - minY + 1
            let elongation = Double(max(bw, bh)) / Double(max(1, min(bw, bh)))
            guard elongation <= 5 else { continue }

            if area > bestArea {
                bestArea = area; bestSumX = sumX; bestSumY = sumY
            }
        }

        guard bestArea >= minBlobArea else { return nil }
        let cy = Double(bestSumY) / Double(bestArea)
        let cx = Double(bestSumX) / Double(bestArea)
        // Bigger blobs are more convincing, up to a point; past ~24px we are
        // probably looking at part of the player and shouldn't grow more certain.
        let confidence = Float(min(1.0, Double(bestArea) / 24.0))

        return Reading(normalizedY: CGFloat(cy) / CGFloat(h),
                       normalizedX: CGFloat(cx) / CGFloat(w),
                       confidence: confidence)
    }
}

/// Which part of the wall a ball hit, relative to the band the player set.
enum WallZone: String {
    /// Under the lower line — on a court this ball hit the net.
    case net
    /// Between the lines — a driving ball that clears and lands in.
    case band
    /// Over the upper line — on a court this ball would be sailing long.
    case long
    /// The rep happened; we could not see where. Never counted against anyone.
    case unknown
}

// MARK: - Ground-referenced net line

import Vision

/// Estimates where a tennis net's height falls on the wall, using the player
/// as the ruler.
///
/// There is no way to recover metric scale from one photo of a wall. But a
/// person standing against that wall is a known length in the same plane: their
/// feet mark the ground, their head marks their height, and the pixels between
/// convert metres to screen units at the wall — which is the only place we need
/// the conversion to hold.
///
/// Only the NET line is derived from physics (0.914 m, a singles net at the
/// centre). The upper line has no physical definition — how high a good ball
/// strikes the wall depends on how far back you stand — so it is offset by a
/// default metre and openly presented as a starting point to drag.
enum WallNetEstimator {

    /// Regulation net height at the centre strap, in metres.
    static let netHeightM: CGFloat = 0.914
    /// Default gap from the net line to the "too high" line. A guess, not a rule.
    static let defaultBandM: CGFloat = 1.0

    struct Estimate {
        /// Normalized view coords (0 = top of frame), same space as the band.
        let netY: CGFloat
        let topY: CGFloat
        /// Where the player's feet were — the ground line we measured from.
        let groundY: CGFloat
    }

    /// Measure from one frame. `playerHeightM` is what the whole thing is
    /// calibrated against; a wrong height scales the answer proportionally,
    /// which is why the player can still drag afterwards.
    ///
    /// Returns nil unless a person is found standing upright and whole — a
    /// half-visible or crouching player would silently produce a wrong ruler,
    /// and a wrong line is worse than no line.
    static func estimate(from pixelBuffer: CVPixelBuffer,
                         playerHeightM: CGFloat) -> Estimate? {
        let request = VNDetectHumanBodyPoseRequest()
        // Frames are delivered pre-rotated upright, so no orientation fixup.
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        try? handler.perform([request])
        guard let observation = request.results?.first,
              let points = try? observation.recognizedPoints(.all) else { return nil }

        func y(of joints: [VNHumanBodyPoseObservation.JointName],
               pick: ([CGFloat]) -> CGFloat?) -> CGFloat? {
            let found = joints.compactMap { name -> CGFloat? in
                guard let p = points[name], p.confidence > 0.3 else { return nil }
                // Vision's origin is bottom-left with y up; the band overlay's
                // is top-left with y down.
                return 1 - p.location.y
            }
            return pick(found)
        }

        // Feet are the LOWEST point on screen, so the largest view y.
        guard let feetY = y(of: [.leftAnkle, .rightAnkle], pick: { $0.max() }),
              let headY = y(of: [.nose, .leftEye, .rightEye, .leftEar, .rightEar],
                            pick: { $0.min() })
        else { return nil }

        let span = feetY - headY
        // A person filling less than a sixth of the frame is too far away, or
        // it isn't a whole person. Either way the ruler can't be trusted.
        guard span > 0.16 else { return nil }

        let unitsPerMetre = span / playerHeightM
        let netY = feetY - netHeightM * unitsPerMetre
        let topY = netY - defaultBandM * unitsPerMetre

        // A net line off the top of the frame means the camera is framed too
        // low to be useful — report nothing rather than clamp to a lie.
        guard netY > 0.05, netY < 0.98 else { return nil }

        return Estimate(netY: netY,
                        topY: max(0.02, topY),
                        groundY: feetY)
    }
}
