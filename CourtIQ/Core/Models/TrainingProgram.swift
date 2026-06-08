import Foundation

enum TrainingAccessTier: String, Codable {
    case free
    case premium

    var title: String {
        switch self {
        case .free: return "Free"
        case .premium: return "Premium"
        }
    }
}

enum TrainingLevel: String, Codable {
    case beginner
    case intermediate
    case advanced

    var title: String {
        switch self {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        }
    }

    var titleTr: String {
        switch self {
        case .beginner: return "Başlangıç"
        case .intermediate: return "Orta"
        case .advanced: return "İleri"
        }
    }

    func localizedTitle(for lang: AppLanguage) -> String {
        lang == .turkish ? titleTr : title
    }
}

enum TrainingGoalCategory: String, CaseIterable, Identifiable, Codable {
    case hybridFoundation
    case betterFootwork
    case strongerShots
    case betterFlexibility
    case matchConditioning

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hybridFoundation: return "Weekly Hybrid Build"
        case .betterFootwork: return "Better Footwork"
        case .strongerShots: return "Stronger Shots"
        case .betterFlexibility: return "Better Flexibility"
        case .matchConditioning: return "Match Conditioning"
        }
    }

    var summary: String {
        switch self {
        case .hybridFoundation:
            return "A full weekly gym and cardio mix for tennis players who need strength, explosiveness, hypertrophy, and conditioning together."
        case .betterFootwork:
            return "Sharper first-step reactions, deceleration strength, lateral power, and cleaner recovery steps."
        case .strongerShots:
            return "Build lower-body drive, rotational power, upper-body force transfer, and shot repeatability."
        case .betterFlexibility:
            return "Improve mobility, tissue tolerance, and range where tennis players tend to lose freedom."
        case .matchConditioning:
            return "Extend point quality deeper into sessions with repeat-sprint capacity and aerobic support."
        }
    }

    var symbolName: String {
        switch self {
        case .hybridFoundation: return "figure.strengthtraining.traditional"
        case .betterFootwork: return "figure.run"
        case .strongerShots: return "bolt.fill"
        case .betterFlexibility: return "figure.cooldown"
        case .matchConditioning: return "heart.circle.fill"
        }
    }

    var accessTier: TrainingAccessTier {
        switch self {
        case .hybridFoundation:
            return .free
        case .betterFootwork, .strongerShots, .betterFlexibility, .matchConditioning:
            return .premium
        }
    }
}

enum TrainingDayType: String, Codable {
    case gym
    case cardio
    case hybrid
    case recovery

    var title: String {
        switch self {
        case .gym: return "Gym"
        case .cardio: return "Cardio"
        case .hybrid: return "Hybrid"
        case .recovery: return "Recovery"
        }
    }
}

struct TrainingExercise: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    var titleTr: String? = nil
    let prescription: String
    let intent: String
    var intentTr: String? = nil
    let howTo: [String]?
    var howToTr: [String]? = nil
    let tennisWhy: String?
    var tennisWhyTr: String? = nil
    let watchOuts: [String]?
    var watchOutsTr: [String]? = nil

    var hasDetail: Bool {
        (howTo?.isEmpty == false) || (tennisWhy?.isEmpty == false) || (watchOuts?.isEmpty == false)
    }

    func localizedTitle(for lang: AppLanguage) -> String {
        lang == .turkish ? (titleTr ?? title) : title
    }

    func localizedIntent(for lang: AppLanguage) -> String {
        lang == .turkish ? (intentTr ?? intent) : intent
    }

    func localizedHowTo(for lang: AppLanguage) -> [String]? {
        lang == .turkish ? (howToTr ?? howTo) : howTo
    }

    func localizedTennisWhy(for lang: AppLanguage) -> String? {
        lang == .turkish ? (tennisWhyTr ?? tennisWhy) : tennisWhy
    }

    func localizedWatchOuts(for lang: AppLanguage) -> [String]? {
        lang == .turkish ? (watchOutsTr ?? watchOuts) : watchOuts
    }
}

struct TrainingDayPlan: Identifiable, Codable, Hashable {
    let id: String
    let dayLabel: String
    let title: String
    let type: TrainingDayType
    let duration: String
    let focus: String
    let objective: String
    let warmup: String
    let exercises: [TrainingExercise]
    let finisher: String
    let recovery: String
    var titleTr: String? = nil
    var focusTr: String? = nil
    var objectiveTr: String? = nil
    var warmupTr: String? = nil
    var finisherTr: String? = nil
    var recoveryTr: String? = nil

    func localizedTitle(for lang: AppLanguage) -> String { lang == .turkish ? (titleTr ?? title) : title }
    func localizedFocus(for lang: AppLanguage) -> String { lang == .turkish ? (focusTr ?? focus) : focus }
    func localizedObjective(for lang: AppLanguage) -> String { lang == .turkish ? (objectiveTr ?? objective) : objective }
    func localizedWarmup(for lang: AppLanguage) -> String { lang == .turkish ? (warmupTr ?? warmup) : warmup }
    func localizedFinisher(for lang: AppLanguage) -> String { lang == .turkish ? (finisherTr ?? finisher) : finisher }
    func localizedRecovery(for lang: AppLanguage) -> String { lang == .turkish ? (recoveryTr ?? recovery) : recovery }
}

struct TrainingPhase: Identifiable, Codable, Hashable {
    let id: String
    let weekRange: String
    let title: String
    let guidance: String
    var titleTr: String? = nil
    var guidanceTr: String? = nil

    func localizedTitle(for lang: AppLanguage) -> String { lang == .turkish ? (titleTr ?? title) : title }
    func localizedGuidance(for lang: AppLanguage) -> String { lang == .turkish ? (guidanceTr ?? guidance) : guidance }
}

struct TrainingProgram: Identifiable, Codable, Hashable {
    let id: String
    let category: TrainingGoalCategory
    let title: String
    let accessTier: TrainingAccessTier
    /// Intended training experience level. Optional so older content
    /// without the field still decodes; defaults to nil (treated as
    /// unspecified in the UI).
    var level: TrainingLevel? = nil
    let durationWeeks: Int
    let overview: String
    let outcome: String
    let emphasis: [String]
    let phases: [TrainingPhase]
    let days: [TrainingDayPlan]
    let persistencePrompts: [String]
    /// ID of the next program in this track. After finishing this program's
    /// 8 weeks, the user progresses to the program with this ID. Nil means
    /// end of track.
    var followOnProgramID: String? = nil
    var titleTr: String? = nil
    var overviewTr: String? = nil
    var outcomeTr: String? = nil
    var emphasisTr: [String]? = nil
    var persistencePromptsTr: [String]? = nil

    func localizedTitle(for lang: AppLanguage) -> String { lang == .turkish ? (titleTr ?? title) : title }
    func localizedOverview(for lang: AppLanguage) -> String { lang == .turkish ? (overviewTr ?? overview) : overview }
    func localizedOutcome(for lang: AppLanguage) -> String { lang == .turkish ? (outcomeTr ?? outcome) : outcome }
    func localizedEmphasis(for lang: AppLanguage) -> [String] { lang == .turkish ? (emphasisTr ?? emphasis) : emphasis }
    func localizedPersistencePrompts(for lang: AppLanguage) -> [String] { lang == .turkish ? (persistencePromptsTr ?? persistencePrompts) : persistencePrompts }

    var isPremium: Bool {
        accessTier == .premium
    }

    /// Resolves the continuation program, if one is wired up.
    var followOnProgram: TrainingProgram? {
        guard let followOnProgramID else { return nil }
        return TrainingProgram.allPrograms.first { $0.id == followOnProgramID }
    }
}

extension TrainingProgram {
    static let allPrograms: [TrainingProgram] = {
        let loaded = BundleContentLoader.loadArray([TrainingProgram].self, named: "training_programs")
        if !loaded.isEmpty {
            return loaded
        }

        return [fallbackProgram]
    }()

    static let featuredProgram = allPrograms.first ?? fallbackProgram

    static func program(for category: TrainingGoalCategory) -> TrainingProgram {
        allPrograms.first { $0.category == category } ?? featuredProgram
    }

    private static let fallbackProgram = TrainingProgram(
        id: "training-hybrid-foundation",
        category: .hybridFoundation,
        title: "8-Week Tennis Hybrid Foundation",
        accessTier: .free,
        level: .intermediate,
        durationWeeks: 8,
        overview: "Repeat a weekly mix of power, strength, and conditioning to build a stronger tennis base.",
        outcome: "A stronger lower body, cleaner force transfer into shots, and better repeat sprint conditioning.",
        emphasis: ["Plyometrics", "Hypertrophy", "Explosive strength", "Conditioning"],
        phases: [
            TrainingPhase(id: "phase-1", weekRange: "Weeks 1-2", title: "Base & Rhythm", guidance: "Learn the patterns and keep one rep in reserve."),
            TrainingPhase(id: "phase-2", weekRange: "Weeks 3-4", title: "Load & Capacity", guidance: "Add small load jumps while sprint quality stays high."),
            TrainingPhase(id: "phase-3", weekRange: "Weeks 5-6", title: "Power Conversion", guidance: "Move weights faster and keep jumps crisp."),
            TrainingPhase(id: "phase-4", weekRange: "Week 7", title: "Deload & Reset", guidance: "Reduce volume and freshen the body."),
            TrainingPhase(id: "phase-5", weekRange: "Week 8", title: "Sharpness Week", guidance: "Keep the sessions sharp and compare week one against week eight.")
        ],
        days: [
            TrainingDayPlan(
                id: "foundation-day-1",
                dayLabel: "Day 1",
                title: "Lower-Body Power + Acceleration",
                type: .hybrid,
                duration: "70 min",
                focus: "Explosive legs and first-step intent",
                objective: "Build force for push-off speed without losing posture.",
                warmup: "Bike, ankle rocks, mobility, pogo hops, and progressive accelerations.",
                exercises: [
                    TrainingExercise(id: "fd1-1", title: "Box jumps", prescription: "4 x 4", intent: "Fast ground contact and clean landing.", howTo: nil, tennisWhy: nil, watchOuts: nil),
                    TrainingExercise(id: "fd1-2", title: "Trap-bar deadlift", prescription: "4 x 5", intent: "Heavy but crisp concentric drive.", howTo: nil, tennisWhy: nil, watchOuts: nil)
                ],
                finisher: "8 x 15 sec bike sprints with 45 sec easy spin.",
                recovery: "Walk 5 minutes, then calf and hip-flexor mobility."
            )
        ],
        persistencePrompts: [
            "How explosive did your first step feel this week?",
            "How well did your legs recover between sessions?",
            "How confident did you feel sustaining intensity late in the week?"
        ]
    )
}
