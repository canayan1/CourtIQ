import AVFoundation
import Combine
import CoreMotion
import Foundation

/// Everything a finished session knows.
struct BodySessionResult {
    /// Where the session was written. The Journal attaches it to the match
    /// logged for the same day, and the coach reads it from there.
    var sessionID: String
    var drill: DrillContext
    var startedAt: Date
    var duration: Double
    /// This session against the player's previous ones, computed once here
    /// rather than in the view — the view used to reload every session file
    /// on every re-render.
    var trend: TrendResult

    /// Every contact the microphone heard, with how loud it was.
    var impacts: [(t: Double, strength: Double)]
    /// Split, when the session gave enough to split on.
    var attribution: ImpactAttribution.Split?
    var splitSteps: [SplitStep]
    var readiness: (share: Double, matched: Int, total: Int)?
    /// How the session was struck: rallies, tempo and how steady it was.
    var rhythm: RallyRhythm?
    /// On a wall, the quieter population — the ball coming back off the wall.
    /// Nil when the two never separated, which says where the phone was more
    /// than it says anything about the player.
    var wallRebounds: Int?
    var efforts: Int
    var workShare: Double?
    var longestRest: Double?
    /// The point of the session: what the player owed and did not pay, and
    /// what could not be looked at.
    var findings: SessionFindings
}

/// Runs a session with the phone worn on the body.
///
/// Thin on purpose. Every decision this makes — what counts as a contact, what
/// counts as a split step, whose stroke it was — belongs to a detector that is
/// tested against signals with known answers. What is left here is plumbing:
/// start the sensors, keep the clocks together, hand the detectors their input
/// and publish what comes back.
///
/// The two clocks are the one thing worth watching. CoreMotion timestamps are
/// uptime and audio buffers arrive with their own, so both are converted to
/// seconds since the session began at the point of capture. Everything
/// downstream compares a split-step landing with a ball contact, and a
/// hundred milliseconds of drift between those two clocks would quietly turn a
/// readiness score into noise.
@MainActor
final class BodySessionRecorder: ObservableObject {

    enum State: Equatable { case idle, running, finishing }

    @Published private(set) var state: State = .idle
    @Published private(set) var elapsed: Double = 0
    @Published private(set) var strokes: Int = 0
    @Published private(set) var splitStepCount: Int = 0
    /// Set when the microphone or motion sensors refuse to start, so the UI
    /// can say what is missing rather than showing a session that records
    /// nothing.
    @Published private(set) var failure: String?

    private let engine = AVAudioEngine()
    private let motionManager = CMMotionManager()
    private let envelopeBuffer = LiveEnvelope()
    /// The phone writes the same file a watch would. This is the piece that
    /// makes "the same data without a watch" true end to end: a phone-only
    /// match lands in SensingSessionStore, the Journal finds it by day, and
    /// the coach block is built from it exactly as from a wrist.
    private let store = SensingSessionStore.shared
    private var sessionID = ""
    /// Derived motion is written as it is harvested, so a session that dies
    /// at forty minutes has forty minutes on disk. Contacts are written once
    /// at the end, because whose they were needs the whole session to say.
    private var effortsEmittedUntil: Double = 0
    private var activityEmittedUntil: Double = 0
    private var drill = DrillContext(kind: .freePlay)
    private var converter: AVAudioConverter?
    private var startedAt = Date()
    private var startUptime: TimeInterval = 0

    private var motion: [BodyMotionSample] = []
    private var splitSteps: [SplitStep] = []
    /// Stroke times the live tick has already counted, so a trailing-window
    /// detection never counts the same strike twice.
    private var liveStrokes: [Double] = []
    private var tickTimer: Timer?
    private var clockTimer: Timer?

    // MARK: - Lifecycle

    func start(drill: DrillContext) {
        guard SensingFeature.isEnabled, state == .idle else { return }
        self.drill = drill
        startedAt = Date()
        sessionID = UUID().uuidString
        effortsEmittedUntil = 0; activityEmittedUntil = 0
        startUptime = ProcessInfo.processInfo.systemUptime
        envelopeBuffer.reset(); motion.removeAll(); splitSteps.removeAll(); liveStrokes.removeAll()
        strokes = 0; splitStepCount = 0; elapsed = 0; failure = nil

        do {
            try startAudio()
            try startMotion()
        } catch {
            failure = error.localizedDescription
            stopSensors()
            return
        }
        state = .running
        // Two timers on purpose: the clock ticks every second so the screen is
        // honest, while the detectors run on the slower interval they were
        // designed for.
        clockTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.state == .running else { return }
                self.elapsed = ProcessInfo.processInfo.systemUptime - self.startUptime
            }
        }
        tickTimer = Timer.scheduledTimer(withTimeInterval: WatchSessionTransport.tickInterval,
                                         repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func stop() -> BodySessionResult {
        tickTimer?.invalidate(); tickTimer = nil
        clockTimer?.invalidate(); clockTimer = nil
        state = .finishing
        stopSensors()

        tick()
        harvestSplitSteps(flushAll: true)

        // The drill decides the gap and what the quiet population means —
        // in DrillContext.Kind, once, for this recorder, the live tick and
        // the watch alike.
        let onWall = drill.kind.contactModel == .wallRebound
        let impacts = BallImpactAudio.detectImpactsWithStrength(
            envelope: envelopeBuffer.snapshot(), dt: BallImpactAudio.envelopeWindow,
            minGap: drill.kind.impactMinGap)

        var split: ImpactAttribution.Split? = nil
        var rebounds: Int? = nil
        var strokeTimes = impacts.map(\.t)
        switch drill.kind.contactModel {
        case .wallRebound:
            // The quiet population is the wall, not an opponent. Both sounds
            // are the player's; only the loud one is a stroke.
            if let separated = ImpactAttribution.separateWallBounces(impacts) {
                strokeTimes = separated.strokes
                rebounds = separated.rebounds.count
            }
        case .twoPlayers:
            // With no wrist to claim them, loudness is the only way to tell
            // the player's own strokes from the other end of the court — and
            // it declines when a session has only one player in it.
            split = ImpactAttribution.splitByLoudness(impacts)
            if let own = split?.own { strokeTimes = own }
        case .solo:
            break
        }

        let readiness = onWall ? nil
            : MovementDetector.readiness(splitSteps: splitSteps,
                                         opponentContacts: split?.opponent ?? [])
        let rhythm = RallyRhythmReader.read(strokes: strokeTimes)
        // `motion` is only the tail harvesting has not discarded. Everything
        // below reads the session file instead — the whole session, the same
        // way the coach reads it — so the summary rows and the coach block
        // can no longer disagree about the same session.
        let recorded = store.load(sessionID)?.decodedEvents ?? []
        let efforts = recorded.compactMap { e -> (t: Double, peak: Double)? in
            if case .effort(let t, let p) = e { return (t, p) }; return nil }
        let activity = recorded.compactMap { e -> Double? in
            if case .activity(_, let share) = e { return share }; return nil }
        let effortTimes = efforts.map(\.t).sorted()
        var longestRest = 0.0
        for i in 1..<max(1, effortTimes.count) { longestRest = max(longestRest, effortTimes[i] - effortTimes[i - 1]) }
        let findings = SessionAnalyst.analyse(
            ownContacts: strokeTimes,
            opponentContacts: split?.opponent ?? [],
            splitSteps: splitSteps, motion: [],
            rhythm: rhythm, drill: drill.kind, efforts: efforts)

        // Contacts, with owners, once. On a wall the rebounds are the
        // player's own ball and nobody's contact, so only strokes are written.
        var contacts: [SensorEvent] = []
        let strength: (Double) -> Double = { t in impacts.first { $0.t == t }?.strength ?? 0 }
        for t in strokeTimes { contacts.append(.contact(t: t, strength: strength(t), owner: .player)) }
        for t in split?.opponent ?? [] { contacts.append(.contact(t: t, strength: strength(t), owner: .opponent)) }
        if !onWall, split == nil {
            // Nobody could be told apart, so nothing is claimed for either
            // side — the coach block and the stint builder both treat
            // .unknown as exactly that.
            contacts = impacts.map { .contact(t: $0.t, strength: $0.strength, owner: .unknown) }
        }
        persist(contacts)
        let stored = store.load(sessionID)
        if let stored { WatchLink.shared.showStored(stored) }
        let trend = stored.map {
            SessionTrends.compare(current: $0, history: store.all().filter { $0.id != sessionID })
        } ?? TrendResult(notes: [], baselineCount: 0, notCompared: "the session was not saved.")

        state = .idle
        return BodySessionResult(
            sessionID: sessionID,
            drill: drill, startedAt: startedAt, duration: elapsed, trend: trend,
            impacts: impacts, attribution: split, splitSteps: splitSteps,
            readiness: readiness, rhythm: rhythm, wallRebounds: rebounds,
            efforts: efforts.count,
            workShare: activity.isEmpty ? nil : activity.reduce(0, +) / Double(activity.count),
            longestRest: effortTimes.count >= 2 ? longestRest : nil,
            findings: findings)
    }

    // MARK: - Sensors

    private func startAudio() throws {
        let session = AVAudioSession.sharedInstance()
        // .record rather than .playAndRecord: nothing here plays, and asking
        // for playback would interrupt whatever the player is listening to.
        try session.setCategory(.record, mode: .measurement, options: [])
        try session.setActive(true)

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        // The hardware runs at 44.1 or 48 kHz; the detector was calibrated at
        // 16. Convert first, then fold — otherwise the envelope has a
        // different spectral shape from the one the threshold was tuned on.
        guard let conv = AVAudioConverter(from: format, to: LiveEnvelope.calibratedFormat) else {
            throw NSError(domain: "BodySession", code: 2, userInfo: [NSLocalizedDescriptionKey:
                "The microphone format could not be converted to the detector's rate."])
        }
        converter = conv
        envelopeBuffer.binSize = Int(LiveEnvelope.calibratedSampleRate * BallImpactAudio.envelopeWindow)
        // The tap runs on a real-time audio thread. It must not wait on the
        // main actor and must not outlive the buffer it was handed, so the
        // samples are converted and folded into the envelope right here,
        // synchronously, and the buffer is never referenced again.
        let sink = envelopeBuffer
        input.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
            sink.consume(buffer, converter: conv)
        }
        engine.prepare()
        try engine.start()
    }

    private func startMotion() throws {
        // A session with no motion records no footwork, no split steps and no
        // efforts — which is most of what it exists for. Earlier this only set
        // `failure` and let the session run anyway: the screen showed a
        // stopwatch that never moved and saved a file with nothing in it.
        // Better to refuse.
        guard motionManager.isDeviceMotionAvailable else {
            throw NSError(domain: "BodySession", code: 1, userInfo: [NSLocalizedDescriptionKey:
                "This device has no motion sensors, so a session would record nothing. "
                + "The simulator has none; use a real iPhone."])
        }
        // 100 Hz. Human movement lives below about 5 Hz, so this is not a
        // compromise — nothing about footwork improves above it.
        motionManager.deviceMotionUpdateInterval = 1.0 / 100
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self, let d = data else { return }
            // startDeviceMotionUpdates(to: .main) delivers on the main
            // thread, which is where this object lives.
            MainActor.assumeIsolated {
            let t = d.timestamp - self.startUptime
            self.motion.append(BodyMotionSample(
                t: t,
                accX: d.userAcceleration.x, accY: d.userAcceleration.y, accZ: d.userAcceleration.z,
                gravX: d.gravity.x, gravY: d.gravity.y, gravZ: d.gravity.z))
            }
        }
    }

    // MARK: - Periodic work

    private func tick() {
        guard state != .idle else { return }
        // From the clock, not from the last motion sample: if the sensor
        // stalls the session should show that it is still running rather than
        // freezing at whatever second the samples stopped.
        elapsed = ProcessInfo.processInfo.systemUptime - startUptime
        harvestSplitSteps(flushAll: false)

        // The live count: the same gap and the same meaning of the quiet
        // population the final pass uses, so the number on the screen and
        // the number in the file agree. Detected on a trailing window, not
        // the whole session — the count is cumulative.
        let dt = BallImpactAudio.envelopeWindow
        let (window, first) = envelopeBuffer.snapshot(lastSeconds: WatchSessionTransport.liveAudioWindow,
                                                      binDuration: dt)
        let heard = BallImpactAudio.detectImpactsWithStrength(envelope: window, dt: dt,
                                                              minGap: drill.kind.impactMinGap)
            .map { (t: $0.t + Double(first) * dt, strength: $0.strength) }
        let counted: [Double]
        if drill.kind.contactModel == .wallRebound, let sep = ImpactAttribution.separateWallBounces(heard) {
            counted = sep.strokes
        } else {
            counted = heard.map(\.t)
        }
        for t in counted where t < elapsed - 0.5 && !liveStrokes.contains(where: { abs($0 - t) < 0.2 }) {
            liveStrokes.append(t)
        }
        strokes = liveStrokes.count
    }

    /// Runs split-step detection over the motion collected so far, then throws
    /// away what it has finished with.
    ///
    /// An hour at 100 Hz is 360,000 samples, so the buffer cannot simply grow.
    /// A margin is left at the live end because a hop that is only half
    /// recorded would be found as something else — detection stops half a
    /// second short of now, and that tail is carried into the next pass.
    private func harvestSplitSteps(flushAll: Bool) {
        let margin = flushAll ? 0.0 : 0.5
        guard let last = motion.last else { return }
        let cutoff = last.t - margin
        let ready = motion.filter { $0.t <= cutoff }
        guard ready.count > 40 else { return }

        var fresh: [SensorEvent] = []
        for step in MovementDetector.splitSteps(ready) {
            if let previous = splitSteps.last, step.landing <= previous.landing { continue }
            splitSteps.append(step)
            fresh.append(.splitStep(t: step.landing, landingG: step.landingG))
        }
        splitStepCount = splitSteps.count

        // Efforts and activity, the same way the watch harvests them, so a
        // stint built from this file cannot tell which device wrote it.
        for e in MovementDetector.efforts(ready) where e > effortsEmittedUntil {
            let peak = ready.filter { abs($0.t - e) < 0.25 }.map(\.horizontal).max() ?? 0
            fresh.append(.effort(t: e, peakPush: peak))
        }
        effortsEmittedUntil = cutoff
        let slice = ready.filter { $0.t > activityEmittedUntil }
        if slice.count > 40, let wr = MovementDetector.workRest(slice) {
            fresh.append(.activity(t: cutoff, movingShare: wr.workShare))
            activityEmittedUntil = cutoff
        }
        persist(fresh)

        // Keep a second of overlap so a hop spanning the boundary survives.
        if !flushAll { motion.removeAll { $0.t < cutoff - 1.0 } }
    }

    /// Appends to the session file. The codec refuses raw motion, so nothing
    /// here can ship it by accident; what is written is what was concluded.
    private func persist(_ events: [SensorEvent]) {
        guard !events.isEmpty, !sessionID.isEmpty else { return }
        let dtos = events.compactMap { try? SensorEventCodec.dto($0) }
        store.append(dtos, to: sessionID, startedAt: startedAt,
                     drill: drill.kind.rawValue, highRateMotion: false)
    }

    /// Idempotent, so the failure path and the normal stop can both call it.
    private func stopSensors() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        motionManager.stopDeviceMotionUpdates()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
