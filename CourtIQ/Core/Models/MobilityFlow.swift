import Foundation

enum MobilityFlowType: String, CaseIterable, Codable, Identifiable {
    case quickReset
    case dailyMobility
    case recovery

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quickReset: return "Quick Reset"
        case .dailyMobility: return "Daily Mobility"
        case .recovery: return "Recovery"
        }
    }
}

enum MobilityFocusArea: String, CaseIterable, Codable, Identifiable {
    case hips
    case hamstrings
    case thoracicRotation
    case shoulders
    case ankles

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hips: return "Hips"
        case .hamstrings: return "Hamstrings"
        case .thoracicRotation: return "Thoracic Rotation"
        case .shoulders: return "Shoulders"
        case .ankles: return "Ankles"
        }
    }
}

struct MobilityMovement: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let duration: String
    let notes: String?
}

struct MobilityFlow: Identifiable, Codable {
    let id: String
    let title: String
    let duration: String
    let type: MobilityFlowType
    let goal: String
    let focusAreas: [MobilityFocusArea]
    let movements: [MobilityMovement]
    let instructions: String
    let coachingCues: String
    let whyItMatters: String

    var focusLabel: String {
        focusAreas.map { $0.title }.joined(separator: ", ")
    }
}

extension MobilityFlow {
    static let sampleFlows: [MobilityFlow] = [
        MobilityFlow(
            id: "quick-reset-001",
            title: "Serve Shoulder Reset",
            duration: "6 min",
            type: .quickReset,
            goal: "Refresh shoulder and upper-back motion before serving.",
            focusAreas: [.shoulders, .thoracicRotation],
            movements: [
                MobilityMovement(id: "quick-reset-001-1", title: "Arm circles with thoracic rotation", duration: "1 min", notes: "Keep the chest lifted.") ,
                MobilityMovement(id: "quick-reset-001-2", title: "Wall shoulder slides", duration: "90 sec", notes: "Keep elbows soft and scapula engaged."),
                MobilityMovement(id: "quick-reset-001-3", title: "Standing open-book reps", duration: "1 min", notes: "Move from the mid-back, not the lower back."),
                MobilityMovement(id: "quick-reset-001-4", title: "Gentle band pull-aparts", duration: "1 min", notes: "Use slow control to feel the back of the shoulder."),
                MobilityMovement(id: "quick-reset-001-5", title: "Controlled shoulder rolls", duration: "1 min", notes: "Breathe as you move.")
            ],
            instructions: "Work through the upper-body sequence with controlled tempo so your serve shoulder feels ready without tension.",
            coachingCues: "Keep the shoulder blade active, rotate through the mid-back, and avoid shrugging.",
            whyItMatters: "Better shoulder freedom and thoracic rotation support a smoother serve toss, cleaner swing path, and less late-arm tension."
        ),
        MobilityFlow(
            id: "quick-reset-002",
            title: "Hips & Ankle Warm-Up",
            duration: "7 min",
            type: .quickReset,
            goal: "Prime the lower body for split-step speed and court coverage.",
            focusAreas: [.hips, .ankles],
            movements: [
                MobilityMovement(id: "quick-reset-002-1", title: "Lateral ankle rocks", duration: "1 min", notes: "Keep the foot close to the ground."),
                MobilityMovement(id: "quick-reset-002-2", title: "90/90 hip switches", duration: "1 min", notes: "Turn through the hips, not the lower spine."),
                MobilityMovement(id: "quick-reset-002-3", title: "Standing hip circles", duration: "1 min", notes: "Move slowly to feel each direction."),
                MobilityMovement(id: "quick-reset-002-4", title: "Heel-toe calf lifts", duration: "1 min", notes: "Control the motion on both sides."),
                MobilityMovement(id: "quick-reset-002-5", title: "Mini squat holds with ankle drive", duration: "1 min", notes: "Sink only as low as you can keep your weight balanced.")
            ],
            instructions: "Move deliberately through each lower-body reset drill before stepping onto court or starting a practice block.",
            coachingCues: "Feel the range in your hips and ankles before you accept the first ball.",
            whyItMatters: "Stable hips and mobile ankles reduce early match stiffness, making it easier to react and recover on the first step."
        ),
        MobilityFlow(
            id: "quick-reset-003",
            title: "Hamstring Release Flow",
            duration: "5 min",
            type: .quickReset,
            goal: "Loosen the hamstrings after long rallies or between sets.",
            focusAreas: [.hamstrings, .hips],
            movements: [
                MobilityMovement(id: "quick-reset-003-1", title: "Standing hamstring swings", duration: "1 min", notes: "Keep a soft knee."),
                MobilityMovement(id: "quick-reset-003-2", title: "Seated single-leg reach", duration: "1 min", notes: "Use the opposite hip to level the pelvis."),
                MobilityMovement(id: "quick-reset-003-3", title: "Kneeling half-splits", duration: "1 min", notes: "Shift weight forward gently."),
                MobilityMovement(id: "quick-reset-003-4", title: "Dynamic toe taps", duration: "1 min", notes: "Keep the spine long."),
                MobilityMovement(id: "quick-reset-003-5", title: "Standing hip hinge pulses", duration: "1 min", notes: "Move with control.")
            ],
            instructions: "Use this quick flow to ease hamstring tension while maintaining movement quality.",
            coachingCues: "Stay tall through your torso and let the legs lengthen without forcing.",
            whyItMatters: "Smoothed hamstrings help you recover faster after long rallies and move more dynamically on the next point."
        ),
        MobilityFlow(
            id: "quick-reset-004",
            title: "Thoracic Rotation Reset",
            duration: "6 min",
            type: .quickReset,
            goal: "Restore mid-back twist and prepare for groundstroke rotation.",
            focusAreas: [.thoracicRotation, .shoulders],
            movements: [
                MobilityMovement(id: "quick-reset-004-1", title: "Open-book sequence", duration: "1 min", notes: "Keep both hips grounded."),
                MobilityMovement(id: "quick-reset-004-2", title: "Kneeling thoracic reach", duration: "1 min", notes: "Reach through the chest."),
                MobilityMovement(id: "quick-reset-004-3", title: "Seated twist with arm extension", duration: "1 min", notes: "Breathe into each turn."),
                MobilityMovement(id: "quick-reset-004-4", title: "Standing band rotation", duration: "1 min", notes: "Keep the pelvis stable."),
                MobilityMovement(id: "quick-reset-004-5", title: "Reverse shoulder circles", duration: "1 min", notes: "Maintain a neutral neck.")
            ],
            instructions: "Flow through these rotation drills to restore clean torso movement without aggressive stretching.",
            coachingCues: "Rotate from the mid-back, not from the low back.",
            whyItMatters: "A mobile thoracic spine supports better racket head speed, recovery between strokes, and a safer serve turn."
        ),
        MobilityFlow(
            id: "quick-reset-005",
            title: "Match Day Energy Reset",
            duration: "8 min",
            type: .quickReset,
            goal: "Reduce stiffness and reset range of motion between sets.",
            focusAreas: [.hips, .shoulders, .ankles],
            movements: [
                MobilityMovement(id: "quick-reset-005-1", title: "Standing hip swings", duration: "1 min", notes: "Keep the opposite hand on a support if needed."),
                MobilityMovement(id: "quick-reset-005-2", title: "Shoulder band draws", duration: "1 min", notes: "Keep the shoulder blades low."),
                MobilityMovement(id: "quick-reset-005-3", title: "Ankle circles and dorsiflexion prep", duration: "1 min", notes: "Move both directions."),
                MobilityMovement(id: "quick-reset-005-4", title: "Half-kneeling hip flexor access", duration: "2 min", notes: "Sink gently into the front hip."),
                MobilityMovement(id: "quick-reset-005-5", title: "Controlled walking lunges", duration: "2 min", notes: "Maintain a tall chest.")
            ],
            instructions: "Use this match-day reset when you want a short, complete movement refresh.",
            coachingCues: "Stay steady through your breath and keep each joint moving in the direction you want to feel on court.",
            whyItMatters: "A quick mobility reset supports faster recovery, better lateral mobility, and clear movement before the next game."
        ),
        MobilityFlow(
            id: "daily-mobility-001",
            title: "Court-Ready Rotation Sequence",
            duration: "12 min",
            type: .dailyMobility,
            goal: "Build consistent thoracic and shoulder mobility for groundstroke rotation.",
            focusAreas: [.thoracicRotation, .shoulders],
            movements: [
                MobilityMovement(id: "daily-mobility-001-1", title: "Seated spinal twists", duration: "2 min", notes: "Lengthen through the spine."),
                MobilityMovement(id: "daily-mobility-001-2", title: "World’s greatest stretch", duration: "2 min", notes: "Focus on the upper back."),
                MobilityMovement(id: "daily-mobility-001-3", title: "Standing reach and rotate", duration: "2 min", notes: "Keep the hips square."),
                MobilityMovement(id: "daily-mobility-001-4", title: "Thread-the-needle press", duration: "2 min", notes: "Move slowly through each side."),
                MobilityMovement(id: "daily-mobility-001-5", title: "Overhead band rotations", duration: "2 min", notes: "Keep the core engaged.")
            ],
            instructions: "Complete this daily rotation flow to support cleaner torso turns in rallies and serve preparation.",
            coachingCues: "Avoid rushing and feel the rotation through the spine, not just the arms.",
            whyItMatters: "Better rotation helps you generate power with less stress and recover faster between shots."
        ),
        MobilityFlow(
            id: "daily-mobility-002",
            title: "Lower-Body Movement Circuit",
            duration: "15 min",
            type: .dailyMobility,
            goal: "Improve hip and hamstring range for faster change of direction.",
            focusAreas: [.hips, .hamstrings],
            movements: [
                MobilityMovement(id: "daily-mobility-002-1", title: "Walking hip openers", duration: "3 min", notes: "Step with intent."),
                MobilityMovement(id: "daily-mobility-002-2", title: "Alternating kneeling lunge reaches", duration: "3 min", notes: "Keep the pelvis level."),
                MobilityMovement(id: "daily-mobility-002-3", title: "Single-leg Romanian deadlift reach", duration: "3 min", notes: "Use a slow, controlled hinge."),
                MobilityMovement(id: "daily-mobility-002-4", title: "Seated hamstring band stretch", duration: "3 min", notes: "Keep the chest up."),
                MobilityMovement(id: "daily-mobility-002-5", title: "Side shuffle hip access", duration: "3 min", notes: "Keep a soft bend in the knees.")
            ],
            instructions: "Use this daily sequence to keep your legs responsive and ready for quick court movement.",
            coachingCues: "Feel the stretch without forcing, and maintain stability through the core.",
            whyItMatters: "More mobile hips and hamstrings improve your ability to cover the court and recover after wide shots."
        ),
        MobilityFlow(
            id: "daily-mobility-003",
            title: "Shoulder Freedom Routine",
            duration: "10 min",
            type: .dailyMobility,
            goal: "Maintain shoulder mobility for serving and overhead control.",
            focusAreas: [.shoulders, .thoracicRotation],
            movements: [
                MobilityMovement(id: "daily-mobility-003-1", title: "Band shoulder draws", duration: "2 min", notes: "Keep the ribs packed."),
                MobilityMovement(id: "daily-mobility-003-2", title: "Cross-body shoulder swings", duration: "2 min", notes: "Move with rhythm."),
                MobilityMovement(id: "daily-mobility-003-3", title: "Wall angel slides", duration: "2 min", notes: "Keep contact through the spine."),
                MobilityMovement(id: "daily-mobility-003-4", title: "Doorway chest opener", duration: "2 min", notes: "Avoid arching the lower back."),
                MobilityMovement(id: "daily-mobility-003-5", title: "Overhead reach and rotate", duration: "2 min", notes: "Link the shoulder and thoracic spine.")
            ],
            instructions: "Flow calmly through the shoulder drills to maintain range without fatigue.",
            coachingCues: "Breathe deeply and move with control through each position.",
            whyItMatters: "A free shoulder and upper-back chain supports serve speed, overhead placement, and consistent follow-through."
        ),
        MobilityFlow(
            id: "daily-mobility-004",
            title: "Ankle & Lower Leg Support",
            duration: "11 min",
            type: .dailyMobility,
            goal: "Build ankle resilience for quick directional changes.",
            focusAreas: [.ankles, .hips],
            movements: [
                MobilityMovement(id: "daily-mobility-004-1", title: "Toe-calf lifts with pulse", duration: "2 min", notes: "Stay balanced."),
                MobilityMovement(id: "daily-mobility-004-2", title: "Ankle circles and dorsiflexion", duration: "2 min", notes: "Move both directions."),
                MobilityMovement(id: "daily-mobility-004-3", title: "Cossack squat reach", duration: "2 min", notes: "Keep the weight centered."),
                MobilityMovement(id: "daily-mobility-004-4", title: "Single-leg balance reach", duration: "2 min", notes: "Control the knee tracking."),
                MobilityMovement(id: "daily-mobility-004-5", title: "Standing hip hinge pulses", duration: "3 min", notes: "Keep the spine long.")
            ],
            instructions: "Use this mobility routine to keep your lower legs stable through quick stops and starts.",
            coachingCues: "Move with control and avoid locking the joints.",
            whyItMatters: "Stronger ankle mobility helps you push off more efficiently and reduces the risk of late-match fatigue."
        ),
        MobilityFlow(
            id: "daily-mobility-005",
            title: "Full-Body Tennis Flow",
            duration: "18 min",
            type: .dailyMobility,
            goal: "Connect the hips, shoulders, and spine for smoother court movement.",
            focusAreas: [.hips, .thoracicRotation, .shoulders],
            movements: [
                MobilityMovement(id: "daily-mobility-005-1", title: "Walking knee hugs with rotation", duration: "3 min", notes: "Keep the chest open."),
                MobilityMovement(id: "daily-mobility-005-2", title: "Lateral leg swings", duration: "3 min", notes: "Move with control."),
                MobilityMovement(id: "daily-mobility-005-3", title: "Half-kneeling thoracic reaches", duration: "3 min", notes: "Breathe into each side."),
                MobilityMovement(id: "daily-mobility-005-4", title: "Standing shoulder plates", duration: "3 min", notes: "Use small repetitions."),
                MobilityMovement(id: "daily-mobility-005-5", title: "Dynamic hip openers", duration: "3 min", notes: "Keep the movement smooth.")
            ],
            instructions: "Complete this full-body flow to keep your tennis movement chain balanced and ready.",
            coachingCues: "Link each segment slowly and maintain awareness of the range you feel.",
            whyItMatters: "A coordinated mobility routine lowers stiffness and improves the quality of your movement on the court."
        ),
        MobilityFlow(
            id: "recovery-001",
            title: "Post-Match Hip & Hamstring Recovery",
            duration: "22 min",
            type: .recovery,
            goal: "Release the lower body after a long match.",
            focusAreas: [.hips, .hamstrings],
            movements: [
                MobilityMovement(id: "recovery-001-1", title: "Foam roll hamstrings", duration: "4 min", notes: "Move slowly over tight spots."),
                MobilityMovement(id: "recovery-001-2", title: "Supine hip bridges", duration: "4 min", notes: "Drive through the heels."),
                MobilityMovement(id: "recovery-001-3", title: "Pigeon pose hold", duration: "4 min", notes: "Breathe into the front hip."),
                MobilityMovement(id: "recovery-001-4", title: "Seated forward fold", duration: "4 min", notes: "Soften the spine."),
                MobilityMovement(id: "recovery-001-5", title: "Supported figure-four release", duration: "4 min", notes: "Keep the pelvis squared.")
            ],
            instructions: "Use this recovery flow after play to remove stiffness and support tomorrow’s movement.",
            coachingCues: "Stay relaxed and let the muscles lengthen without force.",
            whyItMatters: "Recovering the hips and hamstrings helps you move more freely and lowers injury risk after long days on court."
        ),
        MobilityFlow(
            id: "recovery-002",
            title: "Shoulder & Spine Recovery",
            duration: "24 min",
            type: .recovery,
            goal: "Ease upper-body tension after a hard hitting session.",
            focusAreas: [.shoulders, .thoracicRotation],
            movements: [
                MobilityMovement(id: "recovery-002-1", title: "Foam roll upper back", duration: "4 min", notes: "Stay gentle."),
                MobilityMovement(id: "recovery-002-2", title: "Child’s pose with reach", duration: "4 min", notes: "Breathe long."),
                MobilityMovement(id: "recovery-002-3", title: "Sleeper stretch hold", duration: "4 min", notes: "Keep the shoulder blade down."),
                MobilityMovement(id: "recovery-002-4", title: "Lying thoracic twists", duration: "4 min", notes: "Move slowly."),
                MobilityMovement(id: "recovery-002-5", title: "Doorway shoulder opener", duration: "4 min", notes: "Avoid arching the lower back.")
            ],
            instructions: "Finish play with this upper-body recovery routine to reduce tightness and restore rotation.",
            coachingCues: "Let each position settle before you move on.",
            whyItMatters: "Shoulder and spine recovery preserves serve quality and reduces the feel of fatigue in the upper body."
        ),
        MobilityFlow(
            id: "recovery-003",
            title: "Match-Day Lower-Body Reset",
            duration: "20 min",
            type: .recovery,
            goal: "Reset legs and ankles after a long practice or match.",
            focusAreas: [.ankles, .hips, .hamstrings],
            movements: [
                MobilityMovement(id: "recovery-003-1", title: "Seated calf release", duration: "4 min", notes: "Use a massage ball if available."),
                MobilityMovement(id: "recovery-003-2", title: "Passive hamstring stretch", duration: "4 min", notes: "Keep the breath steady."),
                MobilityMovement(id: "recovery-003-3", title: "Supine twists with bent knees", duration: "4 min", notes: "Relax the lower back."),
                MobilityMovement(id: "recovery-003-4", title: "Glute bridges with hold", duration: "4 min", notes: "Focus on the contraction."),
                MobilityMovement(id: "recovery-003-5", title: "Ankle mobility floor drills", duration: "4 min", notes: "Control each direction." )
            ],
            instructions: "Use this recovery routine to settle the lower body and keep your legs ready for the next practice.",
            coachingCues: "Move with purpose and use the rest positions to unload the joints.",
            whyItMatters: "Well-managed lower-body recovery improves your ability to return fresh the next day and reduces ankle and calf fatigue."
        ),
        MobilityFlow(
            id: "recovery-004",
            title: "Court-to-Couch Recovery",
            duration: "25 min",
            type: .recovery,
            goal: "Recover after a long tennis day with a full-body release.",
            focusAreas: [.shoulders, .hips, .ankles],
            movements: [
                MobilityMovement(id: "recovery-004-1", title: "Gentle spine roll-downs", duration: "4 min", notes: "Keep the knees soft."),
                MobilityMovement(id: "recovery-004-2", title: "Supported shoulder opener", duration: "4 min", notes: "Use a cushion if needed."),
                MobilityMovement(id: "recovery-004-3", title: "Standing hip flexor release", duration: "4 min", notes: "Breathe into the front side."),
                MobilityMovement(id: "recovery-004-4", title: "Seated ankle mobilizations", duration: "4 min", notes: "Move through each plane."),
                MobilityMovement(id: "recovery-004-5", title: "Relaxed hamstring stretch", duration: "4 min", notes: "Keep the spine long." )
            ],
            instructions: "Finish the day with this full-body recovery flow to ease tension and support tomorrow’s movement.",
            coachingCues: "Stay slow and let the positions feel restorative, not forced.",
            whyItMatters: "A thoughtful recovery routine after play helps you sleep better and maintain consistent mobility for the next session."
        ),
        MobilityFlow(
            id: "recovery-005",
            title: "Long-Play Joint Recovery",
            duration: "30 min",
            type: .recovery,
            goal: "Support joint recovery after extended court time.",
            focusAreas: [.hips, .shoulders, .ankles],
            movements: [
                MobilityMovement(id: "recovery-005-1", title: "Foam roll outer hips", duration: "5 min", notes: "Breathe through the tight areas."),
                MobilityMovement(id: "recovery-005-2", title: "Thoracic foam mobilization", duration: "5 min", notes: "Move slowly along the spine."),
                MobilityMovement(id: "recovery-005-3", title: "Supported shoulder stretch", duration: "5 min", notes: "Keep the scapula stable."),
                MobilityMovement(id: "recovery-005-4", title: "Ankle dorsiflexion holds", duration: "5 min", notes: "Maintain even pressure."),
                MobilityMovement(id: "recovery-005-5", title: "Supine figure-four release", duration: "5 min", notes: "Let the glute relax." )
            ],
            instructions: "Use this joint-focused recovery routine after long playing days to preserve range and reduce discomfort.",
            coachingCues: "Breathe deeply and let each position settle into the joint instead of forcing the movement.",
            whyItMatters: "Joint recovery after extended play keeps you moving well in the next session and reduces lingering stiffness."
        )
    ]
}
