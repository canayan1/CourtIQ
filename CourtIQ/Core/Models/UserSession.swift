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
            return "Daily IQ stays open. Premium content is previewable but locked."
        case .premiumAllAccess:
            return "Training, mobility, archived insights, and community posting are unlocked."
        }
    }

    var isPremium: Bool {
        self == .premiumAllAccess
    }
}

enum BillingIntegrationMode: String {
    case preview
    case appStoreConfigured
    case revenueCatReady

    var title: String {
        switch self {
        case .preview: return "Preview"
        case .appStoreConfigured: return "App Store"
        case .revenueCatReady: return "RevenueCat Ready"
        }
    }
}

enum SignInProvider: String, Codable {
    case apple
    case guest
}

struct SessionIdentity: Identifiable, Codable, Equatable {
    let id: UUID
    var displayName: String
    var email: String?
    var provider: SignInProvider
}

struct RemoteUserProfile: Identifiable, Codable {
    let id: UUID
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
    case purchaseCancelled
    case purchasePending
    case verificationFailed
    case unknown

    var errorDescription: String? {
        switch self {
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

    private let defaults = UserDefaults.standard
    private let storageKey = "CourtIQ.Auth.Identity"

    init() {
        load()
    }

    var isSignedInWithApple: Bool {
        identity?.provider == .apple
    }

    func signInAsGuest() {
        identity = SessionIdentity(
            id: UUID(),
            displayName: "Guest Player",
            email: nil,
            provider: .guest
        )
        save()
    }

    func signInWithApple(credential: ASAuthorizationAppleIDCredential, preserving existing: SessionIdentity?) {
        let formatter = PersonNameComponentsFormatter()
        let providedName = formatter.string(from: credential.fullName ?? PersonNameComponents()).trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackName = existing?.displayName == "Guest Player" ? "CourtIQ Player" : (existing?.displayName ?? "CourtIQ Player")

        identity = SessionIdentity(
            id: existing?.id ?? UUID(),
            displayName: providedName.isEmpty ? fallbackName : providedName,
            email: credential.email ?? existing?.email,
            provider: .apple
        )
        save()
    }

    func signOut() {
        identity = nil
        defaults.removeObject(forKey: storageKey)
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey) else { return }
        identity = try? JSONDecoder().decode(SessionIdentity.self, from: data)
    }

    private func save() {
        guard let identity, let data = try? JSONEncoder().encode(identity) else { return }
        defaults.set(data, forKey: storageKey)
    }
}

@MainActor
final class SubscriptionManager: ObservableObject {
    @Published private(set) var entitlementState: EntitlementState
    @Published private(set) var offers: [SubscriptionOffer]
    @Published private(set) var integrationMode: BillingIntegrationMode

    let premiumBenefits = [
        "Full 8-week training programs",
        "Full mobility and recovery library",
        "Archived quiz history and focus insights",
        "Community commenting and thread participation",
        "Future synced progress across devices"
    ]

    private let configuration: AppConfiguration
    private let defaults = UserDefaults.standard
    private let entitlementKey = "CourtIQ.Subscription.EntitlementState"
    private var productsByID: [String: Product] = [:]

    init(configuration: AppConfiguration = .shared) {
        let defaults = UserDefaults.standard
        self.configuration = configuration
        self.entitlementState = Self.loadEntitlement(from: defaults)
        self.offers = [
            SubscriptionOffer(
                id: configuration.monthlyProductID,
                title: "Monthly All Access",
                detail: "Best for trialing a focused training block.",
                priceDisplay: "$9.99 / month",
                isFeatured: false
            ),
            SubscriptionOffer(
                id: configuration.yearlyProductID,
                title: "Yearly All Access",
                detail: "Best value for full-season progress.",
                priceDisplay: "$59.99 / year",
                isFeatured: true
            )
        ]
        self.integrationMode = configuration.hasRevenueCatConfiguration ? .revenueCatReady : .preview

        Task {
            await refreshProducts()
        }
    }

    var isPremiumUnlocked: Bool {
        entitlementState.isPremium
    }

    func purchase(_ offer: SubscriptionOffer) async throws {
        if let product = productsByID[offer.id] {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    throw SubscriptionError.verificationFailed
                }
                entitlementState = .premiumAllAccess
                saveEntitlement()
                integrationMode = configuration.hasRevenueCatConfiguration ? .revenueCatReady : .appStoreConfigured
                await transaction.finish()
            case .pending:
                throw SubscriptionError.purchasePending
            case .userCancelled:
                throw SubscriptionError.purchaseCancelled
            @unknown default:
                throw SubscriptionError.unknown
            }
        } else {
            entitlementState = .premiumAllAccess
            saveEntitlement()
        }
    }

    func restorePurchases() async {
        if !productsByID.isEmpty {
            do {
                try await AppStore.sync()
            } catch {
                return
            }
        }
    }

    func reset() {
        entitlementState = .freePreview
        saveEntitlement()
    }

    private func refreshProducts() async {
        do {
            let products = try await Product.products(for: [configuration.monthlyProductID, configuration.yearlyProductID])
            guard !products.isEmpty else { return }

            productsByID = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
            integrationMode = configuration.hasRevenueCatConfiguration ? .revenueCatReady : .appStoreConfigured

            offers = offers.map { offer in
                guard let product = productsByID[offer.id] else { return offer }
                return SubscriptionOffer(
                    id: offer.id,
                    title: offer.title,
                    detail: offer.detail,
                    priceDisplay: product.displayPrice + (offer.id == configuration.yearlyProductID ? " / year" : " / month"),
                    isFeatured: offer.isFeatured
                )
            }
        } catch {
            integrationMode = configuration.hasRevenueCatConfiguration ? .revenueCatReady : .preview
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
    }

    func updateCurrentFocus(_ focus: String) {
        guard var profile else { return }
        profile.currentFocus = focus
        profile.updatedAt = Date()
        self.profile = profile
        save()
    }

    func updateTopMistakePatterns(_ patterns: [String]) {
        guard var profile else { return }
        profile.topMistakePatterns = patterns
        profile.updatedAt = Date()
        self.profile = profile
        save()
    }

    func delete() {
        profile = nil
        defaults.removeObject(forKey: storageKey)
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey) else { return }
        profile = try? JSONDecoder().decode(RemoteUserProfile.self, from: data)
    }

    private func save() {
        guard let profile, let data = try? JSONEncoder().encode(profile) else { return }
        defaults.set(data, forKey: storageKey)
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

        bindChildObjects()
    }

    var currentUserID: String {
        authManager.identity?.id.uuidString ?? "anonymous-preview"
    }

    var isAuthenticated: Bool {
        authManager.identity != nil
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

    var integrationSummary: String {
        if configuration.hasRemoteSyncConfiguration && configuration.hasRevenueCatConfiguration {
            return "Remote sync and RevenueCat keys are configured."
        }

        if configuration.hasRemoteSyncConfiguration || configuration.hasRevenueCatConfiguration {
            return "Partial production configuration detected. Complete remaining keys before App Store release."
        }

        return "App Store testing mode is active. Add Supabase and RevenueCat keys in Info.plist before release."
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
            authManager.signInWithApple(credential: credential, preserving: previousIdentity)
            if let identity = authManager.identity {
                profileStore.bootstrap(
                    from: identity,
                    preserving: profileStore.profile?.currentFocus ?? currentImprovementFocus,
                    topMistakePatterns: profileStore.profile?.topMistakePatterns ?? topMistakePatterns
                )
            }
            completeOnboarding()

        case .failure(let error):
            authErrorMessage = error.localizedDescription
        }
    }

    func signOut() {
        authManager.signOut()
        profileStore.delete()
        subscriptionManager.reset()
        hasCompletedOnboarding = false
        defaults.set(false, forKey: onboardingKey)
    }

    func deleteAccount() async {
        DailyQuizManager.shared.reset()
        TrainingProgressManager.shared.reset()
        DiscussionStore.shared.reset()
        signOut()
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
