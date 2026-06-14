import Foundation

/// Calls the `match-analysis` Supabase edge function. Mirrors the
/// networking pattern in `SwingAnalysisService`: attaches the caller's
/// Supabase JWT (apikey + Authorization Bearer), POSTs a small JSON body
/// (`{mode, summary}`), and returns the AI coaching text (or throws on an
/// `{error}` / HTTP failure).
///
/// Two modes:
/// - `"pre"`     — a short take on the user's pre-match plan.
/// - `"compound"`— a full post-match analysis blending plan + result +
///   ratings + notes.
///
/// The *client* builds the `summary` string from a `MatchEntry` (see
/// `Self.buildSummary`), so the function receives a clean, labeled,
/// multi-line description and doesn't need to know our model shape.
@MainActor
final class MatchAnalysisService {

    private let configuration: AppConfiguration
    private let urlSession: URLSession

    init(configuration: AppConfiguration = .shared, urlSession: URLSession = .shared) {
        self.configuration = configuration
        self.urlSession = urlSession
    }

    private var functionName: String {
        (Bundle.main.object(forInfoDictionaryKey: "COURTIQ_MATCH_ANALYSIS_FUNCTION") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmptyMA ?? "match-analysis"
    }

    enum Mode: String {
        case pre
        case compound
    }

    // MARK: - Request / response shapes

    private struct Request: Encodable {
        let mode: String
        let summary: String
    }

    private struct Response: Decodable {
        let report: String?
        let error: String?
    }

    // MARK: - Public API

    /// POSTs `{mode, summary}` to the `match-analysis` function and returns
    /// the `report` text. Throws `RemoteDataError` on failure.
    func analyze(
        mode: Mode,
        summary: String,
        session: SupabaseSession
    ) async throws -> String {
        guard let baseURL = configuration.supabaseURL else {
            throw RemoteDataError.missingConfiguration
        }

        let url = baseURL.appendingPathComponent("functions/v1/\(functionName)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        if let anonKey = configuration.supabaseAnonKey {
            request.setValue(anonKey, forHTTPHeaderField: "apikey")
        }
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = Request(mode: mode.rawValue, summary: summary)
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw RemoteDataError.invalidResponse
        }

        let decoded = try? JSONDecoder().decode(Response.self, from: data)

        switch http.statusCode {
        case 200..<300:
            if let report = decoded?.report?.nonEmptyMA { return report }
            if let serverError = decoded?.error?.nonEmptyMA { throw RemoteDataError.message(serverError) }
            throw RemoteDataError.invalidResponse
        case 401, 403:
            throw RemoteDataError.unauthorized
        default:
            if let serverError = decoded?.error?.nonEmptyMA { throw RemoteDataError.message(serverError) }
            throw RemoteDataError.message(
                HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            )
        }
    }

    // MARK: - Summary builder

    /// Build the clean labeled multi-line summary string the function
    /// reasons over. Includes only the fields relevant to `mode`:
    /// - `.pre`      → opponent, surface, plan.
    /// - `.compound` → everything: plan, result + score, ratings, notes,
    ///   takeaway.
    @MainActor
    static func buildSummary(for entry: MatchEntry, mode: Mode, language: AppLanguage) -> String {
        var lines: [String] = []
        let surface = entry.surface.rawValue
        let opponent = entry.opponentName.trimmingCharacters(in: .whitespacesAndNewlines)

        // Language hint so the function can answer in the user's language.
        lines.append("Language: \(language.rawValue)")
        lines.append("Surface: \(surface)")
        if !opponent.isEmpty { lines.append("Opponent: \(opponent)") }

        let plan = entry.preMatchNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !plan.isEmpty { lines.append("Plan: \(plan)") }

        if mode == .compound {
            if let result = entry.result {
                var resultLine = "Result: \(result.rawValue)"
                let score = entry.score.trimmingCharacters(in: .whitespacesAndNewlines)
                if !score.isEmpty { resultLine += " (\(score))" }
                lines.append(resultLine)
            }

            var ratings: [String] = []
            if let v = entry.serveRating    { ratings.append("serve \(v)/5") }
            if let v = entry.returnRating   { ratings.append("return \(v)/5") }
            if let v = entry.movementRating { ratings.append("movement \(v)/5") }
            if let v = entry.mentalRating   { ratings.append("mental \(v)/5") }
            if !ratings.isEmpty { lines.append("Self-ratings: " + ratings.joined(separator: ", ")) }

            let post = entry.postMatchNotes.trimmingCharacters(in: .whitespacesAndNewlines)
            if !post.isEmpty { lines.append("Post-match notes: \(post)") }

            let take = entry.takeaway.trimmingCharacters(in: .whitespacesAndNewlines)
            if !take.isEmpty { lines.append("Takeaway: \(take)") }
        }

        // Personalize: append the player's Tennis Profile + a brief recent-match
        // trend so the analysis references their real level/style/goals and
        // recent form instead of generic advice. Optional — absent if the
        // player hasn't completed a profile or logged any matches.
        if let playerContext = PlayerContext.forMatch() {
            lines.append(playerContext)
        }

        return lines.joined(separator: "\n")
    }
}

private extension String {
    var nonEmptyMA: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
