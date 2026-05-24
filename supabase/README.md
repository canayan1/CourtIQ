# CourtIQ Supabase backend

Edge Functions + Postgres schema for the bits of CourtIQ that need a
server: account deletion and the v1.x AI Coach. Everything in `supabase/`
deploys to the CourtIQ Supabase Cloud project (separate from the iOS
repo). The iOS app just calls the functions over HTTPS using the user's
auth JWT.

## What's in here

```
supabase/
├── functions/
│   └── ai-chat/
│       └── index.ts        Deno + Anthropic Haiku 3.5 + prompt caching
└── migrations/
    └── 0001_ai_chat_tables.sql   4 tables + RLS for the AI Coach
```

The existing `delete-account` function lives in this same Supabase
project but its source is tracked elsewhere — it predates this folder.

## Prerequisites

- Supabase CLI installed locally (`brew install supabase/tap/supabase`)
- Logged into the right Supabase account (`supabase login`)
- Anthropic API key with billing enabled
- The CourtIQ Supabase project ref handy (found in dashboard URL)

## One-time setup

```bash
cd supabase

# Link to the existing CourtIQ Supabase project
supabase link --project-ref <YOUR_PROJECT_REF>

# Apply the AI Coach migration
supabase db push

# Set Edge Function secrets — function reads these at runtime
supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
supabase secrets set ANTHROPIC_MODEL=claude-haiku-3-5-20241022
supabase secrets set MAX_DAILY_MESSAGES_PREMIUM=50
# SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY are
# auto-injected by Supabase — don't set them manually.

# Deploy the Edge Function
supabase functions deploy ai-chat
```

## Verify the deploy

```bash
# Should return method_not_allowed (the endpoint is POST-only)
curl https://<project-ref>.supabase.co/functions/v1/ai-chat \
  -H "apikey: <anon-key>"
```

A real call from an authenticated client:

```bash
JWT="<a fresh user access token>"
ANON="<your-supabase-anon-key>"

curl -X POST https://<project-ref>.supabase.co/functions/v1/ai-chat \
  -H "Authorization: Bearer $JWT" \
  -H "apikey: $ANON" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Bugün Begum'\''a 4-6, 3-6 kaybettim, ne yapayım?",
    "chatId": null,
    "context": {
      "profile": { "level": "Intermediate", "currentFocus": "Decision-making",
                   "topMistakePatterns": ["Second serve pressure"] },
      "matches": [{
        "date": "2026-05-24", "opponentName": "Begum", "result": "lost",
        "score": "4-6, 3-6",
        "ratings": { "serve": 2, "return": 3, "movement": 3, "mental": 2 },
        "takeaway": "Çok BH'\''ye girdim"
      }],
      "quiz": { "topMistakes": ["Predictable cross-court"] },
      "imported": null
    }
  }'
```

Response (200):

```json
{
  "reply": "Sinirini anlıyorum…",
  "chatId": "uuid",
  "messagesRemainingToday": 49,
  "usage": {
    "input_tokens": 12,
    "output_tokens": 234,
    "cache_creation_input_tokens": 2104,
    "cache_read_input_tokens": 0
  },
  "promptVersion": "0.2"
}
```

On the second call within 5 minutes, `cache_read_input_tokens` should
be ~2104 and `cache_creation_input_tokens` should be 0 — that's how we
keep the bill under target.

## Cost guards

The function enforces:

1. **JWT verification** — anonymous calls return 401.
2. **50 messages/day per user** (`MAX_DAILY_MESSAGES_PREMIUM`) — 51st
   call returns 429 with `capReached: true`.
3. **4000 character message ceiling** — keeps a single prompt bounded.
4. **Anthropic per-call max_tokens = 700** — caps output cost per turn.

Additional guards to add as the user base grows:

- Anthropic Console: soft cap $50/month, hard cap $100/month
- Supabase Edge Function logs: alert on `total_output_tokens` spikes

## Iterating the system prompt

The CourtIQ Coach prompt is hard-coded in `functions/ai-chat/index.ts`
as `SYSTEM_PROMPT`. Bump `COURTIQ_PROMPT_VERSION` when changing, then
redeploy:

```bash
supabase functions deploy ai-chat
```

Prompt-caching invalidates automatically because the cache key includes
the full prompt text. A redeployed prompt costs one extra cache-write
(~$0.001) per first-user-per-prompt-version.
