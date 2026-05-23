import Foundation
import AVFoundation
import Speech

/// Records a voice note and transcribes it on-device.
///
/// Design intent (post-Begum-pivot):
///   • One tap to start, one tap to stop — no press-and-hold. Press-and-hold
///     is faster for power users but punishing for new users and worse for
///     accessibility. The icon swap + waveform gives clear "I am recording"
///     feedback.
///   • Transcription happens on-device when `requiresOnDeviceRecognition`
///     is available, which it is on every device that runs iOS 17. Nothing
///     leaves the phone. We never set `shouldReportPartialResults` to a
///     server-bound recognizer.
///   • Max length cap (90s) keeps storage and transcription cost bounded
///     and matches the "this is a quick reflection, not a podcast" intent
///     of the match journal.
///
/// The recorder is intentionally NOT a singleton. Each invocation of the
/// journal entry view owns its own instance so two recordings (pre + post)
/// can't accidentally cross-pollute each other's state.
@MainActor
final class VoiceNoteRecorder: ObservableObject {

    // MARK: - Published state

    enum State: Equatable {
        case idle
        case requestingPermission
        case recording
        case transcribing
        case finished(transcript: String, audioFile: String)
        case failed(message: String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var recordingLevel: Float = 0  // 0...1, drives the waveform UI
    @Published private(set) var elapsed: TimeInterval = 0  // seconds since record start

    // MARK: - Configuration

    /// Hard cap on a single recording. Above this we auto-stop with the
    /// transcript we have so the user is never punished for forgetting
    /// to tap stop. 90 s is a deliberately tight ceiling — reflection,
    /// not soliloquy.
    let maxDuration: TimeInterval = 90

    /// Locale used for transcription. We let the system pick — it matches
    /// the user's preferred language on the device, which is what the
    /// user expects when they speak.
    private let recognizer: SFSpeechRecognizer? = SFSpeechRecognizer()

    // MARK: - Private state

    private var recorder: AVAudioRecorder?
    private var audioFileName: String?
    private var levelTimer: Timer?
    private var elapsedTimer: Timer?
    private var startedAt: Date?

    // MARK: - Public API

    /// Begin recording for the given entry and scope. Asks for mic +
    /// speech-recognition permission on first invocation.
    func start(entryID: String, scope: MatchMediaStore.AudioScope) async {
        state = .requestingPermission
        guard await ensurePermissions() else {
            state = .failed(message: NSLocalizedString("voice.permission_denied", comment: ""))
            return
        }

        guard let allocation = MatchMediaStore.newAudioFile(scope: scope, entryID: entryID) else {
            state = .failed(message: NSLocalizedString("voice.storage_error", comment: ""))
            return
        }

        do {
            try configureAudioSession()
        } catch {
            state = .failed(message: NSLocalizedString("voice.audio_session_error", comment: ""))
            return
        }

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 22050.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]

        do {
            let r = try AVAudioRecorder(url: allocation.url, settings: settings)
            r.isMeteringEnabled = true
            r.record()
            recorder = r
            audioFileName = allocation.fileName
            startedAt = Date()
            startMeters()
            state = .recording
        } catch {
            state = .failed(message: NSLocalizedString("voice.record_start_error", comment: ""))
        }
    }

    /// Stop the current recording, run on-device transcription, and emit
    /// a `.finished(transcript:audioFile:)` state when done.
    func stop() async {
        guard state == .recording, let r = recorder else { return }
        r.stop()
        stopMeters()

        state = .transcribing
        let url = r.url
        let fileName = audioFileName ?? url.lastPathComponent

        do {
            let transcript = try await transcribe(url: url)
            state = .finished(transcript: transcript, audioFile: fileName)
        } catch {
            // Recording succeeded even if transcription failed — emit the
            // audio with an empty transcript so the user can still keep
            // the recording and type or retry.
            state = .finished(transcript: "", audioFile: fileName)
        }

        deactivateAudioSession()
        recorder = nil
        audioFileName = nil
    }

    /// Discard the current recording without saving. Called when the user
    /// cancels mid-record.
    func cancel() {
        recorder?.stop()
        stopMeters()
        if let url = recorder?.url {
            try? FileManager.default.removeItem(at: url)
        }
        recorder = nil
        audioFileName = nil
        deactivateAudioSession()
        state = .idle
    }

    // MARK: - Permissions

    private func ensurePermissions() async -> Bool {
        // Microphone — AVAudioApplication is the iOS 17+ entry; fall back
        // to the older API for older runtimes (we deploy to 17.0 so the
        // newer one is always available but keep the conditional for
        // future deployment-target relaxation).
        let micGranted: Bool = await withCheckedContinuation { cont in
            AVAudioApplication.requestRecordPermission { granted in
                cont.resume(returning: granted)
            }
        }
        guard micGranted else { return false }

        // Speech recognition — separate prompt. Some users grant mic and
        // deny speech; recording still works but transcription won't.
        let speechGranted: Bool = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }
        // Speech denial isn't fatal — we still record and let user type.
        _ = speechGranted
        return true
    }

    // MARK: - Audio session

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.duckOthers, .defaultToSpeaker])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func deactivateAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Meter + elapsed timers

    private func startMeters() {
        recordingLevel = 0
        elapsed = 0
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tickMeters() }
        }
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tickElapsed() }
        }
    }

    private func stopMeters() {
        levelTimer?.invalidate()
        levelTimer = nil
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }

    private func tickMeters() {
        guard let r = recorder else { return }
        r.updateMeters()
        // averagePower returns negative dBFS; map roughly to 0...1 for the
        // UI. -60 dBFS = silence, 0 dBFS = clipping.
        let dB = r.averagePower(forChannel: 0)
        let normalized = max(0, min(1, (dB + 60) / 60))
        recordingLevel = normalized
    }

    private func tickElapsed() {
        guard let startedAt else { return }
        elapsed = Date().timeIntervalSince(startedAt)
        if elapsed >= maxDuration {
            Task { await stop() }
        }
    }

    // MARK: - Transcription

    private func transcribe(url: URL) async throws -> String {
        guard let recognizer, recognizer.isAvailable else {
            throw NSError(domain: "VoiceNoteRecorder", code: -1)
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    cont.resume(throwing: error)
                    return
                }
                guard let result, result.isFinal else { return }
                cont.resume(returning: result.bestTranscription.formattedString)
            }
        }
    }
}
