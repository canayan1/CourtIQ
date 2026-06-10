import Foundation

/// Calls the `swing-analysis` Supabase edge function. Extracts frames from the
/// chosen clip, attaches the caller's Supabase JWT, POSTs the frames, and
/// returns the AI coaching text (or throws on an `{error}` / HTTP failure).
///
/// Mirrors the AI Coach networking contract exactly: same `apikey` +
/// `Authorization: Bearer <accessToken>` headers and the same
/// `functions/v1/<name>` endpoint shape as `AppConfiguration`'s function
/// requests.
@MainActor
final class SwingAnalysisService {

    private let configuration: AppConfiguration
    private let urlSession: URLSession

    init(configuration: AppConfiguration = .shared, urlSession: URLSession = .shared) {
        self.configuration = configuration
        self.urlSession = urlSession
    }

    /// Function path component. Overridable via Info.plist for parity with the
    /// other configurable function names, defaulting to "swing-analysis".
    private var functionName: String {
        (Bundle.main.object(forInfoDictionaryKey: "COURTIQ_SWING_ANALYSIS_FUNCTION") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty ?? "swing-analysis"
    }

    // MARK: - Request / response shapes

    private struct Request: Encodable {
        let stroke: String
        let handedness: String?
        let frames: [String]
    }

    private struct Response: Decodable {
        let analysis: String?
        let stroke: String?
        let model: String?
        let error: String?
    }

    // MARK: - Public API

    /// Extracts frames from `videoURL`, calls the edge function with the given
    /// `stroke` (+ optional `handedness`) and `session` JWT, and returns the
    /// analysis text. Throws `RemoteDataError` on configuration / HTTP / server
    /// errors, or `SwingFrameExtractor.ExtractionError` if the clip is unusable.
    func analyze(
        videoURL: URL,
        stroke: SwingStroke,
        handedness: SwingHandedness?,
        session: SupabaseSession
    ) async throws -> String {
        let frames = try await SwingFrameExtractor.extractFrames(from: videoURL)

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

        let payload = Request(
            stroke: stroke.rawValue,
            handedness: handedness?.rawValue,
            frames: frames
        )
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw RemoteDataError.invalidResponse
        }

        // Try to decode the structured body for both success and error cases —
        // the function returns `{error}` with a non-2xx status in most paths.
        let decoded = try? JSONDecoder().decode(Response.self, from: data)

        switch http.statusCode {
        case 200..<300:
            if let analysis = decoded?.analysis?.nonEmpty {
                return analysis
            }
            if let serverError = decoded?.error?.nonEmpty {
                throw RemoteDataError.message(serverError)
            }
            throw RemoteDataError.invalidResponse
        case 401, 403:
            throw RemoteDataError.unauthorized
        default:
            if let serverError = decoded?.error?.nonEmpty {
                throw RemoteDataError.message(serverError)
            }
            throw RemoteDataError.message(
                HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            )
        }
    }
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
