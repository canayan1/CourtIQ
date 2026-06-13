import Foundation

/// Rolling, auto-compacted long-term memory of the user's match history.
///
/// The AI Coach only ever receives the most recent handful of matches
/// *verbatim* (with full pre/post notes) — shipping the entire corpus on
/// every turn would be wasteful and eventually blow the context window.
/// Everything older than that recent window is folded into a single
/// running text summary (`summary`) by the `compact_matches` Edge Function
/// mode, so the Coach can still reason over long-term patterns ("your
/// mental rating dips on clay", "you keep losing close third sets") without
/// the token cost of the raw history.
///
/// Storage is local-only (UserDefaults + JSON), matching the
/// MatchEntryManager / AIChatClient pattern. The summary is NOT persisted
/// server-side — it travels in the per-turn context payload — so there's a
/// single source of truth and no merge conflict with the separately-stored
/// imported ChatGPT context.
@MainActor
final class MatchMemoryStore: ObservableObject {

    static let shared = MatchMemoryStore()

    // MARK: - Tuning

    /// How many of the newest matches are shipped verbatim (with notes)
    /// on every turn. Everything older is candidate for compaction.
    static let recentWindowSize = 6

    /// Minimum number of not-yet-compacted older matches before we bother
    /// firing a (rare) compaction call. Keeps compactions batched.
    static let compactionThreshold = 4

    /// Floor between compactions so opening the Coach repeatedly in a
    /// short window can't trigger back-to-back compaction calls.
    static let minCompactionInterval: TimeInterval = 60 * 60   // 1 hour

    /// Per-match note budget when building the compaction corpus, so a
    /// single very long voice-note transcript can't dominate the call.
    private static let perNoteCharBudget = 600

    // MARK: - Published state

    /// The running long-term summary. Empty until the first compaction.
    @Published private(set) var summary: String = ""

    /// Timestamp of the most recent successful compaction.
    @Published private(set) var lastCompactionAt: Date?

    // MARK: - Private state

    /// IDs of matches already folded into `summary`. Lets us compact only
    /// the *new* older matches each time instead of re-summarising the
    /// whole corpus, and survives match edits/deletes gracefully (a
    /// deleted match simply stops appearing; its summary contribution
    /// lingers harmlessly).
    private(set) var compactedMatchIDs: Set<String> = []

    private let userDefaults: UserDefaults
    private let summaryKey = "CourtIQ.MatchMemory.summary.v1"
    private let idsKey = "CourtIQ.MatchMemory.compactedIDs.v1"
    private let lastAtKey = "CourtIQ.MatchMemory.lastCompactionAt.v1"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        loadFromDisk()
    }

    // MARK: - Queries

    /// Non-empty summary suitable for embedding in the context payload.
    var memoryForContext: String? {
        let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Older matches (beyond the recent verbatim window) that have not yet
    /// been folded into the summary. `committed` MUST be the non-draft
    /// entries sorted newest-first.
    func pendingOlderMatches(committed: [MatchEntry]) -> [MatchEntry] {
        // Only completed (played) matches feed the Coach's long-term memory;
        // upcoming/planned entries carry no result to reason over.
        let played = committed.filter { $0.status == .completed && $0.result != nil }
        guard played.count > Self.recentWindowSize else { return [] }
        let older = played[Self.recentWindowSize...]
        return older.filter { !compactedMatchIDs.contains($0.id) }
    }

    /// Whether a compaction call is warranted right now. Throttled by
    /// count + time so it stays a rare, cheap background operation.
    func shouldCompact(committed: [MatchEntry]) -> Bool {
        guard pendingOlderMatches(committed: committed).count >= Self.compactionThreshold else {
            return false
        }
        if let last = lastCompactionAt,
           Date().timeIntervalSince(last) < Self.minCompactionInterval {
            return false
        }
        return true
    }

    // MARK: - Corpus rendering

    /// Render a batch of matches into the compact, bounded text the
    /// compaction Edge Function folds into the summary. One block per
    /// match, oldest-relevant context first.
    func renderCorpus(_ matches: [MatchEntry]) -> String {
        matches.map(Self.renderMatch).joined(separator: "\n\n")
    }

    private static func renderMatch(_ e: MatchEntry) -> String {
        var lines: [String] = []
        let day = MatchEntry.dayKeyFormatter.string(from: e.date)
        // Upcoming matches have no result yet; render the status instead so
        // the summary never claims an unplayed match was won/lost.
        let outcome = e.result?.rawValue ?? "upcoming"
        var header = "\(day) — \(outcome) on \(e.surface.rawValue)"
        if !e.score.trimmingCharacters(in: .whitespaces).isEmpty {
            header += " (\(e.score))"
        }
        let opp = e.opponentName.trimmingCharacters(in: .whitespaces)
        if !opp.isEmpty { header += " vs \(opp)" }
        lines.append(header)

        var ratings: [String] = []
        if let v = e.serveRating    { ratings.append("serve \(v)/5") }
        if let v = e.returnRating   { ratings.append("return \(v)/5") }
        if let v = e.movementRating { ratings.append("movement \(v)/5") }
        if let v = e.mentalRating   { ratings.append("mental \(v)/5") }
        if !ratings.isEmpty { lines.append("Ratings: " + ratings.joined(separator: ", ")) }

        if let pre = clip(e.preMatchNotes) { lines.append("Pre: \(pre)") }
        if let post = clip(e.postMatchNotes) { lines.append("Post: \(post)") }
        if let take = clip(e.takeaway) { lines.append("Takeaway: \(take)") }

        return lines.joined(separator: "\n")
    }

    private static func clip(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.count <= perNoteCharBudget { return trimmed }
        return String(trimmed.prefix(perNoteCharBudget)) + "…"
    }

    // MARK: - Mutation

    /// Persist the merged summary returned by the Edge Function and mark
    /// the folded matches as compacted so they aren't re-sent next time.
    func recordCompaction(mergedSummary: String, foldedIDs: [String]) {
        summary = mergedSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        compactedMatchIDs.formUnion(foldedIDs)
        lastCompactionAt = Date()
        persistToDisk()
    }

    /// Wipe all long-term memory (used when the user clears AI data).
    func reset() {
        summary = ""
        compactedMatchIDs = []
        lastCompactionAt = nil
        persistToDisk()
    }

    // MARK: - Persistence

    private func loadFromDisk() {
        summary = userDefaults.string(forKey: summaryKey) ?? ""
        if let data = userDefaults.data(forKey: idsKey),
           let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) {
            compactedMatchIDs = decoded
        }
        let ts = userDefaults.double(forKey: lastAtKey)
        lastCompactionAt = ts > 0 ? Date(timeIntervalSince1970: ts) : nil
    }

    private func persistToDisk() {
        userDefaults.set(summary, forKey: summaryKey)
        if let data = try? JSONEncoder().encode(compactedMatchIDs) {
            userDefaults.set(data, forKey: idsKey)
        }
        if let last = lastCompactionAt {
            userDefaults.set(last.timeIntervalSince1970, forKey: lastAtKey)
        } else {
            userDefaults.removeObject(forKey: lastAtKey)
        }
    }
}
