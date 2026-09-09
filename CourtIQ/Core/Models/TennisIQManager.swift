import Foundation
import Combine

// MARK: - State

/// A player's Tennis IQ training state. The IQ number is deliberately an
/// honest, explainable *mastery* score — not a skill-rating claim:
///
///     IQ = 60 + 40 × placementAccuracy + 60 × masteryFraction   (range 60–160)
///
/// where masteryFraction is the difficulty-weighted share of the bundled
/// scenario bank answered correctly. Every point is traceable to either the
/// 8-question placement or a mastered scenario (same "measure, don't invent"
/// discipline as the doubles tier + swing measured-count work).
struct TennisIQState: Codable {
    var masteredIDs: Set<String> = []
    /// Questions answered wrong, oldest first — the daily session's review pool.
    var missedQueue: [String] = []
    var seenIDs: Set<String> = []
    var placement: TennisIQPlacement? = nil
    var placementSkipped: Bool = false
    var xpTotal: Int = 0
    /// One point per day the IQ changed — feeds the progress chart.
    var iqHistory: [TennisIQHistoryPoint] = []
    /// Day key ("yyyy-MM-dd") of the last completed daily session.
    var lastSessionDayKey: String? = nil
}

struct TennisIQPlacement: Codable {
    var correctWeighted: Double
    var totalWeighted: Double
    var weakestCategoryRaw: String
    var completedAt: Date

    var accuracy: Double { totalWeighted > 0 ? correctWeighted / totalWeighted : 0 }
    var weakestCategory: QuizCategory? { QuizCategory(rawValue: weakestCategoryRaw) }
}

struct TennisIQHistoryPoint: Codable, Hashable {
    var dayKey: String
    var iq: Int
}

// MARK: - Engine (pure, deterministic)

/// Stateless scoring + session-building rules. Kept pure so they can be unit
/// tested without the manager once a test target exists.
enum TennisIQEngine {
    static let sessionSize = 5
    static let placementSize = 8

    static func weight(_ difficulty: QuizDifficulty) -> Double {
        switch difficulty {
        case .easy: return 0.5
        case .medium: return 1.0
        case .hard: return 1.5
        }
    }

    static func xp(for difficulty: QuizDifficulty) -> Int {
        switch difficulty {
        case .easy: return 5
        case .medium: return 10
        case .hard: return 15
        }
    }
    static let sessionCompletionXP = 10

    /// The scale, named so the UI can show it: a player with no placement and
    /// nothing mastered reads 60; mastering the whole bank after a perfect
    /// placement reads 160. Skipping the placement assumes a neutral 0.5.
    static let floor = 60
    static let ceiling = 160
    /// What the placement alone can be worth, out of the 100 points above the floor.
    static let placementPoints = 40

    /// IQ = 60 + 40×placement + 60×mastery, rounded. Neutral 0.5 placement
    /// prior when the user skipped the baseline (labelled "estimated" in UI).
    static func iq(state: TennisIQState, bank: [QuizQuestion]) -> Int {
        let placementAccuracy = state.placement?.accuracy ?? 0.5
        let fraction = masteryFraction(state: state, bank: bank)
        return Int((Double(floor) + Double(placementPoints) * placementAccuracy
                    + Double(ceiling - floor - placementPoints) * fraction).rounded())
    }

    static func masteryFraction(state: TennisIQState, bank: [QuizQuestion]) -> Double {
        let total = bank.reduce(0.0) { $0 + weight($1.difficulty) }
        guard total > 0 else { return 0 }
        let mastered = bank.filter { state.masteredIDs.contains($0.id) }
            .reduce(0.0) { $0 + weight($1.difficulty) }
        return mastered / total
    }

    /// Difficulty-weighted mastery per category (0…1 each).
    static func categoryMastery(state: TennisIQState, bank: [QuizQuestion]) -> [QuizCategory: Double] {
        var result: [QuizCategory: Double] = [:]
        for category in QuizCategory.allCases {
            let questions = bank.filter { $0.category == category }
            let total = questions.reduce(0.0) { $0 + weight($1.difficulty) }
            guard total > 0 else { continue }
            let mastered = questions.filter { state.masteredIDs.contains($0.id) }
                .reduce(0.0) { $0 + weight($1.difficulty) }
            result[category] = mastered / total
        }
        return result
    }

    /// Weakest category: lowest mastery, ties broken by the placement blind
    /// spot, then stable category order.
    static func weakestCategory(state: TennisIQState, bank: [QuizQuestion]) -> QuizCategory {
        let mastery = categoryMastery(state: state, bank: bank)
        let minValue = QuizCategory.allCases.map { mastery[$0] ?? 0 }.min() ?? 0
        let candidates = QuizCategory.allCases.filter { (mastery[$0] ?? 0) == minValue }
        if let blind = state.placement?.weakestCategory, candidates.contains(blind) {
            return blind
        }
        return candidates.first ?? .serve
    }

    /// Deterministic daily session: 1 review (oldest miss) + 2 weakest-category
    /// + rotation fill, easy→hard ramp inside each slot group. Stable for a
    /// given (state, date) so re-entering the same day rebuilds the same quiz.
    static func dailySessionQuestions(state: TennisIQState, bank: [QuizQuestion], dayIndex: Int) -> [QuizQuestion] {
        guard !bank.isEmpty else { return [] }
        let byID = Dictionary(uniqueKeysWithValues: bank.map { ($0.id, $0) })
        var picked: [QuizQuestion] = []
        var used = Set<String>()

        func take(_ q: QuizQuestion?) {
            guard let q, !used.contains(q.id), picked.count < sessionSize else { return }
            picked.append(q); used.insert(q.id)
        }
        /// easy→hard, then stable id order — the "ramp".
        func ramped(_ qs: [QuizQuestion]) -> [QuizQuestion] {
            qs.sorted {
                weight($0.difficulty) != weight($1.difficulty)
                    ? weight($0.difficulty) < weight($1.difficulty)
                    : $0.id < $1.id
            }
        }

        // 1. Review: oldest miss not yet mastered.
        if let reviewID = state.missedQueue.first(where: { !state.masteredIDs.contains($0) }) {
            take(byID[reviewID])
        }

        // 2. Two from the weakest category (unmastered, prefer unseen).
        let weakest = weakestCategory(state: state, bank: bank)
        let weakestPool = ramped(bank.filter {
            $0.category == weakest && !state.masteredIDs.contains($0.id) && !used.contains($0.id)
        })
        let weakestUnseen = weakestPool.filter { !state.seenIDs.contains($0.id) }
        for q in (weakestUnseen + weakestPool) where picked.count < 3 { take(q) }

        // 3. Fill from the other categories, rotating the start by day so the
        //    mix varies session to session.
        let others = QuizCategory.allCases.filter { $0 != weakest }
        let rotated = (0..<others.count).map { others[(dayIndex + $0) % others.count] }
        for category in rotated where picked.count < sessionSize {
            let pool = ramped(bank.filter {
                $0.category == category && !state.masteredIDs.contains($0.id) && !used.contains($0.id)
            })
            take(pool.first(where: { !state.seenIDs.contains($0.id) }) ?? pool.first)
        }

        // 4. Everything mastered (or pools dry): seeded refresh over the bank.
        if picked.count < sessionSize {
            let refresh = bank.sorted { $0.id < $1.id }
            var index = dayIndex % refresh.count
            while picked.count < sessionSize {
                take(refresh[index % refresh.count])
                index += 1
                if used.count == refresh.count { break }
            }
        }
        return picked
    }

    /// Placement: per category the first medium question (stable id order),
    /// plus one easy and one hard for range — 8 total, deterministic, no
    /// hardcoded ids so a content update can't break it.
    static func placementQuestions(bank: [QuizQuestion]) -> [QuizQuestion] {
        var picked: [QuizQuestion] = []
        func first(_ category: QuizCategory, _ difficulty: QuizDifficulty) -> QuizQuestion? {
            bank.filter { $0.category == category && $0.difficulty == difficulty }
                .sorted { $0.id < $1.id }
                .first
        }
        for category in QuizCategory.allCases {
            if let q = first(category, .medium) { picked.append(q) }
        }
        if let easy = first(.serve, .easy) { picked.insert(easy, at: 0) }
        if let hard = first(.rally, .hard) { picked.append(hard) }
        // Content edge: if a difficulty bucket is empty, backfill from the bank.
        for q in bank.sorted(by: { $0.id < $1.id }) where picked.count < placementSize {
            if !picked.contains(where: { $0.id == q.id }) { picked.append(q) }
        }
        return Array(picked.prefix(placementSize))
    }
}

// MARK: - Skill path units

/// A slice of a category's questions, easy→hard — one rung of the skill path.
struct TennisIQUnit: Identifiable, Hashable {
    let id: String
    let category: QuizCategory
    let index: Int              // 1-based within the category
    let questionIDs: [String]

    static func == (lhs: TennisIQUnit, rhs: TennisIQUnit) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension TennisIQEngine {
    static let unitTargetSize = 7

    /// Balanced units per category (26 questions → 4 units of 7/7/6/6),
    /// ordered easy→hard then id — a stable difficulty ramp.
    static func units(for category: QuizCategory, bank: [QuizQuestion]) -> [TennisIQUnit] {
        let sorted = bank.filter { $0.category == category }.sorted {
            weight($0.difficulty) != weight($1.difficulty)
                ? weight($0.difficulty) < weight($1.difficulty)
                : $0.id < $1.id
        }
        guard !sorted.isEmpty else { return [] }
        let unitCount = max(1, Int((Double(sorted.count) / Double(unitTargetSize)).rounded(.up)))
        let base = sorted.count / unitCount
        let extra = sorted.count % unitCount
        var units: [TennisIQUnit] = []
        var cursor = 0
        for index in 0..<unitCount {
            let size = base + (index < extra ? 1 : 0)
            let slice = Array(sorted[cursor..<cursor + size])
            cursor += size
            units.append(TennisIQUnit(
                id: "\(category.rawValue)-\(index + 1)",
                category: category,
                index: index + 1,
                questionIDs: slice.map(\.id)
            ))
        }
        return units
    }
}

// MARK: - Manager

/// Owns the persisted Tennis IQ state (UserDefaults + JSON, matching every
/// other progress manager in the app). Views observe this and record session
/// results through it; streak accounting stays with DailyQuizManager.
@MainActor
final class TennisIQManager: ObservableObject {
    static let shared = TennisIQManager()

    @Published private(set) var state: TennisIQState

    private let userDefaults = UserDefaults.standard
    private let stateKey = "CourtIQ.IQ.State"

    private init() {
        state = Self.load(from: userDefaults, key: stateKey)
    }

    // MARK: Derived values

    var bank: [QuizQuestion] { Quiz.fullBank }
    var iq: Int { TennisIQEngine.iq(state: state, bank: bank) }
    var masteredCount: Int { state.masteredIDs.count }
    var totalCount: Int { bank.count }
    var masteryFraction: Double { TennisIQEngine.masteryFraction(state: state, bank: bank) }
    var categoryMastery: [QuizCategory: Double] { TennisIQEngine.categoryMastery(state: state, bank: bank) }
    var weakestCategory: QuizCategory { TennisIQEngine.weakestCategory(state: state, bank: bank) }
    var xpTotal: Int { state.xpTotal }
    var iqHistory: [TennisIQHistoryPoint] { state.iqHistory }
    /// Placement done or explicitly skipped — gates the "set your baseline" card.
    var hasBaseline: Bool { state.placement != nil || state.placementSkipped }
    var isBaselineEstimated: Bool { state.placement == nil }
    var placementBlindSpot: QuizCategory? { state.placement?.weakestCategory }
    var completedSessionToday: Bool { state.lastSessionDayKey == Self.dayKey(for: Date()) }

    // MARK: Quizzes

    func todaySession(for date: Date = Date()) -> Quiz {
        let questions = TennisIQEngine.dailySessionQuestions(
            state: state, bank: bank, dayIndex: Self.dayIndex(for: date)
        )
        return Quiz(
            id: "iq-daily-\(Self.dayKey(for: date))",
            title: "Daily IQ",
            questions: questions
        )
    }

    func placementQuiz() -> Quiz {
        Quiz(
            id: "iq-placement",
            title: "Tennis IQ Placement",
            questions: TennisIQEngine.placementQuestions(bank: bank)
        )
    }

    // MARK: Recording

    /// Fold a completed daily session into mastery/XP/IQ history.
    func recordSession(results: [String: Bool], date: Date = Date()) {
        applyResults(results)
        let correctXP = bank
            .filter { results[$0.id] == true }
            .reduce(0) { $0 + TennisIQEngine.xp(for: $1.difficulty) }
        state.xpTotal += correctXP + TennisIQEngine.sessionCompletionXP
        state.lastSessionDayKey = Self.dayKey(for: date)
        appendHistoryPoint(for: date)
        persist()
    }

    /// Fold the 8-question placement into state and lock the baseline.
    func recordPlacement(results: [String: Bool], date: Date = Date()) {
        let questions = TennisIQEngine.placementQuestions(bank: bank)
        var correct = 0.0, total = 0.0
        var perCategory: [QuizCategory: (correct: Double, total: Double)] = [:]
        for q in questions {
            let w = TennisIQEngine.weight(q.difficulty)
            let isCorrect = results[q.id] == true
            total += w
            correct += isCorrect ? w : 0
            var bucket = perCategory[q.category] ?? (0, 0)
            bucket.total += w
            bucket.correct += isCorrect ? w : 0
            perCategory[q.category] = bucket
        }
        let weakest = QuizCategory.allCases.min { lhs, rhs in
            let l = perCategory[lhs].map { $0.total > 0 ? $0.correct / $0.total : 1 } ?? 1
            let r = perCategory[rhs].map { $0.total > 0 ? $0.correct / $0.total : 1 } ?? 1
            return l < r
        } ?? .serve
        state.placement = TennisIQPlacement(
            correctWeighted: correct,
            totalWeighted: total,
            weakestCategoryRaw: weakest.rawValue,
            completedAt: date
        )
        state.placementSkipped = false
        applyResults(results)
        appendHistoryPoint(for: date)
        persist()
    }

    func skipPlacement() {
        guard !hasBaseline else { return }
        state.placementSkipped = true
        persist()
    }

    // MARK: Skill path

    func units(for category: QuizCategory) -> [TennisIQUnit] {
        TennisIQEngine.units(for: category, bank: bank)
    }

    /// Unit 1 is always open; unit N unlocks once every question of unit N-1
    /// has been attempted (seen), so progression rewards showing up, not
    /// perfection.
    func isUnitUnlocked(_ unit: TennisIQUnit) -> Bool {
        guard unit.index > 1 else { return true }
        let all = units(for: unit.category)
        guard let previous = all.first(where: { $0.index == unit.index - 1 }) else { return true }
        return previous.questionIDs.allSatisfy { state.seenIDs.contains($0) }
    }

    func masteredCount(in unit: TennisIQUnit) -> Int {
        unit.questionIDs.filter { state.masteredIDs.contains($0) }.count
    }

    func practiceQuiz(for unit: TennisIQUnit) -> Quiz {
        let byID = Dictionary(uniqueKeysWithValues: bank.map { ($0.id, $0) })
        return Quiz(
            id: "iq-unit-\(unit.id)",
            title: "\(unit.category.title) · \(unit.index)",
            questions: unit.questionIDs.compactMap { byID[$0] }
        )
    }

    /// Fold a skill-path unit run into mastery/XP — everything the daily
    /// session does except marking today's ritual complete.
    func recordPractice(results: [String: Bool], date: Date = Date()) {
        applyResults(results)
        let correctXP = bank
            .filter { results[$0.id] == true }
            .reduce(0) { $0 + TennisIQEngine.xp(for: $1.difficulty) }
        state.xpTotal += correctXP
        appendHistoryPoint(for: date)
        persist()
    }

    // MARK: - Internals

    private func applyResults(_ results: [String: Bool]) {
        for (id, correct) in results {
            state.seenIDs.insert(id)
            if correct {
                state.masteredIDs.insert(id)
                state.missedQueue.removeAll { $0 == id }
            } else if !state.missedQueue.contains(id) {
                state.missedQueue.append(id)
            }
        }
    }

    private func appendHistoryPoint(for date: Date) {
        let key = Self.dayKey(for: date)
        let point = TennisIQHistoryPoint(dayKey: key, iq: iq)
        if state.iqHistory.last?.dayKey == key {
            state.iqHistory[state.iqHistory.count - 1] = point
        } else if state.iqHistory.last?.iq != point.iq || state.iqHistory.isEmpty {
            state.iqHistory.append(point)
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(state) {
            userDefaults.set(data, forKey: stateKey)
        }
    }

    private static func load(from defaults: UserDefaults, key: String) -> TennisIQState {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(TennisIQState.self, from: data) else {
            return TennisIQState()
        }
        return decoded
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static func dayKey(for date: Date) -> String {
        dayFormatter.string(from: Calendar.current.startOfDay(for: date))
    }

    private static func dayIndex(for date: Date) -> Int {
        Int(Calendar.current.startOfDay(for: date).timeIntervalSince1970 / 86_400)
    }
}
