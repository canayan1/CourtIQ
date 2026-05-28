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

    // MARK: - Tactical profile (v1)

    /// Per-category 0–5 average across every drill the user has ever
    /// completed. Joins each tap to its drill via the bundled drill
    /// catalog so we can resolve `category` even from older sessions
    /// that pre-date the category field. Categories with zero taps
    /// surface as `score == nil` so the UI can render an "not enough
    /// reps yet" state instead of pretending there's signal.
    var tacticalProfile: [TacticalProfileEntry] {
        let drillsByID = Dictionary(
            uniqueKeysWithValues: CourtTapDrill.allDrills.map { ($0.id, $0) }
        )

        // Aggregate raw 0–20 zone scores per category.
        var sumByCategory: [TacticalCategory: Int] = [:]
        var countByCategory: [TacticalCategory: Int] = [:]
        for session in sessions {
            for tap in session.taps {
                let drill = drillsByID[tap.drillID]
                let categoryRaw = drill?.category ?? TacticalCategory.fallback.rawValue
                let category = TacticalCategory(rawValue: categoryRaw) ?? .fallback
                sumByCategory[category, default: 0] += tap.zone.score
                countByCategory[category, default: 0] += 1
            }
        }

        return TacticalCategory.allCases.map { cat in
            guard let count = countByCategory[cat], count > 0 else {
                return TacticalProfileEntry.empty(cat)
            }
            let sum = Double(sumByCategory[cat] ?? 0)
            // sum is in 0...20*count; normalise to 0...5 by dividing
            // by (4 * count). green = 20 → 5.0, yellow = 10 → 2.5,
            // red = 0 → 0.0.
            let score = sum / (4.0 * Double(count))
            return TacticalProfileEntry(category: cat, score: score, sampleCount: count)
        }
    }

    /// Convenience: filter the profile to categories with established
    /// signal (≥3 taps). Used by AI Coach context so we never assert
    /// "your X is weak" off one bad swing.
    var establishedTacticalProfile: [TacticalProfileEntry] {
        tacticalProfile.filter(\.isEstablished)
    }

    /// Drill profile + quiz profile fused into a single per-category
    /// readout. Each side contributes its samples + score; the combined
    /// score is the sample-count-weighted average. Empty buckets stay
    /// nil so the UI can fade rows without data.
    ///
    /// `selfAssessment` (optional) is used as a baseline ONLY for
    /// categories where objective signal is sparse (<3 samples). Once
    /// real drill/quiz data accumulates the self-rating is no longer
    /// blended in — the user's actual reps speak louder than their
    /// initial guess.
    func combinedTacticalProfile(
        with quizManager: DailyQuizManager,
        selfAssessment: SelfAssessment? = nil
    ) -> [TacticalProfileEntry] {
        let drill = tacticalProfile
        let quiz = quizManager.quizTacticalProfile
        return TacticalCategory.allCases.map { cat in
            let d = drill.first { $0.category == cat }
            let q = quiz.first { $0.category == cat }
            let dCount = d?.sampleCount ?? 0
            let qCount = q?.sampleCount ?? 0
            let totalCount = dCount + qCount

            if totalCount >= 3 {
                // Enough objective signal — ignore the self-assessment.
                let dScore = d?.score ?? 0
                let qScore = q?.score ?? 0
                let combined = (dScore * Double(dCount) + qScore * Double(qCount))
                             / Double(totalCount)
                return TacticalProfileEntry(
                    category: cat,
                    score: combined,
                    sampleCount: totalCount
                )
            }

            // Sparse objective signal — fall back to (or blend with)
            // the self-rating so the user sees SOMETHING rather than
            // empty rows on day one. Self-assessment counts as 1
            // "sample" so it never overshadows real data later.
            if let selfScore = selfAssessment?.score(for: cat) {
                let baseline = Double(selfScore)
                if totalCount == 0 {
                    return TacticalProfileEntry(category: cat,
                                                score: baseline, sampleCount: 0)
                }
                let dScore = d?.score ?? 0
                let qScore = q?.score ?? 0
                let blended = (dScore * Double(dCount) + qScore * Double(qCount) + baseline)
                            / Double(totalCount + 1)
                return TacticalProfileEntry(category: cat,
                                            score: blended, sampleCount: totalCount)
            }

            // No self-assessment, no objective signal → empty.
            return totalCount > 0
                ? TacticalProfileEntry(category: cat,
                                       score: (d?.score ?? 0) * 0.5 + (q?.score ?? 0) * 0.5,
                                       sampleCount: totalCount)
                : TacticalProfileEntry.empty(cat)
        }
    }

    // MARK: - Play style profile (v2)

    /// Aggregates every v2 drill tap (taps that carry a chosen shot
    /// type) into a play-style fingerprint. Counts, percentages,
    /// accuracy, and a coarse archetype classification.
    var playStyleProfile: PlayStyleProfile {
        var counts: [ShotType: Int] = [:]
        var correct = 0
        var totalScored = 0

        for session in sessions {
            for tap in session.taps {
                guard let st = tap.shotType else { continue }
                counts[st, default: 0] += 1
                if let was = tap.shotTypeCorrect {
                    totalScored += 1
                    if was { correct += 1 }
                }
            }
        }

        let total = counts.values.reduce(0, +)
        guard total > 0 else { return .empty }

        let pct = counts.mapValues { Double($0) / Double(total) }
        let accuracy: Double? = totalScored > 0
            ? Double(correct) / Double(totalScored) : nil
        let archetype: PlayStyleArchetype? = total >= 30
            ? PlayStyleArchetype.classify(pct)
            : nil   // need at least 30 shot-type votes before classifying —
                    // 10 was too few to stabilise a label, so the Coach
                    // sees raw percentages but no archetype until then.

        return PlayStyleProfile(
            totalShots: total,
            counts: counts,
            percentages: pct,
            shotTypeAccuracy: accuracy,
            archetype: archetype
        )
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
