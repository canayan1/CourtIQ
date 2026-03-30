# Profile and Session Foundation

## Approach

- `UserSessionManager` is the central session object for the app.
- It is injected through `CourtIQApp` as an `@StateObject` and shared with views via `.environmentObject(...)`.
- The profile state is stored locally in `UserDefaults`.

## Data structures

- `UserProfile` contains:
  - `id`
  - `displayName`
  - `premiumStatus`
  - `currentFocus`
  - `topMistakePatterns`
  - `signInProvider`
- `PremiumStatus` has:
  - `.free`
  - `.premium`
- `SignInProvider` has:
  - `.apple`
  - `.guest`

## Auth/session behavior

- The app supports a clean session state without a backend.
- `ProfileView` shows signed-in status, profile summary, and a sign-in call-to-action.
- Local placeholder sign-in currently supports:
  - `Sign in with Apple` style flow
  - `Continue as guest`
- `UserSessionManager` persists profile state so the display name and premium status survive app restarts.

## What is real vs placeholder

- Real: local session state, profile persistence, profile-driven UI, premium-ready model.
- Placeholder: actual Apple authentication and backend account sync are not wired yet.

## Evolution path

- Replace `signInWithApplePlaceholder()` with a real `ASAuthorizationAppleIDProvider` flow.
- Connect `UserProfile` to a backend or secure cloud store.
- Persist and sync premium unlock state across devices.
- Add user-specific improvement history and saved mobility favorites.
