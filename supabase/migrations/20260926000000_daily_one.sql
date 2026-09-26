-- Daily One — the shared question's crowd split.
--
-- Everyone gets the same scenario each day; this is where "61% said B" comes
-- from. Two tables, both written only by the edge function with the service
-- role: anon has no grants here at all, so a leaked anon key cannot stuff a
-- ballot box directly.
--
-- What is stored is a day, an option number and a count. No account id, no
-- device id, no IP. The de-duplication key is a salted hash that is scoped to
-- one day, so it cannot be joined across days into a profile of anybody.

create table if not exists public.daily_one_votes (
    day     date     not null,
    option  smallint not null check (option >= 0 and option < 8),
    votes   integer  not null default 0 check (votes >= 0),
    primary key (day, option)
);

-- One vote per voter per day. `voter` is sha256(salt || day || ip) computed in
-- the edge function: unique within a day, meaningless outside it, and not
-- reversible to an address.
create table if not exists public.daily_one_voters (
    day        date        not null,
    voter      text        not null,
    created_at timestamptz not null default now(),
    primary key (day, voter)
);

create index if not exists daily_one_voters_day_idx on public.daily_one_voters (day);

alter table public.daily_one_votes  enable row level security;
alter table public.daily_one_voters enable row level security;

-- No policies on purpose. RLS with zero policies denies everything to anon and
-- authenticated; the service role bypasses RLS, and the edge function is the
-- only thing holding it.

-- Counting a vote and reading the day back has to be one statement, or two
-- phones answering at the same instant can each read a total that never
-- existed. SECURITY DEFINER so the function owns the write; it is only
-- reachable through the edge function because execute is granted to nobody
-- else.
create or replace function public.daily_one_cast(
    p_day    date,
    p_option smallint,
    p_voter  text
)
-- The OUT names deliberately avoid `option`/`votes`: PL/pgSQL would then have
-- to guess whether those mean the output parameter or the table column, and
-- it resolves that guess by raising an error at runtime.
returns table (opt smallint, cnt integer)
language plpgsql
security definer
set search_path = public
as $$
declare
    v_rows integer := 0;
begin
    if p_option is not null and p_voter is not null then
        insert into public.daily_one_voters (day, voter)
        values (p_day, p_voter)
        on conflict (day, voter) do nothing;

        get diagnostics v_rows = row_count;

        -- Zero rows means this voter already answered today. Their first
        -- answer stands and nothing is counted twice.
        if v_rows > 0 then
            insert into public.daily_one_votes (day, option, votes)
            values (p_day, p_option, 1)
            on conflict (day, option)
            do update set votes = public.daily_one_votes.votes + 1;
        end if;
    end if;

    return query
        select v.option, v.votes
        from public.daily_one_votes v
        where v.day = p_day
        order by v.option;
end;
$$;

revoke all on function public.daily_one_cast(date, smallint, text) from public;
-- The edge function holds the service role and is the only caller.
grant execute on function public.daily_one_cast(date, smallint, text) to service_role;

-- Housekeeping: the counts are only interesting while the day is recent, and
-- the voter rows are dead weight after it. Kept for a season so a "this week"
-- view stays possible, then dropped.
create or replace function public.daily_one_prune(p_keep_days integer default 120)
returns void
language sql
security definer
set search_path = public
as $$
    delete from public.daily_one_voters where day < current_date - p_keep_days;
$$;

revoke all on function public.daily_one_prune(integer) from public;
grant execute on function public.daily_one_prune(integer) to service_role;
