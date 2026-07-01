import Foundation
#if canImport(RevenueCat)
import RevenueCat
#endif

struct AppConfiguration {
    let appName = "DropVolley"
    let privacyPolicyURL: URL?
    let termsOfUseURL: URL?
    let supportURL: URL?
    let supabaseURL: URL?
    let supabaseAnonKey: String?
    let revenueCatAPIKey: String?
    let weeklyProductID: String
    let annualProductID: String
    let premiumEntitlementID: String
    let deleteAccountFunctionName: String
    let aiChatFunctionName: String

    static let shared = AppConfiguration()

    private init(bundle: Bundle = .main) {
        privacyPolicyURL = Self.urlValue(for: "COURTIQ_PRIVACY_URL", bundle: bundle)
        termsOfUseURL = Self.urlValue(for: "COURTIQ_TERMS_URL", bundle: bundle)
        supportURL = Self.urlValue(for: "COURTIQ_SUPPORT_URL", bundle: bundle)
        supabaseURL = Self.urlValue(for: "COURTIQ_SUPABASE_URL", bundle: bundle)
        supabaseAnonKey = Self.stringValue(for: "COURTIQ_SUPABASE_ANON_KEY", bundle: bundle)?.nilIfBlank
        revenueCatAPIKey = Self.stringValue(for: "COURTIQ_REVENUECAT_API_KEY", bundle: bundle)?.nilIfBlank
        weeklyProductID = Self.stringValue(for: "COURTIQ_WEEKLY_PRODUCT_ID", bundle: bundle) ?? "com.courtiq.premium.weekly"
        annualProductID = Self.stringValue(for: "COURTIQ_ANNUAL_PRODUCT_ID", bundle: bundle) ?? "com.courtiq.premium.annual"
        premiumEntitlementID = Self.stringValue(for: "COURTIQ_PREMIUM_ENTITLEMENT_ID", bundle: bundle) ?? "premium_all_access"
        deleteAccountFunctionName = Self.stringValue(for: "COURTIQ_DELETE_ACCOUNT_FUNCTION", bundle: bundle) ?? "delete-account"
        aiChatFunctionName = Self.stringValue(for: "COURTIQ_AI_CHAT_FUNCTION", bundle: bundle) ?? "ai-chat"
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

/// Thin wrapper around the RevenueCat SDK.
///
/// RevenueCat runs in **observer mode** (`purchasesAreCompletedBy: .myApp`):
/// the app keeps its own raw-StoreKit-2 purchase flow (`SubscriptionManager`)
/// and RevenueCat merely *observes* the resulting transactions. We do NOT use
/// it to drive the paywall or the in-app entitlement — `Transaction
/// .currentEntitlements` remains the source of truth for the UI. RevenueCat
/// exists for ONE reason: so the backend can verify a caller is actually a
/// paying user. The AI Coach / swing / doubles / match Edge Functions look the
/// caller up by their Supabase uid (`logIn` aliases the RevenueCat customer to
/// that uid), which closes the "anyone with the public anon key can call the
/// paid functions and burn the LLM budget" hole — without server-side
/// entitlement the client paywall is bypassable via direct API calls.
///
/// Every entry point is a no-op when `COURTIQ_REVENUECAT_API_KEY` is absent
/// (dev / preview), so the app behaves exactly as before until the key ships.
enum RevenueCatManager {
    /// Configure the SDK once, at launch. Observer mode + StoreKit 2.
    static func configure() {
        #if canImport(RevenueCat)
        guard let key = AppConfiguration.shared.revenueCatAPIKey else { return }
        Purchases.logLevel = .warn
        Purchases.configure(
            with: Configuration.Builder(withAPIKey: key)
                .with(purchasesAreCompletedBy: .myApp, storeKitVersion: .storeKit2)
                .build()
        )
        #endif
    }

    /// Alias the RevenueCat customer to the Supabase uid so the Edge Functions
    /// can verify entitlement by the same id they read from the caller's JWT.
    /// Safe to call repeatedly; called on every session establishment/restore.
    static func identify(_ supabaseUserID: String) {
        #if canImport(RevenueCat)
        guard AppConfiguration.shared.revenueCatAPIKey != nil,
              Purchases.isConfigured,
              !supabaseUserID.isEmpty else { return }
        Task { _ = try? await Purchases.shared.logIn(supabaseUserID) }
        #endif
    }

    /// Push the device's StoreKit transactions to RevenueCat so the backend
    /// reflects a fresh purchase/restore promptly (belt-and-suspenders on top
    /// of observer mode's automatic transaction observation).
    static func syncPurchases() {
        #if canImport(RevenueCat)
        guard AppConfiguration.shared.revenueCatAPIKey != nil, Purchases.isConfigured else { return }
        Task { _ = try? await Purchases.shared.syncPurchases() }
        #endif
    }
}

/// One-time "taste" of the premium AI for non-premium users — lets a player
/// experience the wow once (their first swing analysis) before the paywall,
/// the highest-converting freemium pattern. Bounded cost (one paid Gemini
/// video call). When the RevenueCat server gate is enforced, a matching
/// server-side free-allowance is added; until then this client flag gates it.
enum FreeTaste {
    private static let swingKey = "CourtIQ.freeTaste.swingUsed"
    static var swingUsed: Bool {
        get { UserDefaults.standard.bool(forKey: swingKey) }
        set { UserDefaults.standard.set(newValue, forKey: swingKey) }
    }
}

/// Single source of truth for premium feature access (per CLAUDE.md: premium
/// gating lives in one `PremiumGate` utility). Shipping model: all CONTENT is
/// free; only the money-burning AI is premium — the **AI Coach** (Anthropic)
/// and **AI swing analysis** (paid Gemini video key). Real access = the
/// StoreKit entitlement (auto-granted in DEBUG); RevenueCat mirrors it
/// server-side for the Edge gate. Consolidates the previously-scattered
/// `entitlementState.isPremium` / dev-allowlist / kill-switch checks.
enum PremiumGate {
    /// Ops kill-switch to reopen the AI Coach to everyone.
    static let aiCoachOpenToAll = false

    /// All non-AI content (quizzes, tips, training, mobility, match logging).
    static let contentUnlocked = true

    /// Raw StoreKit entitlement. (DEBUG auto-grants it — see refreshEntitlements.)
    @MainActor static func isPremium(_ session: UserSessionManager) -> Bool {
        session.subscriptionManager.entitlementState.isPremium
    }

    /// AI Coach: premium, the kill-switch, or a dev-allowlisted account.
    @MainActor static func canUseAICoach(_ session: UserSessionManager) -> Bool {
        aiCoachOpenToAll || isPremium(session) || isDevAllowlisted(session.profileStore.profile?.email)
    }

    /// AI swing analysis: premium/dev, or the one free "taste" (FreeTaste).
    @MainActor static func canUseSwingAnalysis(_ session: UserSessionManager) -> Bool {
        isPremium(session) || isDevAllowlisted(session.profileStore.profile?.email) || !FreeTaste.swingUsed
    }

    /// Developer-only access for TestFlight dogfooding. DEBUG only; Release false.
    static func isDevAllowlisted(_ email: String?) -> Bool {
        #if DEBUG
        guard let raw = email?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else { return false }
        return ["canayan93@gmail.com"].contains(raw)
        #else
        return false
        #endif
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

    /// Mint an anonymous Supabase session — used by the AI Coach when
    /// the user hasn't connected an Apple ID yet. Server returns a
    /// real JWT we can use against `ai-chat` so RLS still scopes to
    /// `auth.uid()`. Anonymous sign-ins must be enabled in the
    /// Supabase project Auth settings (Sign In/Up → Allow anonymous
    /// sign-ins).
    func signInAnonymously() async throws -> SupabaseSession {
        struct EmptyBody: Encodable {}
        // The /auth/v1/signup endpoint with no email/password creates
        // an anonymous user when the provider is enabled. Newer
        // GoTrue versions accept an explicit `data.is_anonymous` flag
        // but the bare-body call also works.
        struct AnonRequest: Encodable {
            let data: [String: Bool]
            init() { self.data = ["is_anonymous": true] }
        }
        let response: AuthResponse = try await authRequest(
            method: .post,
            path: "auth/v1/signup",
            queryItems: [],
            body: AnonRequest()
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

    /// Posts a single AI Coach turn to the `ai-chat` Edge Function and
    /// returns the assistant reply + the user's remaining daily quota.
    /// Wraps the same auth headers + endpoint shape as
    /// `invokeDeleteAccount`; only differs in that it actually carries
    /// a JSON request body and decodes a JSON response.
    func invokeAIChat(
        request payload: AIChatRequestPayload,
        session currentSession: SupabaseSession
    ) async throws -> AIChatResponsePayload {
        try await functionRequest(
            method: .post,
            functionName: configuration.aiChatFunctionName,
            body: payload,
            session: currentSession
        )
    }

    /// Fold a batch of older matches into the rolling long-term summary
    /// via the `compact_matches` mode of the same Edge Function. Hits the
    /// same endpoint as `invokeAIChat` but with a distinct request body —
    /// the function branches on the `mode` field. Not counted against the
    /// daily message cap server-side.
    func invokeMatchMemoryCompaction(
        request payload: AIMatchMemoryRequestPayload,
        session currentSession: SupabaseSession
    ) async throws -> AIMatchMemoryResponsePayload {
        try await functionRequest(
            method: .post,
            functionName: configuration.aiChatFunctionName,
            body: payload,
            session: currentSession
        )
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

    /// Body-carrying variant — Edge Functions that need structured input
    /// (e.g. ai-chat takes the user's message + tennis context). Keeps
    /// the same auth + endpoint shape as the no-body version.
    private func functionRequest<Body: Encodable, Response: Decodable>(
        method: HTTPMethod,
        functionName: String,
        body: Body,
        session: SupabaseSession
    ) async throws -> Response {
        let url = try endpointURL(path: "functions/v1/\(functionName)")
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        applyBaseHeaders(to: &request, session: session)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try Self.encoder.encode(body)
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
            if data.isEmpty {
                // An empty 2xx body is only valid when the caller expects
                // no content. If a concrete Decodable was requested but the
                // server returned nothing, fail loudly instead of
                // force-casting an EmptyResponse (which would crash).
                if let empty = EmptyResponse() as? Response {
                    return empty
                }
                throw RemoteDataError.invalidResponse
            }
            do {
                return try Self.decoder.decode(Response.self, from: data)
            } catch {
                #if DEBUG
                // Surface the exact decode failure on dev builds so we can
                // pinpoint which field/type the server returned. Release
                // builds keep the generic message.
                let body = String(data: data.prefix(900), encoding: .utf8) ?? "<non-utf8>"
                throw RemoteDataError.message("Decode failed [\(Response.self)]: \(error)\n---\n\(body)")
                #else
                throw RemoteDataError.message("Could not decode server response.")
                #endif
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

/// A single JSON value decoded leniently. Supabase `user_metadata` mixes
/// types (e.g. `email_verified` is a Bool, `full_name` a String), so we
/// can't decode it straight into `[String: String]` — that throws and
/// fails the whole auth response ("Could not decode server response",
/// which broke Sign in with Apple while anonymous sign-in, whose metadata
/// is empty, still worked).
private enum JSONScalar: Decodable {
    case string(String)
    case other

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) {
            self = .string(s)
        } else {
            self = .other   // bool / number / null / object / array — ignored
        }
    }

    var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }
}

private struct UserResponse: Decodable {
    let id: String
    let email: String?
    let userMetadata: [String: String]?

    enum CodingKeys: String, CodingKey { case id, email, userMetadata }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        email = try c.decodeIfPresent(String.self, forKey: .email)
        // Keep only the string-valued metadata entries; ignore bools/etc.
        let raw = (try? c.decodeIfPresent([String: JSONScalar].self, forKey: .userMetadata)) ?? nil
        userMetadata = raw?.compactMapValues { $0.stringValue }
    }

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
