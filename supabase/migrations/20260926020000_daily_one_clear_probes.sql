-- Remove the votes this machine cast while testing the deployed endpoint.
--
-- Two days hold one synthetic vote each: 2026-09-25 from a curl smoke test and
-- 2026-09-26 from a tap in the simulator, both proving the path worked. Nobody
-- else has the feature yet, so every row in these two days is mine.
--
-- Neither would ever have been visible — the screen withholds the split below
-- fifty answers — but this feature's whole argument is that it does not show
-- numbers it cannot stand behind, and that argument is weaker if the table it
-- reads from was seeded by its author.
delete from public.daily_one_votes  where day in (date '2026-09-25', date '2026-09-26');
delete from public.daily_one_voters where day in (date '2026-09-25', date '2026-09-26');
