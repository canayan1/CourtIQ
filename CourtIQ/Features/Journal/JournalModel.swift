import Foundation

/// The one thing the journal wants to ask the player right now.
///
/// The user asked for this explicitly: the app should come back and ask "how
/// did that meal leave you?" or "did you feel good that day?" rather than
/// waiting to be filled in. So the journal always has at most one open
/// question, picked by how quickly the answer goes stale — a session you
/// finished an hour ago is remembered accurately; a match from last Tuesday
/// is not.
enum JournalPrompt: Identifiable, Hashable {
    /// A fuel entry logged but never rated. The most perishable answer.
    case rateFuel(NutritionEntry)
    /// A match played on a day with no fuel entry — the log is half written.
    case fuelForMatch(MatchEntry)
    /// A played match with no ratings on it.
    case rateMatch(MatchEntry)

    var id: String {
        switch self {
        case .rateFuel(let e):     return "rateFuel-\(e.id)"
        case .fuelForMatch(let m): return "fuelForMatch-\(m.id)"
        case .rateMatch(let m):    return "rateMatch-\(m.id)"
        }
    }

    var titleKey: String {
        switch self {
        case .rateFuel:     return "journal.prompt_rate_fuel_title"
        case .fuelForMatch: return "journal.prompt_fuel_match_title"
        case .rateMatch:    return "journal.prompt_rate_match_title"
        }
    }

    var bodyKey: String {
        switch self {
        case .rateFuel:     return "journal.prompt_rate_fuel_body"
        case .fuelForMatch: return "journal.prompt_fuel_match_body"
        case .rateMatch:    return "journal.prompt_rate_match_body"
        }
    }

    var ctaKey: String {
        switch self {
        case .rateFuel:     return "journal.prompt_rate_fuel_cta"
        case .fuelForMatch: return "journal.prompt_fuel_match_cta"
        case .rateMatch:    return "journal.prompt_rate_match_cta"
        }
    }

    var symbol: String {
        switch self {
        case .rateFuel:     return "hand.thumbsup"
        case .fuelForMatch: return "fork.knife"
        case .rateMatch:    return "star"
        }
    }
}

/// One line in the merged timeline. Matches and fuel entries are different
/// shapes, and forcing them into a common struct would flatten away exactly
/// the detail each row wants to show, so the timeline carries the originals.
enum JournalItem: Identifiable, Hashable {
    case match(MatchEntry)
    case fuel(NutritionEntry)

    var id: String {
        switch self {
        case .match(let m): return "m-\(m.id)"
        case .fuel(let n):  return "n-\(n.id)"
        }
    }

    var date: Date {
        switch self {
        case .match(let m): return m.date
        case .fuel(let n):  return n.date
        }
    }
}

/// Read-only reasoning over the two logs. A plain struct rather than an
/// observable object: both managers already publish, so the view refreshes
/// on their changes and this only has to answer questions about the current
/// snapshot.
struct JournalDigest {
    let matches: [MatchEntry]
    let fuel: [NutritionEntry]

    /// How far back the journal will chase an unanswered question. Beyond
    /// this, asking produces a guess rather than a memory.
    private static let recallDays = 4

    /// Newest first.
    var timeline: [JournalItem] {
        (matches.map(JournalItem.match) + fuel.map(JournalItem.fuel))
            .sorted { $0.date > $1.date }
    }

    func items(on day: Date) -> [JournalItem] {
        let key = JournalDay.key(day)
        return timeline.filter { JournalDay.key($0.date) == key }
    }

    /// Built once and handed to the grid, so a 49-cell render does not scan
    /// both logs 49 times.
    var marks: [String: DayMark] {
        var out: [String: DayMark] = [:]
        for m in matches where !m.isUpcoming { out[JournalDay.key(m.date), default: .none].match = true }
        for n in fuel { out[JournalDay.key(n.date), default: .none].fuel = true }
        return out
    }

    /// Every day with something on it — matches and fuel together. This is
    /// what makes the journal a single habit rather than two.
    var loggedDayKeys: Set<String> {
        Set(matches.filter { !$0.isUpcoming }.map { JournalDay.key($0.date) })
            .union(fuel.map { JournalDay.key($0.date) })
    }

    /// Consecutive days ending today or yesterday. Yesterday still counts so
    /// a player who logs in the morning does not watch the number reset at
    /// midnight.
    var streak: Int {
        let keys = loggedDayKeys
        guard !keys.isEmpty else { return 0 }
        let cal = Calendar(identifier: .iso8601)
        var day = Date()
        if !keys.contains(JournalDay.key(day)) {
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: day),
                  keys.contains(JournalDay.key(yesterday)) else { return 0 }
            day = yesterday
        }
        var count = 0
        while keys.contains(JournalDay.key(day)) {
            count += 1
            guard let previous = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    /// The single open question, or nil when the journal is up to date.
    var prompt: JournalPrompt? {
        let cutoff = Calendar(identifier: .iso8601)
            .date(byAdding: .day, value: -Self.recallDays, to: Date()) ?? Date()

        if let unrated = fuel.first(where: { !$0.isRated && $0.date > cutoff }) {
            return .rateFuel(unrated)
        }
        let fuelDays = Set(fuel.map { JournalDay.key($0.date) })
        if let bare = matches.first(where: {
            !$0.isUpcoming && $0.date > cutoff && !fuelDays.contains(JournalDay.key($0.date))
        }) {
            return .fuelForMatch(bare)
        }
        if let unrated = matches.first(where: {
            $0.isCompleted && $0.date > cutoff && !$0.hasRatings
        }) {
            return .rateMatch(unrated)
        }
        return nil
    }
}
