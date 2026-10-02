-- Per-user daily caps for the text-LLM features.
--
-- The global breaker (20260701000000) bounds the TOTAL daily bill, which is the
-- right backstop and the wrong tool for this job: it answers "how much can the
-- app spend today" and says nothing about who spent it. Today one account can
-- call match-analysis and doubles-analysis in a loop, eat the whole 400-call
-- allowance before lunch, and every other player gets a 503 for the rest of the
-- day. The bill is safe; the product is not.
--
-- Worse, those two functions share a Google API key with swing-analysis
-- (GEMINI_VIDEO_API_KEY is unset, so swing falls back to GEMINI_API_KEY). So
-- exhausting the free text quota degrades the paid video feature — the one
-- people actually subscribe for.
--
-- swing-analysis already has a per-user cap, for free: it writes a row per
-- analysis and counts its own table under RLS. match and doubles persist
-- nothing, so they need a counter of their own.

create table if not exists public.feature_usage_daily (
    usage_date date    not null default current_date,
    user_id    uuid    not null,
    feature    text    not null,
    call_count integer not null default 0,
    primary key (usage_date, user_id, feature)
);

create index if not exists feature_usage_daily_date_idx
    on public.feature_usage_daily (usage_date);

alter table public.feature_usage_daily enable row level security;
-- No policies, same as the global counter: the SECURITY DEFINER function below
-- is the only way in. A caller may increment their own tally and cannot read
-- it, cannot lower it, and cannot see anybody else's.

-- The user is taken from the JWT, never from an argument.
--
-- That is the whole security of this thing. A `p_user_id` parameter would let
-- any caller bump a stranger's counter to lock them out, or mint a fresh id per
-- request and never hit the cap at all — which would make the cap decorative.
create or replace function public.bump_feature_usage(p_feature text)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    v_user  uuid := auth.uid();
    v_count integer;
begin
    if v_user is null then
        raise exception 'bump_feature_usage requires an authenticated caller';
    end if;
    if p_feature is null or length(p_feature) = 0 or length(p_feature) > 40 then
        raise exception 'bump_feature_usage: bad feature name';
    end if;

    insert into public.feature_usage_daily (usage_date, user_id, feature, call_count)
    values (current_date, v_user, p_feature, 1)
    on conflict (usage_date, user_id, feature)
    do update set call_count = public.feature_usage_daily.call_count + 1
    returning call_count into v_count;

    return v_count;
end;
$$;

revoke all on function public.bump_feature_usage(text) from public;
grant execute on function public.bump_feature_usage(text) to authenticated;

-- Yesterday's tallies are dead weight; nothing reads them after the day turns.
-- Kept for a fortnight so "was that user actually abusing it, or did they just
-- have a busy Sunday" stays answerable.
create or replace function public.prune_feature_usage(p_keep_days integer default 14)
returns void
language sql
security definer
set search_path = public
as $$
    delete from public.feature_usage_daily where usage_date < current_date - p_keep_days;
$$;

revoke all on function public.prune_feature_usage(integer) from public;
grant execute on function public.prune_feature_usage(integer) to service_role;
