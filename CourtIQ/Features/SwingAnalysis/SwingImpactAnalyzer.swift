import AVFoundation
import Vision

/// Deterministic swing counting for a picked video (Faz 1 of the swing
/// pipeline): finds ball-strike candidates on the AUDIO track, then confirms
/// each with a Vision person-check on the frame at the impact.
///
/// Why: video-LLMs are motion-blind — asking the model to count reps was our
/// #1 fabrication source. Ground truth calibration (docs/SWING-PIPELINE-PLAN)
/// showed raw audio over-counts 20-45% (wall bounces, ambient noise) and the
/// person-gate brings counts to ~truth. So: the COUNT comes from DSP+Vision on
/// device; the AI only ever coaches, never counts.
///
/// The audio stage now lives in `BallImpactAudio`, because the duel pipeline
/// needs the same calibrated numbers WITHOUT the person gate below: pose is
/// what fails for the player across the net.
enum SwingImpactAnalyzer {

    struct Scan {
        /// Person-confirmed impact times (seconds into the clip).
        let impacts: [Double]
        /// Of the confirmed impacts, how many show OVERHEAD contact (wrist
        /// above the head at the strike) — the serve/smash family. Lets the
        /// app refuse a "serve" request for a clip with zero overhead strikes
        /// BEFORE any upload: the model fabricates serve mechanics when asked
        /// to coach a serve it cannot see (field-tested failure).
        let overheadImpacts: Int
        /// Audio candidates before the person gate (diagnostics).
        let rawImpactCount: Int
        let duration: Double
    }

    // Tuned constants — keep in sync with tools/stroke-miner/mine.py.
    /// Frames around the impact must show a person with at least this many
    /// confident joints to count as a real swing (kills ball-collection walks
    /// far from camera and out-of-frame strokes).
    private static let minJoints = 6
    private static let jointConfidence: Float = 0.3

    /// Full scan: audio candidates + person gate. Cheap (a few seconds for a
    /// 60-90 s clip) and fully on-device.
    static func scan(videoURL: URL) async -> Scan? {
        let asset = AVURLAsset(url: videoURL)
        guard let duration = try? await asset.load(.duration).seconds,
              duration > 0 else { return nil }

        guard let envelope = try? BallImpactAudio.readEnvelope(asset: asset) else { return nil }
        let candidates = BallImpactAudio.detectImpacts(envelope: envelope,
                                                       dt: BallImpactAudio.envelopeWindow)
            .filter { $0 > 0.6 && $0 < duration - 0.4 }
        guard !candidates.isEmpty else {
            return Scan(impacts: [], overheadImpacts: 0, rawImpactCount: 0, duration: duration)
        }

        let gated = await personGate(asset: asset, times: candidates)
        return Scan(
            impacts: gated.map(\.time),
            overheadImpacts: gated.filter(\.overhead).count,
            rawImpactCount: candidates.count,
            duration: duration
        )
    }

    // MARK: - Vision person gate

    /// Keeps only impacts whose frame actually shows a person (≥ `minJoints`
    /// joints above `jointConfidence`), noting for each whether the contact is
    /// OVERHEAD (a wrist above the head — the serve/smash family).
    private static func personGate(
        asset: AVAsset, times: [Double]
    ) async -> [(time: Double, overhead: Bool)] {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 480, height: 480)
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.1, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.1, preferredTimescale: 600)

        var confirmed: [(time: Double, overhead: Bool)] = []
        for t in times {
            let time = CMTime(seconds: t, preferredTimescale: 600)
            guard let image = try? await copyImage(generator: generator, at: time) else { continue }
            if let pose = personPose(in: image) {
                confirmed.append((time: t, overhead: isOverhead(pose)))
            }
        }
        return confirmed
    }

    private static func personPose(
        in image: CGImage
    ) -> [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]? {
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cgImage: image)
        guard (try? handler.perform([request])) != nil,
              let pose = request.results?.first,
              let points = try? pose.recognizedPoints(.all) else { return nil }
        let confident = points.values.filter { $0.confidence > jointConfidence }
        return confident.count >= minJoints ? points : nil
    }

    /// Overhead contact ⇒ a confident wrist sits clearly above the head.
    /// Vision coordinates are normalized with the origin at the BOTTOM-left,
    /// so "above" means a larger y. Groundstroke contact lives at waist to
    /// shoulder height, and even a high finish barely reaches ear height at
    /// the strike itself, so a small margin over the head reference is a
    /// clean separator for serve/smash contact.
    private static func isOverhead(
        _ points: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]
    ) -> Bool {
        let headY = [VNHumanBodyPoseObservation.JointName.nose, .leftEar, .rightEar]
            .compactMap { points[$0] }
            .filter { $0.confidence > jointConfidence }
            .map(\.location.y)
            .max()
        guard let headY else { return false }
        let wristY = [VNHumanBodyPoseObservation.JointName.leftWrist, .rightWrist]
            .compactMap { points[$0] }
            .filter { $0.confidence > jointConfidence }
            .map(\.location.y)
            .max()
        guard let wristY else { return false }
        return wristY > headY + 0.02
    }

    private static func copyImage(generator: AVAssetImageGenerator, at time: CMTime) async throws -> CGImage {
        try await withCheckedThrowingContinuation { continuation in
            generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, image, _, result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if result == .succeeded, let image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: SwingFrameExtractor.ExtractionError.unreadableVideo)
                }
            }
        }
    }
}
