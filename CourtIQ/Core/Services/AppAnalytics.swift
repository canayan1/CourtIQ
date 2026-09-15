import Foundation
import SwiftUI
#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif

/// Thin, provider-agnostic analytics facade for **Google Analytics for Firebase**.
///
/// Why a facade: call sites never import Firebase directly, so the whole app is
/// decoupled from the backend. The Firebase calls are wrapped in
/// `#if canImport(FirebaseAnalytics)`, so:
///   • **Before** the FirebaseAnalytics package is added → this compiles as a
///     safe no-op (DEBUG prints events so you can see them while developing).
///   • **After** the package + `GoogleService-Info.plist` are added → every
///     `screen(_:)` / `log(_:)` lights up in GA4 with zero call-site changes.
///
/// Gated by a single opt-out flag (default ON) so a privacy toggle can bind here.
/// See `docs/ANALYTICS.md` for the Firebase console + privacy-label steps.
final class AppAnalytics {
    static let shared = AppAnalytics()
    private init() {}

    private static let enabledKey = "DropVolley.analytics.enabled.v1"

    /// Master opt-out (default ON). Persisted so a Settings switch can bind here.
    var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.enabledKey)
            #if canImport(FirebaseAnalytics)
            Analytics.setAnalyticsCollectionEnabled(newValue)
            #endif
        }
    }

    /// True only when a real backend is linked (package present).
    var backendLinked: Bool {
        #if canImport(FirebaseAnalytics)
        return true
        #else
        return false
        #endif
    }

    // MARK: - Screen views

    /// Logs a GA4 `screen_view`. Call via the `.trackScreen("Name")` modifier on
    /// each top-level screen so you can see where users go and where they drop.
    func screen(_ name: String, screenClass: String? = nil) {
        guard isEnabled else { return }
        #if canImport(FirebaseAnalytics)
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: name,
            AnalyticsParameterScreenClass: screenClass ?? name
        ])
        #else
        debugLog("screen_view · \(name)")
        #endif
    }

    // MARK: - Events

    /// Logs a custom event. Keep names snake_case + stable (see `AnalyticsEvent`).
    func log(_ event: String, _ params: [String: Any]? = nil) {
        guard isEnabled else { return }
        #if canImport(FirebaseAnalytics)
        Analytics.logEvent(event, parameters: params)
        #else
        debugLog("\(event) · \(params ?? [:])")
        #endif
    }

    /// Sets a user property (e.g. skill level, premium) for segmentation.
    func setUserProperty(_ value: String?, forName name: String) {
        guard isEnabled else { return }
        #if canImport(FirebaseAnalytics)
        Analytics.setUserProperty(value, forName: name)
        #endif
    }

    private func debugLog(_ line: String) {
        #if DEBUG
        print("📊 [analytics] \(line)")
        #endif
    }
}

/// Stable event names — one place so dashboards + call sites never drift.
/// Extend as new funnels are instrumented.
enum AnalyticsEvent {
    // Engagement / funnels
    static let quizCompleted        = "quiz_completed"
    static let swingAnalyzed        = "swing_analyzed"
    static let matchLogged          = "match_logged"
    static let doublesAnalyzed      = "doubles_analyzed"
    static let wallSessionCompleted = "wall_session_completed"
    static let mentalCheckCompleted = "mental_check_completed"
    static let coachMessageSent     = "coach_message_sent"
    static let tipViewed            = "tip_viewed"
    // Activation / retention
    static let onboardingCompleted  = "onboarding_completed"
    // Monetization
    static let paywallShown         = "paywall_shown"
    static let subscriptionStarted  = "subscription_started"
    /// G0 demand gate for the human Coach Review marketplace
    /// (docs/COACH-REVIEW-PLAN.md) — fired once per user per source.
    static let coachReviewInterest  = "coach_review_interest"
    /// A paid human review was purchased + submitted.
    static let coachReviewOrdered   = "coach_review_ordered"
    /// Nutrition: a pre-session meal was logged / a session was rated.
    static let nutritionLogged      = "nutrition_logged"
    static let nutritionRated       = "nutrition_rated"
}

extension View {
    /// Logs a GA4 `screen_view` each time this screen appears. Apply once per
    /// top-level screen with a short, stable name.
    func trackScreen(_ name: String) -> some View {
        onAppear { AppAnalytics.shared.screen(name) }
    }
}
