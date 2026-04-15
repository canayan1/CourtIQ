# CourtIQ Configuration Guide

## Required Info.plist Keys

The app reads release configuration from `CourtIQ/Info.plist`.

| Key | Purpose |
| --- | --- |
| `COURTIQ_MONTHLY_PRODUCT_ID` | Monthly auto-renewable subscription product ID |
| `COURTIQ_YEARLY_PRODUCT_ID` | Yearly auto-renewable subscription product ID |
| `COURTIQ_PREMIUM_ENTITLEMENT_ID` | RevenueCat entitlement identifier |
| `COURTIQ_PRIVACY_URL` | Published privacy policy URL |
| `COURTIQ_TERMS_URL` | Published terms URL |
| `COURTIQ_SUPPORT_URL` | Published support/help URL |
| `COURTIQ_SUPABASE_URL` | Supabase project URL |
| `COURTIQ_SUPABASE_ANON_KEY` | Supabase anon key |
| `COURTIQ_REVENUECAT_API_KEY` | RevenueCat public SDK key |

## Current Runtime Behavior

- No Supabase keys:
  - profile and progress stay local
  - app shows preview integration messaging
- No RevenueCat key:
  - paywall still renders
  - purchase flow falls back to preview unlock behavior for local testing
- No legal URLs:
  - in-app legal views still render placeholder copy
  - published links stay hidden

## Recommended Production Setup

1. Create App Store Connect subscriptions.
2. Configure RevenueCat with the same products and one entitlement.
3. Create Supabase project and run the schema file.
4. Update `Info.plist` with production values.
5. Replace placeholder legal text with approved copy and URLs.
6. Validate purchase, restore, sign-in, and delete-account flows on a real device.

## Notes

- Guest mode is intentionally local-only.
- Community posting is intentionally gated behind both All Access and Sign in with Apple.
- The app content library is bundled as JSON in `CourtIQ/Resources/Content`.
