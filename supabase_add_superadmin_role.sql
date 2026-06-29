-- ============================================================
-- Add SUPER_ADMIN role to profiles
-- Run this in Supabase SQL Editor (Dashboard → SQL Editor)
-- Idempotent — safe to run multiple times
-- ============================================================

-- ── 1. Update CHECK constraint to allow SUPER_ADMIN ───────────────────────────
do $$ begin
  alter table public.profiles drop constraint if exists profiles_role_check;
exception when others then null;
end $$;

alter table public.profiles add constraint profiles_role_check
  check (role in ('ADMIN', 'WAITRESS', 'SUPER_ADMIN'));

-- ── 2. Update trigger function for new signups ───────────────────────────────
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v_role text;
begin
  v_role := coalesce(new.raw_user_meta_data->>'role', 'WAITRESS');
  insert into public.profiles (id, email, full_name, role, status)
  values (
    new.id,
    new.email,
    new.raw_user_meta_data->>'full_name',
    v_role,
    case when v_role = 'ADMIN' then 'PENDING' else 'APPROVED' end
  );
  return new;
end;
$$;

-- ── 3. Update RLS policies to grant SUPER_ADMIN same access as ADMIN ─────────
-- Drop old policies
drop policy if exists "Admins can update any profile" on public.profiles;
drop policy if exists "Admins can delete profiles" on public.profiles;
drop policy if exists "Admin can update transactions" on public.transactions;
drop policy if exists "Admin can delete transactions" on public.transactions;
drop policy if exists "Admins can manage merchants" on public.merchants;
drop policy if exists "Admins can manage platform settings" on public.platform_settings;
drop policy if exists "Admins can view audit logs" on public.audit_logs;

-- Re-create with role in ('ADMIN', 'SUPER_ADMIN')
create policy "Admins can update any profile" on public.profiles
  for update using (
    exists (select 1 from public.profiles where id = auth.uid() and role in ('ADMIN', 'SUPER_ADMIN'))
  );

create policy "Admins can delete profiles" on public.profiles
  for delete using (
    exists (select 1 from public.profiles where id = auth.uid() and role in ('ADMIN', 'SUPER_ADMIN'))
  );

create policy "Admin can update transactions" on public.transactions
  for update using (
    exists (select 1 from public.profiles where id = auth.uid() and role in ('ADMIN', 'SUPER_ADMIN'))
  );

create policy "Admin can delete transactions" on public.transactions
  for delete using (
    exists (select 1 from public.profiles where id = auth.uid() and role in ('ADMIN', 'SUPER_ADMIN'))
  );

create policy "Admins can manage merchants" on public.merchants
  for all using (
    exists (select 1 from public.profiles where id = auth.uid() and role in ('ADMIN', 'SUPER_ADMIN'))
  );

create policy "Admins can manage platform settings" on public.platform_settings
  for all using (
    exists (select 1 from public.profiles where id = auth.uid() and role in ('ADMIN', 'SUPER_ADMIN'))
  );

create policy "Admins can view audit logs" on public.audit_logs
  for select using (
    exists (select 1 from public.profiles where id = auth.uid() and role in ('ADMIN', 'SUPER_ADMIN'))
  );

-- ── 4. Update clear_all_data function (used by dashboard) ────────────────────
create or replace function public.clear_all_data()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1 from public.profiles where id = auth.uid() and role in ('ADMIN', 'SUPER_ADMIN')
  ) then
    raise exception 'Only admins can clear all data';
  end if;
  delete from public.notifications;
  delete from public.transactions;
end;
$$;

grant execute on function public.clear_all_data() to authenticated;
