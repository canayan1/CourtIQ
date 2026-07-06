import Foundation

/// One completed wall session, persisted so the wall becomes STICKY — history,
/// per-drill personal bests, and a contribution to the unified activity streak
/// (via `activeDayKeys`).
struct WallSessionRecord: Codable, Identifiable, Hashable {
    let id: String
    let drillID: String?      // nil for the free-rally ("Wall Tennis") mode
    let title: String
    let hits: Int
    let seconds: Int
    let date: Date
    let isFreeRally: Bool
}

/// Records wall sessions + exposes personal bests and the days the player hit
/// the wall (for the unified `ActivityManager` streak). UserDefaults-backed;
/// no backend needed for the local, sticky part (the leaderboard is separate).
@MainActor
final class WallProgressManager: ObservableObject {
    static let shared = WallProgressManager()

    private static let key = "DropVolley.wallSessions.v1"
    @Published private(set) var sessions: [WallSessionRecord] = []

    private init() { load() }

    func record(drillID: String?, title: String, hits: Int, seconds: Int, isFreeRally: Bool) {
        let record = WallSessionRecord(
            id: UUID().uuidString, drillID: drillID, title: title,
            hits: hits, seconds: seconds, date: Date(), isFreeRally: isFreeRally
        )
        sessions.insert(record, at: 0)
        persist()
    }

    /// Best hit-count ever for a given drill (0 if never done) — the "PB" chip.
    func personalBest(drillID: String) -> Int {
        sessions.filter { $0.drillID == drillID }.map(\.hits).max() ?? 0
    }

    /// How many times a given drill has been completed.
    func timesCompleted(drillID: String) -> Int {
        sessions.filter { $0.drillID == drillID }.count
    }

    var totalSessions: Int { sessions.count }
    var lastSession: WallSessionRecord? { sessions.first }

    /// Days with ≥1 wall session — feeds the unified activity streak.
    var activeDayKeys: Set<String> { Set(sessions.map { $0.date.todayKey }) }

    // MARK: - Persistence

    private func persist() {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.key),
              let decoded = try? JSONDecoder().decode([WallSessionRecord].self, from: data) else { return }
        sessions = decoded.sorted { $0.date > $1.date }
    }
}
