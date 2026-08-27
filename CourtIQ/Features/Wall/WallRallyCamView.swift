import SwiftUI
import AVFoundation

/// "Wall Rally Cam" (MVP / experimental). Prop the phone BEHIND you facing the
/// wall and the app counts how many wall hits you string together, hearing each
/// impact through the microphone. Placement scoring (a net band, a too-high
/// zone) is planned but NOT here yet — see docs/WALL-PRACTICE-PLAN.md. Fully
/// on-device:
/// no server, no AI spend.
///
/// ⚠️ The mic only runs on a REAL DEVICE — the Simulator renders the UI but
/// hears nothing. The impact thresholds below are a FIRST PASS and will need
/// tuning on-device (wall material, room reverb, distance, ambient noise).
struct WallRallyCamView: View {
    @EnvironmentObject private var lang: LanguageManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = RallyCamModel()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if model.permissionDenied {
                permissionCard
            } else {
                RallyCamPreview(model: model).ignoresSafeArea()
                hud
            }
        }
        .statusBarHidden(true)
        // Keep the screen awake — you're across the room hitting a ball, not
        // touching the phone. (A top competitor's #1 complaint: auto-lock kills
        // the recording mid-session.)
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            model.stop()
        }
    }

    // MARK: - Heads-up display

    private var hud: some View {
        VStack {
            HStack(alignment: .top) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.headline.weight(.bold)).foregroundStyle(.white)
                        .padding(12).background(Circle().fill(.black.opacity(0.4)))
                }
                Spacer()
                statPill(label: lang.t("rallycam.best"), value: "\(model.maxStreak)")
            }
            .padding()

            Spacer()

            // Big live streak count.
            VStack(spacing: 4) {
                Text("\(model.currentStreak)")
                    .appFont(80, weight: .heavy).foregroundStyle(.white)
                    .monospacedDigit().shadow(color: .black.opacity(0.6), radius: 8)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: model.currentStreak)
                Text(lang.t("rallycam.in_a_row"))
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.white.opacity(0.85))
            }

            Spacer()

            Text(hintText)
                .font(.footnote).foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center).padding(.horizontal, 32)
                .padding(.bottom, 8)

            Button {
                model.isRunning ? model.finish(record: true) : model.start()
                if !model.isRunning { dismiss() }
            } label: {
                Text(model.isRunning ? lang.t("rallycam.stop") : lang.t("rallycam.start"))
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 15)
                    .background(model.isRunning ? AppPalette.alert : AppPalette.clay)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(.horizontal, 24).padding(.bottom, 28)
        }
    }

    private func statPill(label: String, value: String) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(label).font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.7)).textCase(.uppercase).tracking(0.5)
            Text(value).appFont(22, weight: .heavy).foregroundStyle(.white).monospacedDigit()
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 12).fill(.black.opacity(0.4)))
    }

    private var hintText: String {
        model.isRunning ? lang.t("rallycam.hint_running") : lang.t("rallycam.hint_setup")
    }

    private var permissionCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "camera.fill").appFont(40, design: .default).foregroundStyle(.white)
            Text(lang.t("rallycam.permission_title")).appFont(18, weight: .heavy).foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text(lang.t("rallycam.permission_body")).font(.subheadline).foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            Button(lang.t("common.close")) { dismiss() }
                .buttonStyle(.borderedProminent).tint(AppPalette.clay).padding(.top, 6)
        }
        .padding(32)
    }
}

// MARK: - Model

@MainActor
final class RallyCamModel: ObservableObject {
    @Published var currentStreak = 0
    @Published var maxStreak = 0
    @Published var isRunning = false
    @Published var lastHit = false
    @Published var permissionDenied = false
    /// The mic is the whole detector. Vision trajectory fitting was tried here
    /// and abandoned — `VNDetectTrajectoriesRequest` fits PARABOLIC paths, and a
    /// ball rebounding off a wall toward the camera isn't one. The placement
    /// layer (net band / too high) is planned on a different mechanism entirely:
    /// frame-differencing at the audio impact's timestamp. See
    /// docs/WALL-PRACTICE-PLAN.md.
    private var lastImpactTime: TimeInterval = 0

    private var flashWork: DispatchWorkItem?

    func start() {
        isRunning = true
        currentStreak = 0; maxStreak = 0
        lastImpactTime = 0
    }

    /// A wall impact heard by the mic. A gap over 3s ends the rally; the longest
    /// rally is the best streak. No sound cue here, so the mic doesn't hear our
    /// own feedback.
    func registerAudioHit() {
        guard isRunning else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if now - lastImpactTime > 3.0 { currentStreak = 0 }
        lastImpactTime = now
        currentStreak += 1
        maxStreak = max(maxStreak, currentStreak)
        Haptics.success()
        flash()
    }

    func finish(record: Bool) {
        isRunning = false
        if record && maxStreak > 0 {
            WallProgressManager.shared.record(
                drillID: "wall-rally-cam", title: "Rally Cam",
                hits: maxStreak, seconds: 0, isFreeRally: true
            )
            AppAnalytics.shared.log(AnalyticsEvent.wallSessionCompleted,
                                    ["title": "rally_cam", "hits": maxStreak])
            RatingPrompt.registerWin()   // a finished rally is a genuine win moment
        }
    }

    func stop() { isRunning = false }

    private func flash() {
        lastHit = true
        flashWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.lastHit = false }
        flashWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }
}

// MARK: - Camera preview + mic pipeline (UIKit-backed)

struct RallyCamPreview: UIViewControllerRepresentable {
    let model: RallyCamModel

    func makeUIViewController(context: Context) -> RallyCamController {
        let c = RallyCamController()
        c.model = model
        return c
    }
    func updateUIViewController(_ controller: RallyCamController, context: Context) {}
}

/// Owns the `AVCaptureSession` (preview only, for now) and the mic-based
/// `AudioImpactDetector` that drives the hit count.
final class RallyCamController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    weak var model: RallyCamModel?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let videoQueue = DispatchQueue(label: "dropvolley.rallycam.video")
    /// The hit detector.
    private let impactDetector = AudioImpactDetector()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                guard let self else { return }
                if granted { self.configureSession() }
                else { self.model?.permissionDenied = true }
            }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .high
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
        }
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: videoQueue)
        if session.canAddOutput(output) { session.addOutput(output) }
        session.commitConfiguration()

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.addSublayer(preview)
        previewLayer = preview

        startImpactAudio()
        videoQueue.async { [weak self] in self?.session.startRunning() }
    }

    /// Wire + start the mic impact counter (the primary hit detector). Peaks are
    /// throttled to ~10 Hz for the on-screen tuning readout.
    private func startImpactAudio() {
        impactDetector.onImpact = { [weak self] in
            DispatchQueue.main.async { self?.model?.registerAudioHit() }
        }
        impactDetector.start()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        impactDetector.stop()
        videoQueue.async { [weak self] in self?.session.stopRunning() }
    }

    /// Frames arrive but nothing consumes them yet. The output stays wired
    /// because the placement layer (docs/WALL-PRACTICE-PLAN.md, P2) needs the
    /// two or three frames around each audio impact — but running a Vision pass
    /// on every frame to feed a readout nobody sees was pure battery cost.
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {}
}

// MARK: - Audio impact detector (primary hit counter)

/// A single biquad section (RBJ cookbook). Cascading a high-pass + low-pass gives
/// a band-pass that isolates a tennis-ball impact's energy (~100 Hz–3 kHz) and
/// rejects wind/handling rumble below and hiss/sibilance above — the biggest
/// single false-positive reduction for impact detection.
private struct Biquad {
    var b0: Float = 1, b1: Float = 0, b2: Float = 0, a1: Float = 0, a2: Float = 0
    var x1: Float = 0, x2: Float = 0, y1: Float = 0, y2: Float = 0

    mutating func process(_ x: Float) -> Float {
        let y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2 = x1; x1 = x; y2 = y1; y1 = y
        return y
    }

    static func highPass(fs: Double, f0: Double, q: Double = 0.707) -> Biquad {
        let w0 = 2 * Double.pi * f0 / fs, c = cos(w0), alpha = sin(w0) / (2 * q)
        let a0 = 1 + alpha
        var bq = Biquad()
        bq.b0 = Float((1 + c) / 2 / a0); bq.b1 = Float(-(1 + c) / a0); bq.b2 = bq.b0
        bq.a1 = Float(-2 * c / a0); bq.a2 = Float((1 - alpha) / a0)
        return bq
    }

    static func lowPass(fs: Double, f0: Double, q: Double = 0.707) -> Biquad {
        let w0 = 2 * Double.pi * f0 / fs, c = cos(w0), alpha = sin(w0) / (2 * q)
        let a0 = 1 + alpha
        var bq = Biquad()
        bq.b0 = Float((1 - c) / 2 / a0); bq.b1 = Float((1 - c) / a0); bq.b2 = bq.b0
        bq.a1 = Float(-2 * c / a0); bq.a2 = Float((1 - alpha) / a0)
        return bq
    }
}

/// Placement-independent hit counter: taps the mic and flags a hit on a sharp
/// amplitude transient (a ball striking the wall). Far more robust than
/// parabolic Vision for simply COUNTING wall hits — works from any angle, in any
/// light, phone anywhere it can HEAR the wall. TUNE `threshold` on device using
/// the on-screen live "mic peak" readout.
final class AudioImpactDetector {
    private let engine = AVAudioEngine()
    private var running = false
    private var lastHit: TimeInterval = 0

    var onImpact: (() -> Void)?

    // TUNE ON DEVICE ↓  — a band-pass isolates the impact band, then an ADAPTIVE
    // threshold triggers when the FILTERED peak spikes above the tracked ambient
    // floor (abs floor so silence never fires).
    private let absFloor: Float = 0.02            // never trigger below this
    private let spikeRatio: Float = 2.8           // impact ≈ this × ambient
    private let refractory: TimeInterval = 0.14   // min gap between hits (s)
    private var ambient: Float = 0.02             // running noise-floor estimate
    // Band-pass ≈ 100 Hz–3 kHz (coefficients set once the sample rate is known).
    private var hp = Biquad(), lp = Biquad()
    private var filtersReady = false

    func start() {
        guard !running else { return }
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            guard granted, let self else { return }
            DispatchQueue.main.async { self.configure() }
        }
    }

    private func configure() {
        do {
            let session = AVAudioSession.sharedInstance()
            // .measurement disables AGC/noise-suppression → raw transients.
            try session.setCategory(.playAndRecord, mode: .measurement,
                                    options: [.defaultToSpeaker, .mixWithOthers])
            try session.setActive(true, options: [])
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            let fs = format.sampleRate > 0 ? format.sampleRate : 44100
            hp = .highPass(fs: fs, f0: 100)
            lp = .lowPass(fs: fs, f0: 3000)
            filtersReady = true
            input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
                self?.process(buffer)
            }
            engine.prepare()
            try engine.start()
            running = true
        } catch {
            running = false
        }
    }

    private func process(_ buffer: AVAudioPCMBuffer) {
        guard let ch = buffer.floatChannelData?[0] else { return }
        let n = Int(buffer.frameLength)
        var peak: Float = 0
        var i = 0
        while i < n {
            // Band-pass each sample, then track the peak of the FILTERED signal.
            let f = filtersReady ? lp.process(hp.process(ch[i])) : ch[i]
            let a = abs(f)
            if a > peak { peak = a }
            i += 1
        }
        let threshold = max(absFloor, ambient * spikeRatio)
        let now = ProcessInfo.processInfo.systemUptime
        if peak >= threshold && now - lastHit >= refractory {
            lastHit = now
            onImpact?()
        } else {
            // Track the ambient floor from NON-impact frames only, so a hit
            // doesn't inflate the floor and suppress the next one.
            ambient = ambient * 0.95 + peak * 0.05
        }
    }

    func stop() {
        guard running else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        running = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
