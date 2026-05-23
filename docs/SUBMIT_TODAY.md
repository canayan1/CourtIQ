# Submit Today — Step-by-Step

This is the operational checklist for submitting CourtIQ to App Store in one sitting. Estimated total time: **90-120 minutes** including App Store Connect setup, screenshots, and the final submit click. Apple review takes 24-48h after submit; that part is not in your control.

Bundle: `com.canayan93.courtiq` · Version 1.0 (2)

---

## Phase 1 — Unblock (you, 5 min)

These two pieces of info from you, then I do everything in pbxproj + docs.

### A. Paid Apple Developer Team ID

In Xcode: `Settings → Accounts → canayan93@gmail.com → Download Manual Profiles`. A second team should appear next to "can ayan (Personal Team)". Click it. **Team ID** is the 10-character string in the right pane.

```
Paste here: __________________
```

### B. Sole-trader entity name + Eircode address

Goes into Privacy Policy / Terms of Use / Support docs (3 placeholders each). Visible to App Review and to users who click your privacy link.

```
Entity name: __________________
(suggestion: "Can Ayan trading as CourtIQ" — simplest sole-trader format)

Registered address: __________________
(street + city + county + Eircode like D02 X285)
```

Once you paste both, I:
1. Update `DEVELOPMENT_TEAM = <your team ID>` in pbxproj
2. Find-and-replace placeholders in `docs/PRIVACY_POLICY.md`, `docs/TERMS_OF_USE.md`, `docs/SUPPORT.md`
3. Commit + push → GitHub Pages auto-updates in 1-2 min
4. Verify all 5 legal URLs return 200

---

## Phase 2 — App Store Connect setup (you, 20-30 min)

These are pure UI clicks in App Store Connect. I can't do them — no API for app creation.

### 1. Sign Paid Apps Agreement
- https://appstoreconnect.apple.com → **Agreements, Tax, and Banking**
- Sign the "Paid Apps Agreement"
- Tax info → fill in (W-9 if US-tax-treaty-Ireland, otherwise local equivalent — your accountant or Apple's helper will guide)
- Banking info → IBAN of your business account

### 2. Create the app record
- App Store Connect → **My Apps** → **+** → **New App**
- **Platform:** iOS
- **Name:** `CourtIQ` *(if taken, try `CourtIQ Tennis Mind` or `CourtIQ — Tennis IQ`)*
- **Primary language:** English (U.S.)
- **Bundle ID:** select `com.canayan93.courtiq` from the dropdown
  - If it's not there, you need to register it first: https://developer.apple.com → Certificates → Identifiers → `+` → Bundle ID with that name
- **SKU:** `courtiq-ios-001` (any unique string for your account)
- **User Access:** Full Access

### 3. App Information
- **Subtitle:** `Train your tennis mind`
- **Category Primary:** Sports
- **Category Secondary:** Health & Fitness
- **Content Rights:** ✓ "I own or have licensed all content"

### 4. Pricing and Availability
- **Price:** Free
- **Availability:** All territories (or limit to TR + EU + US + UK if you want to start small — your call)

### 5. Confirm App ID capabilities (developer.apple.com)
- Certificates, Identifiers & Profiles → Identifiers → click `com.canayan93.courtiq`
- Scroll to Capabilities → ensure **Sign in with Apple** has a checkmark
- If not, check it → Save

---

## Phase 3 — Screenshots (you, 30-45 min)

App Review **requires** screenshots for the device sizes you select to support. Minimum: iPhone 6.7" (`1290 × 2796`). Strongly recommended: also iPhone 6.1" (`1290 × 2796` works for both — same dimensions in the modern lineup).

### Easiest path: simulator capture + light overlay

For each of these 6 screens, in the simulator:
1. Navigate to the screen
2. `cmd+s` to save screenshot (lands on Desktop)
3. Rename to match the order below

**Order matters** — first 3 are visible on the search-results card. Lead with the unique-format hooks.

| # | Screen | How to reach |
|---|---|---|
| 1 | Daily Court Drill mid-game | Today → Daily Drill → Start → after first tap |
| 2 | Pro Shot animation playing | Today → Pro Shot card → middle of animation |
| 3 | Three Rings (all closed) | Today screen with all 3 rings filled — needs you to complete the drill + log a match + open mobility once |
| 4 | Match Journal entry detail | Matches → existing entry tap |
| 5 | Avatar Locker Room | Profile → tap avatar card |
| 6 | Training program detail | Training → tap a program → scroll mid-page |

If you want text overlays (recommended, ~2x conversion): drop the screenshots into Figma, use a parchment-colored backdrop, add the captions from `docs/APP_STORE_METADATA.md` in `SF Pro Rounded Heavy` 36pt at the top 20%.

Upload via App Store Connect → `1.0 Prepare for Submission` → Screenshots section.

---

## Phase 4 — Metadata (you, 10 min)

Copy-paste from `docs/APP_STORE_METADATA.md`:

- **Promotional Text** (170 chars max — editable any time without review)
- **Description** (English) — paste the full block from the doc
- **Description** (Turkish) — paste the TR block under the Turkish locale
- **Keywords** (100 chars max)
- **What's New in This Version** — paste the v1.0 changelog
- **Marketing URL:** `https://canayan1.github.io/CourtIQ/`
- **Support URL:** `https://canayan1.github.io/CourtIQ/SUPPORT`
- **Privacy Policy URL:** `https://canayan1.github.io/CourtIQ/PRIVACY_POLICY`

---

## Phase 5 — App Privacy survey (you, 5 min)

App Store Connect → `App Privacy` → Get Started

Match `docs/APP_STORE_METADATA.md` `App Privacy` section. Quick summary:

- **Data Used to Track You:** None
- **Data Linked to You:** Email, Name, User ID, Purchase History, Product Interaction
- **Data Not Linked to You:** Crash Data, Performance Data

Every data type → tick "Used for App Functionality" only (no advertising, no analytics-sharing). User ID and Email are also "Linked to user's identity" because they come from Sign in with Apple.

---

## Phase 6 — Age Rating (you, 2 min)

App Store Connect → `Age Rating` → fill in the questionnaire.

All answers: **None / No** except:
- **Medical/Treatment Information:** Infrequent/Mild *(training programs include intensity guidance)*
- **User-Generated Content:** Infrequent/Mild *(community comments on daily tip — moderated)*

Result: **4+**

---

## Phase 7 — Upload the build (me, 15-20 min after your Phase 1 reply)

I'll do these as soon as you give me the team ID:

```bash
# 1. Update pbxproj DEVELOPMENT_TEAM
# 2. Archive
xcodebuild \
  -scheme CourtIQ \
  -destination 'generic/platform=iOS' \
  -archivePath /tmp/CourtIQ.xcarchive \
  -allowProvisioningUpdates \
  clean archive

# 3. Export for App Store
xcodebuild -exportArchive \
  -archivePath /tmp/CourtIQ.xcarchive \
  -exportPath /tmp/CourtIQ-export \
  -exportOptionsPlist /tmp/ExportOptions.plist \
  -allowProvisioningUpdates

# 4. Upload to App Store Connect
xcrun altool --upload-app \
  -f /tmp/CourtIQ-export/CourtIQ.ipa \
  -u canayan93@gmail.com \
  -p "<app-specific-password>"
```

You'll need an **app-specific password** for step 4: appleid.apple.com → Sign-In and Security → App-Specific Passwords → Generate (label it `CourtIQ ASC upload`). Give me that string and I run the command.

Alternative: I tell you "build ready at `/tmp/CourtIQ.xcarchive`" and **you** open Xcode → Organizer → click the archive → **Distribute App** → App Store Connect → Upload. Same outcome, you click through the UI yourself. 5-min walkthrough.

---

## Phase 8 — Build appears on App Store Connect (~10 min after upload)

- Apple processes the IPA, scans for malware, verifies signing
- You'll get an email when it's "Ready to Test"
- The build will appear under `TestFlight → Build numbers` and also become selectable under `1.0 Prepare for Submission → Build`

### Pick it as the v1.0 build
- App Store Connect → `1.0 Prepare for Submission`
- Scroll to **Build** → click **+** → select the just-uploaded build (`1.0 (2)`)
- Save

---

## Phase 9 — Review notes (you, 5 min — critical for first-time)

App Store Connect → `1.0 Prepare for Submission` → **App Review Information**

```
Sign-in required: Yes — but a Guest mode is also available

Demo account: (not required since Guest mode works,
but if you want to enable SIWA testing for the reviewer,
provide a sandbox Apple ID — App Store Connect → Sandbox →
Testers → Create a test sandbox account)

Notes:
CourtIQ is a tennis IQ training app. Reviewers can either tap
"Continue as guest" on the Account screen to bypass sign-in,
or sign in with their own Apple ID (no email required since
SIWA supports hide-my-email).

Premium subscription is gated behind Sign in with Apple per the
App Store guideline. Restore Purchases is visible on both the
paywall and Profile.

The Daily Court Drill, Pro Shot of the Day, Match Journal,
Three Activity Rings, and Avatar customization are all available
for free. Premium unlocks additional training programs and the
full mobility library.

Data collection: Email, Name (optional), User ID, Purchase
History, Product Interaction — all "Used for App Functionality"
only. No third-party tracking. Privacy manifest declares
UserDefaults, FileTimestamp, SystemBootTime, DiskSpace categories.

Contact: canayan93@gmail.com
```

---

## Phase 10 — Submit (you, 1 click)

App Store Connect → `1.0 Prepare for Submission` → **Submit for Review** button at the top.

You'll get a confirmation email. Review status will be:
- **Waiting for Review** (usually 12-24h)
- **In Review** (1-12h, sometimes more)
- **Approved** or **Rejected** with reasons

Average first-submission review time today: **24-36 hours**. If rejected, the reasons are surgical (single-line fixes most of the time). You re-submit after fixing.

---

## What's next after approval

- App goes live based on your selected release option (Automatic = immediately on approval; Manual = your click; Scheduled = a date you pick)
- Real users can download
- Watch for crashes in App Store Connect → Analytics → Crashes
- TestFlight remains usable for testing fixes before submitting v1.0.1

---

**Net the minimum from you to start Phase 7 (the actual upload):**

```
1. Paid Team ID
2. Entity name + Eircode
3. App-specific password (for me to upload via altool — optional, can do via Xcode Organizer too)
```

Send the first 2 and I'll proceed. App-specific password optional.
