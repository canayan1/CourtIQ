-- Coach Review P0 — real human swing reviews (docs/COACH-REVIEW-PLAN.md).
--
-- A user buys a review (consumable IAP), their clip lands in a PRIVATE bucket,
-- a real coach watches it and returns the "One Thing" deliverable
-- (docs/COACH-REVIEW-TEMPLATE.md §6). Users only ever see their own rows;
-- coaches read the queue through the service role (edge functions), never
-- directly from the client.

-- ---------------------------------------------------------------- storage --
insert into storage.buckets (id, name, public)
values ('coach-reviews', 'coach-reviews', false)
on conflict (id) do nothing;

-- ----------------------------------------------------------------- orders --
create table if not exists public.coach_review_orders (
    id             uuid primary key default gen_random_uuid(),
    user_id        uuid not null references auth.users (id) on delete cascade,
    status         text not null default 'submitted'
                     check (status in ('submitted','in_review','delivered','refunded','cancelled')),
    stroke         text not null,
    handedness     text,
    note           text,                      -- optional "what should I look at?"
    video_path     text not null,             -- object path inside coach-reviews
    iap_txn_id     text,                      -- StoreKit transaction id (audit)
    created_at     timestamptz not null default now(),
    sla_due_at     timestamptz not null default now() + interval '72 hours',
    delivered_at   timestamptz,
    -- 90-day retention on the RAW video (deliverables are kept, see policy §5)
    purge_video_at timestamptz
);

create index if not exists coach_review_orders_user_idx
    on public.coach_review_orders (user_id, created_at desc);
create index if not exists coach_review_orders_queue_idx
    on public.coach_review_orders (status, sla_due_at);

-- ----------------------------------------------------------- deliverables --
-- The "One Thing" format: a 5-checkpoint scorecard, ONE highest-leverage fix
-- (sentence + timestamp + cue), 3 micro-notes, 1 drill, plus a 2-3 min voice
-- note. Everything except the voice file is small JSON/text.
create table if not exists public.coach_review_deliverables (
    id             uuid primary key default gen_random_uuid(),
    order_id       uuid not null unique references public.coach_review_orders (id) on delete cascade,
    scorecard      jsonb not null default '{}'::jsonb,  -- {preparation:1-5|null, contact:…, chain:…, finish:…, footwork:…}
    one_thing      text not null,
    one_thing_at   numeric,                             -- seconds into the clip
    one_thing_cue  text,
    micro_notes    jsonb not null default '[]'::jsonb,  -- [{at: 4.0, kind:'good'|'fault', text:'…'}]
    drill_title    text,
    drill_body     text,
    voice_path     text,                                -- object path inside coach-reviews
    rating         smallint check (rating between 1 and 5),
    created_at     timestamptz not null default now()
);

-- --------------------------------------------------------------- coaches --
-- Roster row per reviewer. Kept minimal at P0 (the owner is coach #1); the
-- public-facing tier labels live in the app, not here.
create table if not exists public.coach_review_coaches (
    id            uuid primary key default gen_random_uuid(),
    user_id       uuid unique references auth.users (id) on delete set null,
    display_tier  text not null default 'founding',
    active        boolean not null default true,
    revenue_share numeric not null default 0.80,
    created_at    timestamptz not null default now()
);

-- ------------------------------------------------------------------ RLS ---
alter table public.coach_review_orders       enable row level security;
alter table public.coach_review_deliverables enable row level security;
alter table public.coach_review_coaches      enable row level security;

-- Users: read their own orders. Writes happen through edge functions
-- (service role) so an order can never exist without a verified purchase.
drop policy if exists coach_orders_select_own on public.coach_review_orders;
create policy coach_orders_select_own
    on public.coach_review_orders for select
    using (auth.uid() = user_id);

-- Users: read the deliverable for an order they own.
drop policy if exists coach_deliverables_select_own on public.coach_review_deliverables;
create policy coach_deliverables_select_own
    on public.coach_review_deliverables for select
    using (exists (
        select 1 from public.coach_review_orders o
        where o.id = coach_review_deliverables.order_id
          and o.user_id = auth.uid()
    ));

-- Storage: a user may read only objects under their own uid prefix
-- (<uid>/<order>/clip.mp4). Coaches stream via short-lived signed URLs minted
-- by the service role — never by a client policy (policy §4).
drop policy if exists coach_reviews_read_own on storage.objects;
create policy coach_reviews_read_own
    on storage.objects for select
    using (
        bucket_id = 'coach-reviews'
        and (storage.foldername(name))[1] = auth.uid()::text
    );
