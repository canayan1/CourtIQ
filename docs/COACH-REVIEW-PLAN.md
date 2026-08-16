# Coach Review — real coaches, async video feedback (project plan)

*Drafted 24 Jul 2026. Status: PLAN — not committed to roadmap until the
interest gate (below) passes.*

## 1. Concept & positioning

**"Get your swing reviewed by a real coach."** Async video review: user uploads
(existing swing flow), a certified coach returns a voice-over + timestamped
notes within 72h. AI stays as the instant/cheap layer; the human review is the
premium anchor above it.

Why it fits us:
- Kills our biggest weakness (AI swing trust) by *not depending on it* — the AI
  pipeline (impact counting, stroke clips) becomes the coach's prep tool, not
  the product promise.
- Moat: marketplaces are hard to copy; content (coach clips) feeds the IG flywheel.
- Comps: Skillest (direct), OnForm/CoachNow (team tools), SwingVision (AI-only).
  Our wedge: integrated IQ ecosystem + AI-prepped review = faster coach turnaround
  = lower price than Skillest lessons.

## 2. Phases + the demand gate (build nothing heavy first)

| Phase | What | Trigger |
|---|---|---|
| **G0 Interest gate** | In-app card "Real coach review — notify me" (no charge, honest waitlist) + price shown ($14.99 intro). Measure taps. | Ship with 1.0.4/1.0.5 |
| **P0 Concierge (1-2 wk)** | 1-2 "Founding Coaches" (Can's network). Purchase = consumable IAP credit. Assignment/delivery MANUAL (Supabase dashboard + push). Deliverable: voice memo + text w/ timestamps, shown in a simple report screen. | Waitlist CTR ≥ ~8% of swing users OR 25+ signups |
| **P1 Productize** | Order queue, SLA timers, in-app deliverable player, ratings, refund flow. | ≥20 paid reviews, repeat ≥25% |
| **P2 Marketplace** | Coach profiles, user picks coach, coach sets price in bands, automated payouts. | ≥5 active coaches, supply-constrained |
| **P3 Live 1:1** | Realtime lessons (Apple 3.1.3(d) person-to-person realtime → external payment allowed). | P2 healthy |

## 3. Money: pricing, split, Apple

**Pricing (P0):** single review $19.99 (intro $14.99) · 3-pack $49.99.
Later: Premium+ sub ($24.99/mo incl. 1 review/mo).

**Apple:** async review is digital content consumed in-app → **IAP required**
(consumable "review credit", RevenueCat already in place). The realtime-P2P
exception does NOT cover async. US link-out entitlement is a later optimization.
With Small Business Program: Apple 15%.

**Split (of net after Apple):**
- Standard: **coach 70 / platform 30**
- Founding Coaches (first 6 mo): **80 / 20** + in-app + IG profile promotion
- Example: $19.99 → net ~$17 → coach ~$12–13.6. AI-prepped review target
  15–20 min coach time → **$36–55/h effective** — strong for TR coaches
  (USD income), viable part-time for EU/US coaches.

**Payouts:** monthly, manual at P0 via **Wise** (Stripe has no Turkey support;
Stripe Connect only if the platform entity moves abroad later). Ledger table
from day 1; coaches are independent contractors (invoice/receipt per local law
— TR coaches: serbest meslek makbuzu; get accountant sign-off).

## 4. Coaches: recruitment, vetting, agreement

**Recruit:** Can's Instagram tennis network (warm, credible), TR club coaches
(PTR/ITF/TTF certified — USD earnings attractive), tennis-coach FB groups /
r/10s. Pitch = "founding coach": better split, profile promo, weekly coach clip
on our IG (their marketing too → content flywheel).

**Vet:** certification proof + 1 sample review (we pay) scored against a rubric
(reuse swing checkpoint metrics from SWING-SYSTEM-DESIGN: preparation, contact
zone, kinetic chain, finish, footwork).

**Agreement (lawyer-reviewed template, one-time cost):**
- Independent contractor, non-exclusive; SLA 72h or auto-reassign
- **Confidentiality + DPA annex**: video = personal data; view-only, no
  download/redistribution/social posting; access ends at delivery
- Feedback IP licensed to user + platform (in-app display, anonymized promo
  only with explicit user opt-in)
- Conduct policy (no medical claims, no injury diagnosis — refer out), takedown
  + termination terms, quality floor (rating < threshold → offboard)

## 5. Privacy & legal (KVKK + GDPR + Apple)

- **Consent at upload:** explicit "a human coach will view this video" screen
  (separate from AI consent we already have), listing who/what/how long.
- **Third parties in frame:** user attests they have consent of visible persons
  (club-mate/opponent). No face-blur at MVP; on roadmap.
- **Minors:** launch **18+ for coach review** (age gate at order). Junior flow
  (verified parent orders for child) is P2 — do not improvise COPPA/KVKK-child
  compliance at MVP.
- **Storage:** Supabase Storage **private bucket**, signed URLs (short TTL),
  RLS on every table. Coach streams via expiring link.
- **Retention:** raw video auto-deleted 90 days post-delivery (user can delete
  anytime → cascades to coach access); deliverables kept in user's account.
- **Docs to update:** privacy policy (human review, processor list, retention),
  ToS (marketplace, refunds), **App Privacy labels** (video linked to user,
  user content shared with contractors) — web UI, user does it.
- Liability: fitness-advice disclaimer surfaced in ToS + delivery screen.

## 6. Backend (all on existing Supabase + one small web app)

**Tables** (`coach_*` namespace, RLS):
`coaches` (profile, certs, langs, split, payout_info, status) ·
`review_orders` (user, video_path, stroke, context, status:
submitted→assigned→in_review→delivered→closed, sla_due_at, iap_tx) ·
`review_deliverables` (order, voice_path, notes[{t, text}], rating) ·
`payout_ledger` (coach, order, gross/net, period, paid_at)

**Edge functions:** `coach-order-create` (validates RevenueCat webhook/receipt
→ credit → order), `coach-assign` (P0: manual flip), `coach-deliver`
(validates deliverable, fires push), `coach-payout-report` (monthly CSV for Wise).

**Coach surface:** NOT a second iOS app. Lightweight **Next.js dashboard on
Vercel** (Supabase auth, coach role): queue → stream video → record voice memo
(MediaRecorder) → timestamped notes → deliver. Mobile-browser friendly.

**AI prep (our unfair advantage):** on upload, existing pipeline attaches
impact count + per-stroke clips + Create ML labels + draft observations. Coach
starts from a prepared case file → 15-20 min instead of 40.

**App side (reuses everything):** order sheet on swing result screen ("Want a
real coach's eyes on this?"), order status card in Recent, deliverable player
(audio + synced timestamps over video), rating prompt.

## 7. Ops & quality

- SLA 72h; breach → auto-reassign + free credit apology.
- Refunds: no-questions within 24h of delivery at P0 (volume tiny, goodwill high).
- QC: first 3 reviews of every coach hand-checked; ongoing via user ratings +
  random sampling against the rubric.
- Support: single inbox (existing), macros for the 5 predictable cases.

## 8. Unit economics sanity (P0, per review)

| Item | $ |
|---|---|
| Price (intro) | 14.99 |
| Apple 15% | -2.25 |
| Coach (80% founding) | -10.19 |
| Storage/AI prep/push | -0.15 |
| **Platform margin** | **~2.40** |

Margin is thin at intro price by design (supply seeding + testimonials with
consent). Standard price + 70/30 → ~$5.8/review platform margin.

## 9. Risks (honest)

1. **Demand at ~0 installs** — why the G0 gate exists. Don't build the
   marketplace before the waitlist proves anyone pays.
2. **Liquidity/SLA with 1-2 coaches** — concierge phase caps daily orders.
3. **Apple review friction** — human-service IAP is fine (Skillest precedent),
   but label it clearly as digital delivery in-app.
4. **Coach quality variance** — rubric + sampling; offboard fast.
5. **TR payout/tax friction** — accountant before first payout, not after.

## 10. Immediate next actions (when green-lit)

1. G0 interest card behind a remote flag + analytics event (half-day).
2. Founding-coach pitch DM list (10 names from Can's network).
3. Lawyer: coach agreement + privacy-policy delta (parallel, one-time).
4. P0 schema + 2 edge functions + dashboard skeleton (2-3 days of build).
