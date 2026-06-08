-- App sync tables that the client reads/writes but were never created.
--
-- Like public.profiles, these were referenced by the client managers but
-- missing from the schema, so signed-in (Apple) sync failed with
-- "Could not find the table 'public.<name>' in the schema cache". Anonymous
-- sessions never exercised these paths, hiding the gap. Columns mirror the
-- client Remote*Record structs (encoder uses snake_case). All `id`s are
-- app-generated text (upserts use onConflict "id").

-- ===================== quiz_completions (per-user) =====================
create table if not exists public.quiz_completions (
    id               text        primary key,
    user_id          uuid        not null references auth.users(id) on delete cascade,
    quiz_id          text        not null,
    title            text        not null,
    focus_label      text        not null,
    score            integer     not null,
    total_questions  integer     not null,
    mistake_types    jsonb       not null default '[]'::jsonb,
    completed_at     timestamptz not null default now(),
    is_daily         boolean     not null default false
);
create index if not exists quiz_completions_user_idx on public.quiz_completions (user_id);
alter table public.quiz_completions enable row level security;
create policy "quiz_completions: select own" on public.quiz_completions for select using (auth.uid() = user_id);
create policy "quiz_completions: insert own" on public.quiz_completions for insert with check (auth.uid() = user_id);
create policy "quiz_completions: update own" on public.quiz_completions for update using (auth.uid() = user_id);
create policy "quiz_completions: delete own" on public.quiz_completions for delete using (auth.uid() = user_id);

-- ===================== training_session_logs (per-user) =====================
create table if not exists public.training_session_logs (
    id            text        primary key,
    user_id       uuid        not null references auth.users(id) on delete cascade,
    program_id    text        not null,
    week          integer     not null,
    day_id        text        not null,
    completed_at  timestamptz not null default now()
);
create index if not exists training_session_logs_user_idx on public.training_session_logs (user_id);
alter table public.training_session_logs enable row level security;
create policy "training_session_logs: select own" on public.training_session_logs for select using (auth.uid() = user_id);
create policy "training_session_logs: insert own" on public.training_session_logs for insert with check (auth.uid() = user_id);
create policy "training_session_logs: update own" on public.training_session_logs for update using (auth.uid() = user_id);
create policy "training_session_logs: delete own" on public.training_session_logs for delete using (auth.uid() = user_id);

-- ===================== weekly_checkins (per-user) =====================
create table if not exists public.weekly_checkins (
    id             text        primary key,
    user_id        uuid        not null references auth.users(id) on delete cascade,
    program_id     text        not null,
    week           integer     not null,
    readiness      integer     not null,
    explosiveness  integer     not null,
    conditioning   integer     not null,
    notes          text        not null default '',
    updated_at     timestamptz not null default now()
);
create index if not exists weekly_checkins_user_idx on public.weekly_checkins (user_id);
alter table public.weekly_checkins enable row level security;
create policy "weekly_checkins: select own" on public.weekly_checkins for select using (auth.uid() = user_id);
create policy "weekly_checkins: insert own" on public.weekly_checkins for insert with check (auth.uid() = user_id);
create policy "weekly_checkins: update own" on public.weekly_checkins for update using (auth.uid() = user_id);
create policy "weekly_checkins: delete own" on public.weekly_checkins for delete using (auth.uid() = user_id);

-- ===================== discussion_threads (shared community) =====================
create table if not exists public.discussion_threads (
    id              text        primary key,
    target_type     text        not null,
    target_id       text        not null,
    title           text        not null,
    subtitle        text        not null,
    starter_prompt  text        not null,
    updated_at      timestamptz not null default now()
);
alter table public.discussion_threads enable row level security;
-- Shared content: any signed-in user reads, and upserts the thread row that
-- anchors a discussion (keyed by id).
create policy "discussion_threads: read" on public.discussion_threads for select to authenticated using (true);
create policy "discussion_threads: insert" on public.discussion_threads for insert to authenticated with check (true);
create policy "discussion_threads: update" on public.discussion_threads for update to authenticated using (true);

-- ===================== discussion_comments (shared, author-owned writes) =====================
create table if not exists public.discussion_comments (
    id           text        primary key,
    thread_id    text        not null,
    author_id    uuid        not null references auth.users(id) on delete cascade,
    author_name  text        not null,
    body         text        not null,
    is_pinned    boolean     not null default false,
    created_at   timestamptz not null default now(),
    edited_at    timestamptz
);
create index if not exists discussion_comments_thread_idx on public.discussion_comments (thread_id);
alter table public.discussion_comments enable row level security;
create policy "discussion_comments: read" on public.discussion_comments for select to authenticated using (true);
create policy "discussion_comments: insert own" on public.discussion_comments for insert to authenticated with check (auth.uid() = author_id);
create policy "discussion_comments: update own" on public.discussion_comments for update to authenticated using (auth.uid() = author_id);
create policy "discussion_comments: delete own" on public.discussion_comments for delete to authenticated using (auth.uid() = author_id);

-- ===================== comment_likes (shared read, owner writes) =====================
create table if not exists public.comment_likes (
    id          text        primary key,
    thread_id   text        not null,
    comment_id  text        not null,
    user_id     uuid        not null references auth.users(id) on delete cascade,
    created_at  timestamptz not null default now()
);
create index if not exists comment_likes_comment_idx on public.comment_likes (comment_id);
alter table public.comment_likes enable row level security;
create policy "comment_likes: read" on public.comment_likes for select to authenticated using (true);
create policy "comment_likes: insert own" on public.comment_likes for insert to authenticated with check (auth.uid() = user_id);
create policy "comment_likes: delete own" on public.comment_likes for delete to authenticated using (auth.uid() = user_id);

-- ===================== comment_reports (reporter-owned) =====================
create table if not exists public.comment_reports (
    id           text        primary key,
    thread_id    text        not null,
    comment_id   text        not null,
    reporter_id  uuid        not null references auth.users(id) on delete cascade,
    reason       text        not null,
    created_at   timestamptz not null default now()
);
create index if not exists comment_reports_comment_idx on public.comment_reports (comment_id);
alter table public.comment_reports enable row level security;
create policy "comment_reports: insert own" on public.comment_reports for insert to authenticated with check (auth.uid() = reporter_id);
create policy "comment_reports: select own" on public.comment_reports for select to authenticated using (auth.uid() = reporter_id);
