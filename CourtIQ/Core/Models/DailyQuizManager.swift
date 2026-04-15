import Foundation
import Combine

struct QuizSessionRecord: Identifiable, Codable, Hashable {
    let id: String
    let quizID: String
    let title: String
    let focusLabel: String
    let score: Int
    let totalQuestions: Int
    let mistakeTypes: [String]
    let completedAt: Date
    let isDaily: Bool

    var accuracyText: String {
        "\(score)/\(totalQuestions)"
    }
}

struct QuizCompletionSummary {
    let quizID: String
    let title: String
    let focusLabel: String
    let score: Int
    let totalQuestions: Int
    let mistakeTypes: [String]
}

@MainActor
final class DailyQuizManager: ObservableObject {
    static let shared = DailyQuizManager()

    @Published private(set) var completedDates: [String] = []
    @Published private(set) var sessionHistory: [QuizSessionRecord] = []

    private let userDefaults = UserDefaults.standard
    private let completedKey = "CourtIQ.CompletedDates"
    private let historyKey = "CourtIQ.Quiz.SessionHistory"

    private init() {
        completedDates = Self.loadCompletedDates(from: userDefaults)
        sessionHistory = Self.loadHistory(from: userDefaults)
    }

    var todayQuiz: Quiz {
        Quiz.dailyQuiz(for: Date())
    }

    var totalQuizzesCompleted: Int {
        sessionHistory.filter(\.isDaily).count
    }

    var completedThisWeek: Int {
        let calendar = Calendar.current
        let recentKeys = (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: Date())?.todayKey
        }

        return recentKeys.filter { completedDates.contains($0) }.count
    }

    var weeklyCompletionRate: Double {
        Double(completedThisWeek) / 7.0
    }

    var isCompletedToday: Bool {
        completedDates.contains(Date.todayKey)
    }

    var currentStreak: Int {
        let completedSet = Set(completedDates)
        let calendar = Calendar.current
        var streak = 0
        var date = Date()

        if !isCompletedToday {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: date) else {
                return 0
            }
            date = yesterday
        }

        while completedSet.contains(date.todayKey) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: date) else {
                break
            }
            date = previous
        }

        return streak
    }

    var topMistakePatterns: [String] {
        let counts = sessionHistory
            .flatMap(\.mistakeTypes)
            .reduce(into: [String: Int]()) { counts, type in
                counts[type, default: 0] += 1
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

    var archivedDailyHistory: [QuizSessionRecord] {
        sessionHistory.filter(\.isDaily)
    }

    func recordCompletion(summary: QuizCompletionSummary, isDaily: Bool) {
        let record = QuizSessionRecord(
            id: "\(summary.quizID)-\(Date.todayKey)-\(isDaily ? "daily" : "practice")",
            quizID: summary.quizID,
            title: summary.title,
            focusLabel: summary.focusLabel,
            score: summary.score,
            totalQuestions: summary.totalQuestions,
            mistakeTypes: summary.mistakeTypes,
            completedAt: Date(),
            isDaily: isDaily
        )

        if isDaily {
            completedDates.removeAll { $0 == Date.todayKey }
            completedDates.append(Date.todayKey)
            completedDates.sort()
            userDefaults.set(completedDates, forKey: completedKey)
        }

        if let existingIndex = sessionHistory.firstIndex(where: { $0.id == record.id }) {
            sessionHistory[existingIndex] = record
        } else {
            sessionHistory.insert(record, at: 0)
        }
        saveHistory()
    }

    func reset() {
        completedDates = []
        sessionHistory = []
        userDefaults.removeObject(forKey: completedKey)
        userDefaults.removeObject(forKey: historyKey)
    }

    private static func loadCompletedDates(from defaults: UserDefaults) -> [String] {
        guard let saved = defaults.array(forKey: "CourtIQ.CompletedDates") as? [String] else {
            return []
        }
        return saved.sorted()
    }

    private static func loadHistory(from defaults: UserDefaults) -> [QuizSessionRecord] {
        guard let data = defaults.data(forKey: "CourtIQ.Quiz.SessionHistory"),
              let decoded = try? JSONDecoder().decode([QuizSessionRecord].self, from: data) else {
            return []
        }
        return decoded.sorted { $0.completedAt > $1.completedAt }
    }

    private func saveHistory() {
        guard let data = try? JSONEncoder().encode(sessionHistory) else { return }
        userDefaults.set(data, forKey: historyKey)
    }
}

private extension Date {
    static var todayKey: String {
        dateFormatter.string(from: Calendar.current.startOfDay(for: Date()))
    }

    var todayKey: String {
        Self.dateFormatter.string(from: Calendar.current.startOfDay(for: self))
    }

    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
