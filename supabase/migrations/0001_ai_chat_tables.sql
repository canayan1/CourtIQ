-- =============================================================
-- AI Coach — schema (CourtIQ v1.x)
-- =============================================================
--
-- Four tables back the AI Coach feature. All four are user-scoped
-- via Row Level Security so the Edge Function (running with the
-- end-user's JWT) can only ever read/write rows belonging to that
-- user. Tokens, costs, and rate limits are persisted server-side
-- so client tampering can't cheat the daily cap.
--
-- Schema is forward-compatible with v2 streaming + structured
-- output (no enums on role; jsonb columns where shape may evolve).

-- -------------------------------------------------------------
-- Conversations (one row per chat thread the user starts)
-- -------------------------------------------------------------
create table if not exists public.ai_chats (
    id              uuid        primary key default gen_random_uuid(),
    user_id         uuid        not null references auth.users(id) on delete cascade,
    title           text        not null default 'New chat',
    created_at      timestamptz not null default now(),
    last_message_at timestamptz not null default now()
);

create index if not exists ai_chats_user_recent_idx
    on public.ai_chats (user_id, last_message_at desc);

alter table public.ai_chats enable row level security;

create policy "ai_chats: select own"
    on public.ai_chats for select
    using (auth.uid() = user_id);

create policy "ai_chats: insert own"
    on public.ai_chats for insert
    with check (auth.uid() = user_id);

create policy "ai_chats: update own"
    on public.ai_chats for update
    using (auth.uid() = user_id);

create policy "ai_chats: delete own"
    on public.ai_chats for delete
    using (auth.uid() = user_id);


-- -------------------------------------------------------------
-- Messages (one row per turn — user prompt or assistant reply)
-- -------------------------------------------------------------
create table if not exists public.ai_messages (
    id              uuid        primary key default gen_random_uuid(),
    chat_id         uuid        not null references public.ai_chats(id) on delete cascade,
    user_id         uuid        not null references auth.users(id) on delete cascade,
    role            text        not null check (role in ('user', 'assistant')),
    content         text        not null,
    -- Token accounting. assistant rows carry both prompt + completion
    -- tokens for the API call that produced them; user rows carry zeros.
    input_tokens            integer     not null default 0,
    output_tokens           integer     not null default 0,
    cache_read_tokens       integer     not null default 0,
    cache_creation_tokens   integer     not null default 0,
    model                   text        not null default 'claude-haiku-3-5',
    created_at              timestamptz not null default now()
);

create index if not exists ai_messages_chat_chrono_idx
    on public.ai_messages (chat_id, created_at);
create index if not exists ai_messages_user_chrono_idx
    on public.ai_messages (user_id, created_at desc);

alter table public.ai_messages enable row level security;

create policy "ai_messages: select own"
    on public.ai_messages for select
    using (auth.uid() = user_id);

create policy "ai_messages: insert own"
    on public.ai_messages for insert
    with check (auth.uid() = user_id);


-- -------------------------------------------------------------
-- Per-user daily usage (rate-limit + cost accounting)
-- -------------------------------------------------------------
create table if not exists public.ai_usage_daily (
    user_id                 uuid        not null references auth.users(id) on delete cascade,
    usage_date              date        not null default current_date,
    message_count           integer     not null default 0,
    total_input_tokens      integer     not null default 0,
    total_output_tokens     integer     not null default 0,
    total_cache_read_tokens integer     not null default 0,
    updated_at              timestamptz not null default now(),
    primary key (user_id, usage_date)
);

create index if not exists ai_usage_daily_date_idx
    on public.ai_usage_daily (usage_date desc);

alter table public.ai_usage_daily enable row level security;

create policy "ai_usage_daily: select own"
    on public.ai_usage_daily for select
    using (auth.uid() = user_id);

-- INSERT / UPDATE happens via the Edge Function with elevated client.
-- No anon policy: we don't want users mutating their own counters.


-- -------------------------------------------------------------
-- Imported context (ChatGPT paste / JSON export summaries)
-- -------------------------------------------------------------
create table if not exists public.ai_imported_context (
    user_id      uuid        not null references auth.users(id) on delete cascade,
    source       text        not null check (source in ('chatgpt_paste', 'chatgpt_export', 'manual_note')),
    summary      text        not null,
    raw_excerpt  text,
    imported_at  timestamptz not null default now(),
    updated_at   timestamptz not null default now(),
    primary key (user_id, source)
);

alter table public.ai_imported_context enable row level security;

create policy "ai_imported_context: select own"
    on public.ai_imported_context for select
    using (auth.uid() = user_id);

create policy "ai_imported_context: insert own"
    on public.ai_imported_context for insert
    with check (auth.uid() = user_id);

create policy "ai_imported_context: update own"
    on public.ai_imported_context for update
    using (auth.uid() = user_id);

create policy "ai_imported_context: delete own"
    on public.ai_imported_context for delete
    using (auth.uid() = user_id);
