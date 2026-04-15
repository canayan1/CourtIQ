import Foundation
import Combine

struct TrainingWeeklyCheckIn: Codable, Hashable {
    var readiness: Int
    var explosiveness: Int
    var conditioning: Int
    var notes: String
    var updatedAt: Date
}

@MainActor
final class TrainingProgressManager: ObservableObject {
    static let shared = TrainingProgressManager()

    @Published private(set) var completedSessionKeys: Set<String> = []
    @Published private(set) var weeklyCheckIns: [String: TrainingWeeklyCheckIn] = [:]
    @Published var selectedWeek = 1

    private let defaults = UserDefaults.standard
    private let completedKey = "CourtIQ.Training.CompletedSessionKeys"
    private let checkInKey = "CourtIQ.Training.WeeklyCheckIns"

    private init() {
        load()
    }

    func isCompleted(programID: String, week: Int, dayID: String) -> Bool {
        completedSessionKeys.contains(sessionKey(programID: programID, week: week, dayID: dayID))
    }

    func toggleCompletion(programID: String, week: Int, dayID: String) {
        let key = sessionKey(programID: programID, week: week, dayID: dayID)

        if completedSessionKeys.contains(key) {
            completedSessionKeys.remove(key)
        } else {
            completedSessionKeys.insert(key)
        }

        saveCompleted()
    }

    func completedCount(programID: String, week: Int) -> Int {
        completedSessionKeys.filter { $0.hasPrefix("\(programID)|week-\(week)|") }.count
    }

    func completionRate(programID: String, week: Int, totalDays: Int) -> Double {
        guard totalDays > 0 else { return 0 }
        return Double(completedCount(programID: programID, week: week)) / Double(totalDays)
    }

    func checkIn(for programID: String, week: Int) -> TrainingWeeklyCheckIn? {
        weeklyCheckIns[checkInStorageKey(programID: programID, week: week)]
    }

    func hasCheckIn(programID: String, week: Int) -> Bool {
        weeklyCheckIns[checkInStorageKey(programID: programID, week: week)] != nil
    }

    func saveCheckIn(programID: String, week: Int, readiness: Int, explosiveness: Int, conditioning: Int, notes: String) {
        weeklyCheckIns[checkInStorageKey(programID: programID, week: week)] = TrainingWeeklyCheckIn(
            readiness: readiness,
            explosiveness: explosiveness,
            conditioning: conditioning,
            notes: notes,
            updatedAt: Date()
        )
        saveCheckIns()
    }

    func totalCompletedSessions(programID: String) -> Int {
        completedSessionKeys.filter { $0.hasPrefix("\(programID)|") }.count
    }

    func checkInHistory(programID: String) -> [TrainingWeeklyCheckIn] {
        weeklyCheckIns
            .filter { $0.key.hasPrefix("\(programID)|") }
            .map(\.value)
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func reset() {
        completedSessionKeys = []
        weeklyCheckIns = [:]
        selectedWeek = 1
        defaults.removeObject(forKey: completedKey)
        defaults.removeObject(forKey: checkInKey)
    }

    private func sessionKey(programID: String, week: Int, dayID: String) -> String {
        "\(programID)|week-\(week)|\(dayID)"
    }

    private func checkInStorageKey(programID: String, week: Int) -> String {
        "\(programID)|week-\(week)"
    }

    private func load() {
        if let saved = defaults.array(forKey: completedKey) as? [String] {
            completedSessionKeys = Set(saved)
        }

        guard let data = defaults.data(forKey: checkInKey) else { return }
        if let decoded = try? JSONDecoder().decode([String: TrainingWeeklyCheckIn].self, from: data) {
            weeklyCheckIns = decoded
        }
    }

    private func saveCompleted() {
        defaults.set(Array(completedSessionKeys).sorted(), forKey: completedKey)
    }

    private func saveCheckIns() {
        if let data = try? JSONEncoder().encode(weeklyCheckIns) {
            defaults.set(data, forKey: checkInKey)
        }
    }
}
