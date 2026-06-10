-- Per-user usage ledger for AI Swing Analysis, used to enforce a hard
-- daily/monthly cap (cost control for the Claude vision calls).
create table if not exists public.swing_analyses (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null default auth.uid(),
  created_at timestamptz not null default now()
);

alter table public.swing_analyses enable row level security;

do $$ begin
  create policy "swing_analyses_insert_own" on public.swing_analyses
    for insert with check (auth.uid() = user_id);
exception when duplicate_object then null; end $$;

do $$ begin
  create policy "swing_analyses_select_own" on public.swing_analyses
    for select using (auth.uid() = user_id);
exception when duplicate_object then null; end $$;

create index if not exists swing_analyses_user_time_idx
  on public.swing_analyses (user_id, created_at);
