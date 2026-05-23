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
    // when populated. Transcripts from voice notes flow into these same
    // fields so search, trends, and rendering treat dictated entries
    // identically to typed ones.
    var preMatchNotes: String
    var postMatchNotes: String
    var takeaway: String                // 0-200 chars, the "one thing" line

    // Optional voice-note file names (e.g. "pre-<uuid>.m4a") stored under
    // `MatchMediaStore.audioDirectory`. Nil means no audio recorded.
    // Stored as bare file names — never absolute paths — so the data is
    // portable across iCloud restores and Documents path changes.
    var preMatchAudioFile: String?
    var postMatchAudioFile: String?

    // Optional photo attachments — scorecards, gear, partner shots, etc.
    // Stored as bare file names (e.g. "<entryID>-<n>.jpg") under
    // `MatchMediaStore.photoDirectory(forEntry:)`. Capped at 4 per
    // entry by the UI; the model itself doesn't enforce a limit so
    // future bulk-import flows aren't artificially blocked.
    var photoFileNames: [String]

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
        preMatchAudioFile: String? = nil,
        postMatchAudioFile: String? = nil,
        photoFileNames: [String] = [],
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
        self.preMatchAudioFile = preMatchAudioFile
        self.postMatchAudioFile = postMatchAudioFile
        self.photoFileNames = photoFileNames
        self.isQuickLog = isQuickLog
    }

    // Older entries persisted before v1.1.B decoded with no
    // `photoFileNames` key. Provide a defaulted decoder so they migrate
    // silently to an empty array rather than failing the whole load.
    enum CodingKeys: String, CodingKey {
        case id, date, opponentName, surface, result, score
        case serveRating, returnRating, movementRating, mentalRating
        case preMatchNotes, postMatchNotes, takeaway
        case preMatchAudioFile, postMatchAudioFile
        case photoFileNames, isQuickLog
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        date = try c.decode(Date.self, forKey: .date)
        opponentName = try c.decode(String.self, forKey: .opponentName)
        surface = try c.decode(MatchSurface.self, forKey: .surface)
        result = try c.decode(MatchResult.self, forKey: .result)
        score = try c.decode(String.self, forKey: .score)
        serveRating = try c.decodeIfPresent(Int.self, forKey: .serveRating)
        returnRating = try c.decodeIfPresent(Int.self, forKey: .returnRating)
        movementRating = try c.decodeIfPresent(Int.self, forKey: .movementRating)
        mentalRating = try c.decodeIfPresent(Int.self, forKey: .mentalRating)
        preMatchNotes = try c.decode(String.self, forKey: .preMatchNotes)
        postMatchNotes = try c.decode(String.self, forKey: .postMatchNotes)
        takeaway = try c.decode(String.self, forKey: .takeaway)
        preMatchAudioFile = try c.decodeIfPresent(String.self, forKey: .preMatchAudioFile)
        postMatchAudioFile = try c.decodeIfPresent(String.self, forKey: .postMatchAudioFile)
        photoFileNames = try c.decodeIfPresent([String].self, forKey: .photoFileNames) ?? []
        isQuickLog = try c.decode(Bool.self, forKey: .isQuickLog)
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
