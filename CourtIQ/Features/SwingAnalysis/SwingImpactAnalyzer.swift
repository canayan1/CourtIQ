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
/// The audio algorithm is the Swift port of tools/stroke-miner/mine.py, which
/// was calibrated against Can's hand-counted wall sessions: high-pass
/// differentiator → 10 ms RMS envelope → adaptive threshold (median + 6·MAD)
/// → min-gap peak picking where the STRONGEST peak in each window wins (the
/// near-mic racket hit beats the far wall bounce).
enum SwingImpactAnalyzer {

    struct Scan {
        /// Person-confirmed impact times (seconds into the clip).
        let impacts: [Double]
        /// Audio candidates before the person gate (diagnostics).
        let rawImpactCount: Int
        let duration: Double
    }

    // Tuned constants — keep in sync with tools/stroke-miner/mine.py.
    private static let sampleRate: Double = 16_000
    private static let envelopeWindow: Double = 0.010   // 10 ms RMS
    private static let minGap: Double = 1.4             // s between strokes
    private static let madK: Double = 6.0               // threshold = med + K·MAD
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

        guard let envelope = try? readEnvelope(asset: asset) else { return nil }
        let candidates = detectImpacts(envelope: envelope, dt: envelopeWindow)
            .filter { $0 > 0.6 && $0 < duration - 0.4 }
        guard !candidates.isEmpty else {
            return Scan(impacts: [], rawImpactCount: 0, duration: duration)
        }

        let confirmed = await personGate(asset: asset, times: candidates)
        return Scan(impacts: confirmed, rawImpactCount: candidates.count, duration: duration)
    }

    // MARK: - Audio envelope (offline)

    /// Decodes the clip's audio to 16 kHz mono float PCM and reduces it to a
    /// 10 ms RMS envelope of the high-pass differentiated signal.
    private static func readEnvelope(asset: AVAsset) throws -> [Double] {
        guard let track = asset.tracks(withMediaType: .audio).first else {
            throw NSError(domain: "SwingImpactAnalyzer", code: 1)
        }
        let reader = try AVAssetReader(asset: asset)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsNonInterleaved: false,
        ]
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
        reader.add(output)
        reader.startReading()

        let window = Int(envelopeWindow * sampleRate)   // 160 samples
        var envelope: [Double] = []
        var previous: Float = 0
        var sumSquares: Double = 0
        var filled = 0

        while let sample = output.copyNextSampleBuffer() {
            guard let block = CMSampleBufferGetDataBuffer(sample) else { continue }
            var length = 0
            var pointer: UnsafeMutablePointer<Int8>?
            guard CMBlockBufferGetDataPointer(
                block, atOffset: 0, lengthAtOffsetOut: nil,
                totalLengthOut: &length, dataPointerOut: &pointer) == noErr,
                let bytes = pointer else { continue }

            bytes.withMemoryRebound(to: Float.self, capacity: length / 4) { floats in
                for i in 0..<(length / 4) {
                    let x = floats[i]
                    let hp = Double(x - previous)   // differentiator ≈ high-pass
                    previous = x
                    sumSquares += hp * hp
                    filled += 1
                    if filled == window {
                        envelope.append((sumSquares / Double(window)).squareRoot())
                        sumSquares = 0
                        filled = 0
                    }
                }
            }
        }
        return envelope
    }

    /// Adaptive threshold + min-gap strongest-peak picking (mirror of mine.py).
    private static func detectImpacts(envelope: [Double], dt: Double) -> [Double] {
        guard envelope.count > 10 else { return [] }
        let sorted = envelope.sorted()
        let median = sorted[sorted.count / 2]
        let deviations = envelope.map { abs($0 - median) }.sorted()
        let mad = max(deviations[deviations.count / 2], 1e-9)
        let threshold = median + madK * mad

        let above = envelope.indices.filter { envelope[$0] > threshold }
        guard !above.isEmpty else { return [] }

        let gapSamples = Int(minGap / dt)
        var kept: [Int] = []
        for index in above.sorted(by: { envelope[$0] > envelope[$1] }) {
            if kept.allSatisfy({ abs($0 - index) >= gapSamples }) {
                kept.append(index)
            }
        }
        return kept.sorted().map { Double($0) * dt }
    }

    // MARK: - Vision person gate

    /// Keeps only impacts whose frame actually shows a person (≥ `minJoints`
    /// joints above `jointConfidence`).
    private static func personGate(asset: AVAsset, times: [Double]) async -> [Double] {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 480, height: 480)
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.1, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.1, preferredTimescale: 600)

        var confirmed: [Double] = []
        for t in times {
            let time = CMTime(seconds: t, preferredTimescale: 600)
            guard let image = try? await copyImage(generator: generator, at: time) else { continue }
            if personVisible(in: image) { confirmed.append(t) }
        }
        return confirmed
    }

    private static func personVisible(in image: CGImage) -> Bool {
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cgImage: image)
        guard (try? handler.perform([request])) != nil,
              let pose = request.results?.first,
              let points = try? pose.recognizedPoints(.all) else { return false }
        let confident = points.values.filter { $0.confidence > jointConfidence }
        return confident.count >= minJoints
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
