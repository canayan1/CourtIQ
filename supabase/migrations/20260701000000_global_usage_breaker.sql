-- Global daily budget breaker.
--
-- A single shared counter that every paid-LLM edge function bumps right before
-- it calls the provider. Once the whole app crosses GLOBAL_DAILY_CALL_CAP for
-- the day, the functions refuse further calls — so a spam/abuse burst (or a
-- leaked anon key) can never drain the prepaid AI budget. The worst-case daily
-- bill is bounded to roughly (cap × per-call cost) regardless of attack shape.
--
-- Edge functions run with the caller's JWT (RLS applies), so they cannot touch
-- this table directly. All access goes through bump_global_usage(), a
-- SECURITY DEFINER function that increments atomically and is tamper-proof: the
-- caller may EXECUTE it but can neither read nor write the counter.

create table if not exists public.global_usage_daily (
    usage_date  date    primary key,
    call_count  integer not null default 0
);

alter table public.global_usage_daily enable row level security;
-- Intentionally NO policies: only the SECURITY DEFINER function below may touch
-- the counter. Direct reads/writes by anon/authenticated are denied by RLS.

create or replace function public.bump_global_usage()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    new_count integer;
begin
    insert into public.global_usage_daily (usage_date, call_count)
    values (current_date, 1)
    on conflict (usage_date)
    do update set call_count = public.global_usage_daily.call_count + 1
    returning call_count into new_count;
    return new_count;
end;
$$;

revoke all on function public.bump_global_usage() from public;
grant execute on function public.bump_global_usage() to anon, authenticated;
