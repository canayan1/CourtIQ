-- The first clips migration made two policies look at each other: "may I read
-- this clip" asked clip_recipients, and "may I read this recipient row" asked
-- clips. Postgres evaluates RLS on the inner query too, so the question never
-- bottoms out — 42P17 infinite recursion, a 500 for every caller including the
-- owner. Found by the anon probe before any client ever hit it.
--
-- Fix: each side asks a SECURITY DEFINER helper that reads the other table
-- without RLS. The helpers take the caller's uid from auth.uid(), never from an
-- argument, so they answer only about the caller.

create or replace function public.clip_is_owner(p_clip uuid)
returns boolean language sql security definer stable set search_path = public as $$
    select exists (select 1 from public.clips c where c.id = p_clip and c.owner = auth.uid());
$$;
create or replace function public.clip_is_recipient(p_clip uuid)
returns boolean language sql security definer stable set search_path = public as $$
    select exists (select 1 from public.clip_recipients r where r.clip_id = p_clip and r.user_id = auth.uid());
$$;
revoke all on function public.clip_is_owner(uuid), public.clip_is_recipient(uuid) from public;
grant execute on function public.clip_is_owner(uuid), public.clip_is_recipient(uuid) to authenticated, service_role;

drop policy if exists clips_read on public.clips;
create policy clips_read on public.clips for select
    using (auth.uid() = owner or public.clip_is_recipient(id));

drop policy if exists clip_private_owner on public.clip_private;
create policy clip_private_owner on public.clip_private for select
    using (public.clip_is_owner(clip_id));

drop policy if exists clip_recipients_read on public.clip_recipients;
create policy clip_recipients_read on public.clip_recipients for select
    using (auth.uid() = user_id or public.clip_is_owner(clip_id));

drop policy if exists clip_reports_insert on public.clip_reports;
create policy clip_reports_insert on public.clip_reports for insert
    with check (auth.uid() = reporter and public.clip_is_recipient(clip_id));
