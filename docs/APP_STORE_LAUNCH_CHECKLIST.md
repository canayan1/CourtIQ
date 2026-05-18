# CourtIQ App Store Launch Checklist

## Product
- Confirm free preview scope:
  - Today hub
  - 1 daily IQ quiz
  - foundation training plan
  - 2 mobility preview flows
  - read-only community threads
- Confirm All Access scope:
  - premium training tracks
  - full mobility library
  - premium practice blocks
  - archived quiz insights
  - community posting, likes, and reports
  - signed-in cloud sync
- Review all in-app copy for sync, community, billing, and account deletion consistency.

## Configuration
- Fill `COURTIQ_PRIVACY_URL` in `Info.plist`
- Fill `COURTIQ_TERMS_URL` in `Info.plist`
- Fill `COURTIQ_SUPPORT_URL` in `Info.plist`
- Fill `COURTIQ_SUPABASE_URL` in `Info.plist`
- Fill `COURTIQ_SUPABASE_ANON_KEY` in `Info.plist`
- Fill `COURTIQ_REVENUECAT_API_KEY` in `Info.plist`
- Confirm `COURTIQ_DELETE_ACCOUNT_FUNCTION`
- Confirm product IDs:
  - `com.courtiq.premium.monthly`
  - `com.courtiq.premium.yearly`
- Confirm entitlement ID:
  - `premium_all_access`

## Apple Platform Work
- Add the app to your Apple Developer team.
- Enable the `Sign in with Apple` capability for the app target.
- Create monthly and yearly auto-renewable subscriptions in App Store Connect.
- Attach the correct privacy policy, terms, and support URLs in App Store Connect.
- Confirm the account deletion path remains reachable from `Profile`.
- Prepare iPhone-only screenshots and metadata.

## Backend
- Create the Supabase project and run `Docs/SUPABASE_SCHEMA.sql`.
- Deploy the `delete-account` Edge Function.
- Seed the launch discussion threads.
- Add moderator/admin access for dashboard review.

## Billing
- Configure RevenueCat with the same App Store products and entitlement.
- Confirm offerings expose both monthly and yearly plans.
- Validate purchase, restore, renewal, expiration, and refund behavior.

## QA
- Test guest onboarding.
- Test Sign in with Apple from onboarding.
- Test Sign in with Apple from paywall/profile upgrade.
- Test paywall purchase flow.
- Test restore purchases.
- Test sync after relaunch.
- Test sync after reinstall and on a second device.
- Test account deletion.
- Test reset local data.
- Test weekly training completion persistence.
- Test weekly persistence check history.
- Test premium lock states after relaunch.
- Test comment create, edit, delete, like, unlike, and report.

## Submission Assets
- App icon
- Today screenshot
- Training calendar screenshot
- Mobility screenshot
- Community screenshot
- Paywall screenshot
- Privacy questionnaire answers
- App description and keyword set
- Review notes for Apple sign-in, subscriptions, and delete-account flow
