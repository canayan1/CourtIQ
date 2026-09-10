-- Coach review hardening (docs/COACH-REVIEW-ACTIVATION.md §1c, §2, §4).
--
-- 1. One order per App Store transaction. The app retries a submission after
--    a crash with the SAME transaction; the edge function looks the order up
--    by this id first and returns it, so a retry can never double-order.
create unique index if not exists coach_review_orders_txn_uidx
    on public.coach_review_orders (iap_txn_id)
    where iap_txn_id is not null;

-- 2. What the player will be reviewed in, which storefront environment paid,
--    and when the raw clip was actually deleted (the consent screen promises
--    90 days; the promise needs a record).
alter table public.coach_review_orders
    add column if not exists review_language text not null default 'en',
    add column if not exists iap_environment text,
    add column if not exists video_purged_at timestamptz;

-- 3. Every clip access is attributable (policy §4). Service role only: no
--    policies, RLS on, so neither players nor a leaked anon key can read it.
create table if not exists public.coach_review_access_log (
    id         bigserial primary key,
    order_id   uuid not null references public.coach_review_orders (id) on delete cascade,
    coach_id   uuid references public.coach_review_coaches (id) on delete set null,
    action     text not null check (action in ('mint', 'claim', 'deliver', 'purge')),
    created_at timestamptz not null default now()
);
create index if not exists coach_review_access_log_order_idx
    on public.coach_review_access_log (order_id, created_at desc);
alter table public.coach_review_access_log enable row level security;

-- 4. The 90-day purge runs daily whether or not anyone opens the panel.
--    pg_cron calls the maintenance function through pg_net; the shared
--    secret lives in Vault (inserted once at deploy time, never in a file).
create extension if not exists pg_cron;
create extension if not exists pg_net;

select cron.schedule(
    'coach-review-maintenance',
    '17 3 * * *',
    $cron$
    select net.http_post(
        url     := 'https://ybnodzzrkwennzpwyjmr.supabase.co/functions/v1/coach-review-maintenance',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'x-maintenance-secret',
            (select decrypted_secret from vault.decrypted_secrets
              where name = 'coach_review_maintenance_secret' limit 1)),
        body    := '{"action":"daily"}'::jsonb
    );
    $cron$
);
