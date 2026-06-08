-- profiles — per-user profile row the app upserts/reads after Apple sign-in.
--
-- This table was referenced by the client (UserSessionManager profile sync:
-- upsert/select into "profiles") but never created, so after a successful
-- Apple sign-in the profile sync failed with
--   "Could not find the table 'public.profiles' in the schema cache"
-- which surfaced as an "account issue" and blocked Sign in with Apple
-- (App Review 2.1(a)). Anonymous sessions never hit this (profile push is
-- gated to the Apple provider), which is why the AI Coach worked.
--
-- Columns mirror RemoteUserProfileRecord (client encoder uses snake_case).

create table if not exists public.profiles (
    id                    uuid        primary key references auth.users(id) on delete cascade,
    display_name          text        not null,
    email                 text,
    sign_in_provider      text        not null,
    current_focus         text        not null,
    top_mistake_patterns  jsonb       not null default '[]'::jsonb,
    created_at            timestamptz not null default now(),
    updated_at            timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "profiles: select own"
    on public.profiles for select
    using (auth.uid() = id);

create policy "profiles: insert own"
    on public.profiles for insert
    with check (auth.uid() = id);

create policy "profiles: update own"
    on public.profiles for update
    using (auth.uid() = id);

create policy "profiles: delete own"
    on public.profiles for delete
    using (auth.uid() = id);
