import Foundation

enum QuizCategory: String, CaseIterable, Identifiable, Codable {
    case serve
    case returnPlay
    case rally
    case net
    case mental

    var id: String { rawValue }

    var title: String {
        switch self {
        case .serve: return "Serve"
        case .returnPlay: return "Return"
        case .rally: return "Rally"
        case .net: return "Net Play"
        case .mental: return "Mental"
        }
    }

    var systemImage: String {
        switch self {
        case .serve: return "figure.tennis"
        case .returnPlay: return "arrow.uturn.backward.circle.fill"
        case .rally: return "arrow.left.and.right.circle.fill"
        case .net: return "square.grid.3x1.below.line.grid.1x2"
        case .mental: return "brain.head.profile"
        }
    }

    var summary: String {
        switch self {
        case .serve:
            return "Build safer patterns, placement decisions, and second-serve confidence."
        case .returnPlay:
            return "Read serves faster and start points with cleaner intent."
        case .rally:
            return "Make higher percentage decisions when the point gets neutral."
        case .net:
            return "Sharpen transition choices, closing footwork, and volley selection."
        case .mental:
            return "Stay composed under pressure and recover faster between points."
        }
    }
}

enum QuizDifficulty: String, Codable {
    case easy
    case medium

    var title: String {
        switch self {
        case .easy: return "Foundation"
        case .medium: return "Match Pressure"
        }
    }
}

/// Optional court diagram metadata for a quiz question. Coordinates are
/// expressed in normalized court space: x in [0, 1] (left to right of the
/// doubles court), y in [0, 1] (far baseline = 0, near baseline = 1, net = 0.5).
struct QuizCourtDiagram: Codable, Hashable {
    var surface: String?     // "clay" | "grass" | "hard" — defaults to clay
    var youX: Double         // player position
    var youY: Double
    var opponentX: Double?   // optional opponent marker
    var opponentY: Double?
    var ballOriginX: Double? // dashed incoming ball trajectory start
    var ballOriginY: Double?
    var ballTargetX: Double? // dashed incoming ball trajectory end
    var ballTargetY: Double?
    var scoreChip: String?   // e.g. "30–40 · AD COURT"
}

struct QuizQuestion: Identifiable, Codable, Hashable {
    let id: String
    let category: QuizCategory
    let difficulty: QuizDifficulty
    let focusTag: String
    let scenario: String
    var scenarioTr: String? = nil
    let options: [String]
    var optionsTr: [String]? = nil
    let correctAnswerIndex: Int
    let explanation: String
    var explanationTr: String? = nil
    let takeaway: String
    var takeawayTr: String? = nil
    let mistakeType: String
    var diagram: QuizCourtDiagram? = nil
    /// Maps the question to one of the six TacticalCategory values
    /// (open_court | defense | approach | patterns | net_game | return)
    /// so quiz performance feeds the same Tactical Profile as drills.
    /// Optional in the wire format for backward compatibility; falls
    /// through to `.patterns` when missing.
    var tacticalCategory: String? = nil

    func localizedScenario(for lang: AppLanguage) -> String {
        lang == .turkish ? (scenarioTr ?? scenario) : scenario
    }

    func localizedOptions(for lang: AppLanguage) -> [String] {
        lang == .turkish ? (optionsTr ?? options) : options
    }

    func localizedExplanation(for lang: AppLanguage) -> String {
        lang == .turkish ? (explanationTr ?? explanation) : explanation
    }

    func localizedTakeaway(for lang: AppLanguage) -> String {
        lang == .turkish ? (takeawayTr ?? takeaway) : takeaway
    }

    /// Returns either the authored diagram or a category-aware generic
    /// diagram so every question gets a court visual.
    var resolvedDiagram: QuizCourtDiagram {
        if let diagram { return diagram }
        return Self.genericDiagram(for: category)
    }

    private static func genericDiagram(for category: QuizCategory) -> QuizCourtDiagram {
        switch category {
        case .serve:
            return QuizCourtDiagram(surface: "clay",
                                    youX: 0.5, youY: 0.95,
                                    opponentX: 0.7, opponentY: 0.08,
                                    ballOriginX: 0.5, ballOriginY: 0.95,
                                    ballTargetX: 0.7, ballTargetY: 0.32,
                                    scoreChip: nil)
        case .returnPlay:
            return QuizCourtDiagram(surface: "clay",
                                    youX: 0.7, youY: 0.92,
                                    opponentX: 0.5, opponentY: 0.05,
                                    ballOriginX: 0.5, ballOriginY: 0.05,
                                    ballTargetX: 0.7, ballTargetY: 0.85,
                                    scoreChip: nil)
        case .rally:
            return QuizCourtDiagram(surface: "clay",
                                    youX: 0.5, youY: 0.88,
                                    opponentX: 0.5, opponentY: 0.12,
                                    ballOriginX: 0.5, ballOriginY: 0.18,
                                    ballTargetX: 0.5, ballTargetY: 0.78,
                                    scoreChip: nil)
        case .net:
            return QuizCourtDiagram(surface: "clay",
                                    youX: 0.5, youY: 0.62,
                                    opponentX: 0.5, opponentY: 0.12,
                                    ballOriginX: 0.5, ballOriginY: 0.18,
                                    ballTargetX: 0.5, ballTargetY: 0.55,
                                    scoreChip: nil)
        case .mental:
            return QuizCourtDiagram(surface: "clay",
                                    youX: 0.5, youY: 0.92,
                                    opponentX: nil, opponentY: nil,
                                    ballOriginX: nil, ballOriginY: nil,
                                    ballTargetX: nil, ballTargetY: nil,
                                    scoreChip: nil)
        }
    }
}

struct Quiz: Identifiable, Codable {
    let id: String
    let title: String
    let questions: [QuizQuestion]
}

struct TrainingTip: Identifiable, Codable, Hashable {
    let id: String
    let theme: String
    let advice: String
    let category: QuizCategory?
}

extension Quiz {
    var focusLabel: String {
        let categoryCounts = Dictionary(grouping: questions, by: \.category)
            .mapValues { $0.count }
        return categoryCounts.max { $0.value < $1.value }?.key.title ?? questions.first?.category.title ?? "Match Play"
    }

    var primaryFocusTag: String? {
        questions.first?.focusTag
    }

    var primaryMistakeTypes: [String] {
        let counts = questions.reduce(into: [String: Int]()) { result, question in
            result[question.mistakeType, default: 0] += 1
        }

        return counts
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key < rhs.key
                }
                return lhs.value > rhs.value
            }
            .prefix(3)
            .map(\.key)
    }

    static let sample = dailyQuiz(for: Date())

    static func dailyTrainingTip(for date: Date = Date()) -> TrainingTip {
        let index = dayIndex(for: date) % dailyTrainingTips.count
        return dailyTrainingTips[index]
    }

    static func dailyQuiz(for date: Date = Date()) -> Quiz {
        let all = levelBiasedBank()
        let count = min(5, all.count)
        guard count > 0 else {
            return Quiz(id: "today", title: "Today’s CourtIQ", questions: [])
        }

        let start = dayIndex(for: date) % all.count
        let questions = (0..<count).map { all[(start + $0) % all.count] }

        return Quiz(
            id: "daily-\(dateKey(from: date))",
            title: "Today’s CourtIQ",
            questions: questions
        )
    }

    /// Returns a question bank ordered so that questions matching the user’s
    /// onboarding level appear first, while still including all questions so
    /// the day-index rotation never runs dry.
    private static func levelBiasedBank() -> [QuizQuestion] {
        let level = UserDefaults.standard.string(forKey: "CourtIQ.onboardingLevel") ?? ""
        let all = questionBank

        let preferred: QuizDifficulty?
        switch level {
        case "beginner":         preferred = .easy
        case "club":             preferred = nil          // mixed — no bias
        case "advanced", "coach": preferred = .medium
        default:                 preferred = nil
        }

        guard let preferred else { return all }

        let primary   = all.filter { $0.difficulty == preferred }
        let secondary = all.filter { $0.difficulty != preferred }
        return primary + secondary
    }

    static func practiceQuiz(category: QuizCategory) -> Quiz {
        let categoryQuestions = questionBank.filter { $0.category == category }
        let questions = Array(categoryQuestions.prefix(8))
        return Quiz(
            id: "practice-\(category.rawValue)",
            title: "\(category.title) Practice",
            questions: questions
        )
    }

    private static var questionBank: [QuizQuestion] {
        let loaded = BundleContentLoader.loadArray([QuizQuestion].self, named: "quiz_questions")
        if !loaded.isEmpty {
            return loaded
        }

        return fallbackQuestions
    }

    private static func dateKey(from date: Date) -> String {
        let startOfDay = Calendar.current.startOfDay(for: date)
        return dateFormatter.string(from: startOfDay)
    }

    private static func dayIndex(for date: Date) -> Int {
        let startOfDay = Calendar.current.startOfDay(for: date)
        return Int(startOfDay.timeIntervalSince1970 / 86_400)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let dailyTrainingTips: [TrainingTip] = [
        TrainingTip(id: "tip-1", theme: "First strike", advice: "Build the point with one clear pattern. Don’t ask your serve to win the point and hide a poor first shot.", category: .serve),
        TrainingTip(id: "tip-2", theme: "Return posture", advice: "Start the return from a neutral base so your first move is clean, not rushed.", category: .returnPlay),
        TrainingTip(id: "tip-3", theme: "Neutral rally discipline", advice: "In neutral balls, aim for repeatable depth and shape before you try to accelerate.", category: .rally),
        TrainingTip(id: "tip-4", theme: "Forward intent", advice: "Transition only when your contact and balance tell you the net is earned.", category: .net),
        TrainingTip(id: "tip-5", theme: "Pressure reset", advice: "After a bad point, shorten the next decision. One breath, one target, one clear action.", category: .mental)
    ]

    private static let fallbackQuestions: [QuizQuestion] = [
        QuizQuestion(
            id: "fallback-serve",
            category: .serve,
            difficulty: .medium,
            focusTag: "second serve pressure",
            scenario: "Your first serve has deserted you late in the set. What should anchor the next second serve?",
            options: ["High-margin body spin", "Flat T serve", "Wide ace attempt"],
            correctAnswerIndex: 0,
            explanation: "A body spin serve reduces double-fault pressure while still limiting return quality.",
            takeaway: "Use margin first when pressure spikes.",
            mistakeType: "forcing the second serve"
        ),
        QuizQuestion(
            id: "fallback-return",
            category: .returnPlay,
            difficulty: .easy,
            focusTag: "return positioning",
            scenario: "A big server keeps jamming your forehand from the deuce side. What’s the best first adjustment?",
            options: ["Shift a half-step back", "Stand closer and swing bigger", "Aim instantly for a winner"],
            correctAnswerIndex: 0,
            explanation: "Buying a little time helps you read and stabilize the first contact.",
            takeaway: "Change time and space before changing aggression.",
            mistakeType: "ignoring returner positioning"
        ),
        QuizQuestion(
            id: "fallback-rally",
            category: .rally,
            difficulty: .medium,
            focusTag: "neutral discipline",
            scenario: "The rally is neutral and you’re slightly off balance. What is the better choice?",
            options: ["Recover with a heavy crosscourt ball", "Go line for a surprise winner", "Charge the net immediately"],
            correctAnswerIndex: 0,
            explanation: "Neutral points reward margin and position before risk.",
            takeaway: "Rebuild the point before trying to finish it.",
            mistakeType: "low percentage rally choice"
        ),
        QuizQuestion(
            id: "fallback-net",
            category: .net,
            difficulty: .easy,
            focusTag: "transition timing",
            scenario: "You hit a short, floating approach. What should you do next?",
            options: ["Stay disciplined and expect a passing shot", "Close blindly to the tape", "Watch the winner fly by"],
            correctAnswerIndex: 0,
            explanation: "A weak approach needs smart positioning, not over-closing.",
            takeaway: "Transition quality starts with the approach ball.",
            mistakeType: "rushing the net"
        ),
        QuizQuestion(
            id: "fallback-mental",
            category: .mental,
            difficulty: .easy,
            focusTag: "reset routine",
            scenario: "You missed two routine balls in a row. What helps most before the next point?",
            options: ["One breath and one target cue", "Rush the serve", "Try a low-percentage play"],
            correctAnswerIndex: 0,
            explanation: "A short routine helps reset attention and lowers panic decisions.",
            takeaway: "Reset small so the next point stays simple.",
            mistakeType: "emotion-led decision"
        )
    ]
}
