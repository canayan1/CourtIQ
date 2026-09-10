# Coach Review — activation roadmap

*Written 10 Sep 2026 from a verified audit of the live system, not from the
earlier docs. `COACH-REVIEW-PLAN.md` is the why, `-POLICY.md` the video
rights, `-MVP.md` the multi-coach operating model. This is the ordered list
of what has to be true before the feature is promoted to a single paying
player, and what must not be touched until then.*

---

## 0. Where it actually is (verified 10 Sep)

| Thing | State | How verified |
|---|---|---|
| IAP `com.canayan93.courtiq.coachreview1` (consumable, $19.99) | **APPROVED, on sale in production** | ASC API |
| Buy path in the shipping app (1.1) | **LIVE** on the swing *result* screen whenever StoreKit returns the product | `SwingAnalysisView.canOrder` |
| Store listing | says the review "is coming; the waitlist is inside" | ASC en-US description |
| Orders ever placed | **0** | `coach_review_orders` is empty (remote query) |
| Backend (`coach-review-order`, `coach-review-queue`, migration, private bucket) | deployed, ACTIVE | `supabase functions list` |
| Coach panel https://samosfi.com/coach | HTTP 200, shared password | curl + `route.ts` |
| Panel secret / password files on disk | both present, secret matches the deployed digest | sha256 compare, values never printed |
| Localisation of the flow | 64 keys × EN/TR/FR | `.strings` count |
| Coaches on the roster | 0 rows (Can is implicit; the table is empty) | remote query |

So: the product page says *coming*, the app sells it, nobody has bought,
and three of the pieces a buyer would then need do not exist. That is a
lucky state — the defects below are latent, not live incidents — and the
whole point of this document is to keep it that way until they are fixed.

---

## 1. The three defects that would hurt the first buyer

Ordered by damage. None is hypothetical; each is a line in the code.

### 1a. A failed upload after payment loses the money — silently

`CoachReviewManager.purchaseAndSubmit` deliberately does **not** call
`transaction.finish()` until the order row exists, so that a failed upload
leaves the transaction unfinished and StoreKit re-delivers it. Correct idea.

But `UserSession.startListener()` runs a generic `Transaction.updates`
loop that **finishes every verified transaction it sees**, subscriptions and
consumables alike (`UserSession.swift:518-521`). The consumable purchase
arrives there too. So on the failure path — network drop, clip over the
~19 MB cap (413), function 5xx — the safety net is cut: the player is
charged, no order exists, nothing will ever retry, and the app shows
nothing. Apple would refund on request; the player has no idea what
happened.

**Fix (app, small):** the generic listener skips the coach-review product
id; `CoachReviewManager` owns those transactions end to end. On every launch
it walks `Transaction.unfinished`, and for any coach-review transaction with
no matching local order it shows a "your review is still uploading" card
and resubmits the clip (the clip URL must therefore be persisted alongside
the pending transaction id). Only after the server returns an order id does
`finish()` run.

### 1b. The delivered review is unreachable

`CoachReviewDeliverableView` exists, renders the One Thing format, plays the
voice note — and is constructed **nowhere**. `CoachReviewManager.refresh(
session:)` — the only code that pulls order status and the deliverable from
the server — is **called nowhere**. This was true in the P0 commit
(d7eb21d), not something the 1.1 restructure removed. The only post-purchase
screen a player can reach is "Sent — we'll be back within 72 hours".

So a delivered review would sit in Supabase with no way for the player to
see it. Combined with no push, the player would not even know it arrived.

**Fix (app):**
- a status card on the Coach tab root **and** Home while an order is open
  or delivered-unseen (`activeOrder` already computes this);
- `refresh(session:)` on app foreground and on the Coach tab appearing;
- the card opens `CoachReviewDeliverableView` when delivered;
- a local notification scheduled at delivery time is not possible (the app
  learns on foreground), so the honest copy is "open the app to check" and
  the SLA countdown on the card. Push is P1.

### 1c. The server trusts the client about the purchase

`coach-review-order` stores `transactionId` as an audit string and creates
the order for any authenticated Supabase user who posts a clip. Nothing
checks the transaction with Apple, and nothing stops the same id being
reused. Any signed-in user who calls the function gets a free $19.99
review; a coach's time is the cost.

**Fix (backend):** verify the StoreKit 2 JWS (`transaction.jwsRepresentation`
sent by the app; the function checks Apple's signature chain, the bundle id,
the product id, and that the environment is Production for prod), and a
unique index on `iap_txn_id`. Reject → 402, and the app then keeps the
transaction unfinished for 1a's retry path.

---

## 2. What the consent screen promises and the system does not do

The order screen (policy §2) makes four promises. Two are kept by the
existing design (stream-only signed URLs; RLS). Two are not implemented:

| Promise on screen | Reality | Fix |
|---|---|---|
| "Original video auto-deletes 90 days after delivery" | `purge_video_at` is stamped; **nothing reads it**. No cron, no function. | Scheduled edge function (daily): delete objects + null `video_path` where `purge_video_at < now()`. Also honour user account deletion (cascade exists at DB level; storage object does not cascade — the function must handle it). |
| "Their access ends when your review is delivered" | Signed URLs are 2 h TTL, so access lapses; but a URL minted just before delivery outlives it, and nothing revokes on the `delivered` flip. | Acceptable at P0 with TTL → 30 min (MVP §2). Log every mint (`coach_access_log`) so the claim is auditable. |

Until 2a exists the consent copy is false. It is a one-day fix and it is
blocking, because the policy doc made retention a *promise*, not a goal.

---

## 3. Legal text that has to exist before the first sale

Found by reading the published documents, not the plans:

- **Privacy policy: zero mention of human review.** A certified coach
  watching an identifiable video is a new processing purpose, a new
  recipient category ("independent coaches under contract"), a new
  retention period, and — for a Turkish coach reviewing an EU player — a
  transfer. Policy §6 listed this; it was never done. *(Can, with the
  lawyer's pass on wording; I can draft.)*
- **Terms of Use: no paid-review clause.** Needs: what is delivered (the
  One Thing format), 72 h target and what happens if missed, refunds are
  Apple's (already stated generally), 18+, the coach is an independent
  contractor and the review is opinion, re-review as the remedy before a
  refund request. *(Can + lawyer; I can draft.)*
- **App Privacy labels** — "User Content: video, linked to identity, shared
  with service providers". Web UI only. *(Can.)*
- **Coach agreement** — not needed while Can is the only coach reviewing
  his own users' clips, but the privacy policy's processor language has to
  be true from day one. Needed before coach #2 signs in.
- **Review language disclosure.** The French launch makes this concrete: a
  French player will receive a review in English or Turkish. That must be
  on the order screen before the price, or it is a refund every time.

---

## 4. Operational readiness (Can's side, not code)

- **Capacity.** One coach, a 72 h clock, and no assignment. The order
  function should refuse (→ the app falls back to the waitlist card) above
  N open orders, N chosen by Can — 5 is honest for a part-time solo coach.
  Without this, a small ad spike converts straight into SLA breaches.
- **SLA alarm.** Nothing alerts anyone. A daily scheduled function that
  emails Can any order with < 24 h left, and any order past due, is the
  minimum. The panel already colours < 12 h red, but only if opened.
- **Sandbox run on a real device, before flipping anything:** sandbox
  tester → buy → pull Wi-Fi mid-upload → relaunch → the retry card appears
  → order lands → deliver from the panel → foreground → card → deliverable
  → voice plays. Every step of that is a fix from §1; the run is the proof.
- **StoreKit test config** (`CourtIQ.storekit`) does not contain the
  consumable, so the simulator has *never* shown the Buy path — which is
  how the 1.1 restructure QA missed §1b. Add the product to the config so
  the sim exercises the whole flow.

---

## 4a. Deploy runbook for Step 1 (needs the words "deploy et")

Everything below is built and committed; nothing is deployed. Run in this
order — the migration schedules a cron job that reads a Vault secret, so
the secret must exist before 03:17 UTC of the first day.

```bash
# 1. schema + cron (pg_cron, pg_net, unique txn index, access log, language)
supabase db push --linked

# 2. the maintenance secret into Vault (value read from disk, never typed)
supabase db query --linked "select vault.create_secret('$(tr -d '\n' < ~/.appstore-keys/coach_maintenance_secret.txt)', 'coach_review_maintenance_secret');"

# 3. function secrets (same file for the function side; cap and sandbox flag)
supabase secrets set COACH_MAINTENANCE_SECRET="$(tr -d '\n' < ~/.appstore-keys/coach_maintenance_secret.txt)" COACH_REVIEW_MAX_OPEN=5 COACH_REVIEW_ALLOW_SANDBOX=1

# 4. functions
supabase functions deploy coach-review-order
supabase functions deploy coach-review-queue --no-verify-jwt
supabase functions deploy coach-review-maintenance --no-verify-jwt

# 5. the panel (repo canayanIOSapps)
cd /Users/can/Projects/canayanIOSapps && vercel deploy --prod
```

`COACH_REVIEW_ALLOW_SANDBOX=1` stays on for Step 3 (the device test) and is
set back to `0` at Step 4. With it on, a sandbox receipt can create an
order; with it off, only a production one can.

Smoke test after deploy, before touching the app: `curl` the maintenance
function with the secret → `{ purged: 0, open: 0, ... }`; post to the
order function with a garbage `transactionJws` → `402 { error: "purchase" }`.

## 5. Order of work

**Step 0 — decide the exposure now (Can). ✅ 10 Sep: IAP set
`DEVELOPER_REMOVED_FROM_SALE`.** The Buy button is live to real
users today with §1a unfixed. Two honest options:

- *(a)* Temporarily remove the IAP from sale in all territories (ASC
  availability, no review needed, reversible). `Product.products` then
  returns nothing and the app falls back to the waitlist by itself — no
  release, no dead button, no money-loss path. Recommended.
- *(b)* Leave it. Zero orders in three weeks says the exposure is small.
  A single buyer with a bad upload is the cost.

**Step 1 — the three app/backend fixes (§1a, §1b, §1c) + retention cron
(§2) + capacity cap + SLA visibility (§4).** ✅ Built and committed 10 Sep
(292f3ea app, 0f8b5e4 backend, panel 3b1aade). Not yet deployed — §4a.
SLA *mail* was dropped for now: no mail provider is configured; the panel
banner and the daily digest cover it until one is.

**Step 2 — legal text (§3).** Drafts committed 10 Sep (privacy §2a, terms
§3a). Wording sign-off from Can / lawyer, published to the GitHub Pages policy + ToS before submission, App
Privacy labels updated in the web UI. Blocking for the App Store review as
much as for the law: the review screenshot of a consumable that shares
video with a person, next to a privacy policy that never mentions a person,
is a 5.1.1 question waiting to be asked.

**Step 3 — the sandbox run (§4).** On the iPhone, end to end, both failure
and success paths. Nothing is "activated" until this has been done once.

**Step 4 — flip.** Restore IAP availability (if pulled), submit 1.2 with
the store description changed from "is coming" to what it is, the French
listing attached, and the review language stated on the order screen.

**Step 5 — after the first ten reviews.** Only then the MVP doc's P1:
assignment, magic-link auth, delivery gates, rating loop, push.

---

## 6. Do not

- Do not add a second coach, a tier, or a name to the roster before §1c and
  §3 — the shared-password panel means every coach sees every clip, and the
  privacy policy does not yet admit a human exists.
- Do not promote the feature (ads, IG, store text "live") before Step 3.
- Do not "fix" §1a by having the server refuse orders: with the listener
  bug in place, any server-side refusal is exactly the money-loss path.
- Do not put a review count, a rating, or "coaches" plural anywhere in the
  product until they are real (App Store 2.3.1; house rule).
- Do not echo the panel secret or password; both live only in
  `~/.appstore-keys/` and in the deployed environments.
