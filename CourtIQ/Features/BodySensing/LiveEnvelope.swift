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
/// what `AudioPolicy` promises.
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

    func reset() {
        lock.lock(); defer { lock.unlock() }
        bins.removeAll(); accumulator = 0; filled = 0; previous = 0
    }
}
