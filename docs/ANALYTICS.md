# DropVolley — Analytics (Google Analytics for Firebase)

The app is instrumented for **Google Analytics for Firebase** (GA4) through a thin
facade, [`AppAnalytics`](../CourtIQ/Core/Services/AppAnalytics.swift). Call sites
never import Firebase — the Firebase calls are wrapped in
`#if canImport(FirebaseAnalytics)`, so the app **builds and runs today as a no-op**
(DEBUG prints events to the console) and **lights up in GA4 the moment** the
package + `GoogleService-Info.plist` are added — with zero code changes.

## What's already instrumented (in code)

**Screens** (`screen_view`) — every main surface via `.trackScreen("…")`:
`Home`, `Train`, `Matches`, `Doubles`, `Coach`, `Paywall`.

**Events** (funnels + retention) — `AnalyticsEvent` constants:
- `quiz_completed` (score, total)
- `wall_session_completed` (title, hits, seconds, free_rally)
- `paywall_shown` (source) · `subscription_started` (product)

More are stubbed in `AnalyticsEvent` and easy to add at their call sites:
`swing_analyzed`, `match_logged`, `doubles_analyzed`, `mental_check_completed`,
`coach_message_sent`, `tip_viewed`, `onboarding_completed`.

## Your steps to switch it on (Google account — can't be automated)

1. **Firebase project** — https://console.firebase.google.com → *Add project*
   (or reuse one). On creation, keep **Google Analytics enabled** so a GA4
   property is linked automatically.
2. **Add the iOS app** — bundle ID **`com.canayan93.courtiq`**. Download the
   generated **`GoogleService-Info.plist`**.
3. **Add the plist to the app** — drop `GoogleService-Info.plist` into the
   `CourtIQ` target (Xcode → drag into the project, "Copy items if needed",
   target = CourtIQ). (Or hand it to me and I'll place + bundle it.)
4. **Add the SDK** — Xcode → *File ▸ Add Package Dependencies…* →
   `https://github.com/firebase/firebase-ios-sdk` → add the **FirebaseAnalytics**
   product to the CourtIQ target. (This is the one GUI step I can't type into
   Xcode for you.)
5. Build. `FirebaseApp.configure()` runs (guarded on the plist), and events start
   flowing. Verify live in **GA4 → DebugView** (enable with the launch arg
   `-FIRDebugEnabled`, or `-FIRAnalyticsDebugEnabled`).

Once done it answers exactly what you asked: **every screen** (screen_view),
**where users drop** (funnel exploration + screen paths), **what they use**
(event counts), and **retention** (GA4 Retention / cohorts).

## Privacy / App Review (don't skip)

Firebase Analytics collects usage + device data, so before the next submission:
- **App Privacy labels** (App Store Connect) — declare data collection:
  *Usage Data* (product interaction) and *Identifiers* (device ID) linked to the
  user for **Analytics**, not tracking (Firebase default is non-tracking).
- **Privacy manifest** — the FirebaseAnalytics SDK ships its own
  `PrivacyInfo.xcprivacy`; keep the app's existing
  [`PrivacyInfo.xcprivacy`](../CourtIQ/PrivacyInfo.xcprivacy) consistent (no
  new *required-reason API* declarations are needed for Analytics itself).
- **Opt-out** — `AppAnalytics.shared.isEnabled` (default ON) gates everything and
  calls `setAnalyticsCollectionEnabled`; wire a Settings toggle to it if you want
  a user-facing opt-out (recommended for EU users).

## Adding a new event

```swift
AppAnalytics.shared.log(AnalyticsEvent.matchLogged, ["result": entry.result.rawValue])
```
Add the name to `AnalyticsEvent` first so dashboards + call sites never drift.
