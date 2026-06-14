import Foundation
import AVFoundation

/// Calls the `swing-analysis` Supabase edge function. Compresses the chosen clip
/// to 720p, attaches the caller's Supabase JWT, POSTs the video (which the
/// function sends to Gemini for native video understanding), and returns the AI
/// coaching text (or throws on an `{error}` / HTTP failure).
/// The decoded result of a swing analysis: the coaching text plus an optional
/// 0–100 score (the edge function may return `null` for the score).
struct SwingAnalysisResult {
    let analysis: String
    let score: Int?
}

@MainActor
final class SwingAnalysisService {

    private let configuration: AppConfiguration
    private let urlSession: URLSession

    init(configuration: AppConfiguration = .shared, urlSession: URLSession = .shared) {
        self.configuration = configuration
        self.urlSession = urlSession
    }

    private var functionName: String {
        (Bundle.main.object(forInfoDictionaryKey: "COURTIQ_SWING_ANALYSIS_FUNCTION") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty ?? "swing-analysis"
    }

    /// Inline-data requests to Gemini cap around 20MB; keep the encoded video
    /// safely under that. Longer/larger clips should be shortened.
    private static let maxBase64Bytes = 19_000_000

    // MARK: - Request / response shapes

    private struct Request: Encodable {
        let stroke: String
        let handedness: String?
        let video: String       // base64 mp4 (no data: prefix)
        let mimeType: String
        /// Optional, compact, privacy-safe player context (profile + recent
        /// scores) so the AI personalizes its coaching. Omitted when nil.
        let context: String?
    }

    private struct Response: Decodable {
        let analysis: String?
        let score: Int?
        let stroke: String?
        let model: String?
        let error: String?
    }

    enum PrepError: LocalizedError {
        case couldNotPrepare
        case tooLarge
        var errorDescription: String? {
            switch self {
            case .couldNotPrepare: return "The video could not be read."
            case .tooLarge:        return "That clip is too large — try a shorter one."
            }
        }
    }

    // MARK: - Public API

    /// Compresses `videoURL` to 720p, calls the edge function with the given
    /// `stroke` (+ optional `handedness`) and `session` JWT, and returns the
    /// analysis text. Throws `RemoteDataError` / `PrepError` on failures.
    func analyze(
        videoURL: URL,
        stroke: SwingStroke,
        handedness: SwingHandedness?,
        context: String? = nil,
        session: SupabaseSession
    ) async throws -> SwingAnalysisResult {
        let videoData = try await Self.compressedVideoData(from: videoURL)
        let base64 = videoData.base64EncodedString()
        guard base64.count <= Self.maxBase64Bytes else { throw PrepError.tooLarge }

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
            video: base64,
            mimeType: "video/mp4",
            context: context?.nonEmpty
        )
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw RemoteDataError.invalidResponse
        }

        let decoded = try? JSONDecoder().decode(Response.self, from: data)

        switch http.statusCode {
        case 200..<300:
            if let analysis = decoded?.analysis?.nonEmpty {
                return SwingAnalysisResult(analysis: analysis, score: decoded?.score)
            }
            if let serverError = decoded?.error?.nonEmpty { throw RemoteDataError.message(serverError) }
            throw RemoteDataError.invalidResponse
        case 401, 403:
            throw RemoteDataError.unauthorized
        default:
            if let serverError = decoded?.error?.nonEmpty { throw RemoteDataError.message(serverError) }
            throw RemoteDataError.message(
                HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            )
        }
    }

    // MARK: - Compression

    /// Exports the clip to a 720p MP4 to keep the upload small. Falls back to the
    /// original bytes if an export session can't be created.
    private static func compressedVideoData(from url: URL) async throws -> Data {
        let asset = AVURLAsset(url: url)
        guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset1280x720) else {
            return try Data(contentsOf: url)
        }
        let outURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".mp4")
        export.outputURL = outURL
        export.outputFileType = .mp4
        export.shouldOptimizeForNetworkUse = true

        return try await withCheckedThrowingContinuation { continuation in
            export.exportAsynchronously {
                defer { try? FileManager.default.removeItem(at: outURL) }
                if export.status == .completed, let data = try? Data(contentsOf: outURL) {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: export.error ?? PrepError.couldNotPrepare)
                }
            }
        }
    }
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
