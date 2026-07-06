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
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(model.lastHit ? AppPalette.moss : .white.opacity(0.9),
                        style: StrokeStyle(lineWidth: 3, dash: model.lastHit ? [] : [8, 6]))
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .shadow(color: .black.opacity(0.5), radius: 4)
                .animation(.easeOut(duration: 0.15), value: model.lastHit)
            // Drag to reposition the target over the wall square.
                .gesture(
                    DragGesture().onChanged { value in
                        let nx = min(max(0, value.location.x / geo.size.width - r.width / 2), 1 - r.width)
                        let ny = min(max(0, value.location.y / geo.size.height - r.height / 2), 1 - r.height)
                        model.target.origin = CGPoint(x: nx, y: ny)
                    }
                )
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
                VStack(alignment: .trailing, spacing: 2) {
                    Text(lang.t("rallycam.best")).font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.7)).textCase(.uppercase).tracking(0.5)
                    Text("\(model.maxStreak)").appFont(24, weight: .heavy).foregroundStyle(.white)
                        .monospacedDigit()
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 12).fill(.black.opacity(0.4)))
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

            Text(model.isRunning ? lang.t("rallycam.hint_running") : lang.t("rallycam.hint_setup"))
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
    /// Target square in normalized [0,1] VIEW coords (top-left origin). Default
    /// centered; the player drags it over the real wall square.
    @Published var target = CGRect(x: 0.30, y: 0.24, width: 0.40, height: 0.34)

    private var flashWork: DispatchWorkItem?

    func start() { isRunning = true; currentStreak = 0 }

    func finish(record: Bool) {
        isRunning = false
        if record && maxStreak > 0 {
            WallProgressManager.shared.record(
                drillID: "wall-rally-cam", title: "Rally Cam",
                hits: maxStreak, seconds: 0, isFreeRally: true
            )
            AppAnalytics.shared.log(AnalyticsEvent.wallSessionCompleted,
                                    ["title": "rally_cam", "hits": maxStreak])
        }
    }

    func stop() { isRunning = false }

    /// Called by the capture pipeline when a completed ball trajectory ended
    /// INSIDE the target square.
    func registerHit() {
        guard isRunning else { return }
        currentStreak += 1
        maxStreak = max(maxStreak, currentStreak)
        Haptics.success()
        AudioManager.shared.play(.ballHit)
        flash()
    }

    /// Called when a trajectory ended OUTSIDE the square (a miss) — breaks the run.
    func registerMiss() {
        guard isRunning, currentStreak > 0 else { return }
        currentStreak = 0
        Haptics.warning()
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

    // TUNE ON DEVICE ↓
    private let minConfidence: VNConfidence = 0.6
    private lazy var trajectoryRequest: VNDetectTrajectoriesRequest = {
        let request = VNDetectTrajectoriesRequest(frameAnalysisSpacing: .zero, trajectoryLength: 6) { [weak self] req, _ in
            self?.handle(req.results as? [VNTrajectoryObservation] ?? [])
        }
        // A tennis ball ~a small fraction of the frame; widen if it isn't caught.
        request.objectMinimumNormalizedRadius = 0.006
        request.objectMaximumNormalizedRadius = 0.20
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
        // Back camera in portrait → `.right`. TUNE if trajectories look rotated.
        try? sequenceHandler.perform([trajectoryRequest], on: pixelBuffer, orientation: .right)
    }

    /// Map each newly-completed trajectory to a hit (endpoint inside the target
    /// square) or a miss (endpoint outside). Vision points are normalized with a
    /// BOTTOM-left origin; the target rect is top-left, so flip Y.
    private func handle(_ observations: [VNTrajectoryObservation]) {
        guard let model else { return }
        for obs in observations where obs.confidence >= minConfidence {
            guard !seenTrajectoryIDs.contains(obs.uuid),
                  let end = obs.detectedPoints.last?.location else { continue }
            seenTrajectoryIDs.insert(obs.uuid)
            let point = CGPoint(x: CGFloat(end.x), y: 1 - CGFloat(end.y))
            let target = model.target
            DispatchQueue.main.async {
                target.contains(point) ? model.registerHit() : model.registerMiss()
            }
        }
        // Keep the de-dupe set from growing unbounded.
        if seenTrajectoryIDs.count > 200 { seenTrajectoryIDs.removeAll() }
    }
}
