import Foundation

/// Single source of truth for the public launch promo: while
/// `allFeaturesFree` is `true`, every Premium-gated surface in the app
/// behaves as if the user is fully subscribed, and the paywall reframes
/// itself as an optional "Support CourtIQ" tip jar.
///
/// Why this lives in one place:
///   • All gating reads `session.isPremiumUnlocked`, which falls through
///     to this flag in `SubscriptionManager.isPremiumUnlocked`.
///   • Flipping `allFeaturesFree` to `false` re-enables the existing
///     paid plumbing — no other code changes needed.
///   • Users who do contribute during the launch window keep their
///     entitlement (StoreKit-backed) even after the flag flips off,
///     because the OR short-circuits to the real `entitlementState`.
///
/// `endsOn` is purely informational right now — the paywall copy reads
/// it to set tone — but a future build can use it to auto-disable the
/// promo. Keep it intentionally vague (calendar month, not a hard date)
/// so we never embarrass ourselves with a "Promo ends in 3 hours" timer
/// when we haven't decided yet.
enum LaunchOffer {
    /// Master flag. When true, all Premium gates are open and the
    /// paywall is a tip jar.
    static let allFeaturesFree = true

    /// Optional human-readable end window for marketing copy. We don't
    /// enforce this client-side — it's only used to seed copy on the
    /// paywall if/when we want to put a soft horizon on the offer.
    /// Set to nil to render copy without any end-date framing.
    static let endsOn: String? = nil
}
