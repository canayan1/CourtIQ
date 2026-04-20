import Foundation

struct AppConfiguration {
    let appName = "CourtIQ"
    let privacyPolicyURL: URL?
    let termsOfUseURL: URL?
    let supportURL: URL?
    let supabaseURL: URL?
    let supabaseAnonKey: String?
    let revenueCatAPIKey: String?
    let monthlyProductID: String
    let yearlyProductID: String
    let premiumEntitlementID: String
    let deleteAccountFunctionName: String

    static let shared = AppConfiguration()

    private init(bundle: Bundle = .main) {
        privacyPolicyURL = Self.urlValue(for: "COURTIQ_PRIVACY_URL", bundle: bundle)
        termsOfUseURL = Self.urlValue(for: "COURTIQ_TERMS_URL", bundle: bundle)
        supportURL = Self.urlValue(for: "COURTIQ_SUPPORT_URL", bundle: bundle)
        supabaseURL = Self.urlValue(for: "COURTIQ_SUPABASE_URL", bundle: bundle)
        supabaseAnonKey = Self.stringValue(for: "COURTIQ_SUPABASE_ANON_KEY", bundle: bundle)?.nilIfBlank
        revenueCatAPIKey = Self.stringValue(for: "COURTIQ_REVENUECAT_API_KEY", bundle: bundle)?.nilIfBlank
        monthlyProductID = Self.stringValue(for: "COURTIQ_MONTHLY_PRODUCT_ID", bundle: bundle) ?? "com.courtiq.premium.monthly"
        yearlyProductID = Self.stringValue(for: "COURTIQ_YEARLY_PRODUCT_ID", bundle: bundle) ?? "com.courtiq.premium.yearly"
        premiumEntitlementID = Self.stringValue(for: "COURTIQ_PREMIUM_ENTITLEMENT_ID", bundle: bundle) ?? "premium_all_access"
        deleteAccountFunctionName = Self.stringValue(for: "COURTIQ_DELETE_ACCOUNT_FUNCTION", bundle: bundle) ?? "delete-account"
    }

    var hasRemoteSyncConfiguration: Bool {
        supabaseURL != nil && supabaseAnonKey != nil
    }

    var hasRevenueCatConfiguration: Bool {
        revenueCatAPIKey != nil
    }

    var hasLegalLinks: Bool {
        privacyPolicyURL != nil && termsOfUseURL != nil && supportURL != nil
    }

    private static func stringValue(for key: String, bundle: Bundle) -> String? {
        bundle.object(forInfoDictionaryKey: key) as? String
    }

    private static func urlValue(for key: String, bundle: Bundle) -> URL? {
        guard let value = stringValue(for: key, bundle: bundle)?.nilIfBlank else {
            return nil
        }
        return URL(string: value)
    }
}

enum RemoteSyncState: Equatable {
    case localOnly
    case unavailable
    case syncing
    case synced(Date)
    case failed(String)

    var title: String {
        switch self {
        case .localOnly:
            return "Local Preview"
        case .unavailable:
            return "Configuration Missing"
        case .syncing:
            return "Syncing"
        case .synced:
            return "Synced"
        case .failed:
            return "Sync Issue"
        }
    }

    var detail: String {
        switch self {
        case .localOnly:
            return "Guest preview is using local storage on this device."
        case .unavailable:
            return "Add Supabase configuration to enable Apple sign-in and cloud sync."
        case .syncing:
            return "Refreshing your profile, progress, and community data."
        case .synced(let date):
            return "Last synced \(RelativeDateTimeFormatter.syncFormatter.localizedString(for: date, relativeTo: Date()))."
        case .failed(let message):
            return message
        }
    }
}

struct SupabaseSession: Codable, Equatable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let userID: String
    let email: String?
    let fullName: String?

    var isExpired: Bool {
        expiresAt <= Date()
    }
}

struct SupabaseAuthUser: Codable, Equatable {
    let id: String
    let email: String?
    let fullName: String?
}

enum RemoteDataError: LocalizedError {
    case missingConfiguration
    case missingIdentityToken
    case invalidResponse
    case unauthorized
    case message(String)

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "Cloud sync is not configured yet."
        case .missingIdentityToken:
            return "Apple sign-in did not return a usable identity token."
        case .invalidResponse:
            return "The server returned an unexpected response."
        case .unauthorized:
            return "Your session expired. Please sign in again."
        case .message(let message):
            return message
        }
    }
}

enum CommunityAccessState {
    case readOnly
    case interactive

    var title: String {
        switch self {
        case .readOnly:
            return "Read-only"
        case .interactive:
            return "Post, like, and report"
        }
    }
}

final class SupabaseRESTClient {
    static let shared = SupabaseRESTClient()

    private let configuration: AppConfiguration
    private let session: URLSession

    private init(
        configuration: AppConfiguration = .shared,
        session: URLSession = .shared
    ) {
        self.configuration = configuration
        self.session = session
    }

    var isConfigured: Bool {
        configuration.hasRemoteSyncConfiguration
    }

    func signInWithApple(idToken: String) async throws -> SupabaseSession {
        let response: AuthResponse = try await authRequest(
            method: .post,
            path: "auth/v1/token",
            queryItems: [URLQueryItem(name: "grant_type", value: "id_token")],
            body: AppleTokenRequest(provider: "apple", idToken: idToken)
        )
        return response.sessionValue
    }

    func refresh(session currentSession: SupabaseSession) async throws -> SupabaseSession {
        let response: AuthResponse = try await authRequest(
            method: .post,
            path: "auth/v1/token",
            queryItems: [URLQueryItem(name: "grant_type", value: "refresh_token")],
            body: RefreshTokenRequest(refreshToken: currentSession.refreshToken)
        )
        return response.sessionValue
    }

    func fetchCurrentUser(session: SupabaseSession) async throws -> SupabaseAuthUser {
        let response: UserResponse = try await authRequest(
            method: .get,
            path: "auth/v1/user",
            session: session
        )
        return response.userValue
    }

    func signOut(session currentSession: SupabaseSession) async {
        do {
            _ = try await authRequest(
                method: .post,
                path: "auth/v1/logout",
                session: currentSession
            ) as EmptyResponse
        } catch {
            // Best-effort logout. Local session cleanup still happens in the app.
        }
    }

    func invokeDeleteAccount(session currentSession: SupabaseSession) async throws {
        _ = try await functionRequest(
            method: .post,
            functionName: configuration.deleteAccountFunctionName,
            session: currentSession
        ) as EmptyResponse
    }

    func selectRows<Response: Decodable>(
        from table: String,
        queryItems: [URLQueryItem] = [],
        session: SupabaseSession? = nil
    ) async throws -> [Response] {
        try await databaseRequest(
            method: .get,
            table: table,
            queryItems: [URLQueryItem(name: "select", value: "*")] + queryItems,
            session: session
        )
    }

    func upsertRows<Payload: Encodable, Response: Decodable>(
        _ payload: Payload,
        into table: String,
        onConflict: String? = nil,
        session: SupabaseSession
    ) async throws -> [Response] {
        var headers = ["Prefer": "resolution=merge-duplicates,return=representation"]
        if let onConflict {
            headers["on_conflict"] = onConflict
        }
        return try await databaseRequest(
            method: .post,
            table: table,
            queryItems: onConflict.map { [URLQueryItem(name: "on_conflict", value: $0)] } ?? [],
            body: payload,
            extraHeaders: headers,
            session: session
        )
    }

    func insertRow<Payload: Encodable, Response: Decodable>(
        _ payload: Payload,
        into table: String,
        session: SupabaseSession
    ) async throws -> Response {
        let response: [Response] = try await databaseRequest(
            method: .post,
            table: table,
            body: payload,
            extraHeaders: ["Prefer": "return=representation"],
            session: session
        )
        guard let first = response.first else {
            throw RemoteDataError.invalidResponse
        }
        return first
    }

    func updateRows<Payload: Encodable, Response: Decodable>(
        _ payload: Payload,
        in table: String,
        queryItems: [URLQueryItem],
        session: SupabaseSession
    ) async throws -> [Response] {
        try await databaseRequest(
            method: .patch,
            table: table,
            queryItems: queryItems,
            body: payload,
            extraHeaders: ["Prefer": "return=representation"],
            session: session
        )
    }

    func deleteRows(
        from table: String,
        queryItems: [URLQueryItem],
        session: SupabaseSession
    ) async throws {
        _ = try await databaseRequest(
            method: .delete,
            table: table,
            queryItems: queryItems,
            extraHeaders: ["Prefer": "return=minimal"],
            session: session
        ) as EmptyResponse
    }

    private func authRequest<Response: Decodable, Body: Encodable>(
        method: HTTPMethod,
        path: String,
        queryItems: [URLQueryItem] = [],
        body: Body? = nil,
        session: SupabaseSession? = nil
    ) async throws -> Response {
        let url = try endpointURL(path: path, queryItems: queryItems)
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        applyBaseHeaders(to: &request, session: session)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body {
            request.httpBody = try Self.encoder.encode(body)
        }

        return try await perform(request)
    }

    private func functionRequest<Response: Decodable>(
        method: HTTPMethod,
        functionName: String,
        session: SupabaseSession
    ) async throws -> Response {
        let url = try endpointURL(path: "functions/v1/\(functionName)")
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        applyBaseHeaders(to: &request, session: session)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await perform(request)
    }

    private func databaseRequest<Response: Decodable, Body: Encodable>(
        method: HTTPMethod,
        table: String,
        queryItems: [URLQueryItem] = [],
        body: Body? = nil,
        extraHeaders: [String: String] = [:],
        session: SupabaseSession? = nil
    ) async throws -> Response {
        let url = try endpointURL(path: "rest/v1/\(table)", queryItems: queryItems)
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        applyBaseHeaders(to: &request, session: session)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        for (name, value) in extraHeaders {
            if name == "on_conflict" {
                continue
            }
            request.setValue(value, forHTTPHeaderField: name)
        }

        if let body {
            request.httpBody = try Self.encoder.encode(body)
        }

        return try await perform(request)
    }

    private func endpointURL(path: String, queryItems: [URLQueryItem] = []) throws -> URL {
        guard let baseURL = configuration.supabaseURL else {
            throw RemoteDataError.missingConfiguration
        }

        let url = baseURL.appendingPathComponent(path)
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw RemoteDataError.invalidResponse
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let finalURL = components.url else {
            throw RemoteDataError.invalidResponse
        }
        return finalURL
    }

    private func applyBaseHeaders(to request: inout URLRequest, session: SupabaseSession?) {
        if let anonKey = configuration.supabaseAnonKey {
            request.setValue(anonKey, forHTTPHeaderField: "apikey")
        }

        if let session {
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        }
    }

    private func perform<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RemoteDataError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200..<300:
            if Response.self == EmptyResponse.self && data.isEmpty {
                return EmptyResponse() as! Response
            }
            if data.isEmpty {
                return EmptyResponse() as! Response
            }
            do {
                return try Self.decoder.decode(Response.self, from: data)
            } catch {
                throw RemoteDataError.message("Could not decode server response.")
            }
        case 401, 403:
            throw RemoteDataError.unauthorized
        default:
            if let apiError = try? Self.decoder.decode(SupabaseAPIError.self, from: data) {
                throw RemoteDataError.message(apiError.readableMessage)
            }
            throw RemoteDataError.message(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
        }
    }

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            if let date = ISO8601DateFormatter.full.date(from: value) {
                return date
            }

            if let date = ISO8601DateFormatter().date(from: value) {
                return date
            }

            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO8601 date string: \(value)")
        }
        return decoder
    }()

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(ISO8601DateFormatter.full.string(from: date))
        }
        return encoder
    }()
}

private enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case patch = "PATCH"
    case delete = "DELETE"
}

private struct AppleTokenRequest: Encodable {
    let provider: String
    let idToken: String
}

private struct RefreshTokenRequest: Encodable {
    let refreshToken: String
}

private struct AuthResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let expiresAt: TimeInterval?
    let user: UserResponse

    var sessionValue: SupabaseSession {
        let resolvedExpiry: Date
        if let expiresAt {
            resolvedExpiry = Date(timeIntervalSince1970: expiresAt)
        } else {
            resolvedExpiry = Date().addingTimeInterval(TimeInterval(expiresIn))
        }

        return SupabaseSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: resolvedExpiry,
            userID: user.id,
            email: user.email,
            fullName: user.userMetadata?["full_name"] ?? user.userMetadata?["name"]
        )
    }
}

private struct UserResponse: Decodable {
    let id: String
    let email: String?
    let userMetadata: [String: String]?

    var userValue: SupabaseAuthUser {
        SupabaseAuthUser(
            id: id,
            email: email,
            fullName: userMetadata?["full_name"] ?? userMetadata?["name"]
        )
    }
}

private struct SupabaseAPIError: Decodable {
    let message: String?
    let errorDescription: String?
    let error: String?

    var readableMessage: String {
        errorDescription ?? message ?? error ?? "The request could not be completed."
    }
}

private struct EmptyResponse: Decodable {
    init() {}
}

private extension RelativeDateTimeFormatter {
    static let syncFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()
}

private extension ISO8601DateFormatter {
    static let full: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension SupabaseRESTClient {
    func authRequest<Response: Decodable>(
        method: HTTPMethod,
        path: String,
        queryItems: [URLQueryItem] = [],
        session: SupabaseSession? = nil
    ) async throws -> Response {
        try await authRequest(
            method: method,
            path: path,
            queryItems: queryItems,
            body: Optional<EmptyBody>.none,
            session: session
        )
    }

    func databaseRequest<Response: Decodable>(
        method: HTTPMethod,
        table: String,
        queryItems: [URLQueryItem] = [],
        extraHeaders: [String: String] = [:],
        session: SupabaseSession? = nil
    ) async throws -> Response {
        try await databaseRequest(
            method: method,
            table: table,
            queryItems: queryItems,
            body: Optional<EmptyBody>.none,
            extraHeaders: extraHeaders,
            session: session
        )
    }
}

private struct EmptyBody: Encodable {}
