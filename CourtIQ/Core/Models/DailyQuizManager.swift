import Foundation
import Combine

final class DailyQuizManager: ObservableObject {
    static let shared = DailyQuizManager()

    @Published private(set) var completedDates: [String] = []

    private let userDefaults = UserDefaults.standard
    private let storageKey = "CourtIQ.CompletedDates"

    private init() {
        completedDates = Self.loadCompletedDates(from: userDefaults)
    }

    var todayQuiz: Quiz {
        Quiz.dailyQuiz(for: Date())
    }

    var totalQuizzesCompleted: Int {
        completedDates.count
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

    func markCompletedToday() {
        let today = Date.todayKey
        guard !completedDates.contains(today) else { return }
        completedDates.append(today)
        completedDates.sort()
        userDefaults.set(completedDates, forKey: storageKey)
    }

    private static func loadCompletedDates(from defaults: UserDefaults) -> [String] {
        guard let saved = defaults.array(forKey: "CourtIQ.CompletedDates") as? [String] else {
            return []
        }
        return saved.sorted()
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
