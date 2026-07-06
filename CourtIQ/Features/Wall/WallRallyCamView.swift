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
                targetOverlay
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

            // DEBUG readout (temporary): frames flowing + any trajectory seen +
            // its confidence. traj climbing = Vision sees the ball.
            Text("f:\(model.framesSeen)  traj:\(model.trajDetected)  conf:\(String(format: "%.2f", model.lastConfidence))")
                .font(.system(size: 12, design: .monospaced)).foregroundStyle(.green)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(.black.opacity(0.55)).clipShape(Capsule())

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
        if !model.isRunning { return lang.t("rallycam.hint_setup") }
        return model.targetLocked ? lang.t("rallycam.hint_running") : lang.t("rallycam.hint_first")
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
        targetLocked = false
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

        videoQueue.async { [weak self] in self?.session.startRunning() }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
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

    /// Map each newly-completed trajectory to a hit (endpoint inside the target
    /// square) or a miss (endpoint outside). Vision points are normalized with a
    /// BOTTOM-left origin; the target rect is top-left, so flip Y.
    private func handle(_ observations: [VNTrajectoryObservation]) {
        guard let model else { return }
        // Diagnostics: count ANY trajectory (even below the scoring threshold) so
        // the on-screen readout shows whether Vision sees the ball at all.
        if !observations.isEmpty {
            let best = observations.map { Double($0.confidence) }.max() ?? 0
            let count = observations.count
            DispatchQueue.main.async { model.trajDetected += count; model.lastConfidence = best }
        }
        for obs in observations where obs.confidence >= minConfidence {
            guard !seenTrajectoryIDs.contains(obs.uuid),
                  let end = obs.detectedPoints.last?.location else { continue }
            seenTrajectoryIDs.insert(obs.uuid)
            let point = CGPoint(x: CGFloat(end.x), y: 1 - CGFloat(end.y))
            DispatchQueue.main.async {
                model.registerImpact(at: point)
            }
        }
        // Keep the de-dupe set from growing unbounded.
        if seenTrajectoryIDs.count > 200 { seenTrajectoryIDs.removeAll() }
    }
}
