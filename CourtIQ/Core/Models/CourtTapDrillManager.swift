import Foundation
import Combine
import CoreGraphics

/// Owns daily drill selection, scoring evaluation, and session history.
/// Mirrors the manager pattern used by `DailyQuizManager` —
/// UserDefaults + Codable JSON, no SwiftData @Model.
@MainActor
final class CourtTapDrillManager: ObservableObject {
    static let shared = CourtTapDrillManager()

    @Published private(set) var sessions: [DrillSession] = []

    /// Number of scenarios per daily drill — keeps total commitment to
    /// ~30-60 seconds (5 × ~10 sec).
    static let scenariosPerDay = 5

    private let sessionsKey = "CourtIQ.drillSessions.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.sessions = Self.load(from: defaults, key: sessionsKey)
    }

    // MARK: - Daily picks

    /// 5 deterministically-selected scenarios for the given date. Using
    /// day-of-epoch as the seed means everyone sees the same drill on the
    /// same day (Wordle-style), and a user's "tomorrow" is always different
    /// from "today."
    func todaysDrills(for date: Date = Date()) -> [CourtTapDrill] {
        let all = CourtTapDrill.allDrills
        guard !all.isEmpty else { return [] }
        let dayIndex = dayNumber(for: date)
        let count = min(Self.scenariosPerDay, all.count)
        return (0..<count).map { offset in
            all[(dayIndex + offset) % all.count]
        }
    }

    /// Persistent "Drill #N" counter for the shareable card.
    func dayNumber(for date: Date = Date()) -> Int {
        let startOfDay = Calendar.current.startOfDay(for: date)
        return Int(startOfDay.timeIntervalSince1970 / 86_400)
    }

    /// `true` once the user has completed today's drill — used by Today
    /// to flip the card state and to close the Quiz Ring.
    var completedToday: Bool {
        sessions.contains { Calendar.current.isDateInToday($0.date) }
    }

    var todaysSession: DrillSession? {
        sessions.first { Calendar.current.isDateInToday($0.date) }
    }

    // MARK: - Scoring

    /// Evaluate a single tap. Pure function — used by both the live game
    /// view and the post-game replay.
    static func evaluate(tap: CGPoint, on drill: CourtTapDrill) -> DrillZone {
        if PolygonMath.contains(tap, polygon: drill.greenPolygon) {
            return .green
        }
        for poly in drill.yellowPolygons where PolygonMath.contains(tap, polygon: poly) {
            return .yellow
        }
        // Near-miss handling — if the user landed just outside green by
        // ~3% of court width, treat it as yellow rather than punishing
        // a borderline tap. Tunable; 0.04 reads as "very close."
        let greenDist = PolygonMath.minDistanceToEdge(tap, polygon: drill.greenPolygon)
        if greenDist < 0.04 { return .yellow }
        return .red
    }

    /// Record a completed session.
    func recordSession(taps: [DrillTap], for date: Date = Date()) {
        let id = Self.iso8601DayString(for: date)
        // Replace existing entry for the same date if any (lets user retry
        // before midnight if they wish — though we typically only allow
        // one completion per day in the UI).
        sessions.removeAll { Calendar.current.isDate($0.date, inSameDayAs: date) }
        let session = DrillSession(
            id: id,
            date: date,
            dayNumber: dayNumber(for: date),
            taps: taps
        )
        sessions.append(session)
        sessions.sort { $0.date > $1.date }
        persist()
        // Fan out to the unlock system so avatar gear can be granted as
        // the user hits "10 drills completed", "30 drills", etc.
        AvatarManager.shared.checkMilestones(
            logStreak: MatchEntryManager.shared.currentStreak,
            totalDrillsCompleted: sessions.count,
            totalMatches: MatchEntryManager.shared.totalEntries,
            tripleRingDays: TripleRingTracker.shared.count
        )
    }

    func resetLocalData() {
        sessions = []
        defaults.removeObject(forKey: sessionsKey)
    }

    // MARK: - Persistence

    private func persist() {
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        defaults.set(data, forKey: sessionsKey)
    }

    private static func load(from defaults: UserDefaults, key: String) -> [DrillSession] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([DrillSession].self, from: data)
        else { return [] }
        return decoded.sorted { $0.date > $1.date }
    }

    private static func iso8601DayString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
