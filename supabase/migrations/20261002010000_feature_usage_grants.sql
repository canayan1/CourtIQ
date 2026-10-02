-- Same lesson as 20260926010000: RLS with no policies answers an anon SELECT
-- with `200 []`, which is not a leak but is not a statement of intent either.
-- A reader should be told "you cannot", not "there is nothing here today" —
-- the second sentence becomes false the moment someone adds a policy for an
-- unrelated reason.
revoke all on table public.feature_usage_daily from anon, authenticated;
