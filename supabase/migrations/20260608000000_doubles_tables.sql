-- Doubles v1.1 — account-linked partnerships via invite link + joint match log.
--
-- A partnership is one row: the inviter creates it (status 'pending') with a
-- short share `code`; the invitee opens the WhatsApp/universal link, installs +
-- signs in, and accepts via the RPC (status 'active'). Both participants can
-- then read the partnership (→ both see the compatibility score) and log
-- doubles matches against it.
--
-- Additive only: new tables + RLS + RPCs. Does NOT touch existing tables.

-- ============================================================ partnerships
create table if not exists public.doubles_partnerships (
    id               uuid        primary key default gen_random_uuid(),
    code             text        not null unique,                 -- short code in the share link
    inviter_user_id  uuid        not null references auth.users(id) on delete cascade,
    inviter_name     text,
    inviter_profile  jsonb       not null,                        -- DoublesProfile JSON
    invitee_user_id  uuid        references auth.users(id) on delete set null,
    invitee_name     text,
    invitee_profile  jsonb,                                       -- null until accepted
    status           text        not null default 'pending',      -- pending | active
    created_at       timestamptz not null default now(),
    accepted_at      timestamptz
);

create index if not exists doubles_partnerships_inviter_idx on public.doubles_partnerships (inviter_user_id);
create index if not exists doubles_partnerships_invitee_idx on public.doubles_partnerships (invitee_user_id);

alter table public.doubles_partnerships enable row level security;

-- Read / update / delete: either participant. (Pre-accept lookup by code is
-- done through the SECURITY DEFINER RPCs below, since the invitee isn't a
-- participant yet.)
create policy "doubles_partnerships: select participant"
    on public.doubles_partnerships for select
    using (auth.uid() = inviter_user_id or auth.uid() = invitee_user_id);

create policy "doubles_partnerships: insert own"
    on public.doubles_partnerships for insert
    with check (auth.uid() = inviter_user_id);

create policy "doubles_partnerships: update participant"
    on public.doubles_partnerships for update
    using (auth.uid() = inviter_user_id or auth.uid() = invitee_user_id);

create policy "doubles_partnerships: delete participant"
    on public.doubles_partnerships for delete
    using (auth.uid() = inviter_user_id or auth.uid() = invitee_user_id);

-- ============================================================ matches
create table if not exists public.doubles_matches (
    id                 uuid        primary key default gen_random_uuid(),
    partnership_id     uuid        not null references public.doubles_partnerships(id) on delete cascade,
    logged_by_user_id  uuid        references auth.users(id) on delete set null,
    played_on          date        not null,
    won                boolean,
    score              text,
    opponents          text,
    notes              text,
    created_at         timestamptz not null default now()
);

create index if not exists doubles_matches_partnership_idx on public.doubles_matches (partnership_id);

alter table public.doubles_matches enable row level security;

-- A match is visible/editable to either partner of its partnership.
create policy "doubles_matches: select partner"
    on public.doubles_matches for select
    using (exists (
        select 1 from public.doubles_partnerships p
        where p.id = partnership_id
          and (auth.uid() = p.inviter_user_id or auth.uid() = p.invitee_user_id)
    ));

create policy "doubles_matches: insert partner"
    on public.doubles_matches for insert
    with check (
        auth.uid() = logged_by_user_id
        and exists (
            select 1 from public.doubles_partnerships p
            where p.id = partnership_id
              and (auth.uid() = p.inviter_user_id or auth.uid() = p.invitee_user_id)
        )
    );

create policy "doubles_matches: update partner"
    on public.doubles_matches for update
    using (exists (
        select 1 from public.doubles_partnerships p
        where p.id = partnership_id
          and (auth.uid() = p.inviter_user_id or auth.uid() = p.invitee_user_id)
    ));

create policy "doubles_matches: delete partner"
    on public.doubles_matches for delete
    using (exists (
        select 1 from public.doubles_partnerships p
        where p.id = partnership_id
          and (auth.uid() = p.inviter_user_id or auth.uid() = p.invitee_user_id)
    ));

-- ============================================================ invite RPCs
-- The invitee isn't a participant until they accept, so they can't SELECT the
-- pending row under RLS. These SECURITY DEFINER functions provide a narrow,
-- safe lookup/accept path keyed by the share code.

-- Minimal pre-accept peek: who invited me + current status. No profiles leaked.
create or replace function public.peek_doubles_invite(invite_code text)
returns table (inviter_name text, status text, already_member boolean)
language sql
security definer
set search_path = public
as $$
    select p.inviter_name,
           p.status,
           (auth.uid() = p.inviter_user_id or auth.uid() = p.invitee_user_id) as already_member
    from public.doubles_partnerships p
    where p.code = invite_code
    limit 1;
$$;

-- Accept an invite: claim the pending row as the invitee. Guards against
-- accepting your own invite or an already-accepted one. Returns partnership id.
create or replace function public.accept_doubles_invite(
    invite_code text,
    p_invitee_name text,
    p_invitee_profile jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
    pid uuid;
begin
    if auth.uid() is null then
        raise exception 'not authenticated';
    end if;

    select id into pid
    from public.doubles_partnerships
    where code = invite_code
    for update;

    if pid is null then
        raise exception 'invite not found';
    end if;

    -- Idempotent: if the caller already joined this partnership, just return it.
    if exists (
        select 1 from public.doubles_partnerships
        where id = pid and invitee_user_id = auth.uid()
    ) then
        return pid;
    end if;

    if exists (
        select 1 from public.doubles_partnerships
        where id = pid and inviter_user_id = auth.uid()
    ) then
        raise exception 'cannot accept your own invite';
    end if;

    if exists (
        select 1 from public.doubles_partnerships
        where id = pid and status = 'active'
    ) then
        raise exception 'invite already accepted';
    end if;

    update public.doubles_partnerships
    set invitee_user_id = auth.uid(),
        invitee_name    = p_invitee_name,
        invitee_profile = p_invitee_profile,
        status          = 'active',
        accepted_at     = now()
    where id = pid;

    return pid;
end;
$$;

grant execute on function public.peek_doubles_invite(text) to authenticated;
grant execute on function public.accept_doubles_invite(text, text, jsonb) to authenticated;
