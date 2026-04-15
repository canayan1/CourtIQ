# CourtIQ App Store Launch Checklist

## Product
- Confirm free preview scope:
  - Today hub
  - 1 daily IQ quiz
  - foundation training plan
  - 2 mobility preview flows
  - read-only discussion
- Confirm All Access scope:
  - premium training tracks
  - full mobility library
  - practice skill blocks
  - archived quiz insights
  - community posting
- Replace placeholder legal copy in-app with production-approved text.

## Configuration
- Fill `COURTIQ_PRIVACY_URL` in `Info.plist`
- Fill `COURTIQ_TERMS_URL` in `Info.plist`
- Fill `COURTIQ_SUPPORT_URL` in `Info.plist`
- Fill `COURTIQ_SUPABASE_URL` in `Info.plist`
- Fill `COURTIQ_SUPABASE_ANON_KEY` in `Info.plist`
- Fill `COURTIQ_REVENUECAT_API_KEY` in `Info.plist`
- Confirm product IDs:
  - `com.courtiq.premium.monthly`
  - `com.courtiq.premium.yearly`
- Confirm entitlement ID:
  - `premium_all_access`

## Apple Platform Work
- Add the app to your Apple Developer team.
- Enable `Sign in with Apple` capability for the app target.
- Create monthly and yearly auto-renewable subscriptions in App Store Connect.
- Attach the correct privacy policy, terms, and support URLs in App Store Connect.
- Verify in-app account deletion remains reachable from `Profile`.

## RevenueCat
- Create an app in RevenueCat.
- Add the monthly and yearly App Store products.
- Create an entitlement named `premium_all_access`.
- Add an offering that includes both packages.
- Paste the public SDK key into `COURTIQ_REVENUECAT_API_KEY`.

## Supabase
- Create the project and run `Docs/SUPABASE_SCHEMA.sql`.
- Turn on Row Level Security for every user table.
- Add moderation/admin users before enabling public commenting.
- Paste project URL and anon key into `Info.plist`.

## QA
- Test guest onboarding.
- Test Sign in with Apple from onboarding.
- Test Sign in with Apple from profile upgrade.
- Test paywall purchase flow.
- Test restore purchases.
- Test account deletion.
- Test weekly training completion persistence.
- Test weekly persistence check history.
- Test premium lock states after relaunch.
- Test comment create, edit, delete, like, and report.

## Submission Assets
- App icon
- Today screenshot
- Training calendar screenshot
- Mobility screenshot
- Community screenshot
- Paywall screenshot
- Privacy questionnaire answers
- App description and keyword set
