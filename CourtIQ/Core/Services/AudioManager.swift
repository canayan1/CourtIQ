import AVFoundation

/// Lightweight sound-effect player for the app's "peak moments" (a swing score
/// landing, a correct quiz answer, a doubles compatibility reveal). The cues are
/// SYNTHESISED in code — a short percussive "pock" that evokes a clean racket
/// hit — so there are no audio files to bundle yet; drop real samples in later
/// and switch `play` to file-backed buffers.
///
/// Design guarantees (so it never "breaks" anything):
/// - `AVAudioSession` uses `.ambient` + `.mixWithOthers`: it respects the
///   hardware silent switch and never ducks or stops the user's music/podcast.
/// - Gated by a single on/off flag (default ON). Off → hard no-op.
/// - Fails open-silent: if the engine can't start, `play` just does nothing.
final class AudioManager {
    static let shared = AudioManager()

    enum SFX { case sweetSpot, correct, wrong }

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var buffers: [SFX: AVAudioPCMBuffer] = [:]
    private var started = false
    private let sampleRate = 44_100.0

    private static let key = "DropVolley.soundEffects.v1"

    /// Master toggle (default ON). Persisted so a settings switch can bind here.
    var soundEffectsEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Self.key) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Self.key) }
    }

    private init() {}

    /// Plays a cue if sound is on. Safe to call from the main actor / any view.
    func play(_ sfx: SFX) {
        guard soundEffectsEnabled else { return }
        ensureStarted()
        guard started, let buf = buffers[sfx] else { return }
        player.scheduleBuffer(buf, at: nil, options: .interrupts, completionHandler: nil)
        if !player.isPlaying { player.play() }
    }

    // MARK: - Engine

    private func ensureStarted() {
        guard !started else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, options: [.mixWithOthers])
            try session.setActive(true)

            guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return }
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)

            buffers[.sweetSpot] = Self.pock(freq: 340, decay: 0.045, noise: 0.35, dur: 0.16, sr: sampleRate, format: format)
            buffers[.correct]   = Self.pock(freq: 520, decay: 0.040, noise: 0.28, dur: 0.14, sr: sampleRate, format: format)
            buffers[.wrong]     = Self.pock(freq: 150, decay: 0.075, noise: 0.08, dur: 0.20, sr: sampleRate, format: format)

            try engine.start()
            started = true
        } catch {
            started = false
        }
    }

    /// Synthesises a short percussive "pock": a decaying tonal body (fundamental
    /// + a touch of 2nd harmonic) plus a brief noise burst on the attack for the
    /// racket "thwock" transient.
    private static func pock(freq: Double, decay: Double, noise: Double,
                             dur: Double, sr: Double, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let frames = AVAudioFrameCount(dur * sr)
        guard frames > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frames
        let attack = 0.006
        for i in 0..<Int(frames) {
            let t = Double(i) / sr
            let env = exp(-t / decay)
            let body = sin(2 * .pi * freq * t) * 0.7 + sin(2 * .pi * freq * 2 * t) * 0.2
            let atk = t < attack ? (Double.random(in: -1...1) * noise * (1 - t / attack)) : 0
            // Soft-clip a touch so the transient reads without harsh peaks.
            channel[i] = Float(tanh((body * env + atk) * 0.9) * 0.55)
        }
        return buffer
    }
}
