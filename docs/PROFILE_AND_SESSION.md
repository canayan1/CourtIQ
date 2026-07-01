# Profile and Session Foundation

## Approach

- `UserSessionManager` is the orchestration layer for auth, billing, profile sync, and account actions.
- `AuthManager` handles guest identity plus Sign in with Apple backed by Supabase auth.
- `ProfileStore` keeps a local cache for fast launch and syncs profile state when the user is signed in.

## Current behavior

- Guest mode keeps progress on-device and unlocks the free preview surface.
- Sign in with Apple upgrades the session to a cloud-backed account and restores synced progress.
- Billing uses StoreKit product loading and entitlement refresh on launch, purchase, restore, and transaction updates.
- `Delete Account` is reserved for signed-in users and is expected to call the Supabase Edge Function named in configuration.
- `Reset Local Data` clears device caches and then rehydrates from the cloud when a signed-in user is present.

## Evolution path

- Wire the RevenueCat SDK into the existing billing orchestration so offerings and entitlement refresh can be mirrored through RevenueCat.
- Add deeper conflict handling for cases where signed-in remote data and guest local data diverge before first migration.
- Expand profile sync with richer improvement history and saved mobility favorites.
