import UIKit

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
