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

/// Lifecycle of a match record.
/// - `.upcoming`: scheduled / coming up. Has a plan (preMatchNotes) but no
///   result, score, or ratings yet. Excluded from W/L stats.
/// - `.completed`: played. Has a required result + optional score/ratings.
///
/// Every pre-existing entry decodes as `.completed` (the decoder defaults
/// the key) so old data keeps counting toward stats exactly as before.
enum MatchStatus: String, Codable, Hashable {
    case upcoming
    case completed
}

/// A single user-authored match record, in one of two lifecycle states
/// (`status`):
/// - **Upcoming** (`.upcoming`): a planned match. Captures opponent,
///   surface, date and a tactical plan (`preMatchNotes`); no result, score
///   or ratings yet. Optionally carries an `aiPreComment` on the plan.
/// - **Completed** (`.completed`): a played match. Has a required
///   `result`, optional score + 1-5 self-ratings + post-match notes, and a
///   compound `aiReport`.
///
/// Both states share the same struct so they collate cleanly in the
/// calendar and history list. Only completed matches (with a non-nil
/// `result`) feed W/L stats, win rate, streak math, and rating averages.
///
/// `isQuickLog` is retained only to decode legacy "Quick Log" entries; the
/// app no longer produces them.
struct MatchEntry: Codable, Identifiable, Hashable {
    let id: String
    var date: Date
    var opponentName: String
    var surface: MatchSurface

    /// Whether this match is upcoming (planned) or completed (played).
    var status: MatchStatus

    /// W/L outcome. **Nil for upcoming matches**; required (non-nil) once a
    /// match is completed. Aggregates must skip nil so an unplayed match
    /// never counts toward win rate / streak / averages.
    var result: MatchResult?
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

    /// AI's take on the pre-match plan (mode "pre"). Nil until requested.
    var aiPreComment: String?

    /// Compound post-match AI analysis (mode "compound"). Nil until the
    /// match is completed and analysis succeeds. Read from local storage
    /// for viewing — no network needed to re-read.
    var aiReport: String?

    /// Played flow only: did the user have a plan before the match? Drives
    /// whether `preMatchNotes` was captured up front. Nil for entries that
    /// predate the pre/post split, and for upcoming matches (which always
    /// have a plan).
    var hadPlan: Bool?

    /// **Legacy decode-only.** Old "Quick Log" entries decode with this
    /// true; we no longer *produce* quick logs. Kept so historical data
    /// loads without loss. New entries always set this false.
    var isQuickLog: Bool

    /// Draft / pre-save flag. An entry the user started filling in but
    /// never explicitly tapped Save on is auto-persisted as a draft when
    /// the editor is dismissed (e.g. an accidental swipe-down). Drafts are
    /// fully editable and deletable later, but are excluded from every
    /// aggregate (streak, win rate, totals, trends) so an in-progress log
    /// never skews the user's real statistics. Tapping Save clears it.
    var isDraft: Bool

    init(
        id: String = UUID().uuidString,
        date: Date = Date(),
        opponentName: String = "",
        surface: MatchSurface = .hard,
        status: MatchStatus = .completed,
        result: MatchResult? = nil,
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
        aiPreComment: String? = nil,
        aiReport: String? = nil,
        hadPlan: Bool? = nil,
        isQuickLog: Bool = false,
        isDraft: Bool = false
    ) {
        self.id = id
        self.date = date
        self.opponentName = opponentName
        self.surface = surface
        self.status = status
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
        self.aiPreComment = aiPreComment
        self.aiReport = aiReport
        self.hadPlan = hadPlan
        self.isQuickLog = isQuickLog
        self.isDraft = isDraft
    }

    // Older entries persisted before v1.1.B decoded with no
    // `photoFileNames` key. Provide a defaulted decoder so they migrate
    // silently to an empty array rather than failing the whole load.
    enum CodingKeys: String, CodingKey {
        case id, date, opponentName, surface, status, result, score
        case serveRating, returnRating, movementRating, mentalRating
        case preMatchNotes, postMatchNotes, takeaway
        case preMatchAudioFile, postMatchAudioFile
        case photoFileNames, aiPreComment, aiReport, hadPlan
        case isQuickLog, isDraft
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        date = try c.decode(Date.self, forKey: .date)
        opponentName = try c.decode(String.self, forKey: .opponentName)
        surface = try c.decode(MatchSurface.self, forKey: .surface)
        // Old entries have no `status` key → they were all played matches,
        // so default to .completed (keeps them in W/L stats).
        status = try c.decodeIfPresent(MatchStatus.self, forKey: .status) ?? .completed
        // Old entries always had a non-nil result; new upcoming entries omit
        // it. decodeIfPresent covers both.
        result = try c.decodeIfPresent(MatchResult.self, forKey: .result)
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
        aiPreComment = try c.decodeIfPresent(String.self, forKey: .aiPreComment)
        aiReport = try c.decodeIfPresent(String.self, forKey: .aiReport)
        hadPlan = try c.decodeIfPresent(Bool.self, forKey: .hadPlan)
        isQuickLog = try c.decodeIfPresent(Bool.self, forKey: .isQuickLog) ?? false
        isDraft = try c.decodeIfPresent(Bool.self, forKey: .isDraft) ?? false
    }

    /// Convenience: a planned, not-yet-played match.
    var isUpcoming: Bool { status == .upcoming }

    /// Convenience: a played match (has, or should have, a result).
    var isCompleted: Bool { status == .completed }

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
