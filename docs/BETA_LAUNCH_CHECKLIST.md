# TestFlight Beta Launch Checklist

A linear, do-it-in-order list for getting CourtIQ into 200–500 beta testers' hands.

Estimate: ~3 weeks of part-time work, top-to-bottom.

---

## Phase 0 — Prerequisites (do this first)

- [ ] **Apple Developer Program** active ($99/year, must be paid)
- [ ] App Store Connect access confirmed
- [ ] App record created in App Store Connect:
  - Name: `CourtIQ: Tennis IQ & Training`
  - Bundle ID: matches Xcode project
  - Primary language: English
  - Category: Sports (Primary), Health & Fitness (Secondary)
- [ ] Bundle ID + provisioning profile working in Xcode (Archive succeeds)
- [ ] **In-app feedback button** wired up (already implemented in Profile)
- [ ] **CrashReporter.start()** wired in `CourtIQApp.init` (already done)
- [ ] **Privacy Policy** and **Terms of Use** published to a public URL (use `docs/PRIVACY_POLICY.md` and `docs/TERMS_OF_USE.md` as starting drafts)
  - Easy hosting options: GitHub Pages, Notion (toggle "Share to web"), Vercel, Carrd
  - Update placeholder fields: `[Your Legal Entity Name]`, `[Your Address]`, `[Your Jurisdiction]`, `feedback@courtiq.app`, `privacy@courtiq.app`, `support@courtiq.app`
- [ ] Email addresses (`feedback@`, `privacy@`, `support@courtiq.app`) actually receive mail (or alias them to your personal inbox)

---

## Phase 1 — Internal testing (Day 1–7)

- [ ] In Xcode: `Product → Archive` produces a clean build (no warnings about missing entitlements)
- [ ] Upload to App Store Connect via Organizer → Distribute App → App Store Connect → Upload
- [ ] Wait 5–15 minutes for build to appear in App Store Connect → TestFlight tab
- [ ] Fill in **Test Information**:
  - Beta App Description (short, what testers should focus on)
  - Beta App Feedback Email: `feedback@courtiq.app`
  - Marketing URL: your landing page (or `https://courtiq.app`)
  - Privacy Policy URL: the one you published
- [ ] Add Internal Testers (max 100): yourself + 3–5 closest friends/colleagues
- [ ] Build dispatched to internal testers — instant, no Apple review
- [ ] **Verify on at least 2 physical devices** (one new, one old) before going external
- [ ] Fix any P0 crashes that show up in TestFlight Crashes panel

## Phase 2 — Public link prep (Day 7–10)

- [ ] In App Store Connect → TestFlight → External Testing, create group: `Public Beta`
- [ ] Add latest build to that group → triggers **Beta App Review** (24–48h, lighter than full App Store review)
- [ ] **Approval**: enable **Public Link** toggle on the group
- [ ] Set max testers: **500** initially
- [ ] Copy the public link: `https://testflight.apple.com/join/XXXXXXXX`
- [ ] Test the link from a clean device — full join flow works end to end
- [ ] **Welcome email** automation (Loops.so / Buttondown / EmailOctopus, free tier):
  - Trigger: form submission on your landing page
  - Content: TestFlight link + "what to focus on" + reply path

## Phase 3 — Channel-by-channel push (Day 10–28)

### Inner circle (Day 10–12) — easiest wins, ~50 testers
- [ ] WhatsApp: 3–5 court groups, personal message ("yaptığım app'i deneyin")
- [ ] Personal LinkedIn / X / Instagram post (your own followers)
- [ ] Direct DM to 10 friends who actually play tennis

### Niche communities (Day 12–18) — ~50 testers
- [ ] Telegram: join 5+ Turkish tennis groups, contribute for a week before posting beta link
- [ ] Discord: search tennis servers, contribute, then share
- [ ] LinkedIn Sports / Tennis groups
- [ ] Instagram tennis hashtag engagement (#tenistürkiye #recreationaltennis #tennistips)

### Reddit (Day 18–25) — ~100–300 testers (the big push)
- [ ] **Pre-message r/tennis mods** asking about self-promo rules
- [ ] Polish post (use template in `INFLUENCER_OUTREACH.md`)
- [ ] Post Monday 09:00–11:00 ET
- [ ] Reply to **every comment** for the first 24 hours
- [ ] One week later: post in r/10s with different framing
- [ ] Optional: r/tennis-only subreddits in your country

### Influencer outreach (parallel, Day 10–28)
- [ ] Build the list of 20 (see `INFLUENCER_OUTREACH.md`)
- [ ] Send personalized DMs over 2 weeks (5/week, not all at once)
- [ ] Track replies in the spreadsheet
- [ ] Follow up once at day 7 if no reply

### Physical / local (Day 14–28) — ~30 testers, very high quality
- [ ] Print A4 with QR → TestFlight link, hang at 3–5 local courts
- [ ] Tennis pro shops, club bulletin boards
- [ ] Hand-deliver a card to your coach / club manager

---

## Phase 4 — Manage the beta (Day 14–42, ongoing)

- [ ] **Build cadence**: ship a new build weekly. Note in TestFlight "What to test" the new things.
- [ ] **Monitor crashes daily** in App Store Connect → TestFlight → Crashes (also check `CrashReporter` JSON in caches if needed)
- [ ] **Read every feedback email** within 24h. Reply personally — even just "thanks, on it".
- [ ] **Weekly tester pulse**: post in your Discord/Slack (or email) recapping what changed and what you need feedback on
- [ ] **Prune builds**: TestFlight tracks 90 days. Older builds expire automatically.
- [ ] **Consider a Discord/Slack** once you cross 100 testers — TestFlight feedback is one-way; community is two-way

---

## Phase 5 — Beta → App Store (Week 5–6)

- [ ] Final round of polish based on top 5 most-mentioned feedback items
- [ ] App Store screenshots (6.7" + 6.1" required, 5.5" optional)
  - Screenshot 1: Quiz court diagram (the unique visual)
  - Screenshot 2: 8-week training program with progression
  - Screenshot 3: Streak + IQ rating
  - Screenshot 4: Daily tip
  - Screenshot 5: Mobility flow detail
- [ ] App Store preview video (15–30s, sound-off)
- [ ] App description, keywords, support URL, marketing URL
- [ ] Submit for App Store Review
- [ ] Plan launch day announcement (Product Hunt, Reddit retro post, influencer asks for shares, personal social)

---

## Critical metrics to track during beta

Set a simple Notion/Google Sheet:

| Metric | Target | Why |
|---|---|---|
| TestFlight installs | 200–500 | enough volume to find bugs |
| D1 retention | >50% | onboarding works |
| D7 retention | >25% | core loop sticks |
| Median session length | >3 min | engagement is real |
| Feedback emails / week | >5 | testers are engaged enough to write |
| P0 crashes | 0 | ship blocker |
| Public link conversion (visit → install) | >15% | landing page / TestFlight Test Information copy is good |

---

## Things easy to miss

- TestFlight builds **expire after 90 days** — testers can't open old builds, you must keep shipping.
- You can have **10,000 testers via public link**, but individual builds count against quota only when installed.
- **Push notifications work in TestFlight** like production — set up your APNs key now, not later.
- **In-app purchases use sandbox** in TestFlight — real money isn't charged. Test the premium flow regardless.
- Build version (`CFBundleVersion`) must increment on every upload — Xcode does this automatically if you use `agvtool` or set "Generic Versioning System".
- App Store Connect throws a fit if Privacy Policy URL returns 404 — verify after publishing.
