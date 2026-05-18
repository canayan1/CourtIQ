# CourtIQ Configuration Guide

## Required Info.plist Keys

The app reads release configuration from `CourtIQ/Info.plist`.

| Key | Purpose |
| --- | --- |
| `COURTIQ_MONTHLY_PRODUCT_ID` | Monthly auto-renewable subscription product ID |
| `COURTIQ_YEARLY_PRODUCT_ID` | Yearly auto-renewable subscription product ID |
| `COURTIQ_PREMIUM_ENTITLEMENT_ID` | Premium entitlement identifier |
| `COURTIQ_PRIVACY_URL` | Published privacy policy URL |
| `COURTIQ_TERMS_URL` | Published terms URL |
| `COURTIQ_SUPPORT_URL` | Published support/help URL |
| `COURTIQ_SUPABASE_URL` | Supabase project URL |
| `COURTIQ_SUPABASE_ANON_KEY` | Supabase anon key |
| `COURTIQ_REVENUECAT_API_KEY` | RevenueCat public SDK key |
| `COURTIQ_DELETE_ACCOUNT_FUNCTION` | Supabase Edge Function name for account deletion |

## Current Runtime Behavior

- No Supabase keys:
  - guest preview still works locally
  - Apple sign-in and cloud sync stay unavailable
- No App Store products:
  - the paywall still renders
  - purchases fail with a clear user-facing error instead of preview unlocking
- No legal URLs:
  - in-app legal views still render the built-in production copy
  - external document buttons stay hidden

## Recommended Production Setup

1. Create App Store Connect subscriptions.
2. Configure RevenueCat with the same products and one entitlement.
3. Create a Supabase project and run `Docs/SUPABASE_SCHEMA.sql`.
4. Deploy a `delete-account` Edge Function that deletes the auth user plus synced app data.
5. Update `CourtIQ/Info.plist` with production values.
6. Validate Apple sign-in, purchase, restore, sync, community, reset-local-data, and delete-account flows on a real device.

## Notes

- Guest mode is intentionally local-first.
- Signed-in users use remote-first sync with local cache fallback.
- Community writing is gated behind both All Access and Sign in with Apple.
