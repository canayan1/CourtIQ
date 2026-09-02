import Foundation
import CoreGraphics
import CoreVideo
import Vision

/// Which stroke a wall rep was, as read from the player's body — not the ball.
enum WallStroke: String {
    case forehand, backhand
    /// The wrist was too close to the body's midline to call, or the pose
    /// was too weak to trust. Reported, never guessed.
    case unknown
}

/// Counts wall reps by watching the player swing, and tells forehand from
/// backhand by which side of the body the racquet hand is on at the swing.
///
/// This replaced counting by microphone. The field test settled that: a rep
/// makes three impulsive sounds — racquet, wall, floor — and no threshold
/// tells them apart, so every goal came out inflated. A swing is a different
/// kind of signal: one large, fast arc of the racquet wrist that nothing else
/// in a wall session resembles. The player is also the largest thing in the
/// frame, which is the easy case for on-device pose.
///
/// Stroke side is geometry, not judgement. Vision labels joints by the
/// player's own left/right, so with the phone behind the player (the setup
/// the app asks for) a right-hander's wrist to the right of the shoulder
/// midline at the swing is a forehand; across it is a backhand. Anything
/// near the midline is `unknown`.
///
/// ⚠️ Thresholds are first-pass values. They want tuning against a real
/// session — see the offline harness in docs/WALL-PRACTICE-PLAN.md.
final class WallSwingDetector {

    struct Swing {
        let time: TimeInterval
        let stroke: WallStroke
        /// 0–1: how far the wrist sat from the midline, scaled by pose trust.
        let confidence: Float
    }

    /// Set from the player's stored preference. Flipping it flips which side
    /// of the midline reads as forehand.
    var handedness: SwingHandedness = .right

    // MARK: Tuning

    /// Wrist speed, in frame-widths per second, that reads as a swing. A
    /// groundstroke crosses ~half the frame in ~0.2s (≈2.5 w/s); walking or
    /// a shuffle step stays under ~1 w/s.
    private static let swingSpeed: CGFloat = 2.2
    /// Speed must fall back under this share of `swingSpeed` before the next
    /// swing can fire — one arc, one rep, even if the peak is bumpy.
    private static let rearmShare: CGFloat = 0.40
    /// Two real swings at a wall are never closer than this.
    private static let refractory: TimeInterval = 0.55
    /// Wrist offset from the midline (frame widths) below which the side is
    /// too ambiguous to call.
    private static let sideMargin: CGFloat = 0.035
    /// Joint confidence floor. Vision reports 0–1 per joint.
    private static let jointFloor: Float = 0.3

    // MARK: State

    private struct Sample {
        let t: TimeInterval
        /// Racquet-hand wrist, normalized, top-left origin.
        let wrist: CGPoint
        /// Shoulder (or hip) midline x, normalized.
        let midX: CGFloat
        let trust: Float
    }

    private var last: Sample?
    private var speedSmoothed: CGFloat = 0
    private var armed = true
    private var lastSwingAt: TimeInterval = -10

    private let request: VNDetectHumanBodyPoseRequest = {
        let r = VNDetectHumanBodyPoseRequest()
        return r
    }()

    func reset() {
        last = nil
        speedSmoothed = 0
        armed = true
        lastSwingAt = -10
    }

    // MARK: Per-frame

    /// Feed every frame. Returns a swing on the frame where one fires.
    /// Frames are expected upright (the capture connection is rotated), so no
    /// orientation fixup here.
    func process(_ pixelBuffer: CVPixelBuffer, at t: TimeInterval) -> Swing? {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        try? handler.perform([request])
        guard let obs = request.results?.first,
              let pts = try? obs.recognizedPoints(.all) else {
            // Lost the player: forget the last sample so a re-acquired pose
            // doesn't produce a phantom "jump" velocity.
            last = nil
            return nil
        }

        let wristName: VNHumanBodyPoseObservation.JointName =
            handedness == .right ? .rightWrist : .leftWrist
        guard let w = pts[wristName], w.confidence >= Self.jointFloor else {
            last = nil
            return nil
        }

        // Midline from the shoulders; hips as a fallback; neck alone if it
        // comes to that. Without any of them the stroke side is unreadable,
        // but the swing itself can still count.
        let midX: CGFloat? = {
            if let l = pts[.leftShoulder], let r = pts[.rightShoulder],
               l.confidence >= Self.jointFloor, r.confidence >= Self.jointFloor {
                return (l.location.x + r.location.x) / 2
            }
            if let l = pts[.leftHip], let r = pts[.rightHip],
               l.confidence >= Self.jointFloor, r.confidence >= Self.jointFloor {
                return (l.location.x + r.location.x) / 2
            }
            if let n = pts[.neck], n.confidence >= Self.jointFloor { return n.location.x }
            return nil
        }()

        // Vision: origin bottom-left, y up. Band space: origin top-left, y down.
        let wrist = CGPoint(x: w.location.x, y: 1 - w.location.y)
        let sample = Sample(t: t, wrist: wrist, midX: midX ?? -1, trust: w.confidence)
        defer { last = sample }

        guard let prev = last else { return nil }
        let dt = t - prev.t
        guard dt > 0.005, dt < 0.25 else { return nil }   // a dropped stretch, not motion

        let dx = wrist.x - prev.wrist.x
        let dy = wrist.y - prev.wrist.y
        let speed = (dx * dx + dy * dy).squareRoot() / CGFloat(dt)
        // Light smoothing: one noisy frame shouldn't fire a rep.
        speedSmoothed = speedSmoothed * 0.45 + speed * 0.55

        if !armed {
            if speedSmoothed < Self.swingSpeed * Self.rearmShare { armed = true }
            return nil
        }
        guard speedSmoothed >= Self.swingSpeed,
              t - lastSwingAt >= Self.refractory else { return nil }

        armed = false
        lastSwingAt = t

        // Stroke side at the swing. With the phone behind the player, the
        // player's right is the image's right: no mirroring.
        var stroke: WallStroke = .unknown
        var conf: Float = 0
        if let mid = midX {
            let offset = wrist.x - mid            // + = player's right side
            let onForehandSide = handedness == .right ? offset > 0 : offset < 0
            if abs(offset) >= Self.sideMargin {
                stroke = onForehandSide ? .forehand : .backhand
                conf = min(1, Float(abs(offset) / (Self.sideMargin * 3))) * w.confidence
            }
        }
        return Swing(time: t, stroke: stroke, confidence: conf)
    }
}
