# Coach Review — the operating MVP (multi-coach)

*Written 26 Aug 2026. Extends `COACH-REVIEW-PLAN.md` (why + money + legal)
and `COACH-REVIEW-POLICY.md` (video rights). This doc is the part neither
covers: how a second coach gets in, what stops a bad review, and what we do
the day an account is compromised.*

---

## 0. Where we actually are (verified, not remembered)

| Thing | State |
|---|---|
| IAP `com.canayan93.courtiq.coachreview1` | **APPROVED** — purchase is live |
| 1.0.5 | **READY_FOR_SALE**, notes say "Coach review is now live" |
| Order → Supabase → panel → deliverable | built and deployed |
| Coach panel auth | **one shared password for everyone** |
| Order assignment | **none** — the queue is global |
| "Notify me" waitlist | **stores nothing you can act on** |

Two of those rows are the whole reason this doc exists.

### 0a. The waitlist captures nothing

Tapping *Notify me* — or any tier's *Get a quote* — does exactly two things:

1. sets a local `UserDefaults` flag on that one phone, and
2. fires a Firebase Analytics event `coach_review_interest`.

No email. No row. No name. So:

- **Where to see the count:** Firebase console → Analytics → Events →
  `coach_review_interest` (24–48h lag; `source` and `tier` are the params).
  That is a *counter*, not a list.
- **Who you can notify when coaches open:** nobody. There is no contact
  detail anywhere.

A waitlist you cannot mail is a vanity metric. Fixing this is P0 below.

### 0b. Why you saw a waitlist instead of a Buy button

Not a bug, and the release notes are not false. The order path only appears
where an order is possible:

- **Swing *setup* screen** (no clip yet) → always the waitlist card. You
  cannot buy a review of a video that doesn't exist.
- **Swing *result* screen** (clip in hand) → Buy, provided StoreKit returns
  the product. It's approved and the product id matches, so it should.
- **Tier cards** (Advanced Player / Level 2 / Level 3) → always a waitlist.
  Those coaches don't exist yet, by design.

To confirm the live path: run a swing analysis to the result screen and look
for the order CTA there. If it still shows the waitlist, `productAvailable`
is false and that's a StoreKit fetch problem worth chasing.

---

## 1. The one architectural decision: assign orders to a coach

Today the queue is global. Any panel session sees every order and every
player's video. That's survivable while the roster is one person; it is not
survivable at two, for reasons that are privacy, not trust:

- Coach B can watch Coach A's players' clips.
- Nothing attributes a delivery to a person, so "who wrote this?" has no
  answer.
- Deactivating a coach means changing the password for everyone.

**Add `assigned_coach_id` to `coach_review_orders`** and make every read
path filter on it. This is the change everything else in this doc hangs off.

Assignment rule for the MVP (deliberately dumb, no matching engine):

1. Order lands with `assigned_coach_id = null`, status `submitted`.
2. A coach with a matching `review_language` and free capacity claims it, or
   the owner assigns it.
3. Unclaimed after 12h → owner is alerted and assigns manually.
4. Unclaimed at 60h (12h before SLA) → auto-refund path, order `expired`.

---

## 2. Coach identity: kill the shared password

**Replace it with Supabase Auth magic links.**

- A coach is invited by email. `coach_review_coaches.user_id` links to the
  auth user. There is no password to leak, phish or share.
- The panel sends the coach's JWT; the edge function checks the coach row
  exists **and** `active = true` on *every* call, not just at login.
- Revocation is one boolean. `active = false` takes effect on the next
  request — no session to wait out, no secret to rotate.
- Every mint, view and delivery is attributable to a coach id.

Session hygiene: 12-hour sessions, re-auth after. Signed clip URLs drop from
2 hours to **30 minutes**, minted per view, each mint logged with coach id,
order id and timestamp.

**Migration:** the owner's panel keeps working through the shared-password
proxy until the magic-link path is live; then the shared secret is deleted,
not left as a fallback. A fallback is the vulnerability.

---

## 3. The compromise playbook

*"What if a coach's account gets hacked?"* — the honest answer is designed
blast radius, not prevention.

**What an attacker gets:** the clips of orders *assigned to that coach and
still open*. Delivered orders are no longer streamable to the coach, and
unassigned orders were never visible. With a working queue that's a handful
of videos, not the library.

**Detection signals** (alert the owner, don't auto-act):

- signed-URL mints per coach per hour above a threshold,
- a delivery from a new country,
- more than one active session for one coach.

**Response, in order:**

1. `active = false` on the coach row. Access stops on the next request.
2. Re-assign their open orders; SLA clock pauses for those players.
3. Read the access log: which order ids had clips minted during the window.
4. Notify **those** players — specifically, not a blanket mail — within
   72 hours of becoming aware. That's the GDPR clock and it is not optional.
5. Re-invite through a fresh magic link only after the coach's own email
   account is confirmed secure.

Watermarking the stream with coach id + timestamp (policy §4, P1) is what
makes a leaked clip traceable back to one account. Worth doing before the
roster grows.

---

## 4. Review integrity: what stops a bad review

Two different threats. Don't conflate them.

### 4a. A coach who doesn't do the work

The failure mode isn't malice, it's a tired person at 11pm pasting last
week's review. Controls, cheapest first:

| Control | Mechanism |
|---|---|
| **Timestamps must be real** | The panel stamps from actual playback position. Delivery is blocked unless ≥2 timestamps fall inside the clip's duration. |
| **Watch-time floor** | The panel logs playback. Delivery blocked under one full pass of the clip. |
| **Voice note floor** | Required, ≥60 seconds. |
| **Template detection** | Compare the written text against that coach's last 10 deliverables; >0.8 similarity flags for QA rather than blocking. |
| **QA sampling** | Every deliverable while the roster is 1–2 coaches. At 3+: 20% plus every flagged one. |
| **Two strikes** | Two failed QAs → suspended, orders re-assigned. |

None of these judge coaching quality — they establish that the coach watched
*this* video. Quality is the rating loop below.

### 4b. A player who abuses it

- Non-tennis, abusive, or third-party footage → the coach flags and rejects.
  The SLA clock stops; the player gets a credit, not a coaching response.
- Refund-after-delivery: Apple decides consumable refunds, not us. Our lever
  is a **re-review by a different coach**, offered before any refund request.
  Log it — a player with repeated flags stops being eligible.

### 4c. The rating loop

The player rates the delivered review 1–5 with an optional line. Under 3
auto-escalates to the owner and offers a free re-review.

**Coach ratings stay internal** until there is real volume. Publishing an
average built on eleven reviews is the fabricated-social-proof trap we've
avoided everywhere else, and Apple 2.3.1 covers it.

---

## 5. Order states

```
submitted ──▶ assigned ──▶ in_review ──▶ delivered ──▶ rated ──▶ closed
    │             │            │             │
    │             │            │             └──▶ disputed ──▶ re-review
    │             │            └──▶ flagged ──▶ credited
    │             └──▶ (12h unclaimed: owner alerted)
    └──▶ expired (60h unclaimed) ──▶ refund path
```

Payout releases at `closed`, i.e. after a 7-day dispute window, not at
delivery. Wise, 80/20 founding split (`COACH-REVIEW-PLAN.md` §3).

---

## 6. Build order

**P0 — this week, before recruiting anyone**

1. **Waitlist that works.** A `coach_review_waitlist` table (`user_id`,
   `email`, `tier`, `locale`, `created_at`) written through an edge
   function; the app asks for an email at the *Notify me* tap. Without this
   the whole demand-test is unmeasurable and unmailable.
2. **`assigned_coach_id`** on orders + filter every read path on it.
3. **Owner dashboard row counts** — waitlist size by tier, open orders, SLA
   at risk. Three numbers on the existing panel.

**P1 — before coach #2 (your father / the friend in Ireland)**

4. Magic-link auth; delete the shared secret.
5. Claim/assign UI + the 12h/60h escalation timers.
6. Delivery gates: timestamp validation, watch-time floor, voice floor.
7. Signed URL TTL to 30 min + access log surfaced to the owner.

**P2 — before the roster is public**

8. Watermarking, template-similarity flagging, rating loop, QA queue,
   payout ledger.

---

## 7. What this needs from you (not from code)

- **A coach agreement each coach signs** before their first order — the
  video clauses are drafted in `COACH-REVIEW-POLICY.md` §3 and need a
  lawyer's pass, not mine.
- **A decision on review language per coach.** Your father reviews in
  Turkish; that has to be visible to the player *before* they pay, or it's
  a refund every time.
- **Your own QA rubric.** You are coach #1 and the standard-setter. What
  makes a review good enough to pay for is your call, and everything in §4a
  only enforces that you watched — not that you were right.
