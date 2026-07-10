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
        /// Rep count MEASURED on device (audio impacts + Vision person gate).
        /// The AI must never count for itself — video-LLM counting was our #1
        /// fabrication source. Omitted when the scan found nothing (muted
        /// clip, no clear strikes); the edge then forbids stating any count.
        let measuredCount: Int?
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
        /// Declared stroke contradicts what the on-device scan measured —
        /// refuse BEFORE upload. Coaching a stroke the model can't actually
        /// see is our field-tested fabrication case (it invents toss/racquet
        /// drop for a "serve" that never happens), so honesty wins over trying.
        case notAServe(strikes: Int)
        case looksOverhead
        var errorDescription: String? {
            switch self {
            case .couldNotPrepare: return "The video could not be read."
            case .tooLarge:        return "That clip is too large — try a shorter one."
            case .notAServe(let strikes):
                return "This clip doesn't look like serves — a serve meets the ball above your head, and none of the \(strikes) detected strikes do. Check the stroke you picked and try again."
            case .looksOverhead:
                return "These strikes all happen above your head — that's a serve or smash, not the stroke you picked. Check the stroke type and try again."
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
        // Deterministic rep count (audio impacts + person gate) BEFORE upload —
        // fully on-device, a few seconds. nil when nothing confident was found.
        let scan = await SwingImpactAnalyzer.scan(videoURL: videoURL)
        let measuredCount = (scan?.impacts.isEmpty == false) ? scan?.impacts.count : nil

        // Declared-stroke sanity gate: the measured count says NOTHING about
        // the stroke type, so cross-check the one signal pose gives us for
        // free — overhead vs. not — and refuse contradictions before any
        // upload (no cost, no fabricated report).
        if let scan, scan.impacts.count >= 2 {
            if stroke == .serve && scan.overheadImpacts == 0 {
                throw PrepError.notAServe(strikes: scan.impacts.count)
            }
            if (stroke == .forehand || stroke == .backhand)
                && scan.overheadImpacts == scan.impacts.count {
                throw PrepError.looksOverhead
            }
        }

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
            context: context?.nonEmpty,
            measuredCount: measuredCount
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
