import Foundation

/// The gate a Rally Cam session earns against its rung's target.
///
/// The two sensors are not equally trustworthy, and the colors encode that
/// honestly rather than pretending one certainty:
/// - The MIC counts reps. It is the trusted sensor — red/not-red is its call.
/// - The CAMERA reads placement. It is beta — it decides green vs yellow,
///   and can never take a pass away.
///
/// So: red = the count wasn't met. Yellow = counted, but placement was either
/// unreadable or off the band. Green = counted AND the camera confirmed the
/// ball lived between the lines. Yellow and green both open the next rung —
/// green is the one worth chasing.
enum WallVerdict: String, Codable, Comparable {
    case red, yellow, green

    private var rank: Int { self == .red ? 0 : self == .yellow ? 1 : 2 }
    static func < (a: WallVerdict, b: WallVerdict) -> Bool { a.rank < b.rank }
}

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
    /// Optional so records written before verdicts existed still decode.
    var verdict: WallVerdict? = nil
}

/// Records wall sessions + exposes personal bests and the days the player hit
/// the wall (for the unified `ActivityManager` streak). UserDefaults-backed;
/// no backend needed for the local, sticky part (the leaderboard is separate).
@MainActor
final class WallProgressManager: ObservableObject {
    static let shared = WallProgressManager()

    private static let key = "DropVolley.wallSessions.v1"
    private static let clearedKey = "DropVolley.wallCleared.v1"
    private static let verdictKey = "DropVolley.wallVerdicts.v1"
    @Published private(set) var sessions: [WallSessionRecord] = []
    /// Drill ids the player has cleared — drives the level-ladder unlock.
    @Published private(set) var clearedDrills: Set<String> = []
    /// Best verdict ever earned per rung — the seal's color. Only improves:
    /// a yellow after a green never demotes the seal.
    @Published private(set) var bestVerdicts: [String: WallVerdict] = [:]

    private init() { load() }

    func record(drillID: String?, title: String, hits: Int, seconds: Int,
                isFreeRally: Bool, verdict: WallVerdict? = nil) {
        let record = WallSessionRecord(
            id: UUID().uuidString, drillID: drillID, title: title,
            hits: hits, seconds: seconds, date: Date(), isFreeRally: isFreeRally,
            verdict: verdict
        )
        sessions.insert(record, at: 0)
        persist()
    }

    /// The color of a rung's seal (nil = never passed with a verdict).
    func bestVerdict(drillID: String) -> WallVerdict? { bestVerdicts[drillID] }

    /// A session's verdict comes in: passes clear the rung, and the seal keeps
    /// the best color it has ever earned. A red changes nothing — the mic said
    /// the count wasn't met, and there is nothing to record but the attempt.
    func registerVerdict(_ verdict: WallVerdict, drillID: String) {
        guard verdict > .red else { return }
        markCleared(drillID)
        if let current = bestVerdicts[drillID], current >= verdict { return }
        bestVerdicts[drillID] = verdict
        persistVerdicts()
    }

    private func persistVerdicts() {
        let raw = bestVerdicts.mapValues(\.rawValue)
        UserDefaults.standard.set(raw, forKey: Self.verdictKey)
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

    // MARK: - Level ladder progression

    func isCleared(_ drillID: String) -> Bool { clearedDrills.contains(drillID) }

    /// Mark a level cleared (unlocks the next). Called when a free account taps
    /// "I did this" on the demo, or a premium account finishes a Rally Cam run.
    func markCleared(_ drillID: String) {
        guard !clearedDrills.contains(drillID) else { return }
        clearedDrills.insert(drillID)
        UserDefaults.standard.set(Array(clearedDrills), forKey: Self.clearedKey)
    }

    // MARK: - Persistence

    private func persist() {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    private func load() {
        if let saved = UserDefaults.standard.array(forKey: Self.clearedKey) as? [String] {
            clearedDrills = Set(saved)
        }
        if let raw = UserDefaults.standard.dictionary(forKey: Self.verdictKey) as? [String: String] {
            bestVerdicts = raw.compactMapValues(WallVerdict.init(rawValue:))
        }
        guard let data = UserDefaults.standard.data(forKey: Self.key),
              let decoded = try? JSONDecoder().decode([WallSessionRecord].self, from: data) else { return }
        sessions = decoded.sorted { $0.date > $1.date }
    }
}
