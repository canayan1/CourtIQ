# CourtIQ Build Checklist

## Core launch paths

- Build the app for generic iOS and confirm the target still compiles.
- Verify onboarding supports both guest preview and Sign in with Apple entry points.
- Verify the main tabs render: Today, Practice, Community, Training, Profile.
- Verify the paywall loads products or shows a clear product-configuration error.

## Sync and account

- Sign in with Apple and confirm profile/progress sync state updates.
- Relaunch and confirm the signed-in session restores.
- Test `Reset Local Data` and confirm signed-in data rehydrates from the backend.
- Test `Delete Account` against the configured Edge Function.

## Premium and community

- Confirm free preview gates remain intact for premium practice, premium training, and full mobility.
- Confirm purchase and restore update entitlement state.
- Confirm community read-only access for preview users.
- Confirm signed-in premium users can create, edit, delete, like, unlike, and report comments.
