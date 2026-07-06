-- ============================================================
-- Fix SUPER_ADMIN SELECT permissions on all tables
-- Run this in Supabase SQL Editor (Dashboard → SQL Editor)
-- Idempotent — safe to run multiple times
-- ============================================================

-- ── 1. profiles table ────────────────────────────────────────────────────────

-- Drop and recreate the SELECT policies so SUPER_ADMIN can read all profiles
drop policy if exists "Admins can view all profiles" on public.profiles;
drop policy if exists "Super admin can view all profiles" on public.profiles;
drop policy if exists "Users can view own profile" on public.profiles;

-- Allow every authenticated user to view their OWN profile
create policy "Users can view own profile" on public.profiles
  for select using (auth.uid() = id);

-- Allow ADMIN and SUPER_ADMIN to view ALL profiles
create policy "Admins can view all profiles" on public.profiles
  for select using (
    exists (
      select 1 from public.profiles
      where id = auth.uid()
        and role in ('ADMIN', 'SUPER_ADMIN')
    )
  );

-- ── 2. transactions table ────────────────────────────────────────────────────

drop policy if exists "Admins can view all transactions" on public.transactions;
drop policy if exists "Super admin can view all transactions" on public.transactions;
drop policy if exists "Admin can view transactions" on public.transactions;

create policy "Admins can view all transactions" on public.transactions
  for select using (
    exists (
      select 1 from public.profiles
      where id = auth.uid()
        and role in ('ADMIN', 'SUPER_ADMIN')
    )
  );

-- ── 3. notifications table (for NotificationBell) ───────────────────────────

drop policy if exists "Admins can view all notifications" on public.notifications;

create policy "Admins can view all notifications" on public.notifications
  for select using (
    exists (
      select 1 from public.profiles
      where id = auth.uid()
        and role in ('ADMIN', 'SUPER_ADMIN')
    )
  );

-- Allow admins to update notifications (mark as read)
drop policy if exists "Admins can update notifications" on public.notifications;

create policy "Admins can update notifications" on public.notifications
  for update using (
    exists (
      select 1 from public.profiles
      where id = auth.uid()
        and role in ('ADMIN', 'SUPER_ADMIN')
    )
  );

-- ── 4. Verify SELECT RLS is enabled on these tables ─────────────────────────
-- (These should already be enabled, but just to confirm)
alter table public.profiles enable row level security;
alter table public.transactions enable row level security;
alter table public.notifications enable row level security;
