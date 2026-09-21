import AVFoundation
import Combine
import CoreMotion
import Foundation
import HealthKit
import WatchConnectivity

/// Runs a session on the wrist and streams what it concludes to the phone.
///
/// UNRUN — see CourtIQWatchApp. What follows is the intended behaviour, with
/// the reasoning that shaped it, so that the first person to run it knows
/// what to expect and what to doubt.
///
/// Thin on purpose, like the phone recorder: every decision — what counts as a
/// contact, whose it was, what a split step is — belongs to a detector that is
/// tested against signals with known answers. What is left here is plumbing:
/// keep the sensors alive through a workout session, keep the clocks together,
/// hand the detectors their input, and send the phone what came back.
///
/// Three clocks meet here. CoreMotion stamps in system uptime, the audio
/// envelope counts ten-millisecond bins from the moment the engine started,
/// and HealthKit hands over heart-rate samples with wall-clock dates. All three
/// are converted to seconds since the session began at the point of capture,
/// because everything downstream compares a wrist strike with a microphone
/// strike with a split-step landing, and a hundred milliseconds of drift
/// between any two of those turns a readiness score into noise.
@MainActor
final class WatchSessionController: NSObject, ObservableObject {

    enum State: Equatable { case idle, running }

    @Published private(set) var state: State = .idle
    @Published private(set) var elapsed: Double = 0
    @Published private(set) var strokes = 0
    @Published private(set) var opponentStrokes = 0
    @Published private(set) var changeovers = 0
    @Published private(set) var heartRate: Double?
    @Published private(set) var highRateMotion = false
    @Published private(set) var failure: String?

    private let healthStore = HKHealthStore()
    private var workout: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    /// watchOS 10, Series 8 and Ultra: 800 Hz accelerometer, 200 Hz motion.
    private var batched: CMBatchedSensorManager?
    /// Everything older: 100 Hz, which still counts strokes but places
    /// contact far less precisely. The summary says which one ran.
    private var fallback: CMMotionManager?

    private let engine = AVAudioEngine()
    private let envelope = LiveEnvelope()

    private var sessionID = UUID().uuidString
    private var drill = DrillContext(kind: .freePlay)
    private var converter: AVAudioConverter?
    private var startUptime: TimeInterval = 0
    private var tickTimer: Timer?

    // Rolling windows. The detectors want a few seconds of context around an
    // event and nothing more, so the buffers are trimmed every tick and never
    // grow with the session.
    private var accel: [AccelSample] = []
    private var motion: [MotionSample] = []
    private var body: [BodyMotionSample] = []
    private var wristImpacts: [Double] = []          // every own contact so far
    /// Opponent contacts already sent, so a trailing-window detection never
    /// sends the same strike twice. This replaces a "processed until" gate,
    /// which lost any impact that only crossed the adaptive threshold after
    /// its tick had passed, and double-sent any that a louder neighbour
    /// later displaced.
    private var opponentSent: [Double] = []
    private var bodyProcessedUntil: Double = 0
    private var lastTickAt: Double = 0

    /// Events concluded since the last transfer.
    private var pending: [SensorEvent] = []

    private var now: Double { ProcessInfo.processInfo.systemUptime - startUptime }

    // MARK: - Lifecycle

    func start(drill: DrillContext) {
        guard SensingFeature.isEnabled, state == .idle else { return }
        self.drill = drill
        sessionID = UUID().uuidString
        startUptime = ProcessInfo.processInfo.systemUptime
        accel.removeAll(); motion.removeAll(); body.removeAll(); pending.removeAll()
        wristImpacts.removeAll(); envelope.reset()
        strokes = 0; opponentStrokes = 0; changeovers = 0; elapsed = 0
        opponentSent.removeAll(); bodyProcessedUntil = 0; lastTickAt = 0
        failure = nil

        activateLink()
        Task {
            do {
                try await startWorkout()
                startMotion()
                try startAudio()
                state = .running
                tickTimer = Timer.scheduledTimer(withTimeInterval: WatchSessionTransport.tickInterval,
                                                 repeats: true) { [weak self] _ in
                    Task { @MainActor in self?.tick() }
                }
            } catch {
                failure = error.localizedDescription
                stopSensors()
            }
        }
    }

    /// One tap at the changeover. Beats any inference from the rest pattern,
    /// and a tap is what players already give a scoring app.
    func markChangeover() {
        guard state == .running else { return }
        changeovers += 1
        pending.append(.changeover(t: now))
        flush(final: false)
    }

    func stop() {
        guard state == .running else { return }
        tickTimer?.invalidate(); tickTimer = nil
        tick()
        stopSensors()
        endWorkout()
        flush(final: true)
        state = .idle
    }

    // MARK: - Sensors

    private func startWorkout() async throws {
        let config = HKWorkoutConfiguration()
        config.activityType = .tennis
        config.locationType = .outdoor
        try await healthStore.requestAuthorization(
            toShare: [HKQuantityType.workoutType()],
            read: [HKQuantityType(.heartRate)])
        let session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
        let builder = session.associatedWorkoutBuilder()
        builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: config)
        builder.delegate = self
        session.delegate = self
        self.workout = session
        self.builder = builder
        session.startActivity(with: Date())
        try await builder.beginCollection(at: Date())
    }

    private func endWorkout() {
        workout?.end()
        let builder = self.builder
        Task {
            _ = try? await builder?.endCollection(at: Date())
            _ = try? await builder?.finishWorkout()
        }
    }

    private func startMotion() {
        if CMBatchedSensorManager.isAccelerometerSupported,
           CMBatchedSensorManager.isDeviceMotionSupported {
            highRateMotion = true
            let manager = CMBatchedSensorManager()
            batched = manager
            manager.startAccelerometerUpdates { [weak self] batch, _ in
                guard let batch else { return }
                let samples = batch.map { d -> (Double, Double, Double, Double) in
                    (d.timestamp, d.acceleration.x, d.acceleration.y, d.acceleration.z)
                }
                Task { @MainActor in self?.ingestAccel(samples) }
            }
            manager.startDeviceMotionUpdates { [weak self] batch, _ in
                guard let batch else { return }
                let samples = batch.map { d in
                    (d.timestamp, d.rotationRate.x, d.rotationRate.y, d.rotationRate.z,
                     d.gravity.x, d.gravity.y, d.gravity.z,
                     d.userAcceleration.x, d.userAcceleration.y, d.userAcceleration.z)
                }
                Task { @MainActor in self?.ingestMotion(samples) }
            }
        } else {
            highRateMotion = false
            let manager = CMMotionManager()
            fallback = manager
            manager.accelerometerUpdateInterval = 1.0 / 100
            manager.deviceMotionUpdateInterval = 1.0 / 100
            manager.startAccelerometerUpdates(to: .main) { [weak self] d, _ in
                guard let d else { return }
                self?.ingestAccel([(d.timestamp, d.acceleration.x, d.acceleration.y, d.acceleration.z)])
            }
            manager.startDeviceMotionUpdates(to: .main) { [weak self] d, _ in
                guard let d else { return }
                self?.ingestMotion([(d.timestamp, d.rotationRate.x, d.rotationRate.y, d.rotationRate.z,
                                     d.gravity.x, d.gravity.y, d.gravity.z,
                                     d.userAcceleration.x, d.userAcceleration.y, d.userAcceleration.z)])
            }
        }
    }

    private func ingestAccel(_ samples: [(Double, Double, Double, Double)]) {
        for (ts, x, y, z) in samples {
            accel.append(AccelSample(t: ts - startUptime, x: x, y: y, z: z))
        }
        if let last = accel.last { elapsed = last.t }
    }

    private func ingestMotion(_ samples: [(Double, Double, Double, Double, Double, Double, Double,
                                          Double, Double, Double)]) {
        for s in samples {
            let t = s.0 - startUptime
            motion.append(MotionSample(t: t, rotX: s.1, rotY: s.2, rotZ: s.3,
                                       gravX: s.4, gravY: s.5, gravZ: s.6))
            body.append(BodyMotionSample(t: t, accX: s.7, accY: s.8, accZ: s.9,
                                         gravX: s.4, gravY: s.5, gravZ: s.6))
        }
    }

    private func startAudio() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [])
        try session.setActive(true)
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        // Converted to the detector's 16 kHz first, then folded into the
        // envelope on the audio thread and never kept — the same class, the
        // same rate and the same promise as the phone.
        guard let conv = AVAudioConverter(from: format, to: LiveEnvelope.calibratedFormat) else {
            throw NSError(domain: "WatchSession", code: 2, userInfo: [NSLocalizedDescriptionKey:
                "The microphone format could not be converted to the detector's rate."])
        }
        converter = conv
        envelope.binSize = Int(LiveEnvelope.calibratedSampleRate * BallImpactAudio.envelopeWindow)
        let sink = envelope
        input.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
            sink.consume(buffer, converter: conv)
        }
        engine.prepare()
        try engine.start()
    }

    private func stopSensors() {
        batched?.stopAccelerometerUpdates(); batched?.stopDeviceMotionUpdates(); batched = nil
        fallback?.stopAccelerometerUpdates(); fallback?.stopDeviceMotionUpdates(); fallback = nil
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Periodic work

    private func tick() {
        guard state == .running else { return }
        let t = now
        let margin = 0.5   // a stroke that is still ringing is not finished

        // 1. Own strokes, from the wrist. This is a fact, not an inference:
        //    the wrist felt them.
        let swings = WristSwingDetector.swings(accel: accel, motion: motion)
        for s in swings where s.impact < t - margin
            && !wristImpacts.contains(where: { abs($0 - s.impact) < 0.2 }) {
            wristImpacts.append(s.impact)
            pending.append(.contact(t: s.impact, strength: s.impactG, owner: .player))
        }
        strokes = wristImpacts.count

        // 2. The opponent's strokes, from the microphone: every impact it
        //    heard that the wrist did not claim. This is the piece the
        //    accelerometer can never supply on its own and the readiness
        //    metric cannot exist without. The drill decides whether there
        //    IS an opponent: on a wall the unclaimed sounds are the
        //    player's own ball coming back, and a serving session has no
        //    reply at all — the first version reported a wall's rebounds
        //    as thirty opponent strokes.
        if drill.kind.contactModel == .twoPlayers {
            let dt = BallImpactAudio.envelopeWindow
            let (window, first) = envelope.snapshot(lastSeconds: WatchSessionTransport.liveAudioWindow,
                                                    binDuration: dt)
            let heard = BallImpactAudio.detectImpactsWithStrength(envelope: window, dt: dt,
                                                                  minGap: drill.kind.impactMinGap)
                .map { (t: $0.t + Double(first) * dt, strength: $0.strength) }
                .filter { $0.t < t - margin }
            let split = ImpactAttribution.split(audioImpacts: heard.map(\.t), ownSwings: wristImpacts)
            for ot in split.opponent where !opponentSent.contains(where: { abs($0 - ot) < 0.2 }) {
                opponentSent.append(ot)
                let strength = heard.first { $0.t == ot }?.strength ?? 0
                pending.append(.contact(t: ot, strength: strength, owner: .opponent))
            }
            opponentStrokes = opponentSent.count
        }

        // 3. Feet, from device motion — the same detector the phone runs on
        //    its own body samples, so a watch stint and a belt stint agree
        //    about what a hop is.
        let ready = body.filter { $0.t > bodyProcessedUntil - 1.0 && $0.t < t - margin }
        if ready.count > 40 {
            for hop in MovementDetector.splitSteps(ready) where hop.landing > bodyProcessedUntil {
                pending.append(.splitStep(t: hop.landing, landingG: hop.landingG))
            }
            for e in MovementDetector.efforts(ready) where e > bodyProcessedUntil {
                let peak = ready.filter { abs($0.t - e) < 0.25 }.map(\.horizontal).max() ?? 0
                pending.append(.effort(t: e, peakPush: peak))
            }
            let slice = ready.filter { $0.t > lastTickAt }
            if let wr = MovementDetector.workRest(slice) {
                pending.append(.activity(t: t, movingShare: wr.workShare))
            }
            bodyProcessedUntil = t - margin
        }
        lastTickAt = t

        // 4. Trim. Six seconds is longer than any swing look-back; twenty-five
        //    covers a tick plus the overlap the hop detector wants.
        accel.removeAll { $0.t < t - 6 }
        motion.removeAll { $0.t < t - 6 }
        body.removeAll { $0.t < t - 25 }

        flush(final: false)
    }

    // MARK: - Link to the phone

    private func activateLink() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        if session.activationState != .activated { session.activate() }
    }

    /// Queued, not live, so a phone in a bag at the back of the court loses
    /// nothing — every batch arrives when it comes back in range. When the
    /// phone happens to be reachable it is also nudged directly, which is
    /// what makes the bench card current the moment it is opened.
    private func flush(final: Bool) {
        guard !pending.isEmpty || final else { return }
        let batch = SessionBatch(id: sessionID, drill: drill.kind.rawValue,
                                 startedAt: Date(timeIntervalSinceNow: -now),
                                 highRateMotion: highRateMotion,
                                 events: pending.compactMap { try? SensorEventCodec.dto($0) },
                                 final: final)
        guard let data = try? SensorEventCodec.encode(batch) else { return }
        pending.removeAll()
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        let payload: [String: Any] = ["batch": data]
        // Sent once. Live when the phone is reachable, with the queue as the
        // fallback if that fails; queued otherwise. The first version sent
        // every batch both ways whenever the phone was reachable, and the
        // append-only store kept both copies.
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { _ in session.transferUserInfo(payload) }
        } else {
            session.transferUserInfo(payload)
        }
    }
}

// MARK: - HealthKit

extension WatchSessionController: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilder(_ builder: HKLiveWorkoutBuilder,
                                    didCollectDataOf types: Set<HKSampleType>) {
        guard types.contains(HKQuantityType(.heartRate)),
              let stats = builder.statistics(for: HKQuantityType(.heartRate)),
              let bpm = stats.mostRecentQuantity()?
                  .doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        else { return }
        Task { @MainActor in
            self.heartRate = bpm
            self.pending.append(.heartRate(t: self.now, bpm: bpm))
        }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ builder: HKLiveWorkoutBuilder) {}
}

extension WatchSessionController: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ session: HKWorkoutSession,
                                    didChangeTo toState: HKWorkoutSessionState,
                                    from fromState: HKWorkoutSessionState, date: Date) {}
    nonisolated func workoutSession(_ session: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor in self.failure = error.localizedDescription }
    }
}

// MARK: - WatchConnectivity

extension WatchSessionController: WCSessionDelegate {
    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {}
}
