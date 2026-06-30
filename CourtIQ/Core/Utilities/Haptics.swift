import UIKit
import StoreKit

/// Centralized haptic feedback. Apple-only, no third-party, MainActor-bound.
///
/// We pre-create generators where possible and `prepare()` them before use
/// so the first tap doesn't have setup latency. Keep this enum small — too
/// many haptic surfaces feels noisy.
@MainActor
enum Haptics {
    private static let notification = UINotificationFeedbackGenerator()
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)

    /// Call from app entry to warm up the haptic engine (avoids 100-200ms
    /// latency on the first vibration).
    static func warmUp() {
        notification.prepare()
        light.prepare()
        medium.prepare()
        heavy.prepare()
    }

    // MARK: - Public surfaces (use these, not the generators directly)

    /// Quiz correct answer, restore purchase success, etc.
    static func success() {
        notification.notificationOccurred(.success)
        notification.prepare()
    }

    /// Quiz wrong answer, validation fail. Single sharp pulse.
    static func error() {
        notification.notificationOccurred(.error)
        notification.prepare()
    }

    /// Lighter than error — generic warning (network blip, etc.).
    static func warning() {
        notification.notificationOccurred(.warning)
        notification.prepare()
    }

    /// Subtle confirmation — toggle accept, soft tap, modal accept.
    static func tap() {
        light.impactOccurred()
        light.prepare()
    }

    /// Action completed — mark training session done, save check-in.
    static func confirm() {
        medium.impactOccurred()
        medium.prepare()
    }

    /// Celebration — streak milestone, level up.
    static func celebrate() {
        heavy.impactOccurred()
        heavy.prepare()
    }
}

/// Native App Store review prompt, gated to genuine "win" moments.
///
/// Apple throttles `requestReview` itself and hard-caps it to 3 prompts per
/// user per 365 days — and a user rarely gets a second chance. So we only ask
/// after the player has had a couple of satisfying moments (a good quiz, a
/// strong swing result, a won match) and at most once per app version. Ratings
/// are our single biggest App Store conversion lever (we currently have ~0),
/// so the trigger lives on FREE, high-volume surfaces (quiz wins).
@MainActor
enum RatingPrompt {
    private static let promptedVersionKey = "CourtIQ.rating.promptedVersion"
    private static let winCountKey = "CourtIQ.rating.winCount"

    /// Call at a genuine satisfaction moment. Fires the native prompt only
    /// after `minimumWins` wins and at most once per app version. Apple still
    /// throttles + caps display on top of this.
    static func registerWin(minimumWins: Int = 2) {
        let d = UserDefaults.standard
        let wins = d.integer(forKey: winCountKey) + 1
        d.set(wins, forKey: winCountKey)
        guard wins >= minimumWins else { return }

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        guard d.string(forKey: promptedVersionKey) != version else { return }

        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else { return }

        if #available(iOS 18.0, *) {
            AppStore.requestReview(in: scene)
        } else {
            SKStoreReviewController.requestReview(in: scene)
        }
        d.set(version, forKey: promptedVersionKey)
    }
}
