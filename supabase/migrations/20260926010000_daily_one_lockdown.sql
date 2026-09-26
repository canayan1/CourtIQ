-- Daily One — close two holes the first migration left open.
--
-- 20260926000000 revoked execute on both functions FROM PUBLIC and assumed
-- that was enough. It is not. Supabase sets a default privilege granting
-- EXECUTE on new public-schema functions to `anon` and `authenticated`, and a
-- revoke from PUBLIC does not touch a grant held directly by a role. Probing
-- the deployed project with the app's own publishable key confirmed it:
--
--   POST /rest/v1/rpc/daily_one_cast   -> 200, vote counted
--   POST /rest/v1/rpc/daily_one_prune  -> 204, voter rows deleted
--
-- The first is the whole ballot box: the key ships inside the app binary, and
-- a caller passing its own `p_voter` string votes as many times as it likes.
-- The second is worse — a destructive maintenance function anyone could call.
--
-- The edge function reaches these with the service role, which is not routable
-- from a client, so revoking the API roles costs nothing.

revoke execute on function public.daily_one_cast(date, smallint, text)
    from anon, authenticated, public;
revoke execute on function public.daily_one_prune(integer)
    from anon, authenticated, public;

-- The tables were already safe — RLS with no policies returned an empty set
-- rather than rows — but an empty 200 is an accident of RLS, not a statement
-- of intent. Take the grants away too, so the answer is "you cannot" instead
-- of "there is nothing here today".
revoke all on table public.daily_one_votes  from anon, authenticated;
revoke all on table public.daily_one_voters from anon, authenticated;

-- Anything created in this schema later inherits the same default grant that
-- caused this, so stop issuing it.
alter default privileges in schema public revoke execute on functions from anon, authenticated;

-- One-time: 2026-09-25 holds nothing but the probe above — two votes cast by
-- this machine while testing the endpoint. Nobody has the feature yet, so the
-- day is otherwise empty and the honest thing is to leave no fake votes in it.
delete from public.daily_one_votes  where day = date '2026-09-25';
delete from public.daily_one_voters where day = date '2026-09-25';
