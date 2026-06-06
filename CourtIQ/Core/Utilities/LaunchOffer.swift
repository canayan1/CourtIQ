import Foundation

/// Historical note — intentionally empty.
///
/// CourtIQ originally shipped a launch promo where a single
/// `allFeaturesFree` flag opened every premium gate and reframed the
/// paywall as a "Support CourtIQ" tip jar. That model has been retired
/// in favour of the final, permanent pricing:
///
///   • Every content surface (training, mobility, quiz/practice,
///     community, progression, history) is FREE for everyone. The
///     content gate `UserSessionManager.isPremiumUnlocked` is hard-wired
///     to `true`.
///   • The AI Coach is the one paid feature. It gates independently on
///     the real StoreKit entitlement (`entitlementState.isPremium`) at
///     its own entry point, and the paywall sells it as a normal
///     auto-renewing subscription (no tip-jar framing).
///
/// This type is kept (rather than deleted) only so the file reference in
/// the Xcode project stays valid; it carries no behaviour.
enum LaunchOffer {}
