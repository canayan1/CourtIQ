import Foundation

enum PremiumStatus: String, Codable {
    case free
    case premium

    var title: String {
        switch self {
        case .free: return "Free"
        case .premium: return "Premium"
        }
    }

    var description: String {
        switch self {
        case .free: return "Free access with premium library preview."
        case .premium: return "Full mobility and recovery content unlocked."
        }
    }
}

enum SignInProvider: String, Codable {
    case apple
    case guest
}

struct UserProfile: Identifiable, Codable {
    let id: UUID
    var displayName: String
    var premiumStatus: PremiumStatus
    var currentFocus: String
    var topMistakePatterns: [String]
    var signInProvider: SignInProvider
}

@MainActor
final class UserSessionManager: ObservableObject {
    static let shared = UserSessionManager()

    @Published private(set) var profile: UserProfile?

    private let storageKey = "CourtIQ.UserProfile"
    private let userDefaults = UserDefaults.standard

    private init() {
        loadProfile()
    }

    var isAuthenticated: Bool {
        profile != nil
    }

    var displayName: String {
        profile?.displayName ?? "Player"
    }

    var premiumStatus: PremiumStatus {
        profile?.premiumStatus ?? .free
    }

    var currentImprovementFocus: String {
        profile?.currentFocus ?? Quiz.dailyQuiz(for: Date()).focusLabel
    }

    var topMistakePatterns: [String] {
        profile?.topMistakePatterns ?? ["Second serve pressure", "Serve predictability", "Body serve timing"]
    }

    var isPremiumUnlocked: Bool {
        premiumStatus == .premium
    }

    func signInWithApplePlaceholder() {
        profile = createProfile(provider: .apple)
        saveProfile()
    }

    func signInAsGuest() {
        profile = createProfile(provider: .guest)
        saveProfile()
    }

    func signOut() {
        profile = nil
        userDefaults.removeObject(forKey: storageKey)
    }

    private func createProfile(provider: SignInProvider) -> UserProfile {
        UserProfile(
            id: UUID(),
            displayName: provider == .apple ? "Apple Player" : "Guest Player",
            premiumStatus: .free,
            currentFocus: Quiz.dailyQuiz(for: Date()).focusLabel,
            topMistakePatterns: ["Second serve pressure", "Being predictable", "Ignoring returner positioning"],
            signInProvider: provider
        )
    }

    private func loadProfile() {
        guard let data = userDefaults.data(forKey: storageKey) else {
            profile = nil
            return
        }

        let decoder = JSONDecoder()
        if let stored = try? decoder.decode(UserProfile.self, from: data) {
            profile = stored
        } else {
            profile = nil
        }
    }

    private func saveProfile() {
        guard let profile = profile else { return }
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(profile) {
            userDefaults.set(data, forKey: storageKey)
        }
    }
}
