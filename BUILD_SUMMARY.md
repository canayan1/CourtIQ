# Build Summary

## What changed

- Reworked session handling around guest preview plus Sign in with Apple backed by Supabase auth.
- Added remote-first sync hooks for profile data, quiz completions, training logs, weekly check-ins, and community threads.
- Replaced device-only community actions with backend-backed create/edit/delete/like/report flows.
- Tightened StoreKit entitlement handling so purchases, restore, and launch refresh use real App Store state.
- Added iPhone-only target settings and a Sign in with Apple entitlement file.

## Current risks

- RevenueCat wiring is prepared through configuration, but the runtime currently relies on StoreKit entitlement refresh directly.
- Delete-account depends on a deployed Supabase Edge Function named by `COURTIQ_DELETE_ACCOUNT_FUNCTION`.
- End-to-end sync still depends on production Supabase keys and App Store subscription setup.
