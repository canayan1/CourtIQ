# AI Coach — deployment & monitoring playbook

Step-by-step for going from "the code is committed" to "premium users can
actually talk to the coach", plus the ongoing watchpoints that keep the
bill under target.

Repo state when this doc is current:
- iOS: AI Coach UI shipped (commits `fd38480`, `fbcb901`)
- Supabase: `supabase/functions/ai-chat/`, `supabase/migrations/0001_*.sql`
  (commit `445139f`) — files present, **not deployed**
- Anthropic: no API key configured yet

## Phase A — Provision the backend (~15 min)

### 1. Get an Anthropic API key

1. Sign up / log in at console.anthropic.com
2. Add a payment method
3. Set billing alerts — recommended:
   - **Soft cap email at $50/month**
   - **Hard limit at $100/month** (account auto-blocks above)
4. Create an API key: console → Settings → API Keys → Create
5. Copy the `sk-ant-…` string (only shown once)

### 2. Deploy the Supabase Edge Function + tables

From the repo root:

```bash
cd supabase

# Install the Supabase CLI if you don't already have it
brew install supabase/tap/supabase

# Log in (opens browser)
supabase login

# Link to the CourtIQ project
supabase link --project-ref <PROJECT_REF_FROM_DASHBOARD>

# Push the AI Coach migration (creates 4 tables + RLS)
supabase db push

# Secrets — function reads these at runtime
supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
supabase secrets set ANTHROPIC_MODEL=claude-haiku-4-5
supabase secrets set MAX_DAILY_MESSAGES_PREMIUM=50

# Deploy the function
supabase functions deploy ai-chat
```

The function URL will be:
`https://<project-ref>.supabase.co/functions/v1/ai-chat`

### 3. Verify the deploy

A bare `curl` should return 401 (no JWT) — confirms the function is
live and rejecting anonymous requests:

```bash
curl -X POST https://<project-ref>.supabase.co/functions/v1/ai-chat \
  -H "apikey: <anon>" \
  -H "Content-Type: application/json" \
  -d '{"message":"hi"}'
# {"error":"missing_bearer"}
```

For a real authenticated test, use the sample curl in
`supabase/README.md` with a fresh user JWT pulled from a TestFlight
build's Keychain (Charles / Proxyman makes this easy).

## Phase B — Flip CourtIQ's app config (~2 min)

`COURTIQ_AI_CHAT_FUNCTION = "ai-chat"` is already in `CourtIQ/Info.plist`
(default value matches the deployed function name). No code change
needed. Next archive of CourtIQ will pick up the wiring.

If you ever rename the deployed function (e.g. `ai-chat-v2`), bump that
Info.plist key — `AppConfiguration` reads it at launch.

## Phase C — Manual end-to-end test (~10 min)

1. Archive CourtIQ (next bump, e.g. 1.0/5)
2. Install on a physical device via TestFlight
3. Sign in with Apple
4. Tip yourself the supporter subscription so
   `subscriptionManager.entitlementState.isPremium == true`
5. Profile → AI Coach card → should open AICoachView (not the paywall)
6. Tap "+" → New chat → type "Bugün Begum'a 4-6, 3-6 kaybettim"
7. Expect: 2-4 second pause then a CourtIQ-Coach-flavoured reply
   that references your match data + ends with a drill/library
   pointer
8. Profile → AI Coach → menu → "Import from ChatGPT" → paste a
   tennis snippet → save → next chat should now reference it

## Phase D — Ongoing monitoring

### Cost watch (weekly)

Open the Supabase SQL editor and run:

```sql
-- Top 10 most-expensive users this week (Haiku 3.5 rates)
select
    user_id,
    sum(message_count)                                     as msgs,
    sum(total_input_tokens)                                as input_tok,
    sum(total_output_tokens)                               as output_tok,
    sum(total_cache_read_tokens)                           as cache_tok,
    round(
      sum(total_input_tokens)        * 0.00000080
    + sum(total_output_tokens)       * 0.00000400
    + sum(total_cache_read_tokens)   * 0.00000008
    , 4)                                                   as estimated_cost_usd
from public.ai_usage_daily
where usage_date >= current_date - interval '7 days'
group by user_id
order by estimated_cost_usd desc
limit 10;
```

Then total spend per week:

```sql
select round(sum(
    total_input_tokens      * 0.00000080
  + total_output_tokens     * 0.00000400
  + total_cache_read_tokens * 0.00000008
), 2) as weekly_total_usd
from public.ai_usage_daily
where usage_date >= current_date - interval '7 days';
```

Cross-check against Anthropic Console → Usage. The Supabase numbers
should be ≤ Anthropic's (Anthropic also counts cache-creation tokens
which we don't track in `ai_usage_daily`).

### Red flags

| Symptom | Likely cause | Fix |
|---|---|---|
| Anthropic bill > $5/active user/month | Cache misses each call | Check Edge Function logs for `cache_read_input_tokens` — should be > 0 on every non-first call within 5 min |
| One user > 50 msgs/day | Rate limit bypassed | Edge Function returning 200 before checking? Re-deploy fresh build |
| Daily totals plateau at 50 mid-day | Many users hitting cap | Either lower cost-per-message (already at Haiku 3.5) or raise the cap |
| Edge Function 5xx spike | Anthropic outage | Status: status.anthropic.com — function logs the response code |

### Function logs

```bash
supabase functions logs ai-chat --tail
```

Watch for:
- `anthropic_failed` errors → check status, may need retry logic
- `daily_cap_reached` 429s → expected as users hit their cap
- `invalid_jwt` 401s → either expired sessions or someone scraping

## Phase E — Iterating the system prompt

The CourtIQ Coach prompt (v0.2 at time of writing) lives in
`supabase/functions/ai-chat/index.ts` as `SYSTEM_PROMPT`. To change it:

1. Edit the string + bump `COURTIQ_PROMPT_VERSION` (e.g. "0.3")
2. `supabase functions deploy ai-chat`
3. The next request gets the new prompt; cache invalidates because
   the cache key includes full prompt text. First call per user
   pays a one-time cache-write (~$0.001).

The `promptVersion` field is returned to the client on each response,
so the iOS app can log which version handled a turn — useful for
prompt A/B testing later.

## Phase F — Future improvements (not Phase 1-3)

- **Streaming** — set `stream: true` on the Anthropic call, switch
  the Edge Function to SSE response, update `AIChatClient.send` to
  yield partial chunks. Better UX, no cost change.
- **Server-side import summarisation** — instead of storing raw
  paste, run a one-shot summarise call on import and cache the
  ~200 word summary. Keeps per-chat prompt-prefix bounded as users
  accumulate import content.
- **Thread title auto-generation** — first user turn → title via a
  cheap separate call. Currently we just slice the first 60 chars.
- **Cross-device thread sync** — read `ai_chats` + `ai_messages`
  from the iOS client on launch so deleted-and-reinstalled devices
  recover history. Current cache is local only.
- **Premium quota tiers** — `MAX_DAILY_MESSAGES_PREMIUM` is a single
  env var. A future schema split could give different caps to
  different supporter levels (€4.99/year vs €19.99/year).
