# CourtIQ — CLAUDE.md

## Project Overview

CourtIQ is an iOS app that improves tennis IQ for all skill levels through daily tips, scenario-based quizzes, an FAQ section, user profiles, and progress tracking. It follows a freemium monetization model.

## Tech Stack

- **UI**: SwiftUI
- **Local persistence**: SwiftData
- **Backend / Auth / Remote DB**: Firebase (Firestore, Auth, Storage, Analytics)
- **Platform**: iOS 17+
- **Language**: Swift 5.9+

## Architecture

Use **MVVM** throughout:
- `Model` — SwiftData `@Model` classes and plain Swift structs for API payloads
- `ViewModel` — `@Observable` classes that own business logic and call services
- `View` — SwiftUI views that bind to ViewModels; zero business logic in views

Folder structure:
```
CourtIQ/
├── App/                  # App entry point, DI container
├── Core/
│   ├── Models/           # SwiftData models & domain types
│   ├── Services/         # Firebase wrappers, tip/quiz fetchers
│   └── Utilities/        # Extensions, helpers
├── Features/
│   ├── Onboarding/
│   ├── DailyTip/
│   ├── Quiz/
│   ├── FAQ/
│   ├── Profile/
│   └── Progress/
├── SharedUI/             # Reusable components, modifiers, theme
└── Resources/            # Assets, localization
```

## Features

### Daily Tips
- One tip per day fetched from Firestore (`tips` collection)
- Cached locally with SwiftData so tips are available offline
- Tip categories: technique, tactics, fitness, mental game
- Free users see the current tip; premium users access the full archive

### Scenario-Based Quizzes
- Multi-step scenarios with branching logic stored in Firestore (`quizzes` collection)
- All quizzes are free (no daily cap)
- Results persisted locally via SwiftData and synced to Firestore for cross-device progress

### FAQ
- Static content bundled in the app; editable by admins via Firestore (`faq` collection)
- Searchable list with category filters

### User Profiles
- Firebase Auth (email/password + Sign in with Apple)
- Profile data in Firestore (`users/{uid}`) — display name, avatar URL, skill level, join date
- Skill levels: Beginner, Intermediate, Advanced, Pro

### Progress Tracking
- Local SwiftData store for quiz scores, streak counters, tip read history
- Synced to Firestore on demand; merged on sign-in across devices
- Charts with Swift Charts framework (weekly/monthly views)

## Monetization Model

**All in-app content is FREE** — daily court-tap drills, daily tips, scenario
quizzes (no daily cap), pro shot patterns, FAQ, training programs, mobility
flows, match journal, and full progress history. There is no content paywall.

**The one premium feature is the AI Coach** — a tennis chat that knows the
user's profile, recent matches, and quiz mistake patterns. It is premium
because it has a real per-message (Anthropic) cost. Unlocked via StoreKit 2
(monthly / annual auto-renewable subscription), capped at 50 messages/day.

Gating: the content gate `UserSessionManager.isPremiumUnlocked` is hard-wired
`true` (everything unlocked). The AI Coach gates independently on the real
StoreKit entitlement (`entitlementState.isPremium`). The paywall sells only
the AI Coach.

## Firebase Setup

- **Auth**: email/password + Sign in with Apple
- **Firestore** security rules: users can only read/write their own `users/{uid}` document; `tips` and `quizzes` are read-only for authenticated users; admin writes via Cloud Functions only
- **Analytics**: log `quiz_completed`, `tip_viewed`, `premium_upsell_shown`, `subscription_started`
- **Environment**: use separate Firebase projects for `dev` and `prod`; switch via `GoogleService-Info.plist` build configurations

## Coding Conventions

- All async work uses `async/await`; avoid callbacks and Combine unless integrating a third-party SDK
- Inject services via environment or init parameters — no singletons accessed directly from views
- SwiftData `ModelContainer` configured once in `@main` and passed down
- Feature flags for premium gating live in a single `PremiumGate` utility
- Localization-ready: all user-facing strings via `String(localized:)`

## Testing

- Unit test ViewModels with mock services
- UI tests for critical happy paths: onboarding, quiz flow, paywall
- Test targets: `CourtIQTests`, `CourtIQUITests`

## Key Commands

```bash
# Open project
open CourtIQ.xcodeproj

# Run tests
xcodebuild test -scheme CourtIQ -destination 'platform=iOS Simulator,name=iPhone 16'

# Lint (SwiftLint required)
swiftlint lint --strict
```

## Out of Scope (for now)

- Android / cross-platform
- Live match scoring
- Multiplayer / social feed
- Coach-facing admin dashboard
