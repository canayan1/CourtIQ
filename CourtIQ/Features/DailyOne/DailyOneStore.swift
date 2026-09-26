import Foundation

/// What this device has answered, and the streak that follows from it.
///
/// Deliberately small and local: no account, no sync, no server. The daily
/// question is the first thing a brand-new player can do, and asking them to
/// sign in before they may answer one question would cost more players than
/// the streak is worth.
struct DailyOneState: Codable, Equatable {
    struct Entry: Codable, Equatable {
        var originalIndex: Int          // the option as the JSON numbers it
        var correct: Bool
        var answeredAt: Date
    }

    var entries: [String: Entry] = [:]  // dayKey -> what was answered

    var answeredDayKeys: [String] { entries.keys.sorted() }
}

enum DailyOneStreak {

    /// Consecutive days answered, counting back from today.
    ///
    /// A wrong answer does **not** break it. The streak is there to bring
    /// someone back tomorrow, and a player who thought hard and got it wrong
    /// has done the thing the app wants; punishing that would teach them to
    /// skip the days they are unsure about, which is precisely backwards.
    ///
    /// Today counts if it has been answered. If it has not, the streak is
    /// measured to yesterday so it reads as alive all day rather than
    /// resetting to zero at midnight and scaring the player who is about to
    /// keep it.
    static func current(_ state: DailyOneState, today: Date = Date()) -> Int {
        let answered = Set(state.entries.keys)
        guard !answered.isEmpty else { return 0 }

        var day = today
        if !answered.contains(DailyOne.dayKey(for: day)) {
            day = day.addingTimeInterval(-86_400)
            guard answered.contains(DailyOne.dayKey(for: day)) else { return 0 }
        }

        var count = 0
        while answered.contains(DailyOne.dayKey(for: day)) {
            count += 1
            day = day.addingTimeInterval(-86_400)
        }
        return count
    }

    /// How many of the last `days` were answered correctly, and how many were
    /// answered at all — the honest pair, so a card can say "4 of your last 7"
    /// without implying the other three were wrong when they were never played.
    static func record(_ state: DailyOneState, days: Int, today: Date = Date())
        -> (correct: Int, answered: Int) {
        var correct = 0, answered = 0
        for back in 0..<max(0, days) {
            let key = DailyOne.dayKey(for: today.addingTimeInterval(-86_400 * Double(back)))
            guard let entry = state.entries[key] else { continue }
            answered += 1
            if entry.correct { correct += 1 }
        }
        return (correct, answered)
    }
}

/// The state, on disk.
@MainActor
final class DailyOneStore: ObservableObject {
    static let shared = DailyOneStore()

    @Published private(set) var state: DailyOneState

    private let defaults: UserDefaults
    private let key = "DropVolley.dailyOne.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(DailyOneState.self, from: data) {
            state = decoded
        } else {
            state = DailyOneState()
        }
    }

    var streak: Int { DailyOneStreak.current(state) }

    func entry(for dayKey: String) -> DailyOneState.Entry? { state.entries[dayKey] }

    func hasAnswered(_ dayKey: String) -> Bool { state.entries[dayKey] != nil }

    /// First answer wins. A player who backgrounds the app mid-question and
    /// comes back should see what they chose, not a second chance at it —
    /// the crowd split they are about to be shown already counts their vote.
    @discardableResult
    func record(dayKey: String, originalIndex: Int, correct: Bool,
                at date: Date = Date()) -> DailyOneState.Entry {
        if let existing = state.entries[dayKey] { return existing }
        let entry = DailyOneState.Entry(originalIndex: originalIndex,
                                        correct: correct, answeredAt: date)
        state.entries[dayKey] = entry
        persist()
        return entry
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(state) {
            defaults.set(data, forKey: key)
        }
    }
}
