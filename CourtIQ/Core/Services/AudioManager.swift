import AVFoundation

/// Lightweight sound-effect player for the app's "peak moments" (a swing score
/// landing, a correct quiz answer, a struck ball).
///
/// Hybrid source: each cue prefers a REAL sample dropped into the bundled
/// `Audio/` folder (see `docs/AUDIO-LIBRARY.md`), and falls back to an in-code
/// SYNTHESISED "pock" when no file is present — so the app makes sound whether
/// or not the sample library has been filled in yet, and swapping in real
/// tennis audio is just a matter of adding files (no code change).
///
/// Design guarantees (so it never "breaks" anything):
/// - `AVAudioSession` uses `.ambient` + `.mixWithOthers`: it respects the
///   hardware silent switch and never ducks or stops the user's music/podcast.
/// - Gated by a single on/off flag (default ON). Off → hard no-op.
/// - Fails open-silent: if the engine can't start, `play` just does nothing.
final class AudioManager {
    static let shared = AudioManager()

    enum SFX {
        case sweetSpot, correct, wrong, ballHit, bounce

        /// The SFX that may be backed by a real bundled sample.
        static let allLoadable: [SFX] = [.sweetSpot, .correct, .wrong, .ballHit, .bounce]

        /// Base file-name(s) to look for in the bundled `Audio/` folder (any
        /// common audio extension). Drop matching files into
        /// `CourtIQ/Resources/Audio/` and they replace the synth cue; list
        /// several to get natural variety (e.g. multiple racket takes played at
        /// random). See `docs/AUDIO-LIBRARY.md`.
        var fileCandidates: [String] {
            switch self {
            case .sweetSpot: return ["sweet_spot"]
            case .correct:   return ["correct"]
            case .wrong:     return ["net_thud"]
            case .ballHit:   return ["racket_hit_1", "racket_hit_2", "racket_hit_3", "racket_hit_4"]
            case .bounce:    return ["bounce_1", "bounce_2"]
            }
        }
    }

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    /// Real sample variants loaded from the bundled `Audio/` folder — when an
    /// SFX has one or more, `play` picks one at random for natural variety.
    private var fileBuffers: [SFX: [AVAudioPCMBuffer]] = [:]
    /// Synthesised fallback, used when no sample file is bundled for an SFX.
    private var synthBuffers: [SFX: AVAudioPCMBuffer] = [:]
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
        guard started else { return }
        // Prefer a real sample (random variant); fall back to the synth cue.
        guard let buf = fileBuffers[sfx]?.randomElement() ?? synthBuffers[sfx] else { return }
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

            // Synth fallbacks — always available, used until a real sample for
            // the cue is dropped into the bundled `Audio/` folder.
            // Positive + transitions read as clean racket contact off the sweet spot.
            synthBuffers[.sweetSpot] = Self.pock(freq: 384, decay: 0.048, noise: 0.30, dur: 0.16, sr: sampleRate, format: format)
            // Correct = a short two-note "winner" flourish off a clean strike.
            synthBuffers[.correct]   = Self.winner(sr: sampleRate, format: format)
            // A crisp racket "thwock" — brighter fundamental + a heavier noise
            // attack than the score cues, so a struck ball reads as a real hit.
            synthBuffers[.ballHit]   = Self.pock(freq: 430, decay: 0.050, noise: 0.50, dur: 0.15, sr: sampleRate, format: format)
            // Wrong = the dead, buzzy thud of a ball dying in the net — deflating,
            // no clean tone. The unmistakable "into the net" cue for a lost point.
            synthBuffers[.wrong]     = Self.netThud(sr: sampleRate, format: format)
            // Bounce = a soft, low pock — a ball landing on the court.
            synthBuffers[.bounce]    = Self.pock(freq: 200, decay: 0.060, noise: 0.15, dur: 0.13, sr: sampleRate, format: format)

            // Real samples override when present; multiple files per SFX are
            // kept and one is chosen at random per play for variety.
            for sfx in SFX.allLoadable {
                let variants = sfx.fileCandidates.compactMap { Self.loadSample(named: $0, to: format) }
                if !variants.isEmpty { fileBuffers[sfx] = variants }
            }

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

    /// A short two-note "winner" flourish — two clean racket pocks a rising
    /// interval apart — for a correct answer / a green decision. Reads as a
    /// small celebration without a canned fanfare.
    private static func winner(sr: Double, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let dur = 0.30
        let frames = AVAudioFrameCount(dur * sr)
        guard frames > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frames
        let f1 = 520.0, f2 = 784.0        // a rising lift (roughly a perfect fifth)
        let gap = 0.085                    // the second note lands after the first
        let decay = 0.05
        for i in 0..<Int(frames) {
            let t = Double(i) / sr
            var s = sin(2 * .pi * f1 * t) * 0.7 * exp(-t / decay)
                  + sin(2 * .pi * f1 * 2 * t) * 0.16 * exp(-t / decay)
            if t >= gap {
                let t2 = t - gap
                let e2 = exp(-t2 / decay)
                s += sin(2 * .pi * f2 * t2) * 0.7 * e2
                   + sin(2 * .pi * f2 * 2 * t2) * 0.16 * e2
            }
            channel[i] = Float(tanh(s * 0.85) * 0.5)
        }
        return buffer
    }

    /// The dead, buzzy thud of a ball caught in the net — a low muffled body, a
    /// net-cord rattle on the attack, and a slow tremor, with no bright
    /// transient. Reads as "into the net" (point lost), not a clean strike.
    private static func netThud(sr: Double, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let dur = 0.30
        let frames = AVAudioFrameCount(dur * sr)
        guard frames > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frames
        let f0 = 96.0                      // low, muffled body
        for i in 0..<Int(frames) {
            let t = Double(i) / sr
            let bodyEnv = exp(-t / 0.11)
            // low body + a slightly detuned partial for the net "buzz"
            let body = sin(2 * .pi * f0 * t) * 0.6 + sin(2 * .pi * (f0 * 1.5) * t) * 0.14
            // a slow 55 Hz tremor — the net cord shuddering after contact
            let buzz = 1.0 + 0.22 * sin(2 * .pi * 55 * t)
            // brief tape rattle on the attack (noise), decaying fast
            let rattle = Double.random(in: -1...1) * 0.5 * exp(-t / 0.05)
            // muffled + dead: soft-clip low, scaled quieter than the clean hits
            channel[i] = Float(tanh((body * bodyEnv * buzz + rattle) * 0.8) * 0.45)
        }
        return buffer
    }

    // MARK: - Sample loading

    /// Finds `<name>.<ext>` in the bundled `Audio/` folder (trying the common
    /// audio extensions), decodes it, and converts it to the engine's mono
    /// format so it can be scheduled on the shared player node. Returns nil if
    /// the file is missing or unreadable — the caller then keeps the synth cue.
    private static func loadSample(named name: String, to format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let exts = ["caf", "wav", "aif", "aiff", "m4a", "mp3"]
        var found: URL?
        for ext in exts {
            if let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Audio")
                ?? Bundle.main.url(forResource: name, withExtension: ext) {
                found = url
                break
            }
        }
        guard let url = found,
              let file = try? AVAudioFile(forReading: url) else { return nil }

        let srcFormat = file.processingFormat
        let frameCount = AVAudioFrameCount(file.length)
        guard frameCount > 0,
              let srcBuffer = AVAudioPCMBuffer(pcmFormat: srcFormat, frameCapacity: frameCount),
              (try? file.read(into: srcBuffer)) != nil else { return nil }

        // Already mono at the engine rate → use as-is.
        if srcFormat.sampleRate == format.sampleRate,
           srcFormat.channelCount == format.channelCount,
           srcFormat.commonFormat == format.commonFormat {
            return srcBuffer
        }

        // Otherwise convert (sample-rate + channel count) to the engine format.
        guard let converter = AVAudioConverter(from: srcFormat, to: format) else { return nil }
        let ratio = format.sampleRate / srcFormat.sampleRate
        let capacity = AVAudioFrameCount(Double(frameCount) * ratio) + 2048
        guard let outBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }

        var supplied = false
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            if supplied { outStatus.pointee = .noDataNow; return nil }
            supplied = true
            outStatus.pointee = .haveData
            return srcBuffer
        }
        var convError: NSError?
        let status = converter.convert(to: outBuffer, error: &convError, withInputFrom: inputBlock)
        guard status != .error, convError == nil, outBuffer.frameLength > 0 else { return nil }
        return outBuffer
    }
}
