# Submission Handoff — What I Need From You

When you have these pieces ready, paste them here (or in chat) and I'll do the rest in one pass. Everything else (pbxproj edits, doc updates, GitHub push, build verify) is automated on my side.

---

## 1. Paid Apple Developer Team ID  · ~1 min in Xcode

> Without this, TestFlight upload is hard-blocked. Personal Team can't upload.

**How to find it:**
1. Open **Xcode → Settings → Accounts** (`cmd+,`)
2. Select your Apple ID `canayan93@gmail.com` on the left
3. Click **"Download Manual Profiles"** in the bottom-right (forces a fresh team sync)
4. Wait 10-30 seconds — a new team should appear next to "can ayan (Personal Team)"
5. Click the **new team** (paid one, no "Personal Team" suffix)
6. The **Team ID** is visible in the panel — a 10-character string like `A1B2C3D4E5`

> If only Personal Team appears: remove the Apple ID via the **"−"** button, then re-add via **"+"** → Apple ID. Forces a full sync. Wait 30-60s for the paid team to surface.

**Send me:**
```
Paid Team ID: __________
```

I'll update `DEVELOPMENT_TEAM` in `CourtIQ.xcodeproj/project.pbxproj` (currently `DC8ALPY949` — Personal Team).

---

## 2. Sole-trader entity name + address  · ~2 min

> These fill in the legal-doc placeholders. Without them, App Store review reads `[Your Legal Entity Name]` on your public privacy URL and may flag it.

**Two name format options:**
- **Sole trader (no CRO registration)**: `Can Ayan trading as CourtIQ`
- **Sole trader + CRO-registered business name**: `Can Ayan trading as "CourtIQ" (CRO #12345)` — registering at cro.ie costs €20 and takes 5 min, but optional
- **Limited company (future)**: `CourtIQ Limited`

**Address**: your registered Irish address with Eircode.

**Send me:**
```
Legal entity name: __________
Registered address (with Eircode): __________
```

I'll do find-and-replace across `docs/PRIVACY_POLICY.md`, `docs/TERMS_OF_USE.md`, `docs/SUPPORT.md`, push to GitHub Pages, and the live URLs update in 1-2 minutes.

---

## 3. Domain + email aliases  · ~10 min if `courtiq.app` not yet bought

> App Store review will click `feedback@courtiq.app` to verify it works. Without a live mailbox, review may fail.

**If you don't own `courtiq.app`:**
- Buy from **Cloudflare Registrar** (~$12/year, easiest DNS) or **Namecheap**
- Add to Cloudflare nameservers

**Once domain is yours — Cloudflare Email Routing setup (5 min):**
1. Cloudflare dashboard → your domain → **Email** → **Email Routing**
2. Click **Enable Email Routing** (auto-adds MX + TXT records)
3. Create three custom aliases all pointing to your personal Gmail:
   - `feedback@courtiq.app` → `your.personal@gmail.com`
   - `support@courtiq.app` → `your.personal@gmail.com`
   - `privacy@courtiq.app` → `your.personal@gmail.com`
4. Verify your Gmail address (one-click via the verification email Cloudflare sends)
5. Send a test email to `feedback@courtiq.app` → should hit your inbox in seconds

**Send me when done:**
```
Domain mail working: yes ✓
```

(That's it — I don't need any IDs from this step. Once you confirm, I'll know the recipient address in `FeedbackComposer.swift` is live and review will pass.)

---

## 4. App Store Connect app record  · ~10 min in App Store Connect UI

> This is purely your action. I have no API access. Most fields are pre-decided in `docs/APP_STORE_METADATA.md`.

**Steps:**
1. Go to https://appstoreconnect.apple.com → **My Apps** → **+** → **New App**
2. Fill in:
   - **Platform**: iOS
   - **Name**: `CourtIQ` (or `CourtIQ: Tennis Mind` if `CourtIQ` is taken)
   - **Primary language**: English (U.S.)
   - **Bundle ID**: `com.canayan93.courtiq`
     - If the dropdown doesn't show it, you may need to register it first at developer.apple.com → Certificates → Identifiers → +
   - **SKU**: `courtiq-ios-001` (any unique string for your account; not visible to users)
   - **User Access**: Full Access
3. Click **Create**

**Then in the new app's record:**
4. **App Information** tab → **Category**: Sports (Primary), Health & Fitness (Secondary)
5. **App Information** → **Content Rights**: confirm you own all rights to the content
6. **Pricing and Availability**: Free (premium subscription handled separately via StoreKit)
7. **Agreements, Tax, and Banking** (sidebar): sign the **Paid Apps Agreement** — required even though the app itself is free, because you'll add a subscription later

**Send me when done:**
```
App Store Connect record created: yes ✓
Paid Apps Agreement signed: yes ✓
```

(Optional — I don't need anything from you here; just the confirmation. The app record needs to exist before any TestFlight upload will succeed.)

---

## 5. (Optional) Sign in with Apple capability — check at App ID level  · ~30 sec

> Already enabled in `CourtIQ.entitlements`. Need to confirm at the App ID level in Developer Portal.

**Steps:**
1. https://developer.apple.com → **Certificates, Identifiers & Profiles** → **Identifiers**
2. Find `com.canayan93.courtiq` (or the bundle ID in your paid team)
3. Scroll down to **Capabilities** → confirm **Sign in with Apple** has a checkmark
4. If not: check the box, click **Save** — Xcode will auto-pull the updated profile on next archive

**Send me when done:**
```
SIWA capability confirmed: yes ✓
```

---

## What happens once you send me back items 1–5

I will:

1. **Update `DEVELOPMENT_TEAM`** in pbxproj with your paid team ID (~1 line edit)
2. **Fill the 3 legal docs** with your entity name + address, commit + push to GitHub Pages (auto-deploys in 1-2 min)
3. **Bump `CFBundleVersion`** if needed for upload
4. **Archive** the build (`xcodebuild -archivePath ... archive`)
5. **Upload** to App Store Connect via `xcrun altool` or Xcode Organizer (your choice)
6. **Wait** ~10 min for Apple's processing
7. **You** add yourself as Internal Tester in App Store Connect → install via TestFlight on iPhone → smoke test

After ~1 hour from your last reply, you'll have a working internal TestFlight build on your phone, no Personal Team expiration hassle, ready for the 3-day internal-testing soak before external beta.

---

## What I can't do for you regardless

- Click through App Store Connect UI (no API for app creation)
- Sign the Paid Apps Agreement (legally requires your account)
- Buy a domain or set up Cloudflare DNS (requires your billing)
- Take final App Store screenshots (UI navigation flow — see `docs/APP_STORE_METADATA.md` for the 6-frame recipe; you'll do this in simulator + Figma)
- Submit for App Store Review (final review submission is your call, after TestFlight signals)

Everything else is on my side — just need your 5 items above.
