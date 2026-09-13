-- The coach can bounce a clip they cannot open, and the player sends a new
-- one without paying again (docs/COACH-REVIEW-ACTIVATION.md, "received /
-- can't open" handshake).
--
--   submitted ──claim──▶ in_review ──deliver──▶ delivered
--       │                    │
--       └──────reject────────┴──▶ needs_reupload ──reupload──▶ submitted (SLA restarts)

alter table public.coach_review_orders
    drop constraint if exists coach_review_orders_status_check;
alter table public.coach_review_orders
    add constraint coach_review_orders_status_check
    check (status in ('submitted','in_review','needs_reupload','delivered','refunded','cancelled'));

alter table public.coach_review_orders
    -- What the coach told the player when bouncing the clip. Cleared on re-upload.
    add column if not exists coach_message  text,
    add column if not exists reupload_count integer not null default 0;

alter table public.coach_review_access_log
    drop constraint if exists coach_review_access_log_action_check;
alter table public.coach_review_access_log
    add constraint coach_review_access_log_action_check
    check (action in ('mint', 'claim', 'reject', 'reupload', 'deliver', 'purge'));
