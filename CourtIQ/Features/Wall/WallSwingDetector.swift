import Foundation
import CoreGraphics
import CoreVideo
import Vision

/// Which stroke a wall rep was, as read from the player's body — not the ball.
enum WallStroke: String {
    case forehand, backhand
    /// The racquet arm was unreadable around the swing. Reported, never guessed.
    case unknown
}

/// Counts wall reps by watching the player's shoulders turn and square up,
/// and tells forehand from backhand by which side the racquet arm is on
/// as the shoulders come square.
///
/// Why shoulders and not the wrist: the first pose detector watched racquet-
/// wrist speed. On real footage (phone behind the player, the setup the app
/// asks for) it counted 2 of 13 swings — the wrist is hidden behind the torso
/// through most of a groundstroke from that angle, and from behind a swing
/// moves mostly *toward* the wall, which is depth the camera can't see.
///
/// What the camera sees perfectly from behind is rotation. Square to the wall
/// the shoulders span ~0.14 of the frame width; at the unit turn they go to
/// profile and past it (the signed width crosses zero); at contact they snap
/// back square. One turned→square transition is one swing. It's a posture
/// signal, not a speed one, so a slow rep counts and a dropped frame doesn't
/// matter.
///
/// Stroke side: at the moment the shoulders come square, the racquet arm is
/// extended on the side it hit from. Elbow first (tracked far more reliably
/// than the wrist), wrist as fallback, measured against the hip midline.
/// Handedness picks which arm is the racquet arm and which side is forehand.
///
/// Validated on a 36s coach session (10 counted / ~13 real, every stroke
/// side right). Backhand side is geometry and not yet seen in the field —
/// `tools/wall-swing-eval.swift` mirrors this file for checking a clip.
final class WallSwingDetector {

    struct Swing {
        let time: TimeInterval
        let stroke: WallStroke
        /// 0–1: how far the racquet arm sat from the hip midline, scaled by
        /// joint trust. Zero when the stroke is `.unknown`.
        let confidence: Float
    }

    /// Set from the player's stored preference. Read every frame by the
    /// controller, so a flip mid-session takes effect at once.
    var handedness: SwingHandedness = .right

    // MARK: Tuning

    /// Shoulder width, as a share of the player's square-on width, below
    /// which the shoulders have turned. Zero is exact profile; a proper unit
    /// turn goes past it into negative.
    private static let turnShare: CGFloat = 0.25
    /// Shoulder width, as a share of square-on width, above which the
    /// shoulders are back square — the swing fires here.
    private static let squareShare: CGFloat = 0.60
    /// A turn shorter than this is a glance, not a backswing.
    private static let minTurn: TimeInterval = 0.15
    /// Two real swings at a wall are never closer than this.
    private static let refractory: TimeInterval = 0.50
    /// How fast the remembered square-on width decays, per frame, so it
    /// follows the player as they move nearer or farther from the phone.
    private static let neutralDecay: CGFloat = 0.995
    /// Racquet-arm offset from the hip midline (frame widths) below which
    /// the side is too ambiguous to call.
    private static let sideMargin: CGFloat = 0.03
    /// After the swing fires, keep looking this long for a readable racquet
    /// arm before giving up on the side.
    private static let sideWindow: TimeInterval = 0.20
    /// Joint confidence floor. Vision reports 0–1 per joint.
    private static let jointFloor: Float = 0.3

    // MARK: State

    private enum Phase { case square, turned(since: TimeInterval) }
    private var phase: Phase = .square
    /// Remembered square-on shoulder width, in frame widths.
    private var neutralWidth: CGFloat = 0
    private var lastSwingAt: TimeInterval = -10
    /// A swing that fired but whose side wasn't readable on that frame.
    private var pending: (firedAt: TimeInterval, deadline: TimeInterval)?

    private let request = VNDetectHumanBodyPoseRequest()

    func reset() {
        phase = .square
        neutralWidth = 0
        lastSwingAt = -10
        pending = nil
    }

    // MARK: Per-frame

    /// Feed every frame. Returns a swing on the frame where one resolves.
    /// Frames are expected upright (the capture connection is rotated).
    func process(_ pixelBuffer: CVPixelBuffer, at t: TimeInterval) -> Swing? {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        try? handler.perform([request])
        let pts = (request.results?.first).flatMap { try? $0.recognizedPoints(.all) }

        // A pending swing resolves as soon as the arm reads, or expires.
        if let p = pending {
            if let pts, let (stroke, conf) = strokeSide(pts) {
                pending = nil
                return Swing(time: p.firedAt, stroke: stroke, confidence: conf)
            }
            if t >= p.deadline {
                pending = nil
                return Swing(time: p.firedAt, stroke: .unknown, confidence: 0)
            }
        }

        guard let pts,
              let ls = pts[.leftShoulder], let rs = pts[.rightShoulder],
              ls.confidence >= Self.jointFloor, rs.confidence >= Self.jointFloor
        else { return nil }   // shoulders unreadable: hold state, don't guess

        // Signed shoulder width. From behind, the player's right is the
        // image's right, so square-on is positive for either handedness.
        let width = rs.location.x - ls.location.x
        neutralWidth = max(neutralWidth * Self.neutralDecay, abs(width))
        guard neutralWidth >= 0.05 else { return nil }   // too small/far to read

        switch phase {
        case .square:
            if width < neutralWidth * Self.turnShare { phase = .turned(since: t) }
            return nil
        case .turned(let since):
            guard width > neutralWidth * Self.squareShare else { return nil }
            phase = .square
            guard t - since >= Self.minTurn, t - lastSwingAt >= Self.refractory else { return nil }
            lastSwingAt = t
            if let (stroke, conf) = strokeSide(pts) {
                return Swing(time: t, stroke: stroke, confidence: conf)
            }
            pending = (firedAt: t, deadline: t + Self.sideWindow)
            return nil
        }
    }

    /// Racquet-arm side against the hip midline. Nil when neither the elbow
    /// nor the wrist reads — not `.unknown`, so the caller can keep looking.
    private func strokeSide(_ pts: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]) -> (WallStroke, Float)? {
        guard let lh = pts[.leftHip], let rh = pts[.rightHip],
              lh.confidence >= Self.jointFloor, rh.confidence >= Self.jointFloor
        else { return nil }
        let hipMid = (lh.location.x + rh.location.x) / 2
        let right = handedness == .right
        let elbow = pts[right ? .rightElbow : .leftElbow]
        let wrist = pts[right ? .rightWrist : .leftWrist]
        guard let arm = [elbow, wrist].compactMap({ $0 }).first(where: { $0.confidence >= Self.jointFloor })
        else { return nil }
        let offset = arm.location.x - hipMid        // + = player's right
        guard abs(offset) >= Self.sideMargin else { return (.unknown, 0) }
        let onForehandSide = right ? offset > 0 : offset < 0
        let conf = min(1, Float(abs(offset) / (Self.sideMargin * 4))) * arm.confidence
        return (onForehandSide ? .forehand : .backhand, conf)
    }
}
