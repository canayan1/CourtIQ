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
    id text primary key,
    user_id uuid not null references profiles(id) on delete cascade,
    quiz_id text not null,
    title text not null,
    focus_label text not null,
    score integer not null,
    total_questions integer not null,
    mistake_types jsonb not null default '[]'::jsonb,
    is_daily boolean not null default false,
    completed_at timestamptz not null default timezone('utc', now())
);

create table if not exists training_session_logs (
    id text primary key,
    user_id uuid not null references profiles(id) on delete cascade,
    program_id text not null,
    week integer not null,
    day_id text not null,
    completed_at timestamptz not null default timezone('utc', now())
);

create table if not exists weekly_checkins (
    id text primary key,
    user_id uuid not null references profiles(id) on delete cascade,
    program_id text not null,
    week integer not null,
    readiness integer not null check (readiness between 1 and 5),
    explosiveness integer not null check (explosiveness between 1 and 5),
    conditioning integer not null check (conditioning between 1 and 5),
    notes text not null default '',
    updated_at timestamptz not null default timezone('utc', now())
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
    id text primary key,
    thread_id text not null references discussion_threads(id) on delete cascade,
    author_id uuid not null references profiles(id) on delete cascade,
    author_name text not null,
    body text not null,
    is_pinned boolean not null default false,
    created_at timestamptz not null default timezone('utc', now()),
    edited_at timestamptz
);

create table if not exists comment_likes (
    id text primary key,
    thread_id text not null references discussion_threads(id) on delete cascade,
    comment_id text not null references discussion_comments(id) on delete cascade,
    user_id uuid not null references profiles(id) on delete cascade,
    created_at timestamptz not null default timezone('utc', now()),
    unique (comment_id, user_id)
);

create table if not exists comment_reports (
    id text primary key,
    thread_id text not null references discussion_threads(id) on delete cascade,
    comment_id text not null references discussion_comments(id) on delete cascade,
    reporter_id uuid not null references profiles(id) on delete cascade,
    reason text not null,
    created_at timestamptz not null default timezone('utc', now()),
    unique (comment_id, reporter_id)
);

create index if not exists quiz_completions_user_completed_at_idx
    on quiz_completions (user_id, completed_at desc);

create index if not exists training_session_logs_user_program_idx
    on training_session_logs (user_id, program_id, week);

create index if not exists weekly_checkins_user_program_idx
    on weekly_checkins (user_id, program_id, week);

create index if not exists discussion_comments_thread_created_at_idx
    on discussion_comments (thread_id, created_at asc);

create index if not exists comment_likes_thread_comment_idx
    on comment_likes (thread_id, comment_id);

create index if not exists comment_reports_thread_comment_idx
    on comment_reports (thread_id, comment_id);

alter table profiles enable row level security;
alter table quiz_completions enable row level security;
alter table training_session_logs enable row level security;
alter table weekly_checkins enable row level security;
alter table discussion_threads enable row level security;
alter table discussion_comments enable row level security;
alter table comment_likes enable row level security;
alter table comment_reports enable row level security;

create policy "profiles_select_own" on profiles
    for select using (auth.uid() = id);

create policy "profiles_insert_own" on profiles
    for insert with check (auth.uid() = id);

create policy "profiles_update_own" on profiles
    for update using (auth.uid() = id) with check (auth.uid() = id);

create policy "profiles_delete_own" on profiles
    for delete using (auth.uid() = id);

create policy "quiz_select_own" on quiz_completions
    for select using (auth.uid() = user_id);

create policy "quiz_insert_own" on quiz_completions
    for insert with check (auth.uid() = user_id);

create policy "quiz_update_own" on quiz_completions
    for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "training_logs_select_own" on training_session_logs
    for select using (auth.uid() = user_id);

create policy "training_logs_insert_own" on training_session_logs
    for insert with check (auth.uid() = user_id);

create policy "training_logs_delete_own" on training_session_logs
    for delete using (auth.uid() = user_id);

create policy "weekly_checkins_select_own" on weekly_checkins
    for select using (auth.uid() = user_id);

create policy "weekly_checkins_upsert_own" on weekly_checkins
    for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "threads_read_all" on discussion_threads
    for select using (true);

create policy "threads_insert_authenticated" on discussion_threads
    for insert with check (auth.role() = 'authenticated');

create policy "threads_update_authenticated" on discussion_threads
    for update using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

create policy "comments_read_all" on discussion_comments
    for select using (true);

create policy "comments_insert_own" on discussion_comments
    for insert with check (auth.uid() = author_id);

create policy "comments_update_own" on discussion_comments
    for update using (auth.uid() = author_id) with check (auth.uid() = author_id);

create policy "comments_delete_own" on discussion_comments
    for delete using (auth.uid() = author_id);

create policy "likes_read_all" on comment_likes
    for select using (true);

create policy "likes_insert_own" on comment_likes
    for insert with check (auth.uid() = user_id);

create policy "likes_delete_own" on comment_likes
    for delete using (auth.uid() = user_id);

create policy "reports_insert_own" on comment_reports
    for insert with check (auth.uid() = reporter_id);

insert into discussion_threads (id, target_type, target_id, title, subtitle, starter_prompt)
values
    (
        'thread-quiz-serve_001',
        'quizItem',
        'serve_001',
        'Second serve pressure choices',
        'How players protect second serves without getting passive.',
        'What is your safest second-serve pattern when the scoreboard gets tight?'
    ),
    (
        'thread-training-hybrid-foundation',
        'trainingSession',
        'training-hybrid-foundation',
        '8-week hybrid foundation',
        'How players manage soreness, cardio, and explosive work in one weekly plan.',
        'Which day in the foundation week feels most transferable to your tennis goals right now?'
    ),
    (
        'thread-mobility-quick-reset-001',
        'mobilityFlow',
        'quick-reset-001',
        'Serve Shoulder Reset',
        'How the quick reset changes serve feel before practice or match play.',
        'Do you use this flow before serving sessions, after, or both?'
    )
on conflict (id) do update
set
    title = excluded.title,
    subtitle = excluded.subtitle,
    starter_prompt = excluded.starter_prompt,
    updated_at = timezone('utc', now());
