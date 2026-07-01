import Foundation

/// Calls the `doubles-analysis` Supabase edge function. Mirrors the networking
/// pattern in `MatchAnalysisService` / `SwingAnalysisService`: attaches the
/// caller's Supabase JWT (apikey + Authorization Bearer), POSTs a small JSON
/// body (`{summary}`), and returns the AI compatibility report + optional 0–100
/// score (or throws on an `{error}` / HTTP failure).
///
/// The *client* builds the `summary` string from the user's own Tennis Profile
/// (the "You" side, via `PlayerContext`-style formatting) plus the partner
/// mini-profile, so the function receives a clean, labeled description and
/// doesn't need to know our model shape.
@MainActor
final class DoublesService {

    private let configuration: AppConfiguration
    private let urlSession: URLSession

    init(configuration: AppConfiguration = .shared, urlSession: URLSession = .shared) {
        self.configuration = configuration
        self.urlSession = urlSession
    }

    private var functionName: String {
        (Bundle.main.object(forInfoDictionaryKey: "COURTIQ_DOUBLES_ANALYSIS_FUNCTION") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmptyDB ?? "doubles-analysis"
    }

    // MARK: - Request / response shapes

    private struct Request: Encodable {
        let summary: String
    }

    private struct Response: Decodable {
        let report: String?
        let score: Int?
        let model: String?
        let error: String?
    }

    // MARK: - Public API

    /// POSTs `{summary}` (built from the user's profile + the partner) to the
    /// `doubles-analysis` function and returns the report text + optional score.
    /// Throws `RemoteDataError` on failure. Copies `MatchAnalysisService`'s
    /// status handling exactly.
    func analyze(
        partner: DoublesPartner,
        language: AppLanguage,
        session: SupabaseSession
    ) async throws -> (report: String, score: Int?) {
        guard let baseURL = configuration.supabaseURL else {
            throw RemoteDataError.missingConfiguration
        }

        let (summary, computedScore) = Self.buildSummary(partner: partner, language: language)

        let url = baseURL.appendingPathComponent("functions/v1/\(functionName)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        if let anonKey = configuration.supabaseAnonKey {
            request.setValue(anonKey, forHTTPHeaderField: "apikey")
        }
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = Request(summary: summary)
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw RemoteDataError.invalidResponse
        }

        let decoded = try? JSONDecoder().decode(Response.self, from: data)

        switch http.statusCode {
        case 200..<300:
            if let report = decoded?.report?.nonEmptyDB {
                return (report, computedScore)
            }
            if let serverError = decoded?.error?.nonEmptyDB { throw RemoteDataError.message(serverError) }
            throw RemoteDataError.invalidResponse
        case 401, 403:
            throw RemoteDataError.unauthorized
        default:
            if let serverError = decoded?.error?.nonEmptyDB { throw RemoteDataError.message(serverError) }
            throw RemoteDataError.message(
                HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            )
        }
    }

    // MARK: - Summary builder

    /// Build the clean, labeled, multi-line summary string the function reasons
    /// over. The "You (Player A)" side reuses the player's saved Tennis Profile
    /// (level / style / strengths / working-on, via `TennisProfileCopy` with
    /// English labels — the function answers in the user's language regardless).
    /// The "Partner (Player B)" side is the mini-profile the user just filled in.
    @MainActor
    static func buildSummary(partner: DoublesPartner, language: AppLanguage) -> (summary: String, score: Int) {
        var lines: [String] = []
        let copy = TennisProfileCopy(lang: .english)

        // Language hint so the function can answer in the user's language.
        lines.append("Language: \(language.rawValue)")

        // You (Player A) — from the saved Tennis Profile, if completed.
        if let profile = TennisProfileStore.shared.profile {
            let result = profile.result
            var parts: [String] = []
            parts.append("level \(copy.levelTitle(result.level))")
            parts.append("style \(copy.archetypeTitle(result.archetype))")

            let strengths = result.strengths.prefix(3).map { copy.dimension($0) }
            if !strengths.isEmpty {
                parts.append("strengths \(strengths.joined(separator: ", "))")
            }
            var workingOn = result.growthAreas.prefix(2).map { copy.dimension($0) }
            workingOn.append(copy.wantOption(profile.answers.want))
            if !workingOn.isEmpty {
                parts.append("working on \(workingOn.joined(separator: ", "))")
            }
            lines.append("You (Player A): " + parts.joined(separator: ", ") + ".")
        } else {
            lines.append("You (Player A): no tennis profile on file.")
        }

        // Partner (Player B) — the mini-profile.
        var partnerParts: [String] = []
        let name = partner.name.trimmingCharacters(in: .whitespacesAndNewlines)
        partnerParts.append(name.isEmpty ? "partner" : name)
        if let level = partner.level {
            partnerParts.append("level \(copy.levelTitle(level))")
        }
        if let handedness = partner.handedness {
            partnerParts.append("\(handedness.rawValue)-handed")
        }
        if let style = partner.style {
            partnerParts.append("style \(copy.archetypeTitle(style))")
        }
        let strengths = partner.strengths.trimmingCharacters(in: .whitespacesAndNewlines)
        if !strengths.isEmpty { partnerParts.append("strengths \(strengths)") }
        let weaknesses = partner.weaknesses.trimmingCharacters(in: .whitespacesAndNewlines)
        if !weaknesses.isEmpty { partnerParts.append("weaknesses \(weaknesses)") }
        lines.append("Partner (Player B): " + partnerParts.joined(separator: ", ") + ".")

        // Deterministic compatibility score — the AI explains it, never invents it.
        let result = TennisProfileStore.shared.profile?.result
        let compat = DoublesCompatibility.evaluate(
            userLevel: result?.level,
            userArchetype: result?.archetype,
            partner: partner
        )
        lines.append("Computed compatibility score: \(compat.score)/100.")
        if !compat.factors.isEmpty {
            lines.append("Scoring factors: \(compat.factors.joined(separator: ", ")).")
        }

        return (lines.joined(separator: "\n"), compat.score)
    }
}

private extension String {
    var nonEmptyDB: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
