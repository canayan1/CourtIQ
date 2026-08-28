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
    /// The ladder rung this was opened from. Sets the rep goal, records the
    /// session against that drill's personal best, and clears the level when
    /// the goal is met. Nil = a free rally with no goal.
    let drill: WallDrill?

    @EnvironmentObject private var lang: LanguageManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = RallyCamModel()

    init(drill: WallDrill? = nil) { self.drill = drill }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // The mic does the counting, so a denied camera costs the preview
            // and the band — not the session. Taking the whole screen away for
            // a permission the counter never needed was the wrong trade.
            if !model.permissionDenied {
                RallyCamPreview(model: model).ignoresSafeArea()
                bandOverlay.ignoresSafeArea()
            }
            hud
        }
        .statusBarHidden(true)
        // Keep the screen awake — you're across the room hitting a ball, not
        // touching the phone. (A top competitor's #1 complaint: auto-lock kills
        // the recording mid-session.)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            model.configure(for: drill)
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            model.stop()
        }
    }

    // MARK: - Target band

    /// Two lines the player drags onto their wall: below the lower one the ball
    /// hit the net, above the upper one it would have sailed long. Between them
    /// is a driving ball.
    ///
    /// Nothing scores this yet — the mic can hear THAT a ball hit, not WHERE.
    /// The band earns its place anyway: a visible target is where the external
    /// focus of attention comes from, and that effect is the best-evidenced
    /// thing in the wall-practice literature. See docs/WALL-PRACTICE-PLAN.md.
    private var bandOverlay: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let topY = model.bandTop * h
            let bottomY = model.bandBottom * h

            ZStack(alignment: .topLeading) {
                // The good band.
                Rectangle()
                    .fill(bandTint)
                    .frame(height: max(0, bottomY - topY))
                    .offset(y: topY)

                zoneLabel(lang.t("rallycam.zone_long"), color: AppPalette.alert)
                    .offset(y: max(6, topY - 26))
                zoneLabel(lang.t("rallycam.zone_net"), color: AppPalette.alert)
                    .offset(y: min(h - 26, bottomY + 8))

                bandLine(at: topY, size: geo.size, isTop: true)
                bandLine(at: bottomY, size: geo.size, isTop: false)
            }
            .frame(width: geo.size.width, height: h, alignment: .topLeading)
            .coordinateSpace(name: Self.bandSpace)
        }
        .allowsHitTesting(!model.isRunning)
    }

    /// The band lights up on a ball that landed in it. Anything we couldn't
    /// read leaves it alone — silence, not a red mark.
    private var bandTint: Color {
        guard model.isRunning else { return AppPalette.moss.opacity(0.16) }
        switch model.lastZone {
        case .band:    return AppPalette.moss.opacity(model.lastHit ? 0.40 : 0.16)
        case .unknown: return AppPalette.moss.opacity(0.16)
        case .net, .long: return AppPalette.moss.opacity(0.16)
        }
    }

    private func zoneLabel(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.heavy)).tracking(0.8)
            .foregroundStyle(.white)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(color.opacity(0.85), in: Capsule())
            .padding(.leading, 14)
    }

    /// One draggable line. The grab area is 44pt tall (a finger, not a hairline)
    /// while the drawn line stays thin. Handles disappear once the rally starts
    /// so a stray touch can't move the band mid-session.
    private func bandLine(at y: CGFloat, size: CGSize, isTop: Bool) -> some View {
        ZStack {
            Rectangle()
                .fill(.white)
                .frame(height: 2)
                .shadow(color: .black.opacity(0.6), radius: 3)
            if !model.isRunning {
                HStack {
                    Spacer()
                    Image(systemName: "line.3.horizontal")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(AppPalette.ink)
                        .padding(6)
                        .background(Circle().fill(.white))
                        .padding(.trailing, 14)
                }
            }
        }
        .frame(width: size.width, height: 44)
        .contentShape(Rectangle())
        .position(x: size.width / 2, y: y)
        .gesture(
            DragGesture(coordinateSpace: .named(Self.bandSpace))
                .onChanged { value in
                    guard !model.isRunning else { return }
                    model.moveLine(isTop: isTop, toNormalized: value.location.y / max(1, size.height))
                }
                .onEnded { _ in Haptics.tap() }
        )
    }

    private static let bandSpace = "rallycam.band"

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
                Text(lang.t("common.beta"))
                    .font(.caption2.weight(.heavy)).kerning(0.8)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(AppPalette.ink.opacity(0.85), in: Capsule())
                    .padding(.trailing, 8)
                if let goal = model.goal {
                    statPill(label: lang.t("rallycam.goal"), value: "\(model.maxStreak)/\(goal)")
                } else {
                    statPill(label: lang.t("rallycam.best"), value: "\(model.maxStreak)")
                }
            }
            .padding()

            Spacer()

            // Big live streak count.
            VStack(spacing: 4) {
                Text("\(model.currentStreak)")
                    .appFont(80, weight: .heavy)
                    .foregroundStyle(model.goalMet ? AppPalette.moss : .white)
                    .monospacedDigit().shadow(color: .black.opacity(0.6), radius: 8)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: model.currentStreak)
                Text(lang.t("rallycam.in_a_row"))
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.white.opacity(0.85))

                if model.readCount > 0 {
                    HStack(spacing: 12) {
                        splitChip(count: model.zoneCounts[.band] ?? 0,
                                  label: lang.t("rallycam.zone_band"), color: AppPalette.moss)
                        splitChip(count: model.zoneCounts[.net] ?? 0,
                                  label: lang.t("rallycam.zone_net"), color: AppPalette.alert)
                        splitChip(count: model.zoneCounts[.long] ?? 0,
                                  label: lang.t("rallycam.zone_long"), color: AppPalette.alert)
                    }
                    .padding(.top, 10)
                }
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

    /// Placement is REPORTED, never enforced: these numbers sit beside the
    /// streak and can't reduce it. Balls we couldn't read are simply absent
    /// rather than shown as a failure.
    private func splitChip(count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(count)").appFont(20, weight: .heavy).foregroundStyle(color).monospacedDigit()
            Text(label).font(.caption2.weight(.bold)).tracking(0.5)
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(minWidth: 52)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 10).fill(.black.opacity(0.35)))
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
        if model.permissionDenied { return lang.t("rallycam.no_camera") }
        return model.isRunning ? lang.t("rallycam.hint_running") : lang.t("rallycam.hint_setup")
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

    /// The target band, as normalized y in VIEW coords (0 = top of the frame).
    /// `bandTop` is the higher line on screen, so it holds the SMALLER number.
    ///
    /// The player drags these; nothing detects them. A wall's net height depends
    /// on how far back they stand, which no detector could know — and coaches
    /// solve this with tape or paint, so we do the same thing in software.
    @Published var bandTop: CGFloat = RallyCamModel.loadBand().top {
        didSet { persistBand() }
    }
    @Published var bandBottom: CGFloat = RallyCamModel.loadBand().bottom {
        didSet { persistBand() }
    }

    /// Classify a reading against the lines the player set.
    func zone(forNormalizedY y: CGFloat) -> WallZone {
        if y < bandTop { return .long }
        if y > bandBottom { return .net }
        return .band
    }

    /// Keeps the band from collapsing to nothing while being dragged.
    static let minBandHeight: CGFloat = 0.06

    /// Where the last few balls landed. The streak is NOT affected by any of
    /// this: the mic counts reps and the camera only reports. An unproven
    /// detector must never be able to take a rep away from someone.
    @Published private(set) var zoneCounts: [WallZone: Int] = [:]
    @Published private(set) var lastZone: WallZone = .unknown

    var readCount: Int { zoneCounts.values.reduce(0, +) - (zoneCounts[.unknown] ?? 0) }

    /// Rep goal for this rung, from the drill's `.reps` target. Duration-based
    /// drills have no goal here — the mic counts hits, not seconds.
    @Published private(set) var goal: Int?
    private var drillID: String?
    private var drillTitle: String = "Rally Cam"

    var goalMet: Bool {
        guard let goal else { return false }
        return maxStreak >= goal
    }

    func configure(for drill: WallDrill?) {
        guard let drill else { goal = nil; drillID = nil; return }
        drillID = drill.id
        drillTitle = drill.title
        if case .reps(let n) = drill.target { goal = n } else { goal = nil }
    }

    private static let bandKey = "DropVolley.rallycam.band.v1"

    private static func loadBand() -> (top: CGFloat, bottom: CGFloat) {
        let d = UserDefaults.standard
        guard let stored = d.array(forKey: bandKey) as? [Double], stored.count == 2 else {
            // A first guess for a phone propped behind the player: the band sits
            // a little above centre, where a driving ball hits a wall.
            return (0.34, 0.56)
        }
        return (CGFloat(stored[0]), CGFloat(stored[1]))
    }

    private func persistBand() {
        UserDefaults.standard.set([Double(bandTop), Double(bandBottom)], forKey: Self.bandKey)
    }

    /// Drag one line, clamped so the band keeps a usable height and neither
    /// line can pass the other or leave the frame.
    func moveLine(isTop: Bool, toNormalized y: CGFloat) {
        let gap = Self.minBandHeight
        if isTop {
            bandTop = min(max(0.02, y), bandBottom - gap)
        } else {
            bandBottom = max(min(0.98, y), bandTop + gap)
        }
    }

    private var flashWork: DispatchWorkItem?

    func start() {
        isRunning = true
        currentStreak = 0; maxStreak = 0
        lastImpactTime = 0
        zoneCounts = [:]; lastZone = .unknown
    }

    /// A wall impact heard by the mic. A gap over 3s ends the rally; the longest
    /// rally is the best streak. No sound cue here, so the mic doesn't hear our
    /// own feedback.
    /// The placement of the rep the mic just counted, once the locator has
    /// looked. Arrives a beat after `registerAudioHit` and never changes the
    /// count — only the tally.
    func registerZone(_ zone: WallZone) {
        guard isRunning else { return }
        lastZone = zone
        zoneCounts[zone, default: 0] += 1
    }

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
                drillID: drillID ?? "wall-rally-cam", title: drillTitle,
                hits: maxStreak, seconds: 0, isFreeRally: drillID == nil
            )
            // The rung is cleared by DOING it, not by tapping "I did this".
            if goalMet, let drillID { WallProgressManager.shared.markCleared(drillID) }
            // Log what the detector managed to read as well as the count. If
            // `unknown` dominates in the field, the locator's thresholds are
            // wrong and this is how we'll find out.
            AppAnalytics.shared.log(AnalyticsEvent.wallSessionCompleted,
                                    ["title": "rally_cam",
                                     "hits": maxStreak,
                                     "in_band": zoneCounts[.band] ?? 0,
                                     "net": zoneCounts[.net] ?? 0,
                                     "long": zoneCounts[.long] ?? 0,
                                     "unread": zoneCounts[.unknown] ?? 0])
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
    /// Answers WHERE, at the instant the detector says WHEN.
    private let locator = WallBallLocator()

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
        // Bi-planar YUV so the locator can read plane 0 as a ready-made
        // greyscale image. With BGRA it would have to convert every frame.
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String:
                kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        ]
        output.setSampleBufferDelegate(self, queue: videoQueue)
        if session.canAddOutput(output) { session.addOutput(output) }

        // Deliver frames already upright, so a y in the buffer means the same
        // thing as a y in the band overlay. Without this the buffer is
        // landscape and every reading would be rotated 90°.
        //
        // The preview is aspectFill, which crops — but only horizontally. Any
        // camera buffer (16:9 = 0.5625, 4:3 = 0.75 w/h) is proportionally wider
        // than a modern iPhone screen (~0.46), so filling the view matches the
        // HEIGHT exactly and spills over the sides. Vertical maps 1:1, which is
        // the only axis the band cares about.
        if let connection = output.connection(with: .video),
           connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
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
        impactDetector.onImpact = { [weak self] impactTime in
            guard let self else { return }
            // Count first, always. The rep is the mic's to give.
            DispatchQueue.main.async { self.model?.registerAudioHit() }
            // Then look, off the audio thread, and report what we saw.
            self.videoQueue.async {
                let reading = self.locator.locate(impactTime: impactTime)
                DispatchQueue.main.async {
                    guard let model = self.model else { return }
                    // A weak blob is an honest "couldn't see it", not a guess.
                    guard let reading, reading.confidence >= 0.25 else {
                        model.registerZone(.unknown); return
                    }
                    model.registerZone(model.zone(forNormalizedY: reading.normalizedY))
                }
            }
        }
        impactDetector.start()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        impactDetector.stop()
        videoQueue.async { [weak self] in self?.session.stopRunning() }
    }

    /// Keep a second of downscaled frames so the locator has something to look
    /// back at when the mic fires. Stamped on the same clock the impact uses.
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        locator.store(pixelBuffer, at: ProcessInfo.processInfo.systemUptime)
    }
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

    /// Carries the moment of the impact, on `ProcessInfo.systemUptime`, so the
    /// locator can look at the right frames rather than the newest ones.
    var onImpact: ((TimeInterval) -> Void)?

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
            onImpact?(now)
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
