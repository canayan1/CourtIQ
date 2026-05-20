import Foundation

/// Court surface a match was played on. Mirrors `AppPalette.CourtSurface`
/// but lives here as a Codable enum so MatchEntry can serialize cleanly.
enum MatchSurface: String, Codable, CaseIterable, Identifiable {
    case clay
    case grass
    case hard

    var id: String { rawValue }
}

/// W/L outcome of a logged match.
enum MatchResult: String, Codable, CaseIterable, Identifiable {
    case won
    case lost

    var id: String { rawValue }
}

/// A single user-authored match record. Two intended kinds:
/// - **Quick Log** (`isQuickLog == true`): four 1-5 ratings + optional
///   one-sentence takeaway. ~30 second commitment.
/// - **Journal entry** (`isQuickLog == false`): full pre/post-match notes
///   + ratings + takeaway. A few minutes of reflection.
///
/// Both kinds share the same struct so they collate cleanly in trend
/// charts and the calendar view — anything that has ratings counts toward
/// the dashboard regardless of kind.
struct MatchEntry: Codable, Identifiable, Hashable {
    let id: String
    var date: Date
    var opponentName: String
    var surface: MatchSurface
    var result: MatchResult
    var score: String                   // free text e.g. "6-4, 3-6, 7-5"

    // Ratings — 1...5. nil means user didn't rate that dimension on this entry.
    var serveRating: Int?
    var returnRating: Int?
    var movementRating: Int?
    var mentalRating: Int?

    // Long-form text fields. Empty string is fine — the UI shows them only
    // when populated.
    var preMatchNotes: String
    var postMatchNotes: String
    var takeaway: String                // 0-200 chars, the "one thing" line

    var isQuickLog: Bool

    init(
        id: String = UUID().uuidString,
        date: Date = Date(),
        opponentName: String = "",
        surface: MatchSurface = .hard,
        result: MatchResult = .won,
        score: String = "",
        serveRating: Int? = nil,
        returnRating: Int? = nil,
        movementRating: Int? = nil,
        mentalRating: Int? = nil,
        preMatchNotes: String = "",
        postMatchNotes: String = "",
        takeaway: String = "",
        isQuickLog: Bool = false
    ) {
        self.id = id
        self.date = date
        self.opponentName = opponentName
        self.surface = surface
        self.result = result
        self.score = score
        self.serveRating = serveRating
        self.returnRating = returnRating
        self.movementRating = movementRating
        self.mentalRating = mentalRating
        self.preMatchNotes = preMatchNotes
        self.postMatchNotes = postMatchNotes
        self.takeaway = takeaway
        self.isQuickLog = isQuickLog
    }

    /// True when the entry has at least one rating dimension set. The
    /// trend dashboard only considers rated entries when it computes
    /// averages.
    var hasRatings: Bool {
        serveRating != nil || returnRating != nil
            || movementRating != nil || mentalRating != nil
    }

    /// Date floored to day for streak math and calendar grouping.
    var dayKey: String {
        Self.dayKeyFormatter.string(from: date)
    }

    static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
