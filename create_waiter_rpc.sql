-- Run this in Supabase SQL Editor (Dashboard > SQL Editor > New query)
-- Paste the entire contents and click Run.

-- 1. Drop old restrictive insert policy that blocks waiter creation
drop policy if exists "Anyone can submit pending application" on public.profiles;

-- 2. New INSERT policy: allows pending admin signups AND managers creating waiters
create policy "Managers can insert waiter profiles" on public.profiles
  for insert to authenticated
  with check (
    -- Original: pending admin application from sign-up page
    (status = 'PENDING' and role in ('ADMIN', 'SUPER_ADMIN'))
    or
    -- New: a logged-in admin inserting a waiter under their owner_id
    (
      role = 'WAITRESS'
      and status = 'APPROVED'
      and owner_id = auth.uid()
      and exists (
        select 1 from public.profiles p
        where p.id = auth.uid()
          and p.role in ('ADMIN', 'SUPER_ADMIN')
      )
    )
  );

-- 3. SECURITY DEFINER RPC (primary path — bypasses RLS entirely)
create or replace function public.create_waiter_profile(
  waiter_id    uuid,
  waiter_email text,
  waiter_name  text,
  manager_id   uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1 from public.profiles
    where id = auth.uid()
      and role in ('ADMIN', 'SUPER_ADMIN')
  ) then
    raise exception 'Only managers can create waiters';
  end if;

  insert into public.profiles (id, email, full_name, role, owner_id, status, created_at)
  values (waiter_id, waiter_email, waiter_name, 'WAITRESS', manager_id, 'APPROVED', now())
  on conflict (id) do update
    set full_name = excluded.full_name,
        role      = excluded.role,
        owner_id  = excluded.owner_id,
        status    = excluded.status;
end;
$$;

grant execute on function public.create_waiter_profile(uuid, text, text, uuid) to authenticated;
