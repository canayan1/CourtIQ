import Foundation

/// Builds a COMPACT, privacy-safe player-context string from the user's saved
/// Tennis Profile + recent on-device history, used to PERSONALIZE the AI swing
/// and match analyses (so the coaching references the player's real level,
/// style, goals and recent scores instead of giving generic advice).
///
/// Everything here is the player's OWN self-reported data + their own saved
/// scores — no other users, no PII beyond what they entered. The output is kept
/// short (a few labeled lines, well under ~600 chars) so it's cheap to send and
/// the model treats it as light grounding rather than the main payload.
///
/// All accessors run on the main actor because they read the shared stores
/// (`TennisProfileStore`, `SwingAnalysisStore`, `MatchEntryManager`), which are
/// `@MainActor` singletons.
enum PlayerContext {

    /// Hard cap so a malformed profile / long history can never blow up the
    /// request body. We build well under this and then defensively truncate.
    private static let maxChars = 600

    // MARK: - Swing context

    /// Context for the SWING analysis: the player's profile + their recent
    /// scores for the SPECIFIC stroke being analyzed (e.g. "FH 72, 68 (last 3)").
    /// Returns `nil` when there's nothing useful to send (no profile + no
    /// scores) so the AI simply runs un-personalized.
    @MainActor
    static func forSwing(stroke: SwingStroke) -> String? {
        var lines: [String] = []
        if let profileLine = profileLine() { lines.append(profileLine) }
        if let scoresLine = recentSwingScoresLine(for: stroke) { lines.append(scoresLine) }
        return assemble(lines)
    }

    // MARK: - Match context

    /// Context appended to the MATCH analysis summary: the player's profile
    /// plus a short recent-match trend line. Returns `nil` when there's nothing
    /// useful to add.
    @MainActor
    static func forMatch() -> String? {
        var lines: [String] = []
        if let profileLine = profileLine() { lines.append(profileLine) }
        if let trendLine = recentMatchTrendLine() { lines.append(trendLine) }
        return assemble(lines)
    }

    // MARK: - Building blocks

    /// One labeled line summarizing the saved Tennis Profile, or `nil` if the
    /// profile hasn't been completed. English labels (the AI personalizes in
    /// the user's language regardless; this is just grounding).
    @MainActor
    private static func profileLine() -> String? {
        guard let profile = TennisProfileStore.shared.profile else { return nil }
        let result = profile.result
        let copy = TennisProfileCopy(lang: .english)

        let level = copy.levelTitle(result.level)            // e.g. "Intermediate"
        let style = copy.archetypeTitle(result.archetype)    // e.g. "Counterpuncher"

        var parts: [String] = ["PLAYER: level \(level), style \(style)."]

        let strengths = result.strengths
            .prefix(3)
            .map { copy.dimension($0) }
        if !strengths.isEmpty {
            parts.append("Strengths: \(strengths.joined(separator: ", ")).")
        }

        // "Working on" = the lowest dimensions + what they said they want most.
        var workingOn = result.growthAreas
            .prefix(2)
            .map { copy.dimension($0) }
        workingOn.append(copy.wantOption(profile.answers.want))
        if !workingOn.isEmpty {
            parts.append("Working on: \(workingOn.joined(separator: ", ")).")
        }

        return parts.joined(separator: " ")
    }

    /// "Recent <STROKE> scores: 72, 68 (last 3)" using the player's saved swing
    /// scores for that stroke, newest first. `nil` if there are no scored
    /// records for the stroke (or the stroke is a mixed session / footwork,
    /// where a per-stroke trend isn't meaningful).
    @MainActor
    private static func recentSwingScoresLine(for stroke: SwingStroke) -> String? {
        guard !stroke.isSession else { return nil }
        let label = strokeLabel(stroke)
        let scores = SwingAnalysisStore.shared.records
            .filter { $0.strokeRaw == stroke.rawValue }
            .compactMap { $0.score }
            .prefix(3)
        guard !scores.isEmpty else { return nil }
        let list = scores.map(String.init).joined(separator: ", ")
        return "Recent \(label) scores: \(list) (last \(scores.count))."
    }

    /// A short recent-match trend line: last few results (e.g. "W L W") plus a
    /// win rate and the recent self-rating averages, if logged. `nil` if the
    /// player hasn't logged any completed matches.
    @MainActor
    private static func recentMatchTrendLine() -> String? {
        let manager = MatchEntryManager.shared
        let record = manager.winRateSummary
        guard record.total > 0 else { return nil }

        var parts: [String] = []
        if let ratio = record.ratio {
            parts.append("record \(record.wins)W-\(record.losses)L (\(Int((ratio * 100).rounded()))% wins)")
        }

        // Recent self-rating averages (last ~5 matches) where logged.
        var ratings: [String] = []
        if let v = manager.averageRating(\.serveRating, inLast: 30)    { ratings.append("serve \(oneDecimal(v))/5") }
        if let v = manager.averageRating(\.returnRating, inLast: 30)   { ratings.append("return \(oneDecimal(v))/5") }
        if let v = manager.averageRating(\.movementRating, inLast: 30) { ratings.append("movement \(oneDecimal(v))/5") }
        if let v = manager.averageRating(\.mentalRating, inLast: 30)   { ratings.append("mental \(oneDecimal(v))/5") }
        if !ratings.isEmpty {
            parts.append("recent self-ratings " + ratings.joined(separator: ", "))
        }

        guard !parts.isEmpty else { return nil }
        return "RECENT MATCHES: " + parts.joined(separator: "; ") + "."
    }

    // MARK: - Helpers

    /// Short stroke label for the scores line (e.g. "FH", "BH", "serve").
    private static func strokeLabel(_ stroke: SwingStroke) -> String {
        switch stroke {
        case .forehand: return "FH"
        case .backhand: return "BH"
        case .serve:    return "serve"
        case .volley:   return "volley"
        case .footwork: return "footwork"
        case .session:  return "session"
        }
    }

    private static func oneDecimal(_ v: Double) -> String {
        String(format: "%.1f", v)
    }

    /// Joins the labeled lines, trims, returns `nil` when empty, and caps the
    /// total length defensively.
    private static func assemble(_ lines: [String]) -> String? {
        let joined = lines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !joined.isEmpty else { return nil }
        return joined.count <= maxChars ? joined : String(joined.prefix(maxChars))
    }
}
