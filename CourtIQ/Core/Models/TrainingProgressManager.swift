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
    private let client = SupabaseRESTClient.shared

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

        Task {
            await syncCompletion(for: key, programID: programID, week: week, dayID: dayID)
        }
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
        let key = checkInStorageKey(programID: programID, week: week)
        weeklyCheckIns[key] = TrainingWeeklyCheckIn(
            readiness: readiness,
            explosiveness: explosiveness,
            conditioning: conditioning,
            notes: notes,
            updatedAt: Date()
        )
        saveCheckIns()

        Task {
            await syncCheckIn(programID: programID, week: week)
        }
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

    func syncAfterAuthentication(uploadLocalPreview: Bool) async throws {
        guard let session = UserSessionManager.shared.remoteSession else { return }

        if uploadLocalPreview {
            let logPayload = completedSessionKeys.map { key in
                RemoteTrainingSessionLogRecord(storageKey: key, userID: session.userID)
            }
            if !logPayload.isEmpty {
                _ = try await client.upsertRows(logPayload, into: "training_session_logs", onConflict: "id", session: session) as [RemoteTrainingSessionLogRecord]
            }

            let checkInPayload = weeklyCheckIns.map { key, value in
                RemoteTrainingCheckInRecord(storageKey: key, checkIn: value, userID: session.userID)
            }
            if !checkInPayload.isEmpty {
                _ = try await client.upsertRows(checkInPayload, into: "weekly_checkins", onConflict: "id", session: session) as [RemoteTrainingCheckInRecord]
            }
        }

        let logs: [RemoteTrainingSessionLogRecord] = try await client.selectRows(
            from: "training_session_logs",
            queryItems: [
                URLQueryItem(name: "user_id", value: "eq.\(session.userID)")
            ],
            session: session
        )

        let checkIns: [RemoteTrainingCheckInRecord] = try await client.selectRows(
            from: "weekly_checkins",
            queryItems: [
                URLQueryItem(name: "user_id", value: "eq.\(session.userID)"),
                URLQueryItem(name: "order", value: "updated_at.desc")
            ],
            session: session
        )

        completedSessionKeys = Set(logs.map(\.id))
        weeklyCheckIns = Dictionary(uniqueKeysWithValues: checkIns.map { ($0.id, $0.appModel) })
        saveCompleted()
        saveCheckIns()
    }

    func reset() {
        resetLocalData()
    }

    func resetLocalData() {
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

    private func syncCompletion(for storageKey: String, programID: String, week: Int, dayID: String) async {
        guard let session = UserSessionManager.shared.remoteSession else { return }

        do {
            if completedSessionKeys.contains(storageKey) {
                let payload = RemoteTrainingSessionLogRecord(
                    id: storageKey,
                    userID: session.userID,
                    programID: programID,
                    week: week,
                    dayID: dayID,
                    completedAt: Date()
                )
                _ = try await client.upsertRows([payload], into: "training_session_logs", onConflict: "id", session: session) as [RemoteTrainingSessionLogRecord]
            } else {
                try await client.deleteRows(
                    from: "training_session_logs",
                    queryItems: [
                        URLQueryItem(name: "id", value: "eq.\(storageKey)")
                    ],
                    session: session
                )
            }
        } catch {
            await MainActor.run {
                UserSessionManager.shared.registerSyncError("Training completion could not sync right now.")
            }
        }
    }

    private func syncCheckIn(programID: String, week: Int) async {
        guard let session = UserSessionManager.shared.remoteSession else { return }
        let key = checkInStorageKey(programID: programID, week: week)
        guard let checkIn = weeklyCheckIns[key] else { return }

        do {
            let payload = RemoteTrainingCheckInRecord(storageKey: key, checkIn: checkIn, userID: session.userID)
            _ = try await client.upsertRows([payload], into: "weekly_checkins", onConflict: "id", session: session) as [RemoteTrainingCheckInRecord]
        } catch {
            await MainActor.run {
                UserSessionManager.shared.registerSyncError("Weekly check-in could not sync right now.")
            }
        }
    }
}

private struct RemoteTrainingSessionLogRecord: Codable {
    let id: String
    let userID: String
    let programID: String
    let week: Int
    let dayID: String
    let completedAt: Date

    init(
        id: String,
        userID: String,
        programID: String,
        week: Int,
        dayID: String,
        completedAt: Date
    ) {
        self.id = id
        self.userID = userID
        self.programID = programID
        self.week = week
        self.dayID = dayID
        self.completedAt = completedAt
    }

    init(storageKey: String, userID: String) {
        let pieces = storageKey.split(separator: "|").map(String.init)
        let parsedWeek = pieces.count > 1 ? Int(pieces[1].replacingOccurrences(of: "week-", with: "")) ?? 1 : 1
        self.init(
            id: storageKey,
            userID: userID,
            programID: pieces.first ?? TrainingProgram.featuredProgram.id,
            week: parsedWeek,
            dayID: pieces.count > 2 ? pieces[2] : "session",
            completedAt: Date()
        )
    }
}

private struct RemoteTrainingCheckInRecord: Codable {
    let id: String
    let userID: String
    let programID: String
    let week: Int
    let readiness: Int
    let explosiveness: Int
    let conditioning: Int
    let notes: String
    let updatedAt: Date

    init(
        id: String,
        userID: String,
        programID: String,
        week: Int,
        readiness: Int,
        explosiveness: Int,
        conditioning: Int,
        notes: String,
        updatedAt: Date
    ) {
        self.id = id
        self.userID = userID
        self.programID = programID
        self.week = week
        self.readiness = readiness
        self.explosiveness = explosiveness
        self.conditioning = conditioning
        self.notes = notes
        self.updatedAt = updatedAt
    }

    init(storageKey: String, checkIn: TrainingWeeklyCheckIn, userID: String) {
        let pieces = storageKey.split(separator: "|").map(String.init)
        id = storageKey
        self.userID = userID
        programID = pieces.first ?? TrainingProgram.featuredProgram.id
        week = pieces.count > 1 ? Int(pieces[1].replacingOccurrences(of: "week-", with: "")) ?? 1 : 1
        readiness = checkIn.readiness
        explosiveness = checkIn.explosiveness
        conditioning = checkIn.conditioning
        notes = checkIn.notes
        updatedAt = checkIn.updatedAt
    }

    var appModel: TrainingWeeklyCheckIn {
        TrainingWeeklyCheckIn(
            readiness: readiness,
            explosiveness: explosiveness,
            conditioning: conditioning,
            notes: notes,
            updatedAt: updatedAt
        )
    }
}
