import Foundation
import Combine
import AuthenticationServices
import StoreKit
#if canImport(UIKit)
import UIKit
#endif

enum EntitlementState: String, Codable {
    case freePreview
    case premiumAllAccess

    var title: String {
        switch self {
        case .freePreview: return "Free Preview"
        case .premiumAllAccess: return "All Access"
        }
    }

    var description: String {
        switch self {
        case .freePreview:
            return "Daily IQ, the foundation plan, and preview mobility flows stay unlocked."
        case .premiumAllAccess:
            return "Premium training tracks, the full mobility library, archived insights, and community posting are unlocked."
        }
    }

    var isPremium: Bool {
        self == .premiumAllAccess
    }
}

enum BillingIntegrationMode: String {
    case storeKitDirect
    case productConfigurationMissing

    var title: String {
        switch self {
        case .storeKitDirect: return "StoreKit"
        case .productConfigurationMissing: return "Products Missing"
        }
    }
}

enum SignInProvider: String, Codable {
    case apple
    case guest
}

struct SessionIdentity: Identifiable, Codable, Equatable {
    let id: String
    var displayName: String
    var email: String?
    var provider: SignInProvider
}

struct RemoteUserProfile: Identifiable, Codable, Equatable {
    let id: String
    var displayName: String
    var email: String?
    var signInProvider: SignInProvider
    var currentFocus: String
    var topMistakePatterns: [String]
    var joinedAt: Date
    var updatedAt: Date
}

struct SubscriptionOffer: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    let priceDisplay: String
    let isFeatured: Bool
}

enum SubscriptionError: LocalizedError {
    case storeProductsUnavailable
    case purchaseCancelled
    case purchasePending
    case verificationFailed
    case unknown

    var errorDescription: String? {
        switch self {
        case .storeProductsUnavailable:
            return "Subscriptions are not available right now."
        case .purchaseCancelled:
            return "The purchase was cancelled."
        case .purchasePending:
            return "The purchase is still pending."
        case .verificationFailed:
            return "The App Store transaction could not be verified."
        case .unknown:
            return "The purchase could not be completed."
        }
    }
}

@MainActor
final class AuthManager: ObservableObject {
    @Published private(set) var identity: SessionIdentity?
    @Published private(set) var remoteSession: SupabaseSession?

    private let defaults = UserDefaults.standard
    private let client = SupabaseRESTClient.shared
    private let identityStorageKey = "CourtIQ.Auth.Identity"
    private let remoteSessionStorageKey = "CourtIQ.Auth.SupabaseSession"

    init() {
        load()

        Task {
            await restoreRemoteSessionIfPossible()
        }
    }

    var isSignedInWithApple: Bool {
        identity?.provider == .apple && remoteSession != nil
    }

    func signInAsGuest() {
        identity = SessionIdentity(
            id: "guest-\(UUID().uuidString.lowercased())",
            displayName: "Guest Player",
            email: nil,
            provider: .guest
        )
        remoteSession = nil
        save()
    }

    /// Mint an anonymous Supabase session on demand. Used by AI Coach
    /// (and any future feature that needs `auth.uid()` server-side)
    /// when the user hasn't connected Apple Sign-In yet. Cached for
    /// the lifetime of the install — same anonymous user gets the
    /// same row scoping on every subsequent call.
    @discardableResult
    func ensureAnonymousSession() async throws -> SupabaseSession {
        if let remoteSession { return remoteSession }
        guard AppConfiguration.shared.hasRemoteSyncConfiguration else {
            throw RemoteDataError.missingConfiguration
        }
        let session = try await client.signInAnonymously()
        remoteSession = session
        save()
        return session
    }

    func signInWithApple(
        credential: ASAuthorizationAppleIDCredential,
        preserving existing: SessionIdentity?
    ) async throws {
        guard AppConfiguration.shared.hasRemoteSyncConfiguration else {
            throw RemoteDataError.missingConfiguration
        }

        guard let identityTokenData = credential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8),
              !identityToken.isEmpty else {
            throw RemoteDataError.missingIdentityToken
        }

        let session = try await client.signInWithApple(idToken: identityToken)
        remoteSession = session

        let formatter = PersonNameComponentsFormatter()
        let providedName = formatter.string(from: credential.fullName ?? PersonNameComponents()).trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = [
            providedName.nilIfBlank,
            session.fullName?.nilIfBlank,
            existing?.displayName.nilIfBlank,
            "CourtIQ Player"
        ]
        .compactMap { $0 }
        .first ?? "CourtIQ Player"

        identity = SessionIdentity(
            id: session.userID,
            displayName: resolvedName,
            email: credential.email ?? session.email ?? existing?.email,
            provider: .apple
        )
        save()
    }

    func signOut() async {
        if let remoteSession {
            await client.signOut(session: remoteSession)
        }

        identity = nil
        remoteSession = nil
        defaults.removeObject(forKey: identityStorageKey)
        defaults.removeObject(forKey: remoteSessionStorageKey)
    }

    func deleteAccount() async throws {
        guard let remoteSession else {
            throw RemoteDataError.message("There is no signed-in account to delete.")
        }

        try await client.invokeDeleteAccount(session: remoteSession)
        identity = nil
        self.remoteSession = nil
        defaults.removeObject(forKey: identityStorageKey)
        defaults.removeObject(forKey: remoteSessionStorageKey)
    }

    private func restoreRemoteSessionIfPossible() async {
        guard let remoteSession, AppConfiguration.shared.hasRemoteSyncConfiguration else { return }

        do {
            let refreshedSession = try await client.refresh(session: remoteSession)
            self.remoteSession = refreshedSession

            if identity?.provider == .apple {
                let user = try await client.fetchCurrentUser(session: refreshedSession)
                identity = SessionIdentity(
                    id: user.id,
                    displayName: identity?.displayName ?? user.fullName ?? "CourtIQ Player",
                    email: user.email ?? identity?.email,
                    provider: .apple
                )
            }

            save()
        } catch {
            if identity?.provider == .apple {
                identity = nil
            }
            self.remoteSession = nil
            defaults.removeObject(forKey: remoteSessionStorageKey)
            save()
        }
    }

    private func load() {
        if let data = defaults.data(forKey: identityStorageKey) {
            identity = try? JSONDecoder().decode(SessionIdentity.self, from: data)
        }

        if let data = defaults.data(forKey: remoteSessionStorageKey) {
            remoteSession = try? JSONDecoder().decode(SupabaseSession.self, from: data)
        }
    }

    private func save() {
        if let identity, let data = try? JSONEncoder().encode(identity) {
            defaults.set(data, forKey: identityStorageKey)
        } else {
            defaults.removeObject(forKey: identityStorageKey)
        }

        if let remoteSession, let data = try? JSONEncoder().encode(remoteSession) {
            defaults.set(data, forKey: remoteSessionStorageKey)
        } else {
            defaults.removeObject(forKey: remoteSessionStorageKey)
        }
    }
}

@MainActor
final class SubscriptionManager: ObservableObject {
    @Published private(set) var entitlementState: EntitlementState
    @Published private(set) var offers: [SubscriptionOffer]
    @Published private(set) var integrationMode: BillingIntegrationMode

    let premiumBenefits = [
        "Unlimited daily quizzes",
        "Full tip archive — every insight ever published",
        "All 8-week training programs",
        "All mobility and recovery flows",
        "Ongoing fitness program updates as they ship",
        "Early access to every new feature",
        "Full quiz history and performance tracking",
        "Cloud sync across signed-in devices"
    ]

    private let configuration: AppConfiguration
    private let defaults = UserDefaults.standard
    private let entitlementKey = "CourtIQ.Subscription.EntitlementState"
    private var productsByID: [String: Product] = [:]
    private var updatesTask: Task<Void, Never>?

    init(configuration: AppConfiguration = .shared) {
        self.configuration = configuration
        self.entitlementState = Self.loadEntitlement(from: defaults)
        // NOTE: Placeholder offers — `priceDisplay` is intentionally a dash
        // so users never see hardcoded USD prices if StoreKit fails to load
        // (e.g. during App Review without products in "Ready to Submit").
        // Real values come from `loadOfferings()` reading StoreKit's
        // `product.displayPrice`, which respects the user's storefront.
        self.offers = [
            SubscriptionOffer(
                id: configuration.monthlyProductID,
                title: "Monthly All Access",
                detail: "Billed monthly. Cancel anytime.",
                priceDisplay: "—",
                isFeatured: false
            ),
            SubscriptionOffer(
                id: configuration.yearlyProductID,
                title: "Annual All Access",
                detail: "Best value vs monthly.",
                priceDisplay: "—",
                isFeatured: true
            )
        ]
        self.integrationMode = .productConfigurationMissing

        startListener()

        Task {
            await loadOfferings()
            await refreshEntitlements()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    /// During the public launch window CourtIQ ships with every Premium
    /// feature unlocked for everyone — no subscription required. The
    /// paywall stays in the codebase (transformed into a "Support
    /// CourtIQ" tip jar) so that:
    ///   • StoreKit + Apple Small Business Program plumbing stays warm
    ///   • Anyone who taps it can still contribute
    ///   • Re-introducing paid gating later is a single-flag flip,
    ///     and users who paid during the launch window retain
    ///     entitlement via `entitlementState.isPremium`.
    var isPremiumUnlocked: Bool {
        LaunchOffer.allFeaturesFree || entitlementState.isPremium
    }

    func loadOfferings() async {
        do {
            let products = try await Product.products(for: [configuration.monthlyProductID, configuration.yearlyProductID])
            productsByID = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
            integrationMode = productsByID.isEmpty ? .productConfigurationMissing : .storeKitDirect

            offers = offers.map { offer in
                guard let product = productsByID[offer.id] else { return offer }
                let suffix = offer.id == configuration.yearlyProductID ? " / year" : " / month"
                return SubscriptionOffer(
                    id: offer.id,
                    title: offer.title,
                    detail: offer.detail,
                    priceDisplay: product.displayPrice + suffix,
                    isFeatured: offer.isFeatured
                )
            }
        } catch {
            integrationMode = .productConfigurationMissing
        }
    }

    func refreshEntitlements() async {
        var hasPremium = false

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.productID == configuration.monthlyProductID || transaction.productID == configuration.yearlyProductID else {
                continue
            }

            let isActive = transaction.revocationDate == nil &&
                (transaction.expirationDate == nil || transaction.expirationDate ?? .distantPast > Date())
            if isActive {
                hasPremium = true
            }
        }

        entitlementState = hasPremium ? .premiumAllAccess : .freePreview
        saveEntitlement()
    }

    func purchase(_ offer: SubscriptionOffer) async throws {
        guard let product = productsByID[offer.id] else {
            throw SubscriptionError.storeProductsUnavailable
        }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else {
                throw SubscriptionError.verificationFailed
            }
            await transaction.finish()
            await refreshEntitlements()
        case .pending:
            throw SubscriptionError.purchasePending
        case .userCancelled:
            throw SubscriptionError.purchaseCancelled
        @unknown default:
            throw SubscriptionError.unknown
        }
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            UserSessionManager.shared.registerSyncError("Purchases could not be restored right now.")
        }
    }

    func resetLocalEntitlements() {
        entitlementState = .freePreview
        saveEntitlement()
    }

    func startListener() {
        guard updatesTask == nil else { return }

        updatesTask = Task.detached(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                await transaction.finish()
                await self?.refreshEntitlements()
            }
        }
    }

    private static func loadEntitlement(from defaults: UserDefaults) -> EntitlementState {
        guard let raw = defaults.string(forKey: "CourtIQ.Subscription.EntitlementState"),
              let state = EntitlementState(rawValue: raw) else {
            return .freePreview
        }
        return state
    }

    private func saveEntitlement() {
        defaults.set(entitlementState.rawValue, forKey: entitlementKey)
    }
}

@MainActor
final class ProfileStore: ObservableObject {
    @Published private(set) var profile: RemoteUserProfile?

    private let defaults = UserDefaults.standard
    private let storageKey = "CourtIQ.Profile.RemoteUserProfile"
    private let client = SupabaseRESTClient.shared

    init() {
        load()
    }

    func bootstrap(from identity: SessionIdentity, preserving currentFocus: String?, topMistakePatterns: [String]) {
        if var existing = profile {
            existing.displayName = identity.displayName
            existing.email = identity.email
            existing.signInProvider = identity.provider
            existing.currentFocus = currentFocus ?? existing.currentFocus
            existing.topMistakePatterns = topMistakePatterns
            existing.updatedAt = Date()
            profile = existing
        } else {
            profile = RemoteUserProfile(
                id: identity.id,
                displayName: identity.displayName,
                email: identity.email,
                signInProvider: identity.provider,
                currentFocus: currentFocus ?? "Daily IQ",
                topMistakePatterns: topMistakePatterns,
                joinedAt: Date(),
                updatedAt: Date()
            )
        }
        save()

        Task {
            await pushProfileIfPossible()
        }
    }

    func syncAfterAuthentication(
        uploadLocalPreview: Bool,
        identity: SessionIdentity
    ) async throws {
        guard let session = UserSessionManager.shared.remoteSession else { return }

        if uploadLocalPreview, let profile {
            let payload = RemoteUserProfileRecord(profile: profile, userID: session.userID)
            _ = try await client.upsertRows([payload], into: "profiles", onConflict: "id", session: session) as [RemoteUserProfileRecord]
        }

        let remoteProfiles: [RemoteUserProfileRecord] = try await client.selectRows(
            from: "profiles",
            queryItems: [
                URLQueryItem(name: "id", value: "eq.\(session.userID)")
            ],
            session: session
        )

        if let remote = remoteProfiles.first {
            profile = remote.appModel
        } else {
            let payload = RemoteUserProfileRecord(
                id: session.userID,
                displayName: identity.displayName,
                email: identity.email,
                signInProvider: .apple,
                currentFocus: profile?.currentFocus ?? "Daily IQ",
                topMistakePatterns: profile?.topMistakePatterns ?? ["Second serve pressure", "Being predictable", "Return court position"],
                createdAt: Date(),
                updatedAt: Date()
            )
            let created: [RemoteUserProfileRecord] = try await client.upsertRows([payload], into: "profiles", onConflict: "id", session: session)
            profile = created.first?.appModel ?? payload.appModel
        }

        save()
    }

    func updateCurrentFocus(_ focus: String) {
        guard var profile else { return }
        profile.currentFocus = focus
        profile.updatedAt = Date()
        self.profile = profile
        save()

        Task {
            await pushProfileIfPossible()
        }
    }

    func updateTopMistakePatterns(_ patterns: [String]) {
        guard var profile else { return }
        profile.topMistakePatterns = patterns
        profile.updatedAt = Date()
        self.profile = profile
        save()

        Task {
            await pushProfileIfPossible()
        }
    }

    func deleteLocal() {
        profile = nil
        defaults.removeObject(forKey: storageKey)
    }

    func resetLocalData(preserving identity: SessionIdentity?) {
        profile = nil
        defaults.removeObject(forKey: storageKey)

        if let identity {
            bootstrap(
                from: identity,
                preserving: "Daily IQ",
                topMistakePatterns: ["Second serve pressure", "Being predictable", "Return court position"]
            )
        }
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey) else { return }
        profile = try? JSONDecoder().decode(RemoteUserProfile.self, from: data)
    }

    private func save() {
        guard let profile, let data = try? JSONEncoder().encode(profile) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private func pushProfileIfPossible() async {
        guard let session = UserSessionManager.shared.remoteSession,
              let profile,
              profile.signInProvider == .apple else {
            return
        }

        do {
            let payload = RemoteUserProfileRecord(profile: profile, userID: session.userID)
            _ = try await client.upsertRows([payload], into: "profiles", onConflict: "id", session: session) as [RemoteUserProfileRecord]
        } catch {
            await MainActor.run {
                UserSessionManager.shared.registerSyncError("Profile changes could not sync right now.")
            }
        }
    }
}

@MainActor
final class UserSessionManager: ObservableObject {
    static let shared = UserSessionManager()

    let authManager: AuthManager
    let subscriptionManager: SubscriptionManager
    let profileStore: ProfileStore
    let configuration: AppConfiguration

    @Published private(set) var hasCompletedOnboarding: Bool
    @Published var authErrorMessage: String?
    @Published private(set) var syncState: RemoteSyncState

    private let defaults = UserDefaults.standard
    private let onboardingKey = "CourtIQ.App.OnboardingCompleted"
    private var cancellables: Set<AnyCancellable> = []

    private init(
        configuration: AppConfiguration = .shared,
        authManager: AuthManager? = nil,
        subscriptionManager: SubscriptionManager? = nil,
        profileStore: ProfileStore? = nil
    ) {
        self.configuration = configuration
        self.authManager = authManager ?? AuthManager()
        self.subscriptionManager = subscriptionManager ?? SubscriptionManager(configuration: configuration)
        self.profileStore = profileStore ?? ProfileStore()
        self.hasCompletedOnboarding = defaults.bool(forKey: onboardingKey)
        self.syncState = configuration.hasRemoteSyncConfiguration ? .syncing : .unavailable

        bindChildObjects()

        Task {
            await bootstrapSession()
        }
    }

    var currentUserID: String {
        authManager.identity?.id ?? "anonymous-preview"
    }

    var isAuthenticated: Bool {
        authManager.identity != nil
    }

    var remoteSession: SupabaseSession? {
        authManager.remoteSession
    }

    /// Forwarded to `AuthManager.ensureAnonymousSession()` — see there
    /// for semantics. Used by AI Coach to mint an on-demand JWT for
    /// guest users so the chat works before Apple Sign-In is set up.
    @discardableResult
    func ensureAnonymousSession() async throws -> SupabaseSession {
        try await authManager.ensureAnonymousSession()
    }

    var isSignedInWithApple: Bool {
        authManager.isSignedInWithApple
    }

    var isGuest: Bool {
        authManager.identity?.provider == .guest
    }

    var displayName: String {
        profileStore.profile?.displayName ?? authManager.identity?.displayName ?? "Player"
    }

    var premiumStatus: EntitlementState {
        subscriptionManager.entitlementState
    }

    var currentImprovementFocus: String {
        profileStore.profile?.currentFocus ?? Quiz.dailyQuiz(for: Date()).focusLabel
    }

    var topMistakePatterns: [String] {
        profileStore.profile?.topMistakePatterns ?? ["Second serve pressure", "Being predictable", "Return court position"]
    }

    var isPremiumUnlocked: Bool {
        subscriptionManager.isPremiumUnlocked
    }

    var canWriteCommunityComment: Bool {
        isPremiumUnlocked && isSignedInWithApple
    }

    var communityAccessState: CommunityAccessState {
        canWriteCommunityComment ? .interactive : .readOnly
    }

    var integrationSummary: String {
        if isSignedInWithApple {
            return "\(subscriptionManager.integrationMode.title) billing with \(syncState.title.lowercased()) profile sync."
        }

        if isGuest {
            return "Guest preview uses on-device progress until you sign in with Apple."
        }

        return "Sign in with Apple enables cloud sync, community posting, and purchase restore."
    }

    func signInAsGuest() {
        authManager.signInAsGuest()
        if let identity = authManager.identity {
            profileStore.bootstrap(
                from: identity,
                preserving: profileStore.profile?.currentFocus ?? currentImprovementFocus,
                topMistakePatterns: profileStore.profile?.topMistakePatterns ?? topMistakePatterns
            )
        }
        syncState = .localOnly
        completeOnboarding()
    }

    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                authErrorMessage = "Sign in with Apple returned an unexpected credential."
                return
            }

            let previousIdentity = authManager.identity

            Task {
                do {
                    syncState = .syncing
                    try await authManager.signInWithApple(credential: credential, preserving: previousIdentity)

                    if let identity = authManager.identity {
                        profileStore.bootstrap(
                            from: identity,
                            preserving: profileStore.profile?.currentFocus ?? currentImprovementFocus,
                            topMistakePatterns: profileStore.profile?.topMistakePatterns ?? topMistakePatterns
                        )
                    }

                    completeOnboarding()
                    try await refreshRemoteState(uploadLocalPreview: previousIdentity?.provider == .guest)
                } catch {
                    authErrorMessage = error.localizedDescription
                    syncState = .failed(error.localizedDescription)
                }
            }

        case .failure(let error):
            // User-initiated cancellation isn't an error — it's a deliberate
            // action. Suppress the error alert in that case; surface only
            // real failures (network, identity provider failure, etc.).
            let nsError = error as NSError
            let isCanceled =
                (nsError.domain == ASAuthorizationError.errorDomain &&
                 nsError.code == ASAuthorizationError.canceled.rawValue) ||
                nsError.code == NSUserCancelledError
            if !isCanceled {
                authErrorMessage = error.localizedDescription
            }
        }
    }

    func signOut() {
        Task {
            await authManager.signOut()
            profileStore.deleteLocal()
            DailyQuizManager.shared.resetLocalData()
            TrainingProgressManager.shared.resetLocalData()
            DiscussionStore.shared.resetLocalData()
            subscriptionManager.resetLocalEntitlements()
            hasCompletedOnboarding = false
            syncState = configuration.hasRemoteSyncConfiguration ? .syncing : .unavailable
            defaults.set(false, forKey: onboardingKey)
        }
    }

    func deleteAccount() async {
        do {
            try await authManager.deleteAccount()
            profileStore.deleteLocal()
            DailyQuizManager.shared.resetLocalData()
            TrainingProgressManager.shared.resetLocalData()
            DiscussionStore.shared.resetLocalData()
            subscriptionManager.resetLocalEntitlements()
            hasCompletedOnboarding = false
            syncState = configuration.hasRemoteSyncConfiguration ? .syncing : .unavailable
            defaults.set(false, forKey: onboardingKey)
        } catch {
            authErrorMessage = error.localizedDescription
        }
    }

    func resetLocalData() async {
        let existingIdentity = authManager.identity

        DailyQuizManager.shared.resetLocalData()
        TrainingProgressManager.shared.resetLocalData()
        DiscussionStore.shared.resetLocalData()
        profileStore.resetLocalData(preserving: existingIdentity)

        if isSignedInWithApple {
            do {
                try await refreshRemoteState(uploadLocalPreview: false)
            } catch {
                authErrorMessage = error.localizedDescription
            }
        } else if isGuest {
            syncState = .localOnly
        }
    }

    func purchase(offer: SubscriptionOffer) async throws {
        try await subscriptionManager.purchase(offer)
    }

    func restorePurchases() async {
        await subscriptionManager.restorePurchases()
    }

    func updateCurrentFocus(_ focus: String) {
        profileStore.updateCurrentFocus(focus)
    }

    func updateTopMistakePatterns(_ patterns: [String]) {
        guard !patterns.isEmpty else { return }
        profileStore.updateTopMistakePatterns(patterns)
    }

    func openManageSubscriptions() {
        #if canImport(UIKit)
        guard let url = URL(string: "https://apps.apple.com/account/subscriptions") else { return }
        UIApplication.shared.open(url)
        #endif
    }

    func registerSyncError(_ message: String) {
        syncState = .failed(message)
    }

    private func bootstrapSession() async {
        await subscriptionManager.loadOfferings()
        await subscriptionManager.refreshEntitlements()

        if isSignedInWithApple {
            do {
                try await refreshRemoteState(uploadLocalPreview: false)
                // NOTE: We intentionally do NOT call completeOnboarding() here.
                // bootstrapSession runs on every launch; restoring a Keychain
                // identity (the Apple Sign-in token) used to silently mark
                // onboarding complete and skip the entire flow on reinstalls.
                // Onboarding completion is now driven solely by explicit user
                // action in OnboardingView (applyAndSignInApple / applyAndSignInGuest).
            } catch {
                authErrorMessage = error.localizedDescription
                syncState = .failed(error.localizedDescription)
            }
        } else if isGuest {
            syncState = .localOnly
        } else {
            syncState = configuration.hasRemoteSyncConfiguration ? .syncing : .unavailable
        }
    }

    private func refreshRemoteState(uploadLocalPreview: Bool) async throws {
        guard let identity = authManager.identity, identity.provider == .apple else {
            syncState = .localOnly
            return
        }

        syncState = .syncing

        async let profileSync: Void = profileStore.syncAfterAuthentication(
            uploadLocalPreview: uploadLocalPreview,
            identity: identity
        )
        async let quizSync: Void = DailyQuizManager.shared.syncAfterAuthentication(uploadLocalPreview: uploadLocalPreview)
        async let trainingSync: Void = TrainingProgressManager.shared.syncAfterAuthentication(uploadLocalPreview: uploadLocalPreview)
        async let discussionSync: Void = DiscussionStore.shared.syncAfterAuthentication()

        _ = try await (profileSync, quizSync, trainingSync, discussionSync)
        await subscriptionManager.refreshEntitlements()
        syncState = .synced(Date())
    }

    private func completeOnboarding() {
        hasCompletedOnboarding = true
        defaults.set(true, forKey: onboardingKey)
    }

    private func bindChildObjects() {
        [authManager.objectWillChange, subscriptionManager.objectWillChange, profileStore.objectWillChange]
            .forEach { publisher in
                publisher
                    .sink { [weak self] _ in
                        self?.objectWillChange.send()
                    }
                    .store(in: &cancellables)
            }
    }
}

private struct RemoteUserProfileRecord: Codable {
    let id: String
    let displayName: String
    let email: String?
    let signInProvider: SignInProvider
    let currentFocus: String
    let topMistakePatterns: [String]
    let createdAt: Date
    let updatedAt: Date

    init(profile: RemoteUserProfile, userID: String) {
        id = userID
        displayName = profile.displayName
        email = profile.email
        signInProvider = profile.signInProvider
        currentFocus = profile.currentFocus
        topMistakePatterns = profile.topMistakePatterns
        createdAt = profile.joinedAt
        updatedAt = profile.updatedAt
    }

    init(
        id: String,
        displayName: String,
        email: String?,
        signInProvider: SignInProvider,
        currentFocus: String,
        topMistakePatterns: [String],
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.signInProvider = signInProvider
        self.currentFocus = currentFocus
        self.topMistakePatterns = topMistakePatterns
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var appModel: RemoteUserProfile {
        RemoteUserProfile(
            id: id,
            displayName: displayName,
            email: email,
            signInProvider: signInProvider,
            currentFocus: currentFocus,
            topMistakePatterns: topMistakePatterns,
            joinedAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
