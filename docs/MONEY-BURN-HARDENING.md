# Money-burn hardening — status & deploy runbook

The original fear (opening this workstream): a spam/abuse burst — or a leaked
public anon key — drains the prepaid AI budget (Gemini + Anthropic, ~€25 each)
and the app goes dark. This tracks the controls that bound that risk.

## Threat model (what can burn money)

Every paid-LLM edge function is reachable by anyone with the **public** anon key
+ an anonymous Supabase session (both are shippable-by-design). So the budget is
only as safe as the server-side caps:

| Function | Provider | Per-user cap (before this work) | Notes |
|---|---|---|---|
| `ai-chat` | Anthropic (Haiku) | 50 msg/day | premium feature; gate is dark |
| `swing-analysis` | Gemini (video) | 3/day, 30/mo (row-count) | **costliest call**; reinstall = new anon id → cap bypassed |
| `match-analysis` | Gemini (text) | **none** | wide open |
| `doubles-analysis` | Gemini (text) | **none** | wide open |

Per-user caps don't bound the **total** bill: reinstalling mints a fresh anon id,
and match/doubles had no cap at all. The backstop is a global ceiling.

## ✅ Done in the tree (this branch) — needs deploy + `deno check`

**Global daily budget breaker.** One shared counter every paid call bumps right
before hitting the provider; once the whole app crosses `GLOBAL_DAILY_CALL_CAP`
for the day, the function returns 503. Worst-case daily bill is bounded to
~`cap × per-call cost` no matter the attack shape or a key leak.

- `supabase/migrations/20260701000000_global_usage_breaker.sql` — `global_usage_daily`
  table (RLS on, **no policies**) + `bump_global_usage()` `SECURITY DEFINER` RPC
  that increments atomically and is tamper-proof (caller can EXECUTE only; cannot
  read/write the counter).
- Wired into `match-analysis`, `doubles-analysis`, `swing-analysis` (after auth +
  entitlement + input validation, before the provider call). **Fails OPEN** on a
  DB blip — the ceiling is a backstop, never a reason to break a legit request.

> ⚠️ Not `deno check`-ed locally (no Deno on this machine). Verify at deploy.

### Deploy steps (do together, with approval)

1. **Tune the cap for your budget** — this is the important knob. Rough per-call
   cost: match/doubles text ≈ $0.002, swing video ≈ $0.02–0.05, ai-chat ≈ $0.004.
   Given ~€25 prepaid and near-zero legit traffic today, **start low**:
   `supabase secrets set GLOBAL_DAILY_CALL_CAP=400` (≈ worst-case ~$8–16/day),
   raise as real usage grows. (Env is read at cold start → re-deploy to apply.)
2. `deno check supabase/functions/{match-analysis,doubles-analysis,swing-analysis}/index.ts`
3. Apply the migration (`supabase db push` or paste the SQL in the SQL editor).
4. `supabase functions deploy match-analysis doubles-analysis swing-analysis`
5. Smoke-test one call of each (should succeed). Optionally set the cap to `0`
   briefly and confirm a 503, then restore.

## ⏳ Remaining (prioritized) — do at the 1.0.2 edge deploy

1. **Add the breaker to `ai-chat`** — same block, right before the Anthropic call.
   Deferred here only because that function is large (1100 lines, two code paths)
   and warranted a careful, verified edit rather than an unverifiable one.
2. **Per-user caps on match/doubles** — add a `bump_feature_usage(feature)` RPC
   (per user_id + date + feature) so one actor can't eat the whole global budget;
   return 429 past e.g. 15/day. (Global breaker bounds the total; this bounds a
   single abuser.)
3. **Separate the paid video key.** `swing-analysis` falls back to the free
   `GEMINI_API_KEY`; put `GEMINI_VIDEO_API_KEY` in its **own Google Cloud project**
   so match/doubles spam can't degrade/bill the swing path (and vice-versa).
4. **Flip the entitlement gate** — `REQUIRE_ENTITLEMENT=true` for `ai-chat` +
   `swing-analysis` once the RevenueCat build (1.0.2) is live, so non-premium
   users can't call the premium paths at all.
5. **Per-IP anonymous-signup throttle** + **provider spend alerts** (Google/Anthropic
   billing caps + email) — infra/dashboard tasks, outside the codebase.

## Rejected

- **Client-side caps for match/doubles.** Resettable (reinstall / edit
  UserDefaults) — same cosmetic trap as `FreeTaste.swingUsed`. They improve UX but
  give zero budget protection, so the enforcement lives entirely server-side.
