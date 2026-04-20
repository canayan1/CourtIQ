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
    var titleTr: String? = nil
    let duration: String
    let notes: String?
    var notesTr: String? = nil

    func localizedTitle(for lang: AppLanguage) -> String {
        lang == .turkish ? (titleTr ?? title) : title
    }

    func localizedNotes(for lang: AppLanguage) -> String? {
        lang == .turkish ? (notesTr ?? notes) : notes
    }
}

struct MobilityFlow: Identifiable, Codable {
    let id: String
    let title: String
    var titleTr: String? = nil
    let duration: String
    let type: MobilityFlowType
    let goal: String
    var goalTr: String? = nil
    let focusAreas: [MobilityFocusArea]
    let movements: [MobilityMovement]
    let instructions: String
    var instructionsTr: String? = nil
    let coachingCues: String
    var coachingCuesTr: String? = nil
    let whyItMatters: String
    var whyItMattersTr: String? = nil

    var focusLabel: String {
        focusAreas.map { $0.title }.joined(separator: ", ")
    }

    func localizedTitle(for lang: AppLanguage) -> String {
        lang == .turkish ? (titleTr ?? title) : title
    }

    func localizedGoal(for lang: AppLanguage) -> String {
        lang == .turkish ? (goalTr ?? goal) : goal
    }

    func localizedInstructions(for lang: AppLanguage) -> String {
        lang == .turkish ? (instructionsTr ?? instructions) : instructions
    }

    func localizedCoachingCues(for lang: AppLanguage) -> String {
        lang == .turkish ? (coachingCuesTr ?? coachingCues) : coachingCues
    }

    func localizedWhyItMatters(for lang: AppLanguage) -> String {
        lang == .turkish ? (whyItMattersTr ?? whyItMatters) : whyItMatters
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
