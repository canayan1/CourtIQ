import AVFoundation
import Foundation

/// Shared by the phone recorder and the watch controller, so both sensors
/// build the SAME envelope BallImpactAudio was calibrated on. One definition,
/// or the two would drift apart and "same data from either device" would
/// quietly stop being true.
/// The envelope, built on the audio thread and read on the main one.
///
/// A lock rather than an actor, because the microphone tap runs on a real-time
/// thread: it is allowed to take a lock nobody holds for long, and it is not
/// allowed to await anything. Holding the samples to hand across to another
/// thread would be worse than either — the buffer is only valid for the length
/// of the callback, so the arithmetic happens while it is still alive and the
/// samples themselves are never kept.
///
/// What survives is one number per ten milliseconds, which is the whole of
/// what the microphone policy promises: audio is reduced to instants and
/// loudnesses as it arrives and discarded in the same breath. A session is
/// recorded in a public place — the next court, the conversation behind the
/// fence — so what survives is a few hundred numbers and never a recording,
/// nothing written to disk, nothing transmitted, no setting that changes it.
final class LiveEnvelope: @unchecked Sendable {
    private let lock = NSLock()
    private var bins: [Double] = []
    private var accumulator = 0.0
    private var filled = 0
    private var previous: Float = 0
    private var _binSize = 160

    var binSize: Int {
        get { lock.lock(); defer { lock.unlock() }; return _binSize }
        set { lock.lock(); _binSize = max(1, newValue); lock.unlock() }
    }

    func consume(_ samples: UnsafePointer<Float>, count: Int) {
        lock.lock()
        defer { lock.unlock() }
        for i in 0..<count {
            let x = samples[i]
            let highPassed = Double(x - previous)   // differentiator ≈ high-pass
            previous = x
            accumulator += highPassed * highPassed
            filled += 1
            if filled == _binSize {
                bins.append((accumulator / Double(_binSize)).squareRoot())
                accumulator = 0
                filled = 0
            }
        }
    }

    func snapshot() -> [Double] {
        lock.lock(); defer { lock.unlock() }
        return bins
    }

    /// The last `seconds` of envelope, and the absolute index of its first
    /// bin so a caller can put times back on the session clock. The live
    /// tick detects on this rather than on the whole session — copying and
    /// sorting an hour of bins every twenty seconds was the first version.
    func snapshot(lastSeconds seconds: Double, binDuration: Double) -> (bins: [Double], firstIndex: Int) {
        lock.lock(); defer { lock.unlock() }
        let want = Int(seconds / binDuration)
        let start = max(0, bins.count - want)
        return (Array(bins[start...]), start)
    }

    var binCount: Int { lock.lock(); defer { lock.unlock() }; return bins.count }

    // MARK: - Getting to 16 kHz

    /// The rate the detector was calibrated at. The differentiator that
    /// stands in for a high-pass filter has a cutoff proportional to the
    /// sample rate, so an envelope built from the hardware's 48 kHz has a
    /// different spectral shape from one built from 16 kHz, and the
    /// median + 6·MAD threshold tuned on the latter does not mean the same
    /// thing on the former. Every live path converts to this first; the
    /// offline path already decoded at it.
    static let calibratedSampleRate: Double = 16_000

    static var calibratedFormat: AVAudioFormat {
        AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: calibratedSampleRate,
                      channels: 1, interleaved: false)!
    }

    /// Converts a hardware buffer to 16 kHz mono and folds it in. Safe on
    /// the audio thread: the converter does its work synchronously and the
    /// buffer is never referenced after this returns.
    func consume(_ buffer: AVAudioPCMBuffer, converter: AVAudioConverter) {
        let ratio = LiveEnvelope.calibratedSampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 16
        guard let out = AVAudioPCMBuffer(pcmFormat: LiveEnvelope.calibratedFormat, frameCapacity: capacity)
        else { return }
        var fed = false
        var error: NSError?
        converter.convert(to: out, error: &error) { _, status in
            if fed { status.pointee = .noDataNow; return nil }
            fed = true; status.pointee = .haveData; return buffer
        }
        guard error == nil, let channel = out.floatChannelData?[0] else { return }
        consume(channel, count: Int(out.frameLength))
    }

    func reset() {
        lock.lock(); defer { lock.unlock() }
        bins.removeAll(); accumulator = 0; filled = 0; previous = 0
    }
}
