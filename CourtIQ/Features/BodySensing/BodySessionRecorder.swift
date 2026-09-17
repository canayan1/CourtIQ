import AVFoundation
import Combine
import CoreMotion
import Foundation

/// Everything a finished session knows.
struct BodySessionResult {
    var drill: DrillContext
    var startedAt: Date
    var duration: Double
    var ticks: [LiveTick]

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
    @Published private(set) var ticks: [LiveTick] = []
    /// Set when the microphone or motion sensors refuse to start, so the UI
    /// can say what is missing rather than showing a session that records
    /// nothing.
    @Published private(set) var failure: String?

    private let engine = AVAudioEngine()
    private let motionManager = CMMotionManager()
    private let envelopeBuffer = LiveEnvelope()
    private var drill = DrillContext(kind: .freePlay, note: nil, plannedMinutes: nil)
    private var startedAt = Date()
    private var startUptime: TimeInterval = 0

    private var motion: [BodyMotionSample] = []
    private var splitSteps: [SplitStep] = []
    private var tickTimer: Timer?
    private var lastTickAt: Double = 0
    private var lastTickStrokes = 0

    // MARK: - Lifecycle

    func start(drill: DrillContext) {
        guard state == .idle else { return }
        self.drill = drill
        startedAt = Date()
        startUptime = ProcessInfo.processInfo.systemUptime
        envelopeBuffer.reset(); motion.removeAll(); splitSteps.removeAll(); ticks.removeAll()
        strokes = 0; splitStepCount = 0; elapsed = 0; failure = nil
        lastTickAt = 0; lastTickStrokes = 0

        do {
            try startAudio()
            startMotion()
        } catch {
            failure = error.localizedDescription
            return
        }
        state = .running
        tickTimer = Timer.scheduledTimer(withTimeInterval: WatchSessionTransport.tickInterval,
                                         repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func stop() -> BodySessionResult {
        tickTimer?.invalidate(); tickTimer = nil
        state = .finishing
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        motionManager.stopDeviceMotionUpdates()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        tick()
        harvestSplitSteps(flushAll: true)
        // NOTE: `motion` holds only the tail that harvesting has not discarded,
        // so the rules below judge the end of the session rather than all of
        // it. Correct for a first pass — every rule here is a rate — but the
        // moment findings are trended across sessions this has to become a
        // running summary rather than a buffer.

        // A wall rally has its own rhythm — one racket sound and one rebound
        // per cycle — so it gets the gap the wall sessions were calibrated
        // with rather than the faster one a rally between two people needs.
        let onWall = drill.kind == .wall
        let impacts = BallImpactAudio.detectImpactsWithStrength(
            envelope: envelopeBuffer.snapshot(), dt: BallImpactAudio.envelopeWindow,
            minGap: onWall ? BallImpactAudio.wallMinGap : BallImpactAudio.rallyMinGap)

        var split: ImpactAttribution.Split? = nil
        var rebounds: Int? = nil
        var strokeTimes = impacts.map(\.t)
        if onWall {
            // The quiet population here is the wall, not an opponent. Both
            // sounds are the player's; only the loud one is a stroke.
            if let separated = ImpactAttribution.separateWallBounces(impacts) {
                strokeTimes = separated.strokes
                rebounds = separated.rebounds.count
            }
        } else {
            // With no wrist to claim them, loudness is the only way to tell
            // the player's own strokes from the other end of the court — and
            // it declines when a session has only one player in it.
            split = ImpactAttribution.splitByLoudness(impacts)
            if let own = split?.own { strokeTimes = own }
        }

        let readiness = onWall ? nil
            : MovementDetector.readiness(splitSteps: splitSteps,
                                         opponentContacts: split?.opponent ?? [])
        let rhythm = RallyRhythmReader.read(strokes: strokeTimes)
        let work = MovementDetector.workRest(motion)
        let findings = SessionAnalyst.analyse(
            ownContacts: strokeTimes,
            opponentContacts: split?.opponent ?? [],
            splitSteps: splitSteps, motion: motion,
            rhythm: rhythm, isWall: onWall)

        state = .idle
        return BodySessionResult(
            drill: drill, startedAt: startedAt, duration: elapsed, ticks: ticks,
            impacts: impacts, attribution: split, splitSteps: splitSteps,
            readiness: readiness, rhythm: rhythm, wallRebounds: rebounds,
            efforts: MovementDetector.efforts(motion).count,
            workShare: work?.workShare, longestRest: work?.longestRest,
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
        envelopeBuffer.binSize = max(1, Int(format.sampleRate * BallImpactAudio.envelopeWindow))
        // The tap runs on a real-time audio thread. It must not wait on the
        // main actor and must not outlive the buffer it was handed, so the
        // samples are folded into the envelope right here, synchronously, and
        // the buffer is never referenced again.
        let sink = envelopeBuffer
        input.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
            guard let channel = buffer.floatChannelData?[0] else { return }
            sink.consume(channel, count: Int(buffer.frameLength))
        }
        engine.prepare()
        try engine.start()
    }

    private func startMotion() {
        guard motionManager.isDeviceMotionAvailable else {
            failure = "This device has no motion sensors."
            return
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
            self.elapsed = t
            }
        }
    }

    // MARK: - Periodic work

    private func tick() {
        guard state != .idle else { return }
        harvestSplitSteps(flushAll: false)

        let impacts = BallImpactAudio.detectImpacts(
            envelope: envelopeBuffer.snapshot(), dt: BallImpactAudio.envelopeWindow,
            minGap: BallImpactAudio.rallyMinGap)
        strokes = impacts.count

        let window = max(0.001, elapsed - lastTickAt)
        let new = max(0, strokes - lastTickStrokes)
        ticks.append(LiveTick(elapsed: elapsed,
                              swings: new,
                              swingsPerMinute: Double(new) / window * 60,
                              medianPeakRotation: 0,   // the wrist's number; nil from the waist
                              heartRate: nil,
                              distanceMetres: nil,
                              latitude: nil, longitude: nil,
                              locationAccuracy: nil, speed: nil))
        lastTickAt = elapsed
        lastTickStrokes = strokes
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

        for step in MovementDetector.splitSteps(ready) {
            if let previous = splitSteps.last, step.landing <= previous.landing { continue }
            splitSteps.append(step)
        }
        splitStepCount = splitSteps.count

        // Keep a second of overlap so a hop spanning the boundary survives.
        if !flushAll { motion.removeAll { $0.t < cutoff - 1.0 } }
    }
}
