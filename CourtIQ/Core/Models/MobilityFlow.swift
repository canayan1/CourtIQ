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
    static let sampleFlows: [MobilityFlow] = {
        let loaded = BundleContentLoader.loadArray([MobilityFlow].self, named: "mobility_flows")
        if !loaded.isEmpty {
            return loaded
        }

        return [
            MobilityFlow(
                id: "fallback-mobility-001",
                title: "Serve Shoulder Reset",
                duration: "6 min",
                type: .quickReset,
                goal: "Refresh shoulder and thoracic motion before serving.",
                focusAreas: [.shoulders, .thoracicRotation],
                movements: [
                    MobilityMovement(id: "fallback-mobility-001-1", title: "Wall slides", duration: "90 sec", notes: "Keep the ribs quiet."),
                    MobilityMovement(id: "fallback-mobility-001-2", title: "Open-book rotations", duration: "90 sec", notes: "Move from the mid-back."),
                    MobilityMovement(id: "fallback-mobility-001-3", title: "Band pull-aparts", duration: "60 sec", notes: "Feel the back of the shoulder.")
                ],
                instructions: "Move with control and let the shoulder free up before the first serve.",
                coachingCues: "Stay tall, breathe, and avoid shrugging.",
                whyItMatters: "More freedom through the shoulder and thoracic spine supports cleaner serve mechanics."
            )
        ]
    }()
}
