-- Clips, round two (Can, 13 Oct): a pinned clip on the profile that friends
-- can see, and a 1–10 score beside the four questions.
--
-- The score is still about the stroke, not the person, and it is only ever
-- shown to the clip's owner as an aggregate per kind — never a leaderboard,
-- never next to a name. Same rule as every other number in this feature.

create table if not exists public.clip_profiles (
    user_id         uuid primary key references auth.users (id) on delete cascade,
    display_name    text check (length(display_name) between 1 and 40),
    pinned_clip_id  uuid references public.clips (id) on delete set null,
    updated_at      timestamptz not null default now()
);

alter table public.clip_votes
    add column if not exists score smallint check (score between 1 and 10);

alter table public.clip_profiles enable row level security;
revoke all on table public.clip_profiles from anon;

-- "Are these two people friends?" without touching RLS on friendships.
create or replace function public.clip_is_friend(p_other uuid)
returns boolean language sql security definer stable set search_path = public as $$
    select exists (
        select 1 from public.friendships f
        where (f.user_a = auth.uid() and f.user_b = p_other)
           or (f.user_b = auth.uid() and f.user_a = p_other));
$$;
revoke all on function public.clip_is_friend(uuid) from public;
grant execute on function public.clip_is_friend(uuid) to authenticated, service_role;

drop policy if exists clip_profiles_read on public.clip_profiles;
create policy clip_profiles_read on public.clip_profiles for select
    using (auth.uid() = user_id or public.clip_is_friend(user_id));
drop policy if exists clip_profiles_write on public.clip_profiles;
create policy clip_profiles_write on public.clip_profiles for insert with check (auth.uid() = user_id);
drop policy if exists clip_profiles_update on public.clip_profiles;
create policy clip_profiles_update on public.clip_profiles for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- A pinned clip is readable by every friend: the share function keeps
-- clip_recipients in step, and this policy covers friends made later.
drop policy if exists clips_read on public.clips;
create policy clips_read on public.clips for select
    using (auth.uid() = owner
        or public.clip_is_recipient(id)
        or (public.clip_is_friend(owner)
            and exists (select 1 from public.clip_profiles p where p.user_id = clips.owner and p.pinned_clip_id = clips.id)));

-- Tally: the score rides along per kind, owner-only like everything else.
create or replace function public.clip_tally(p_clip uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_uid    uuid := auth.uid();
    v_owner  uuid;
    v_ok     boolean;
    v_min    integer := 3;
    result   jsonb := '{}'::jsonb;
    kinds    text[] := array['coach','player','web','ai'];
    k        text;
    n        integer;
    part     jsonb;
begin
    select owner into v_owner from public.clips where id = p_clip;
    if v_owner is null then return null; end if;
    v_ok := (v_uid = v_owner)
         or exists (select 1 from public.clip_recipients r where r.clip_id = p_clip and r.user_id = v_uid)
         or (public.clip_is_friend(v_owner)
             and exists (select 1 from public.clip_profiles p where p.user_id = v_owner and p.pinned_clip_id = p_clip));
    if not v_ok then raise exception 'not allowed'; end if;

    foreach k in array kinds loop
        select count(*) into n from public.clip_votes v where v.clip_id = p_clip and v.rater_kind = k;
        if n = 0 or (k in ('player','web') and n < v_min) then
            part := jsonb_build_object('n', n, 'shown', false);
        else
            select jsonb_build_object(
                'n', n, 'shown', true,
                'q1', (select coalesce(jsonb_object_agg(q1, c), '{}'::jsonb) from (select q1, count(*) c from public.clip_votes where clip_id = p_clip and rater_kind = k group by q1) s),
                'q2', (select coalesce(jsonb_object_agg(q2, c), '{}'::jsonb) from (select q2, count(*) c from public.clip_votes where clip_id = p_clip and rater_kind = k and q2 is not null group by q2) s),
                'q3_median_ms', (select percentile_cont(0.5) within group (order by q3_ms) from public.clip_votes where clip_id = p_clip and rater_kind = k and q3_ms is not null),
                'q4_mean', (select round(avg(q4_guess)::numeric, 2) from public.clip_votes where clip_id = p_clip and rater_kind = k and q4_guess is not null),
                'q4_n', (select count(*) from public.clip_votes where clip_id = p_clip and rater_kind = k and q4_guess is not null),
                'score_mean', (select round(avg(score)::numeric, 1) from public.clip_votes where clip_id = p_clip and rater_kind = k and score is not null),
                'score_n', (select count(*) from public.clip_votes where clip_id = p_clip and rater_kind = k and score is not null)
            ) into part;
        end if;
        result := result || jsonb_build_object(k, part);
    end loop;

    if v_uid = v_owner then
        result := result || jsonb_build_object('declared',
            (select jsonb_build_object('system', rating_system, 'value', rating_value, 'band', rating_band)
             from public.clip_private where clip_id = p_clip));
    end if;
    return result;
end;
$$;
