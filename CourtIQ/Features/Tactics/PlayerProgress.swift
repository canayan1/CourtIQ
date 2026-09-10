import SwiftUI

// MARK: - Levels

/// XP tiers. The names are tactical roles, not generic ranks, so levelling up
/// reads as "you now understand more of the game" rather than "you ground XP".
enum PlayerLevel: Int, CaseIterable, Identifiable {
    case rookie = 0
    case rallyBuilder = 1
    case pointBuilder = 2
    case courtReader = 3
    case tactician = 4
    case strategist = 5

    var id: Int { rawValue }

    /// XP required to reach this level.
    var threshold: Int {
        switch self {
        case .rookie:       return 0
        case .rallyBuilder: return 100
        case .pointBuilder: return 250
        case .courtReader:  return 450
        case .tactician:    return 700
        case .strategist:   return 950
        }
    }

    /// Bundle keys for the localised name and blurb. `title` / `blurb` below
    /// stay as the English fallback.
    private var slug: String {
        switch self {
        case .rookie: return "rookie"
        case .rallyBuilder: return "rally_builder"
        case .pointBuilder: return "point_builder"
        case .courtReader: return "court_reader"
        case .tactician: return "tactician"
        case .strategist: return "strategist"
        }
    }
    var localizationKey: String { "tactics.level.\(slug)" }
    var blurbKey: String { "tactics.level.\(slug).blurb" }

    var title: String {
        switch self {
        case .rookie:       return "Rookie"
        case .rallyBuilder: return "Rally Builder"
        case .pointBuilder: return "Point Builder"
        case .courtReader:  return "Court Reader"
        case .tactician:    return "Tactician"
        case .strategist:   return "Strategist"
        }
    }

    var blurb: String {
        switch self {
        case .rookie:       return "You're learning where to stand."
        case .rallyBuilder: return "You can keep a rally honest."
        case .pointBuilder: return "You build points instead of hoping."
        case .courtReader:  return "You spot what your opponent can't do."
        case .tactician:    return "You have a plan before the toss."
        case .strategist:   return "You out-think players who out-hit you."
        }
    }

    var symbol: String {
        switch self {
        case .rookie:       return "figure.tennis"
        case .rallyBuilder: return "arrow.left.arrow.right"
        case .pointBuilder: return "square.stack.3d.up"
        case .courtReader:  return "eye"
        case .tactician:    return "brain.head.profile"
        case .strategist:   return "crown"
        }
    }

    static func forXP(_ xp: Int) -> PlayerLevel {
        allCases.last { xp >= $0.threshold } ?? .rookie
    }

    var next: PlayerLevel? {
        PlayerLevel(rawValue: rawValue + 1)
    }
}

// MARK: - XP awards

/// Every way to earn XP, in one place, so the economy is tunable from one spot.
enum XPAward {
    static let lessonRead = 10
    static let quizFirstTry = 15
    static let quizRetry = 5
    static let chapterComplete = 50
}

// MARK: - Persisted shape

/// The entire save file. Codable so the whole thing round-trips through one
/// UserDefaults key — no migration matrix, no SwiftData schema to version.
private struct ProgressSnapshot: Codable {
    var completedLessonIDs: [String] = []
    /// Lesson IDs whose quiz was answered correctly on the first try.
    var perfectLessonIDs: [String] = []
    var xp: Int = 0
    var streakDays: Int = 0
    /// Start-of-day for the last day a lesson was completed.
    var lastActiveDay: Date? = nil
    var bestStreakDays: Int = 0
    /// Start-of-day for the day the free daily lesson was spent.
    var dailyFreeSpentDay: Date? = nil
    var hasOnboarded: Bool = false
    var goal: String? = nil
    var experience: String? = nil
}

// MARK: - Store

/// Owns the player's progress and the gamification rules on top of it.
///
/// Deliberately a single `@Observable` object rather than a per-feature split:
/// XP, streak and unlock state all move together when a lesson is finished, and
/// every screen reads all three.
@Observable
@MainActor
final class PlayerProgress {
    private static let storageKey = "DropVolley.tactics.progress.v1"

    private var snapshot: ProgressSnapshot
    private let defaults: UserDefaults
    private let calendar = Calendar.current
    /// The clock, injectable so the streak rules can actually be tested. Streaks
    /// are a core mechanic whose whole logic is about the boundary between one
    /// calendar day and the next, and that is untestable against a hard-coded
    /// `Date()`.
    private let now: () -> Date

    /// Set when a lesson completion crosses a level threshold, so the completion
    /// screen can celebrate it. Cleared once shown.
    var pendingLevelUp: PlayerLevel?
    /// Set when a lesson completion finishes its chapter.
    var pendingChapterComplete: Chapter?
    /// Set when the streak roll lands exactly on a milestone, so the completion
    /// screen can mark it. Cleared once shown.
    var pendingStreakMilestone: Int?

    /// Day counts worth celebrating. Sparse on purpose: a milestone every day
    /// would make the milestone meaningless.
    private static let streakMilestones: Set<Int> = [3, 7, 14, 30, 60, 100, 365]

    init(defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.now = now
        if let data = defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode(ProgressSnapshot.self, from: data) {
            snapshot = decoded
        } else {
            snapshot = ProgressSnapshot()
        }
    }

    // MARK: Reads

    var xp: Int { snapshot.xp }
    var level: PlayerLevel { .forXP(snapshot.xp) }
    var streakDays: Int { snapshot.streakDays }
    var bestStreakDays: Int { snapshot.bestStreakDays }
    var completedCount: Int { snapshot.completedLessonIDs.count }
    var perfectCount: Int { snapshot.perfectLessonIDs.count }
    var hasOnboarded: Bool { snapshot.hasOnboarded }
    var goal: String? { snapshot.goal }
    var experience: String? { snapshot.experience }

    func isCompleted(_ lessonID: String) -> Bool {
        snapshot.completedLessonIDs.contains(lessonID)
    }

    func isPerfect(_ lessonID: String) -> Bool {
        snapshot.perfectLessonIDs.contains(lessonID)
    }

    func isChapterComplete(_ chapter: Chapter) -> Bool {
        chapter.lessons.allSatisfy { isCompleted($0.id) }
    }

    func completedCount(in chapter: Chapter) -> Int {
        chapter.lessons.filter { isCompleted($0.id) }.count
    }

    /// Progress toward the next level, 0…1. Returns 1 at the top level.
    var levelProgress: Double {
        guard let next = level.next else { return 1 }
        let span = Double(next.threshold - level.threshold)
        guard span > 0 else { return 1 }
        return min(1, Double(snapshot.xp - level.threshold) / span)
    }

    var xpToNextLevel: Int? {
        guard let next = level.next else { return nil }
        return max(0, next.threshold - snapshot.xp)
    }

    /// True if today's free lesson outside chapter 1 has not been spent yet.
    var hasFreeDailyLesson: Bool {
        guard let spent = snapshot.dailyFreeSpentDay else { return true }
        return !calendar.isDate(spent, inSameDayAs: now())
    }

    /// True if a lesson was completed today — drives the "streak safe" banner.
    var didPracticeToday: Bool {
        guard let last = snapshot.lastActiveDay else { return false }
        return calendar.isDate(last, inSameDayAs: now())
    }

    // MARK: Writes

    func completeOnboarding(goal: String, experience: String) {
        snapshot.goal = goal
        snapshot.experience = experience
        snapshot.hasOnboarded = true
        persist()
    }

    /// Records a finished lesson and applies every gamification consequence:
    /// XP, streak roll, level-up and chapter-complete flags.
    ///
    /// Replaying an already-completed lesson is free and awards nothing — the
    /// path stays revisitable without letting the XP economy be farmed.
    func completeLesson(_ lesson: Lesson, in chapter: Chapter, firstTry: Bool) {
        guard !isCompleted(lesson.id) else { return }

        let levelBefore = level

        snapshot.completedLessonIDs.append(lesson.id)
        if firstTry { snapshot.perfectLessonIDs.append(lesson.id) }
        snapshot.xp += XPAward.lessonRead + (firstTry ? XPAward.quizFirstTry : XPAward.quizRetry)

        if isChapterComplete(chapter) {
            snapshot.xp += XPAward.chapterComplete
            pendingChapterComplete = chapter
        }

        let streakBefore = snapshot.streakDays
        rollStreak()
        if snapshot.streakDays != streakBefore,
           Self.streakMilestones.contains(snapshot.streakDays) {
            pendingStreakMilestone = snapshot.streakDays
        }

        if level != levelBefore { pendingLevelUp = level }

        persist()
    }

    /// Marks today's free daily lesson as spent. Called when a free player opens
    /// a gated lesson using their daily allowance.
    func spendFreeDailyLesson() {
        snapshot.dailyFreeSpentDay = calendar.startOfDay(for: now())
        persist()
    }

    func resetAll() {
        snapshot = ProgressSnapshot()
        pendingLevelUp = nil
        pendingChapterComplete = nil
        pendingStreakMilestone = nil
        persist()
    }

    // MARK: Internals

    /// Advances the streak at most once per calendar day. A gap of two or more
    /// days resets it to 1 rather than to 0 — the player practised today, so
    /// today counts.
    private func rollStreak() {
        let today = calendar.startOfDay(for: now())
        defer {
            snapshot.lastActiveDay = today
            snapshot.bestStreakDays = max(snapshot.bestStreakDays, snapshot.streakDays)
        }

        guard let last = snapshot.lastActiveDay else {
            snapshot.streakDays = 1
            return
        }
        if calendar.isDate(last, inSameDayAs: today) { return }

        let gap = calendar.dateComponents([.day], from: last, to: today).day ?? 99
        snapshot.streakDays = gap == 1 ? snapshot.streakDays + 1 : 1
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
