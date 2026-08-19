import Foundation
import AVFoundation

/// Talks to the two coach-review edge functions + reads the user's own rows
/// through PostgREST (RLS scopes them to the caller). Mirrors
/// `SwingAnalysisService`'s transport so auth/compression behave identically.
@MainActor
final class CoachReviewService {
    enum ServiceError: LocalizedError {
        case missingConfiguration
        case videoTooLarge
        case server(String)

        var errorDescription: String? {
            switch self {
            case .missingConfiguration: return "Coach review isn't available right now."
            case .videoTooLarge:        return "That clip is too long — keep it under ~30 seconds."
            case .server(let message):  return message
            }
        }
    }

    private let configuration: AppConfiguration
    /// Same ceiling as the edge function (~19 MB of video as base64).
    private static let maxBase64Bytes = 26 * 1024 * 1024

    init(configuration: AppConfiguration = .shared) {
        self.configuration = configuration
    }

    // MARK: Create

    struct CreatedOrder: Decodable {
        let orderId: String
        let slaDueAt: String
    }

    /// Uploads the clip and creates the order. Call ONLY after the consumable
    /// purchase succeeds — the transaction id is passed through for audit.
    func createOrder(
        videoURL: URL,
        stroke: SwingStroke,
        handedness: SwingHandedness?,
        note: String?,
        transactionID: String?,
        session: SupabaseSession
    ) async throws -> CreatedOrder {
        guard let baseURL = configuration.supabaseURL else { throw ServiceError.missingConfiguration }

        let data = try await Self.compressedVideoData(from: videoURL)
        let base64 = data.base64EncodedString()
        guard base64.count <= Self.maxBase64Bytes else { throw ServiceError.videoTooLarge }

        struct Payload: Encodable {
            let videoBase64: String
            let stroke: String
            let handedness: String?
            let note: String?
            let transactionId: String?
            let mimeType: String
        }

        let url = baseURL.appendingPathComponent("functions/v1/coach-review-order")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        if let anonKey = configuration.supabaseAnonKey {
            request.setValue(anonKey, forHTTPHeaderField: "apikey")
        }
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(Payload(
            videoBase64: base64,
            stroke: stroke.rawValue,
            handedness: handedness?.rawValue,
            note: note?.trimmingCharacters(in: .whitespacesAndNewlines),
            transactionId: transactionID,
            mimeType: "video/mp4"
        ))

        let (body, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ServiceError.server(Self.serverMessage(from: body))
        }
        return try JSONDecoder().decode(CreatedOrder.self, from: body)
    }

    // MARK: Read

    /// The caller's own orders (RLS-scoped), newest first.
    func fetchOrders(session: SupabaseSession) async throws -> [CoachReviewOrder] {
        try await get(
            path: "rest/v1/coach_review_orders",
            query: [URLQueryItem(name: "select", value: "id,status,stroke,handedness,note,created_at,sla_due_at,delivered_at"),
                    URLQueryItem(name: "order", value: "created_at.desc"),
                    URLQueryItem(name: "limit", value: "20")],
            session: session
        )
    }

    /// The deliverable for one of the caller's orders (nil until delivered).
    func fetchDeliverable(orderID: String, session: SupabaseSession) async throws -> CoachReviewDeliverable? {
        let rows: [CoachReviewDeliverable] = try await get(
            path: "rest/v1/coach_review_deliverables",
            query: [URLQueryItem(name: "select", value: "order_id,scorecard,one_thing,one_thing_at,one_thing_cue,micro_notes,drill_title,drill_body,voice_path"),
                    URLQueryItem(name: "order_id", value: "eq.\(orderID)"),
                    URLQueryItem(name: "limit", value: "1")],
            session: session
        )
        return rows.first
    }

    // MARK: - Internals

    private func get<T: Decodable>(
        path: String,
        query: [URLQueryItem],
        session: SupabaseSession
    ) async throws -> T {
        guard let baseURL = configuration.supabaseURL,
              var components = URLComponents(url: baseURL.appendingPathComponent(path),
                                             resolvingAgainstBaseURL: false)
        else { throw ServiceError.missingConfiguration }
        components.queryItems = query
        guard let url = components.url else { throw ServiceError.missingConfiguration }

        var request = URLRequest(url: url)
        if let anonKey = configuration.supabaseAnonKey {
            request.setValue(anonKey, forHTTPHeaderField: "apikey")
        }
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")

        let (body, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ServiceError.server(Self.serverMessage(from: body))
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let raw = try decoder.singleValueContainer().decode(String.self)
            if let date = ISO8601DateFormatter.supabaseFractional.date(from: raw) { return date }
            if let date = ISO8601DateFormatter.supabasePlain.date(from: raw) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                    debugDescription: "Bad date: \(raw)"))
        }
        return try decoder.decode(T.self, from: body)
    }

    private static func serverMessage(from data: Data) -> String {
        struct ErrorBody: Decodable { let error: String? ; let message: String? }
        if let body = try? JSONDecoder().decode(ErrorBody.self, from: data),
           let message = body.error ?? body.message, !message.isEmpty {
            return message
        }
        return "Something went wrong. Please try again."
    }

    /// Reuses the swing pipeline's export preset so a coach gets the same
    /// quality the AI path already handles well.
    private static func compressedVideoData(from url: URL) async throws -> Data {
        let asset = AVURLAsset(url: url)
        guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset960x540) else {
            return try Data(contentsOf: url)
        }
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("coach-\(UUID().uuidString).mp4")
        export.outputURL = output
        export.outputFileType = .mp4
        export.shouldOptimizeForNetworkUse = true
        await export.export()
        guard export.status == .completed else { return try Data(contentsOf: url) }
        defer { try? FileManager.default.removeItem(at: output) }
        return try Data(contentsOf: output)
    }
}

extension ISO8601DateFormatter {
    static let supabaseFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    static let supabasePlain: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
