# 1.5 — what is in it, what is not, and what is still undecided

This file exists because the 1.5 feature list lived in a conversation and was
lost when that conversation was summarised. Nothing here is remembered: every
claim below was read off the repository, the simulator or the deployed backend
on 26–27 September 2026, and the ones that were not verified say so.

**The list of remaining features is at the bottom and it is empty.** That is not
an omission — it is the part only Can can fill, and the reason this file was
written.

---

## Where the branches stand

`release/1.4` was cut at `3ad753a` (17 Sep) and is in App Store review. Since
that cut, **34 commits have landed on `main` that 1.4 does not have**:

| group | commits |
|---|---|
| duel | 11 |
| sensing | 9 |
| docs | 3 |
| watch | 2 |
| marketing | 2 |
| daily one | 2 |
| wall, teaching, review, paywall, challenge | 1 each |

`main` still reads `MARKETING_VERSION = 1.3`, `CURRENT_PROJECT_VERSION = 38`.
The version bump happens on the release branch, not on `main` — that is how 1.4
was done and it is worth not forgetting, because it is invisible from `main`.

**34 commits is not a release, it is a backlog.** Most of what is sitting on
`main` is not shippable, and the section after next says which parts and why.

---

## Ready for 1.5 — built and verified this session

### Daily One — the same question for everybody

The adaptive Daily IQ session picks a player's weakest category, which is right
for teaching one person and wrong for starting a conversation: two people never
hold the same question, so there is nothing to compare. Daily One is the other
thing. One shared scenario a day, twenty seconds, above the pillars on Home.

- The pick is a pure function of the date — no account, no network, no state. A
  phone in flight mode shows what everyone else is seeing.
- The rota walks all 156 scenarios before repeating one.
- **The option order had to be rebuilt.** The bundled bank shuffles each
  question's options *at every launch*, because the content is authored
  correct-answer-first and shipping it verbatim would make every answer "A".
  That per-launch shuffle would have made "61% said B" a sentence about a
  different B on every phone. Daily One reads `Quiz.unshuffledBank` and permutes
  by the date instead, and a vote travels as **the option's index in the JSON**,
  never the position it was drawn in.
- The crowd split is **withheld below 50 answers**, with a sentence saying so
  rather than a percentage computed from eight people.
- The share card is spoiler-free: the scenario and a week of squares, never
  which option was right and never which one the sender chose.

**Backend is live.** `daily-one` edge function plus three migrations are
deployed to `ybnodzzrkwennzpwyjmr`; the `DAILY_ONE_VOTER_SALT` secret is set.

Two security holes were found *by deploying it* and are closed — see
[Supabase grants](#supabase-the-hole-that-only-a-deploy-finds) below.

Tests: `tools/daily-one-test.swift`, 22 checks, run against the real 156
scenarios rather than a stub. Verified in the simulator end to end.

### Challenge — the reply now comes back as a result

The head-to-head feature already existed (17 Sep, in 1.4). Its own source
comment claimed "the reply is the loop". It was not.

A reply link was **byte-for-byte identical to an opening challenge**, because v1
had one score field and no way to say which kind of link it was. So the original
challenger tapped their friend's reply and the app offered them the same five
scenarios they had answered minutes earlier and knew every answer to. They
scored 5/5 and "won". Worse, the reply was built with
`TennisChallenge.from(questions:score:)`, which wrote the replier's score into
the challenger's field — the first number was not unused, it was gone.

v2 carries a kind byte and both scores (19 bytes, 26 base64url characters). A
reply opens straight on the result with nothing to play, and offers no
send-back, because a reply to a reply is the same five questions a third time
with both players knowing the answers. **v1 links still decode**, as
invitations, which is all they could ever express.

Separately: a link that failed to decode did nothing at all — `try?` threw the
error away and the app opened on Home. The three failures have three different
fixes, so they now get three different sentences, and a counter.

Tests: `tools/challenge-test.swift`, 28 checks, with both defects reconstructed
so they fail if either returns.

> ### ⚠️ `release/1.4` ships the broken reply loop
>
> The fix is on `main` only. 1.4 is in review with the defect. This is a real
> decision and it is Can's: the feature is new in 1.4 so few people will hit it,
> and pulling a build from review costs days. **Recommendation: let 1.4 ship and
> fix it in 1.5.** Recorded here so the choice is deliberate rather than
> forgotten.

---

## On `main` but NOT ready to ship

The sensing / duel / watch work — 22 of the 34 commits — is behind `#if DEBUG`
and, by its own commit messages, has **never been run on hardware**:

- `a5157eb watch: the wrist, the phone, and the Journal on one event stream — unrun`
- `5598636 sensing: a session you can actually record, behind a door marked not finished`
- `748fdf5 duel: build the two-player measurement engine, and find it is not ready`

`docs/SENSING-TEST-PLAN.md` defines T1/T3. Until those are run on a real waist
phone and a real Watch, none of this is 1.5 content, and nothing should be built
on top of it.

The marketing, paywall, teaching, review and docs commits were not assessed in
this session. They are on `main`; their readiness is unknown, not good and not
bad.

---

## Supabase: the hole that only a deploy finds

Worth keeping because it will happen again with the next edge function.

`revoke all on function … from public` looks sufficient and is not. Supabase
sets a default privilege granting EXECUTE on new `public`-schema functions
directly to `anon` and `authenticated`, and revoking from PUBLIC does not touch
a grant held by a role. Probed with the app's own publishable key — the one that
ships inside the binary:

```
POST /rest/v1/rpc/daily_one_cast   → 200, vote counted
POST /rest/v1/rpc/daily_one_prune  → 204, voter rows deleted
```

The first is the entire ballot box. The second is a destructive maintenance
function anyone could call. Both now 401.

**For every new function:** write the explicit
`revoke execute … from anon, authenticated, public;`, and after applying the
migration, call it over REST with the anon key and confirm 401. A table behind
RLS with no policies returns `200 []`, which is not a leak but is not a
statement of intent either — take its grants too.

---

## Verification notes worth keeping

- `simctl openurl` hands universal links to **Safari, not the app**, so the
  deep-link path cannot be tested that way. `SIMCTL_CHILD_QC_CHALLENGE=<payload>`
  (DEBUG only) runs a payload through the real `handleInviteURL`, the same
  entry point a real tap uses. Same family as the existing `QC_OPEN` hook.
- All three language files sit at 1112 keys. Check parity, not just EN.
- Release configuration builds clean as of `9d1229b`.

---

## Still to decide

1. **1.4**: let it ship with the broken reply, or pull it? (Recommendation
   above: let it ship.)
2. **Cut order**: does 1.5 wait for 1.4 to clear review, or start now on a
   `release/1.5` branch off `main`?
3. **Scope**: 1.5 = Daily One + the challenge fix, or does it wait for more?

---

## The rest of the 1.5 list

*Empty on purpose. The features planned beyond Daily One and the challenge fix
were discussed and never written down, and reconstructing them from guesswork
would be worse than an honest blank. Add them here — one heading each, with what
"done" means for it — and they will survive the next session.*

<!--
### <feature>
What it is:
Why it earns its place:
Done means:
-->
