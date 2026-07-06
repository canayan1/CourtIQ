import SwiftUI
import AVFoundation
import Vision

/// "Wall Rally Cam" (MVP / experimental). Prop the phone BEHIND you facing the
/// wall, frame the target square on the wall, and the app counts how many times
/// in a row you land a ball inside that square — using Vision's on-device
/// ball-trajectory detection (`VNDetectTrajectoriesRequest`). Fully on-device:
/// no server, no AI spend.
///
/// ⚠️ Camera + Vision only run on a REAL DEVICE — the Simulator renders the UI
/// but detects nothing. The detection thresholds below are a FIRST PASS and
/// WILL need tuning on-device (lighting, ball/wall contrast, camera angle).
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
        .onDisappear { model.stop() }
    }

    // MARK: - Target square the player frames on the wall

    private var targetOverlay: some View {
        GeometryReader { geo in
            let r = model.target
            let rect = CGRect(x: r.minX * geo.size.width, y: r.minY * geo.size.height,
                              width: r.width * geo.size.width, height: r.height * geo.size.height)
            ZStack {
                if model.targetLocked {
                    // Auto-placed on the first impact; flashes green on a hit.
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(model.lastHit ? AppPalette.moss : .white.opacity(0.95),
                                style: StrokeStyle(lineWidth: 3, dash: model.lastHit ? [] : [8, 6]))
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                        .shadow(color: .black.opacity(0.5), radius: 4)
                        .animation(.easeOut(duration: 0.15), value: model.lastHit)
                } else if model.isRunning {
                    // Waiting for the first hit to auto-place the target.
                    Image(systemName: "scope")
                        .font(.system(size: 54, weight: .thin)).foregroundStyle(.white.opacity(0.65))
                        .position(x: geo.size.width / 2, y: geo.size.height * 0.42)
                }
            }
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
                HStack(spacing: 10) {
                    statPill(label: lang.t("rallycam.best"), value: "\(model.maxStreak)")
                    if model.targetLocked {
                        statPill(label: lang.t("rallycam.accuracy"), value: "\(model.accuracy)%")
                    }
                }
            }
            .padding()

            // DEBUG readout (temporary): the SOUND-hit count is the key signal
            // now; the live mic peak is for tuning the impact threshold.
            VStack(spacing: 3) {
                Text("SOUND hits: \(model.audioHits)")
                Text("peak \(String(format: "%.2f", model.audioPeak))   hold \(String(format: "%.2f", model.audioPeakHold))")
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                Text("triggers @ \(String(format: "%.2f", model.audioThreshold))")
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.75))
            }
            .font(.system(size: 20, weight: .heavy, design: .monospaced))
            .foregroundStyle(model.audioHits > 0 ? .green : .yellow)
            .padding(12)
            .background(.black.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

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
    @Published var attempts = 0
    @Published var hitsInTarget = 0
    @Published var isRunning = false
    @Published var lastHit = false
    @Published var targetLocked = false
    @Published var permissionDenied = false
    // First-light diagnostics (shown on-screen; remove once detection is tuned).
    @Published var framesSeen = 0
    @Published var trajDetected = 0
    @Published var lastConfidence: Double = 0
    // Audio path — the primary, placement-independent hit counter.
    @Published var audioPeak: Float = 0        // live mic peak
    @Published var audioPeakHold: Float = 0    // loudest recent peak (read on a soft hit)
    @Published var audioThreshold: Float = 0   // current adaptive trigger level
    @Published var audioHits = 0
    private var lastImpactTime: TimeInterval = 0
    /// Target square in normalized [0,1] VIEW coords (top-left origin). It is
    /// AUTO-set to where the FIRST ball hits the wall (no manual framing).
    @Published var target = CGRect(x: 0.38, y: 0.32, width: 0.24, height: 0.24)

    /// Share of shots that landed inside the target (0–100).
    var accuracy: Int {
        attempts == 0 ? 0 : Int((Double(hitsInTarget) / Double(attempts) * 100).rounded())
    }

    private var flashWork: DispatchWorkItem?

    func start() {
        isRunning = true
        currentStreak = 0; maxStreak = 0
        attempts = 0; hitsInTarget = 0
        audioHits = 0; lastImpactTime = 0
        audioPeakHold = 0
        targetLocked = false
    }

    /// A wall impact heard by the mic — the primary, placement-independent hit
    /// counter (Vision trajectory detection proved too finicky for this setup).
    /// A gap over 3s ends the rally; the longest rally is the best streak. No
    /// sound cue here, so the mic doesn't hear our own feedback.
    func registerAudioHit() {
        guard isRunning else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if now - lastImpactTime > 3.0 { currentStreak = 0 }
        lastImpactTime = now
        currentStreak += 1
        maxStreak = max(maxStreak, currentStreak)
        audioHits += 1
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
                                    ["title": "rally_cam", "hits": maxStreak, "accuracy": accuracy])
        }
    }

    func stop() { isRunning = false }

    /// A completed ball trajectory ended at `point` (normalized, top-left view
    /// coords). The FIRST impact auto-locks the target around it; after that,
    /// in-target = hit + streak, out-of-target = miss (breaks the streak).
    func registerImpact(at point: CGPoint) {
        guard isRunning else { return }
        if !targetLocked {
            lockTarget(around: point)
            targetLocked = true
            attempts = 1; hitsInTarget = 1
            currentStreak = 1; maxStreak = 1
            Haptics.success(); AudioManager.shared.play(.ballHit); flash()
            return
        }
        attempts += 1
        if target.contains(point) {
            hitsInTarget += 1
            currentStreak += 1
            maxStreak = max(maxStreak, currentStreak)
            Haptics.success(); AudioManager.shared.play(.ballHit); flash()
        } else {
            currentStreak = 0
            Haptics.warning()
        }
    }

    /// Center a fixed-size target square on the first impact point (clamped).
    private func lockTarget(around point: CGPoint) {
        let size: CGFloat = 0.24
        let x = min(max(0, point.x - size / 2), 1 - size)
        let y = min(max(0, point.y - size / 2), 1 - size)
        target = CGRect(x: x, y: y, width: size, height: size)
    }

    private func flash() {
        lastHit = true
        flashWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.lastHit = false }
        flashWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }
}

// MARK: - Camera + Vision pipeline (UIKit-backed)

struct RallyCamPreview: UIViewControllerRepresentable {
    let model: RallyCamModel

    func makeUIViewController(context: Context) -> RallyCamController {
        let c = RallyCamController()
        c.model = model
        return c
    }
    func updateUIViewController(_ controller: RallyCamController, context: Context) {}
}

/// Owns the `AVCaptureSession` + the `VNDetectTrajectoriesRequest` sequence, and
/// converts completed trajectories into hit/miss events on the model.
final class RallyCamController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    weak var model: RallyCamModel?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let videoQueue = DispatchQueue(label: "dropvolley.rallycam.video")
    private let sequenceHandler = VNSequenceRequestHandler()
    /// De-dupe: one hit/miss per detected trajectory id.
    private var seenTrajectoryIDs: Set<UUID> = []
    /// Mic-based impact counter — the PRIMARY hit detector.
    private let impactDetector = AudioImpactDetector()
    private var lastPeakUpdate: TimeInterval = 0

    private var frameCounter = 0
    // Loosened for first-light debugging — watch the on-screen f/traj/conf readout.
    private let minConfidence: VNConfidence = 0.3
    private lazy var trajectoryRequest: VNDetectTrajectoriesRequest = {
        let request = VNDetectTrajectoriesRequest(frameAnalysisSpacing: .zero, trajectoryLength: 3) { [weak self] req, _ in
            self?.handle(req.results as? [VNTrajectoryObservation] ?? [])
        }
        // A tennis ball can be tiny in-frame; keep the range wide while debugging.
        request.objectMinimumNormalizedRadius = 0.003
        request.objectMaximumNormalizedRadius = 0.30
        return request
    }()

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
        impactDetector.onPeak = { [weak self] peak, threshold in
            guard let self else { return }
            let now = ProcessInfo.processInfo.systemUptime
            guard now - self.lastPeakUpdate > 0.08 else { return }
            self.lastPeakUpdate = now
            DispatchQueue.main.async {
                guard let m = self.model else { return }
                m.audioPeak = peak
                m.audioThreshold = threshold
                m.audioPeakHold = max(m.audioPeakHold * 0.9, peak)
            }
        }
        impactDetector.start()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        impactDetector.stop()
        videoQueue.async { [weak self] in self?.session.stopRunning() }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        frameCounter += 1
        if frameCounter % 10 == 0 {
            let n = frameCounter
            DispatchQueue.main.async { self.model?.framesSeen = n }
        }
        // Back camera in portrait → `.right`. TUNE if trajectories look rotated.
        try? sequenceHandler.perform([trajectoryRequest], on: pixelBuffer, orientation: .right)
    }

    /// Vision is now DIAGNOSTIC-ONLY (the mic drives the hit count). We still
    /// count any detected trajectory into the on-screen readout so we can tell
    /// whether Vision ever sees the ball in this setup — the visual target /
    /// accuracy layer is a v2 that needs a reliable detector first.
    private func handle(_ observations: [VNTrajectoryObservation]) {
        guard let model, !observations.isEmpty else { return }
        let best = observations.map { Double($0.confidence) }.max() ?? 0
        let count = observations.count
        DispatchQueue.main.async { model.trajDetected += count; model.lastConfidence = best }
    }
}

// MARK: - Audio impact detector (primary hit counter)

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
    var onPeak: ((Float, Float) -> Void)?   // (live peak, current trigger threshold)

    // TUNE ON DEVICE ↓  — ADAPTIVE: trigger when the peak spikes well above the
    // tracked ambient floor, with an absolute floor so silence never fires.
    private let absFloor: Float = 0.03            // never trigger below this
    private let spikeRatio: Float = 2.8           // impact ≈ this × ambient
    private let refractory: TimeInterval = 0.14   // min gap between hits (s)
    private var ambient: Float = 0.02             // running noise-floor estimate

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
            let a = abs(ch[i])
            if a > peak { peak = a }
            i += 1
        }
        let threshold = max(absFloor, ambient * spikeRatio)
        onPeak?(peak, threshold)
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
