import Foundation

/// Talks to the LIVE `doubles_partnerships` table + its RPCs over PostgREST.
/// Self-contained networking, mirroring `DoublesService`: builds its own
/// `URLRequest` from `configuration.supabaseURL`, sets `apikey` = anon key and
/// `Authorization: Bearer <accessToken>`, POSTs/GETs JSON, decodes, and throws
/// `RemoteDataError.message(...)` (surfacing the PostgREST `message`) on failure.
///
/// The backend is already deployed — this only calls it.
@MainActor
final class DoublesInviteService {

    private let configuration: AppConfiguration
    private let urlSession: URLSession

    init(configuration: AppConfiguration = .shared, urlSession: URLSession = .shared) {
        self.configuration = configuration
        self.urlSession = urlSession
    }

    /// Public so the views can build the "OTHER side" relative to me.
    static func authUserId(from session: SupabaseSession) -> String? {
        if let uid = session.userID.nonEmptyTrimmed { return uid }
        return DoublesInviteJWT.subject(from: session.accessToken)
    }

    // MARK: - Universal link

    /// `https://canayan-ios-apps.vercel.app/d/<CODE>` — the share target.
    static func universalLink(for code: String) -> URL {
        URL(string: "https://canayan-ios-apps.vercel.app/d/\(code)")
            ?? URL(string: "https://canayan-ios-apps.vercel.app")!
    }

    // MARK: - Code generation

    /// 6 uppercase chars from an unambiguous alphabet (no O/0/I/1/L).
    static func generateCode() -> String {
        let alphabet = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789")
        return String((0..<6).map { _ in alphabet.randomElement()! })
    }

    // MARK: - Create

    /// INSERT a pending partnership for the current user as inviter, returning
    /// the inserted row (`Prefer: return=representation`).
    func createInvite(
        myName: String,
        myProfile: DoublesProfile,
        session: SupabaseSession
    ) async throws -> DoublesPartnership {
        guard let uid = Self.authUserId(from: session) else {
            throw RemoteDataError.unauthorized
        }

        struct InsertBody: Encodable {
            let code: String
            let inviter_user_id: String
            let inviter_name: String
            let inviter_profile: DoublesProfile
            let status: String
        }

        let body = InsertBody(
            code: Self.generateCode(),
            inviter_user_id: uid,
            inviter_name: myName,
            inviter_profile: myProfile,
            status: "pending"
        )

        let data = try await perform(
            path: "rest/v1/doubles_partnerships",
            method: "POST",
            body: Self.encoder.encode(body),
            session: session,
            extraHeaders: ["Prefer": "return=representation"]
        )

        let rows = try Self.decoder.decode([DoublesPartnership].self, from: data)
        guard let first = rows.first else { throw RemoteDataError.invalidResponse }
        return first
    }

    // MARK: - Peek

    /// `peek_doubles_invite(invite_code)` → returns the inviter name + status so
    /// the invitee can see who invited them before accepting.
    func peekInvite(
        code: String,
        session: SupabaseSession
    ) async throws -> (inviterName: String?, status: String, alreadyMember: Bool) {
        struct Args: Encodable { let invite_code: String }
        struct Row: Decodable {
            let inviter_name: String?
            let status: String?
            let already_member: Bool?
        }

        let data = try await perform(
            path: "rest/v1/rpc/peek_doubles_invite",
            method: "POST",
            body: Self.encoder.encode(Args(invite_code: code)),
            session: session
        )

        let rows = try Self.decoder.decode([Row].self, from: data)
        guard let row = rows.first else {
            throw RemoteDataError.message("We couldn't find that invite code.")
        }
        return (row.inviter_name, row.status ?? "pending", row.already_member ?? false)
    }

    // MARK: - Accept

    /// `accept_doubles_invite(invite_code, p_invitee_name, p_invitee_profile)`
    /// → returns the partnership uuid. The function raises exceptions which
    /// PostgREST surfaces as a non-2xx body with `message`; those are turned
    /// into `RemoteDataError.message(...)`.
    func acceptInvite(
        code: String,
        myName: String,
        myProfile: DoublesProfile,
        session: SupabaseSession
    ) async throws -> UUID {
        struct Args: Encodable {
            let invite_code: String
            let p_invitee_name: String
            let p_invitee_profile: DoublesProfile
        }

        let data = try await perform(
            path: "rest/v1/rpc/accept_doubles_invite",
            method: "POST",
            body: Self.encoder.encode(
                Args(invite_code: code, p_invitee_name: myName, p_invitee_profile: myProfile)
            ),
            session: session
        )

        // A scalar RPC returning uuid comes back as a bare quoted JSON string,
        // e.g. "\"<uuid>\"". Handle that, plus a few robust fallbacks.
        if let id = Self.decodeScalarUUID(from: data) { return id }
        throw RemoteDataError.invalidResponse
    }

    // MARK: - Fetch

    /// GET all partnerships visible to the caller (RLS scopes to participant),
    /// newest-first.
    func fetchPartnerships(session: SupabaseSession) async throws -> [DoublesPartnership] {
        let data = try await perform(
            path: "rest/v1/doubles_partnerships",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "order", value: "created_at.desc")
            ],
            session: session
        )
        return try Self.decoder.decode([DoublesPartnership].self, from: data)
    }

    // MARK: - Scalar decode helper

    private static func decodeScalarUUID(from data: Data) -> UUID? {
        // 1) Bare quoted string: "uuid"
        if let s = try? JSONDecoder().decode(String.self, from: data),
           let id = UUID(uuidString: s) {
            return id
        }
        // 2) Array of strings: ["uuid"]
        if let arr = try? JSONDecoder().decode([String].self, from: data),
           let first = arr.first, let id = UUID(uuidString: first) {
            return id
        }
        // 3) Raw text (strip quotes/whitespace) — last resort.
        if let raw = String(data: data, encoding: .utf8) {
            let trimmed = raw.trimmingCharacters(in: CharacterSet(charactersIn: "\"\n\r \t[]"))
            if let id = UUID(uuidString: trimmed) { return id }
        }
        return nil
    }

    // MARK: - Networking core

    private func perform(
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        body: Data? = nil,
        session: SupabaseSession,
        extraHeaders: [String: String] = [:]
    ) async throws -> Data {
        guard let baseURL = configuration.supabaseURL else {
            throw RemoteDataError.missingConfiguration
        }

        let url = baseURL.appendingPathComponent(path)
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw RemoteDataError.invalidResponse
        }
        if !queryItems.isEmpty { components.queryItems = queryItems }
        guard let finalURL = components.url else { throw RemoteDataError.invalidResponse }

        var request = URLRequest(url: finalURL)
        request.httpMethod = method
        if let anonKey = configuration.supabaseAnonKey {
            request.setValue(anonKey, forHTTPHeaderField: "apikey")
        }
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (name, value) in extraHeaders {
            request.setValue(value, forHTTPHeaderField: name)
        }
        request.httpBody = body

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw RemoteDataError.invalidResponse
        }

        switch http.statusCode {
        case 200..<300:
            return data
        case 401, 403:
            // PostgREST/PLpgSQL exceptions also commonly arrive as 4xx with a
            // message body — prefer the message if present.
            if let message = Self.errorMessage(from: data) {
                throw RemoteDataError.message(message)
            }
            throw RemoteDataError.unauthorized
        default:
            if let message = Self.errorMessage(from: data) {
                throw RemoteDataError.message(message)
            }
            throw RemoteDataError.message(
                HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            )
        }
    }

    /// PostgREST error body: `{"message": "...", "details":..., "hint":...}`.
    private static func errorMessage(from data: Data) -> String? {
        struct APIError: Decodable {
            let message: String?
            let hint: String?
            let details: String?
        }
        guard let err = try? JSONDecoder().decode(APIError.self, from: data) else { return nil }
        return err.message?.nonEmptyTrimmed
            ?? err.details?.nonEmptyTrimmed
            ?? err.hint?.nonEmptyTrimmed
    }

    // MARK: - Coders

    /// Explicit, no global key strategy — the models carry their own snake_case
    /// CodingKeys. ISO8601 dates with/without fractional seconds.
    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            let withFraction = ISO8601DateFormatter()
            withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = withFraction.date(from: value) { return date }
            if let date = ISO8601DateFormatter().date(from: value) { return date }
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Invalid ISO8601 date: \(value)"
            )
        }
        return decoder
    }()

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

/// Minimal JWT payload reader: extracts the `sub` claim (the Supabase auth uid)
/// from a session access token when `SupabaseSession.userID` is unavailable.
enum DoublesInviteJWT {
    static func subject(from jwt: String) -> String? {
        let segments = jwt.split(separator: ".")
        guard segments.count >= 2 else { return nil }
        guard let payloadData = base64URLDecode(String(segments[1])) else { return nil }
        guard let object = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] else {
            return nil
        }
        if let sub = object["sub"] as? String, !sub.isEmpty { return sub }
        return nil
    }

    /// base64url → Data, restoring `+`/`/` and padding the length to a multiple
    /// of 4 with `=`.
    static func base64URLDecode(_ input: String) -> Data? {
        var s = input
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = s.count % 4
        if remainder > 0 {
            s.append(String(repeating: "=", count: 4 - remainder))
        }
        return Data(base64Encoded: s)
    }
}

private extension String {
    var nonEmptyTrimmed: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
