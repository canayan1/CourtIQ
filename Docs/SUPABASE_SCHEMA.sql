create extension if not exists pgcrypto;

create table if not exists profiles (
    id uuid primary key,
    display_name text not null,
    email text,
    sign_in_provider text not null check (sign_in_provider in ('apple', 'guest')),
    current_focus text not null default 'Daily IQ',
    top_mistake_patterns jsonb not null default '[]'::jsonb,
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists quiz_completions (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references profiles(id) on delete cascade,
    quiz_id text not null,
    focus_label text not null,
    score integer not null,
    total_questions integer not null,
    mistake_types jsonb not null default '[]'::jsonb,
    completed_at timestamptz not null default timezone('utc', now())
);

create table if not exists training_session_logs (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references profiles(id) on delete cascade,
    program_id text not null,
    week integer not null,
    day_id text not null,
    completed_at timestamptz not null default timezone('utc', now()),
    unique (user_id, program_id, week, day_id)
);

create table if not exists weekly_checkins (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references profiles(id) on delete cascade,
    program_id text not null,
    week integer not null,
    readiness integer not null check (readiness between 1 and 5),
    explosiveness integer not null check (explosiveness between 1 and 5),
    conditioning integer not null check (conditioning between 1 and 5),
    notes text not null default '',
    updated_at timestamptz not null default timezone('utc', now()),
    unique (user_id, program_id, week)
);

create table if not exists discussion_threads (
    id text primary key,
    target_type text not null,
    target_id text not null,
    title text not null,
    subtitle text not null,
    starter_prompt text not null,
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now()),
    unique (target_type, target_id)
);

create table if not exists discussion_comments (
    id uuid primary key default gen_random_uuid(),
    thread_id text not null references discussion_threads(id) on delete cascade,
    author_id uuid not null references profiles(id) on delete cascade,
    author_name text not null,
    body text not null,
    like_count integer not null default 0,
    is_pinned boolean not null default false,
    created_at timestamptz not null default timezone('utc', now()),
    edited_at timestamptz
);

create table if not exists comment_reports (
    id uuid primary key default gen_random_uuid(),
    thread_id text not null references discussion_threads(id) on delete cascade,
    comment_id uuid not null references discussion_comments(id) on delete cascade,
    reporter_id uuid not null references profiles(id) on delete cascade,
    reason text not null,
    created_at timestamptz not null default timezone('utc', now())
);

alter table profiles enable row level security;
alter table quiz_completions enable row level security;
alter table training_session_logs enable row level security;
alter table weekly_checkins enable row level security;
alter table discussion_threads enable row level security;
alter table discussion_comments enable row level security;
alter table comment_reports enable row level security;

create policy "profiles_select_own" on profiles
    for select using (auth.uid() = id);

create policy "profiles_update_own" on profiles
    for update using (auth.uid() = id);

create policy "quiz_select_own" on quiz_completions
    for select using (auth.uid() = user_id);

create policy "quiz_insert_own" on quiz_completions
    for insert with check (auth.uid() = user_id);

create policy "training_logs_select_own" on training_session_logs
    for select using (auth.uid() = user_id);

create policy "training_logs_insert_own" on training_session_logs
    for insert with check (auth.uid() = user_id);

create policy "weekly_checkins_select_own" on weekly_checkins
    for select using (auth.uid() = user_id);

create policy "weekly_checkins_upsert_own" on weekly_checkins
    for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "threads_read_all" on discussion_threads
    for select using (true);

create policy "comments_read_all" on discussion_comments
    for select using (true);

create policy "comments_insert_own" on discussion_comments
    for insert with check (auth.uid() = author_id);

create policy "comments_update_own" on discussion_comments
    for update using (auth.uid() = author_id);

create policy "comments_delete_own" on discussion_comments
    for delete using (auth.uid() = author_id);

create policy "reports_insert_own" on comment_reports
    for insert with check (auth.uid() = reporter_id);
