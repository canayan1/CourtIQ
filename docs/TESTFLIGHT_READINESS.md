# TestFlight Readiness — Current State

**Audit date:** May 2026
**Bundle ID:** `com.canayan93.courtiq`
**Version:** 1.0 (build 1)

This doc is the single source of truth for "what's done vs. what's left" before we can ship a TestFlight build. The big checklist in `BETA_LAUNCH_CHECKLIST.md` describes the full journey; this one says where we are right now.

---

## ✅ Done (code + project — no user action needed)

### Core architecture
- 5 tabs working: Today, Practice, Community, Training, Matches, Profile
- Full SwiftUI app structure, builds clean on iOS 17+ simulator and physical iPhone (iOS 26)
- All 12 managers wired into `CourtIQApp.body` as environment objects

### Pivot features (post-Begum feedback)
- **Daily Court Tap Drill** (15 scenarios + animation + reveal + shareable emoji result)
- **Match Journal + Quick Log** (long-form entries + 4-rating quick check-in)
- **Match Calendar + Trend Dashboard** (Swift Charts, locked until 5 entries)
- **Three Rings** (Drill / Match / Mobility) + Triple Ring Day tracker
- **Tennis Avatar** (procedural — 5 customization categories, 23 unlockable items)
- **Pro Shot of the Day** (15 hand-authored animated pro patterns, Wordle-style rotation)

### Visual identity
- Tennis design system (`TennisVisuals.swift`): TennisBall, Racket, CourtPerspective, CourtTopDown, TrajectoryArc, StreakRing, TennisGlyph (11 sport glyphs)
- Quiz court diagrams (per-question, 30 hand-authored)
- App icon Contents.json with 18 size slots

### Text reduction (72% across 6 screens per designer-agent spec)
- TodayView (greeting cut, streak pills icon-only)
- OnboardingView (subtitles cut, body shortened)
- TrainingProgramDetailView (timeline icons replace text headers, banners removed)
- MobilityFlowDetailView (section headers → icon timeline, sequence numbered)
- QuizView (per-option footnotes cut, share cards collapsed)
- ProfileView (50%, capped by App Store legal requirements)

### Legal + compliance
- `PrivacyInfo.xcprivacy` manifest (Apple requirement since May 2024)
- Privacy Policy + Terms + Health Disclaimer + Support hosted on GitHub Pages: `https://canayan1.github.io/CourtIQ/`
- Info.plist privacy URLs filled (`COURTIQ_PRIVACY_URL`, `COURTIQ_TERMS_URL`, `COURTIQ_SUPPORT_URL`)
- Paywall has in-app legal fallback (works even if URLs go down)
- Ireland-aligned ToS with EU/UK consumer-rights carve-outs
- Sole-trader-friendly entity language (placeholders still need filling)
- `HealthAcknowledgmentView` modal blocks access until user explicitly accepts assumption-of-risk
- `TrainSafelyBanner` on every training + mobility detail
- `LSApplicationCategoryType = public.app-category.sports`

### Quality / infra
- Hardcoded prices removed (StoreKit `displayPrice` only)
- Deceptive "Start 7-day free trial" CTA in onboarding fixed (no longer pretends to start a purchase)
- `CrashReporter` (MetricKit, native, zero SPM) wired in `CourtIQApp.init`
- `FeedbackComposer` with pre-filled device/build/iOS info (Profile → Beta feedback)
- `NotificationManager` with soft pre-ask after first quiz completion + daily 09:00 reminder
- `Haptics` (warmup + 6 surfaces) used across drill, training save, celebrations
- Streak grace day (1 missed day tolerated) — for both quiz and match log streaks
- Onboarding skip bug fixed (no longer auto-completes from restored Keychain identity)
- SIWA cancellation gracefully suppressed (no false error alert)

### Bundle + signing (Personal Team — works for sideload, NOT for TestFlight)
- `DEVELOPMENT_TEAM = DC8ALPY949` (Personal Team)
- `PRODUCT_BUNDLE_IDENTIFIER = com.canayan93.courtiq` (registered to Personal Team)
- App installs and runs on physical iPhone via Xcode + `devicectl`

---

## ⏳ Remaining manual work — must complete before TestFlight upload

### Phase A — Apple ecosystem setup (you, ~1 hour total)

1. **Switch Xcode to the paid Apple Developer Program team**
   - Xcode → Settings → Accounts → `canayan93@gmail.com` → Download Manual Profiles
   - Or: remove the Apple ID + re-add it (forces fresh team list sync)
   - Expected result: a second team appears alongside "can ayan (Personal Team)" — something like "can ayan (Individual)" or "Can Ayan"

2. **Get the paid team ID** — needed to update `DEVELOPMENT_TEAM` in pbxproj
   - In Xcode Accounts panel, click the paid team name → ID is shown in the team detail
   - Send me the ID, I'll do the pbxproj swap (currently set to `DC8ALPY949` — Personal Team)

3. **Sign Paid Apps Agreement** in App Store Connect
   - https://appstoreconnect.apple.com → Agreements, Tax, and Banking
   - Required before any TestFlight upload will be accepted

4. **App Store Connect — create the App record**
   - Name: `CourtIQ: Tennis IQ & Training` (or alternative — see App Store metadata doc)
   - Primary language: English (US)
   - Bundle ID: `com.canayan93.courtiq`
   - SKU: `courtiq-ios-001` (anything unique to your account)
   - Category: Sports (Primary), Health & Fitness (Secondary)

5. **In App Store Connect → app → Sign in with Apple capability** — confirm enabled at the App ID level
   - Required because `Sign in with Apple` is in `CourtIQ.entitlements`

6. **StoreKit products** (for premium subscription — can do AFTER first TestFlight upload)
   - `com.canayan93.courtiq.premium.monthly`
   - `com.canayan93.courtiq.premium.yearly`
   - Both in same subscription group: `premium_all_access`
   - "Ready to Submit" status, with prices in your storefront

### Phase B — Sole trader entity placeholders (you, ~5 min after info is ready)

These three string placeholders in `docs/PRIVACY_POLICY.md`, `docs/TERMS_OF_USE.md`, and `docs/SUPPORT.md` need filling in:
- `[Your Legal Entity Name]` → e.g. `Can Ayan trading as CourtIQ` (sole trader) or `CourtIQ Limited` (if you form a Ltd later)
- `[Your Registered Address, Ireland]` → your Irish registered address with Eircode

Once you send me the values, I'll do a 30-second find-and-replace + push to GitHub Pages.

### Phase C — Mailbox infrastructure (you, ~5 min via Cloudflare Email Routing)

Three aliases on the `courtiq.app` domain pointing to your personal inbox:
- `info@kalibrefin.com`
- `info@kalibrefin.com`
- `info@kalibrefin.com`

If you don't own `courtiq.app` yet — buy at Namecheap or Cloudflare ($12/yr). Without these, App Store review will mark the privacy contact as broken.

### Phase D — Screenshots + App Store metadata (you + me, ~3 hours)

See `docs/APP_STORE_METADATA.md` (rewrite is on my todo list — will land in the next iteration).

Required for App Store submission (NOT for TestFlight Internal Testing):
- 6.7" iPhone screenshots (5-10 frames)
- 6.1" iPhone screenshots (5-10 frames)
- App Store description (4,000 char max)
- Keywords (100 char max)
- Promotional text (170 char max)
- Preview video (15-30s, optional but boosts conversion ~3x)

For TestFlight beta only, screenshots aren't required.

---

## 🟢 First TestFlight upload — the actual click-through

Once Phase A items 1-5 are done, the upload path is:

```
1. Update Info.plist if needed (build number bump usually auto)
2. Xcode → Product → Archive (clean release build)
3. Organizer opens → "Distribute App" → "App Store Connect" → "Upload"
4. Wait 5-15 min → build appears in App Store Connect → TestFlight tab
5. Fill "Test Information":
   - What to test: copy from `docs/BETA_LAUNCH_CHECKLIST.md` Phase 1
   - Feedback email: info@kalibrefin.com
   - Marketing URL: https://canayan1.github.io/CourtIQ/
   - Privacy Policy URL: https://canayan1.github.io/CourtIQ/PRIVACY_POLICY
6. Add yourself as Internal Tester → install via TestFlight app on iPhone
7. Smoke-test: onboarding → drill → match log → ring close → avatar locker
8. If green, add 3-5 close friends as Internal Testers (max 100)
```

After internal testing settles (~3-5 days), promote to External Testing for the public-link beta — see `BETA_LAUNCH_CHECKLIST.md` Phase 2.

---

## Critical risks to know about

1. **Personal Team is hard-blocked from TestFlight upload.** No workaround. Must switch to paid team first.

2. **Bundle ID `com.canayan93.courtiq` is currently registered to Personal Team.** When switching to paid team, Xcode usually handles re-registration automatically — but if it complains, the manual fix is to register the bundle ID in the developer portal under the paid team before archiving.

3. **App Store Connect "Sign in with Apple" capability must be enabled at App ID level.** If you skip step 5, SIWA will silently fail at runtime.

4. **First TestFlight upload triggers a lightweight beta review** by Apple (24-48h, not the full App Store review). Almost always passes — the main triggers for rejection are missing privacy URL, no public app description, or hardcoded debug content. We're clean on all three.

5. **`docs/PRIVACY_POLICY.md` placeholders are visible** to anyone who hits the published URL. Filling in the legal entity name before TestFlight is recommended (review reads it).

---

## Tl;dr — what unblocks the first TestFlight build

Three things must happen in this order:
1. **You** switch Xcode to the paid Developer Program team and send me the team ID
2. **You** sign the Paid Apps Agreement in App Store Connect
3. **You** create the app record in App Store Connect

I'll do the pbxproj update, archive, upload, fill in test info. From the moment those 3 items are done, first internal TestFlight build can be live within ~1 hour.
