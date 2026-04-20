import Foundation
import Combine

// MARK: - CompletedProgressionWeek

struct CompletedProgressionWeek: Codable, Identifiable {
    var id: String { weekKey }
    let weekKey: String
    let completedAt: Date
    let trainingDays: Int
    let mobilitySessions: Int
    let quizCorrect: Int
}

// MARK: - PlayerProgressionManager

/// Tracks progress through the 9-week journey required to advance from one player level to the next.
/// Each week is a continuous attempt that starts when the player taps "Start" and ends when all
/// three requirements are met (training, mobility, quiz) or when they abandon it.
@MainActor
final class PlayerProgressionManager: ObservableObject {
    static let shared = PlayerProgressionManager()

    // MARK: Requirements

    static let requiredTrainingDays       = 3
    static let requiredMobilitySessions   = 2
    static let requiredQuizCorrect        = 5
    static let totalWeeksToLevelUp        = 9

    // MARK: Storage keys

    private enum Keys {
        static let level         = "CourtIQ.Prog.Level"
        static let weekCount     = "CourtIQ.Prog.WeekCount"
        static let weekStart     = "CourtIQ.Prog.WeekStart"
        static let trainDays     = "CourtIQ.Prog.TrainDays"
        static let mobCount      = "CourtIQ.Prog.MobCount"
        static let completedWeeks = "CourtIQ.Prog.CompletedWeeks"
    }

    // MARK: Published state

    @Published private(set) var currentLevel: TennisPlayerLevel       = .ballKid
    @Published private(set) var completedWeekCount: Int               = 0
    @Published private(set) var currentWeekStartDate: Date?
    @Published private(set) var trainingDaysThisWeek: [String]        = []  // "yyyy-MM-dd", deduped
    @Published private(set) var mobilityCountThisWeek: Int            = 0
    @Published private(set) var completedWeeks: [CompletedProgressionWeek] = []

    private let defaults = UserDefaults.standard
    private lazy var dayFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()

    private init() { load() }

    // MARK: Computed

    var isStarted: Bool { currentWeekStartDate != nil }
    var isLevelComplete: Bool { completedWeekCount >= Self.totalWeeksToLevelUp }
    var isMaxLevel: Bool { currentLevel == .pro }

    var progressionProgress: Double {
        Double(completedWeekCount) / Double(Self.totalWeeksToLevelUp)
    }

    var trainingDaysCount: Int { trainingDaysThisWeek.count }
    var mobilityCount: Int { mobilityCountThisWeek }

    func quizCorrectCount(from history: [QuizSessionRecord]) -> Int {
        guard let start = currentWeekStartDate else { return 0 }
        return history
            .filter { $0.completedAt >= start }
            .reduce(0) { $0 + $1.score }
    }

    func allRequirementsMet(quizHistory: [QuizSessionRecord]) -> Bool {
        trainingDaysCount >= Self.requiredTrainingDays &&
        mobilityCount     >= Self.requiredMobilitySessions &&
        quizCorrectCount(from: quizHistory) >= Self.requiredQuizCorrect
    }

    /// Whether the user can run the progression for their current level.
    /// Ball Kid → Club Player is free; everything above requires premium.
    func canProgress(isPremium: Bool) -> Bool {
        currentLevel == .ballKid || isPremium
    }

    // MARK: Actions

    func startCurrentWeek() {
        guard !isStarted else { return }
        currentWeekStartDate     = Date()
        trainingDaysThisWeek     = []
        mobilityCountThisWeek    = 0
        saveAll()
    }

    func recordTrainingDay() {
        guard isStarted else { return }
        let key = dayFormatter.string(from: Date())
        guard !trainingDaysThisWeek.contains(key) else { return }
        trainingDaysThisWeek.append(key)
        saveAll()
    }

    func removeTrainingDay() {
        guard isStarted else { return }
        let key = dayFormatter.string(from: Date())
        trainingDaysThisWeek.removeAll { $0 == key }
        saveAll()
    }

    func recordMobilitySession() {
        guard isStarted else { return }
        mobilityCountThisWeek += 1
        saveAll()
    }

    /// Call after any tracked activity. Advances the week if all requirements are met.
    func checkAndCompleteWeek(quizHistory: [QuizSessionRecord]) {
        guard isStarted, !isLevelComplete else { return }
        guard allRequirementsMet(quizHistory: quizHistory) else { return }

        let record = CompletedProgressionWeek(
            weekKey: "week-\(completedWeekCount + 1)",
            completedAt: Date(),
            trainingDays: trainingDaysCount,
            mobilitySessions: mobilityCount,
            quizCorrect: quizCorrectCount(from: quizHistory)
        )
        completedWeeks.append(record)
        completedWeekCount += 1

        if completedWeekCount >= Self.totalWeeksToLevelUp {
            // Level up
            if let next = currentLevel.nextLevel {
                currentLevel = next
            }
            completedWeekCount    = 0
            completedWeeks        = []
            currentWeekStartDate  = nil
        } else {
            // Auto-advance to next week
            currentWeekStartDate  = Date()
            trainingDaysThisWeek  = []
            mobilityCountThisWeek = 0
        }
        saveAll()
    }

    // MARK: Persistence

    private func load() {
        currentLevel          = TennisPlayerLevel(rawValue: defaults.integer(forKey: Keys.level)) ?? .ballKid
        completedWeekCount    = defaults.integer(forKey: Keys.weekCount)
        currentWeekStartDate  = defaults.object(forKey: Keys.weekStart) as? Date
        trainingDaysThisWeek  = defaults.stringArray(forKey: Keys.trainDays) ?? []
        mobilityCountThisWeek = defaults.integer(forKey: Keys.mobCount)

        if let data  = defaults.data(forKey: Keys.completedWeeks),
           let weeks = try? JSONDecoder().decode([CompletedProgressionWeek].self, from: data) {
            completedWeeks = weeks
        }
    }

    private func saveAll() {
        defaults.set(currentLevel.rawValue,   forKey: Keys.level)
        defaults.set(completedWeekCount,      forKey: Keys.weekCount)
        defaults.set(currentWeekStartDate,    forKey: Keys.weekStart)
        defaults.set(trainingDaysThisWeek,    forKey: Keys.trainDays)
        defaults.set(mobilityCountThisWeek,   forKey: Keys.mobCount)
        if let data = try? JSONEncoder().encode(completedWeeks) {
            defaults.set(data, forKey: Keys.completedWeeks)
        }
    }
}
