import AVFoundation
import Foundation

/// Ball-strike times from a clip's audio track, and nothing else.
///
/// Lifted out of `SwingImpactAnalyzer` when the duel pipeline needed the same
/// numbers without its Vision person gate — pose is exactly what fails for the
/// player across the net, so gating there would silently delete one player's
/// strokes and hand the comparison to whoever stood nearer the phone. Two
/// callers, one calibrated algorithm; it must not be copied.
///
/// The algorithm is the Swift port of tools/stroke-miner/mine.py, calibrated
/// against hand-counted wall sessions: high-pass differentiator → 10 ms RMS
/// envelope → adaptive threshold (median + 6·MAD) → min-gap peak picking where
/// the strongest peak in each window wins, so the near racket hit beats the
/// far wall bounce.
///
/// It over-counts on its own — the calibration in docs/SWING-PIPELINE-PLAN
/// measured 20-45% on raw audio, from wall bounces and ambient noise — so
/// every caller owes it a rejecting stage of its own.
enum BallImpactAudio {

    static let sampleRate: Double = 16_000
    static let envelopeWindow: Double = 0.010   // 10 ms RMS
    /// The rhythm of a wall session. A rally is faster: the ball crosses the
    /// net in about a second, so the duel asks for a shorter gap.
    static let wallMinGap: Double = 1.4
    static let rallyMinGap: Double = 0.9
    static let madK: Double = 6.0

    /// Every candidate strike, in seconds into the clip.
    static func impacts(videoURL: URL, minGap: Double = wallMinGap) async -> [Double]? {
        let asset = AVURLAsset(url: videoURL)
        guard let duration = try? await asset.load(.duration).seconds, duration > 0,
              let envelope = try? readEnvelope(asset: asset) else { return nil }
        return detectImpacts(envelope: envelope, dt: envelopeWindow, minGap: minGap)
            .filter { $0 > 0.3 && $0 < duration - 0.2 }
    }

    // MARK: - Audio envelope (offline)

    /// Decodes the clip's audio to 16 kHz mono float PCM and reduces it to a
    /// 10 ms RMS envelope of the high-pass differentiated signal.
    static func readEnvelope(asset: AVAsset) throws -> [Double] {
        guard let track = asset.tracks(withMediaType: .audio).first else {
            throw NSError(domain: "BallImpactAudio", code: 1)
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
    static func detectImpacts(envelope: [Double], dt: Double,
                                      minGap: Double = wallMinGap) -> [Double] {
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

}
