-- Clips — "what do you see in this stroke?" (docs/CLIPS-SPEC.md)
--
-- One person, one clip, one share link. Friends (in the app) and anyone with
-- the link (in a browser) answer the same four questions; verified coaches'
-- answers are tallied apart from players'; an AI view fills the empty first
-- day. Nobody's answer is "the" answer — the tally function returns views,
-- never a verdict.
--
-- Privacy shape, in one paragraph: a clip is readable by its owner and the
-- people it was sent to, nobody else, and never through a client policy on
-- storage — playback is a short signed URL minted by the edge function. The
-- uploader's declared rating lives in its own owner-only table so no policy
-- mistake on `clips` can leak it. Raw votes are readable only by the person
-- who cast them; the owner sees aggregates through `clip_tally`.

-- ---------------------------------------------------------------- storage --
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('clips', 'clips', false, 16777216, array['video/mp4', 'video/quicktime', 'image/jpeg'])
on conflict (id) do nothing;

-- ------------------------------------------------------------------ clips --
create table if not exists public.clips (
    id            uuid        primary key default gen_random_uuid(),
    code          text        not null unique,                 -- /k/<code>
    owner         uuid        not null references auth.users (id) on delete cascade,
    stroke        text        not null check (stroke in ('forehand','backhand','serve','volley')),
    duration_ms   integer     not null check (duration_ms between 500 and 20000),
    storage_path  text        not null,                        -- <owner>/<id>/clip.mp4
    poster_path   text,                                        -- <owner>/<id>/poster.jpg
    uploaded_at   timestamptz,                                 -- null until the bytes landed
    visibility    text        not null default 'friends' check (visibility in ('friends','group','public')),
    status        text        not null default 'active' check (status in ('active','reported','removed')),
    created_at    timestamptz not null default now(),
    purge_at      timestamptz not null default now() + interval '180 days',
    purged_at     timestamptz
);
create index if not exists clips_owner_idx on public.clips (owner, created_at desc);
create index if not exists clips_purge_idx on public.clips (purge_at) where purged_at is null;

-- The declared rating is the one thing a viewer must never see before
-- answering Q4. Its own table, its own policy, no join from the viewer side.
create table if not exists public.clip_private (
    clip_id        uuid    primary key references public.clips (id) on delete cascade,
    rating_system  text    check (rating_system in ('wtn','utr','band')),
    rating_value   numeric,
    rating_band    text
);

create table if not exists public.clip_recipients (
    clip_id   uuid not null references public.clips (id) on delete cascade,
    user_id   uuid not null references auth.users (id) on delete cascade,
    sent_at   timestamptz not null default now(),
    primary key (clip_id, user_id)
);
create index if not exists clip_recipients_user_idx on public.clip_recipients (user_id);

-- One row per view of the clip. `rater_kind` is frozen at vote time: becoming
-- a coach later does not rewrite history. Web answers carry a salted IP-day
-- hash instead of a user and never mix into the coach/player tallies.
create table if not exists public.clip_votes (
    id           uuid        primary key default gen_random_uuid(),
    clip_id      uuid        not null references public.clips (id) on delete cascade,
    rater        uuid        references auth.users (id) on delete set null,
    rater_kind   text        not null check (rater_kind in ('coach','player','web','ai')),
    voter_hash   text,
    q1           text        not null,
    q2           text,
    q3_ms        integer,
    q4_guess     numeric,
    answered_at  timestamptz not null default now()
);
create unique index if not exists clip_votes_one_per_user on public.clip_votes (clip_id, rater) where rater is not null;
create unique index if not exists clip_votes_one_per_web  on public.clip_votes (clip_id, voter_hash) where voter_hash is not null;
create unique index if not exists clip_votes_one_ai       on public.clip_votes (clip_id) where rater_kind = 'ai';
create index if not exists clip_votes_clip_idx on public.clip_votes (clip_id);

create table if not exists public.clip_reports (
    id          uuid        primary key default gen_random_uuid(),
    clip_id     uuid        not null references public.clips (id) on delete cascade,
    reporter    uuid        references auth.users (id) on delete set null,
    reason      text        not null check (length(reason) between 1 and 300),
    created_at  timestamptz not null default now()
);

-- ------------------------------------------------------------ friendships --
-- Mutual, formed by opening a friend's link. (user_a < user_b) so a pair has
-- exactly one row whichever side created it.
create table if not exists public.friendships (
    user_a     uuid not null references auth.users (id) on delete cascade,
    user_b     uuid not null references auth.users (id) on delete cascade,
    created_at timestamptz not null default now(),
    source     text not null default 'link',
    primary key (user_a, user_b),
    check (user_a < user_b)
);
create index if not exists friendships_b_idx on public.friendships (user_b);

-- Every user has one short code; it rides inside every link they share so
-- the person who installs from it becomes their friend with nothing typed.
create table if not exists public.user_invite_codes (
    user_id uuid primary key references auth.users (id) on delete cascade,
    code    text not null unique
);

-- ------------------------------------------------------------- coach star --
-- Self-serve application; Can verifies. Until `verified_at`, votes count as
-- player and nothing in the app says "coach" — no "pending" badge either.
alter table public.coach_review_coaches
    add column if not exists credential_type text,
    add column if not exists credential_ref  text,
    add column if not exists credential_path text,   -- private storage path of the uploaded document
    add column if not exists applied_at      timestamptz,
    add column if not exists verified_at     timestamptz,
    add column if not exists verified_by     text;

-- ------------------------------------------------------------------- RLS --
alter table public.clips             enable row level security;
alter table public.clip_private      enable row level security;
alter table public.clip_recipients   enable row level security;
alter table public.clip_votes        enable row level security;
alter table public.clip_reports      enable row level security;
alter table public.friendships       enable row level security;
alter table public.user_invite_codes enable row level security;

-- A clip is visible to its owner and to the people it was sent to.
drop policy if exists clips_read on public.clips;
create policy clips_read on public.clips for select
    using (auth.uid() = owner
        or exists (select 1 from public.clip_recipients r where r.clip_id = clips.id and r.user_id = auth.uid()));
drop policy if exists clips_owner_write on public.clips;
create policy clips_owner_write on public.clips for update using (auth.uid() = owner) with check (auth.uid() = owner);
drop policy if exists clips_owner_delete on public.clips;
create policy clips_owner_delete on public.clips for delete using (auth.uid() = owner);
-- Inserts go through the edge function (service role) so a code is minted
-- and the storage path is shaped server-side.

drop policy if exists clip_private_owner on public.clip_private;
create policy clip_private_owner on public.clip_private for select
    using (exists (select 1 from public.clips c where c.id = clip_private.clip_id and c.owner = auth.uid()));

drop policy if exists clip_recipients_read on public.clip_recipients;
create policy clip_recipients_read on public.clip_recipients for select
    using (auth.uid() = user_id
        or exists (select 1 from public.clips c where c.id = clip_recipients.clip_id and c.owner = auth.uid()));

-- Raw votes: only the person who cast one may read it. Owners read aggregates
-- through clip_tally(); recipients never see each other's answers.
drop policy if exists clip_votes_own on public.clip_votes;
create policy clip_votes_own on public.clip_votes for select using (auth.uid() = rater);

drop policy if exists clip_reports_insert on public.clip_reports;
create policy clip_reports_insert on public.clip_reports for insert
    with check (auth.uid() = reporter
        and exists (select 1 from public.clip_recipients r where r.clip_id = clip_reports.clip_id and r.user_id = auth.uid()));

drop policy if exists friendships_read on public.friendships;
create policy friendships_read on public.friendships for select using (auth.uid() = user_a or auth.uid() = user_b);
drop policy if exists friendships_delete on public.friendships;
create policy friendships_delete on public.friendships for delete using (auth.uid() = user_a or auth.uid() = user_b);

drop policy if exists invite_codes_own on public.user_invite_codes;
create policy invite_codes_own on public.user_invite_codes for select using (auth.uid() = user_id);

-- Storage: nobody reads clip objects through a client policy. The function
-- mints short signed URLs for owner/recipients (and for the web page by code).
-- No policy on storage.objects for this bucket, on purpose.

-- ----------------------------------------------------------------- tally --
-- Views side by side. Returns null tallies below the threshold so the screen
-- says "not enough yet" instead of showing one person's opinion as a crowd.
-- SECURITY DEFINER because raw votes are not readable by the owner; callable
-- only by the clip's owner or a recipient.
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
    v_ok := (v_uid = v_owner) or exists (select 1 from public.clip_recipients r where r.clip_id = p_clip and r.user_id = v_uid);
    if not v_ok then raise exception 'not allowed'; end if;

    foreach k in array kinds loop
        select count(*) into n from public.clip_votes v where v.clip_id = p_clip and v.rater_kind = k;
        -- coach and ai views show from one vote; player and web need a crowd.
        if n = 0 or (k in ('player','web') and n < v_min) then
            part := jsonb_build_object('n', n, 'shown', false);
        else
            select jsonb_build_object(
                'n', n, 'shown', true,
                'q1', (select coalesce(jsonb_object_agg(q1, c), '{}'::jsonb) from (select q1, count(*) c from public.clip_votes where clip_id = p_clip and rater_kind = k group by q1) s),
                'q2', (select coalesce(jsonb_object_agg(q2, c), '{}'::jsonb) from (select q2, count(*) c from public.clip_votes where clip_id = p_clip and rater_kind = k and q2 is not null group by q2) s),
                'q3_median_ms', (select percentile_cont(0.5) within group (order by q3_ms) from public.clip_votes where clip_id = p_clip and rater_kind = k and q3_ms is not null),
                'q4_mean', (select round(avg(q4_guess)::numeric, 2) from public.clip_votes where clip_id = p_clip and rater_kind = k and q4_guess is not null),
                'q4_n', (select count(*) from public.clip_votes where clip_id = p_clip and rater_kind = k and q4_guess is not null)
            ) into part;
        end if;
        result := result || jsonb_build_object(k, part);
    end loop;

    -- The owner's own declared rating rides along only for the owner.
    if v_uid = v_owner then
        result := result || jsonb_build_object('declared',
            (select jsonb_build_object('system', rating_system, 'value', rating_value, 'band', rating_band)
             from public.clip_private where clip_id = p_clip));
    end if;
    return result;
end;
$$;
revoke all on function public.clip_tally(uuid) from public;
grant execute on function public.clip_tally(uuid) to authenticated, service_role;

-- Friend list as the app needs it: the other side of every row.
create or replace function public.my_friends()
returns table (friend uuid, since timestamptz)
language sql
security definer
set search_path = public
stable
as $$
    select case when user_a = auth.uid() then user_b else user_a end, created_at
    from public.friendships
    where user_a = auth.uid() or user_b = auth.uid();
$$;
revoke all on function public.my_friends() from public;
grant execute on function public.my_friends() to authenticated;

-- The 180-day promise, same shape as the coach-review purge.
create or replace function public.prune_clips(p_limit integer default 200)
returns setof public.clips
language sql
security definer
set search_path = public
as $$
    select * from public.clips where purge_at < now() and purged_at is null limit p_limit;
$$;
revoke all on function public.prune_clips(integer) from public;
grant execute on function public.prune_clips(integer) to service_role;

-- Belt and braces: the default EXECUTE grant to anon/authenticated bit us in
-- September (20260926010000). Nothing here is callable by anon.
revoke all on table public.clips, public.clip_private, public.clip_recipients, public.clip_votes,
    public.clip_reports, public.friendships, public.user_invite_codes from anon;
