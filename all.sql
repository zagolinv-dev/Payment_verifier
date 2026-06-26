-- ===== FINAL FIX =====

-- 1. Add all columns to profiles
alter table public.profiles add column if not exists status text check (status in ('PENDING', 'APPROVED', 'REJECTED')) default 'APPROVED';
alter table public.profiles add column if not exists phone text;
alter table public.profiles add column if not exists owner_name text;
alter table public.profiles add column if not exists address text;
alter table public.profiles add column if not exists description text;

-- 1b. Remove FK constraint so we can insert pending profiles without auth user
alter table public.profiles drop constraint if exists profiles_id_fkey;

-- 2. Drop ALL old profile RLS policies
drop policy if exists "Users can read own profile" on public.profiles;
drop policy if exists "Admin can read all profiles" on public.profiles;
drop policy if exists "Admins can view all profiles" on public.profiles;
drop policy if exists "Users can view all profiles" on public.profiles;
drop policy if exists "Users can update own profile" on public.profiles;
drop policy if exists "Admin can update profiles" on public.profiles;
drop policy if exists "Admins can update any profile" on public.profiles;
drop policy if exists "Admins can delete profiles" on public.profiles;

-- 3. Clean profile RLS
create policy "Users can view all profiles" on public.profiles for select using (auth.role() = 'authenticated');
create policy "Users can update own profile" on public.profiles for update using (auth.uid() = id);
create policy "Admins can update any profile" on public.profiles for update using (exists (select 1 from public.profiles where id = auth.uid() and role = 'ADMIN'));
create policy "Admins can delete profiles" on public.profiles for delete using (exists (select 1 from public.profiles where id = auth.uid() and role = 'ADMIN'));

-- 3c. Allow anyone to submit a pending application
create policy "Anyone can submit pending application" on public.profiles
  for insert to anon, authenticated
  with check (status = 'PENDING' and role = 'ADMIN');

-- 4. Drop ALL old notification RLS policies
drop policy if exists "Admin can read notifications" on public.notifications;
drop policy if exists "Admin can insert notifications" on public.notifications;
drop policy if exists "Admin can update notifications" on public.notifications;
drop policy if exists "Users can view own notifications" on public.notifications;
drop policy if exists "Users can insert own notifications" on public.notifications;
drop policy if exists "Users can update own notifications" on public.notifications;

-- 5. Ensure notifications has user_id column
alter table public.notifications add column if not exists user_id uuid references auth.users(id) on delete cascade;

-- 6. Clean notification RLS
create policy "Users can view own notifications" on public.notifications for select using (auth.uid() = user_id);
create policy "Users can insert own notifications" on public.notifications for insert with check (auth.uid() = user_id);
create policy "Users can update own notifications" on public.notifications for update using (auth.uid() = user_id);
create policy "Users can delete own notifications" on public.notifications for delete using (auth.uid() = user_id);

-- 7. Drop ALL old transaction RLS policies
drop policy if exists "Admin can read all transactions" on public.transactions;
drop policy if exists "Waitress can read own transactions" on public.transactions;
drop policy if exists "Admin can insert transactions" on public.transactions;
drop policy if exists "Waitress can insert own transactions" on public.transactions;
drop policy if exists "Admin can update transactions" on public.transactions;
drop policy if exists "Admin can delete transactions" on public.transactions;
drop policy if exists "Authenticated can view transactions" on public.transactions;
drop policy if exists "Authenticated can create transactions" on public.transactions;

-- 8. Clean transaction RLS
create policy "Authenticated can view transactions" on public.transactions for select using (auth.role() = 'authenticated');
create policy "Authenticated can create transactions" on public.transactions for insert with check (auth.role() = 'authenticated');
create policy "Admin can update transactions" on public.transactions for update using (exists (select 1 from public.profiles where id = auth.uid() and role = 'ADMIN'));

-- 9. Recreate trigger with all profile fields
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_role text;
begin
  v_role := coalesce(new.raw_user_meta_data->>'role', 'WAITRESS');
  insert into public.profiles (id, email, full_name, role, status, phone, owner_name, address, description)
  values (
    new.id,
    new.email,
    new.raw_user_meta_data->>'full_name',
    v_role,
    case when v_role = 'ADMIN' then 'PENDING' else 'APPROVED' end,
    new.raw_user_meta_data->>'phone',
    new.raw_user_meta_data->>'owner_name',
    new.raw_user_meta_data->>'address',
    new.raw_user_meta_data->>'description'
  )
  on conflict (id) do update set
    email = excluded.email,
    role = excluded.role,
    status = case when public.profiles.status = 'PENDING' then 'PENDING' else excluded.status end,
    phone = coalesce(public.profiles.phone, excluded.phone),
    owner_name = coalesce(public.profiles.owner_name, excluded.owner_name),
    address = coalesce(public.profiles.address, excluded.address),
    description = coalesce(public.profiles.description, excluded.description);
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 10. Set existing admin profiles
update public.profiles set status = 'PENDING' where role = 'ADMIN' and (status is null or status = 'APPROVED');
update public.profiles set role = 'ADMIN' where email = 'zagolinv@gmail.com' and role is distinct from 'ADMIN';

-- ===== WAITER PASSWORD RESET REQUESTS =====

-- 11. Password reset requests table (waiter -> manager)
create table if not exists public.password_reset_requests (
  id uuid not null default gen_random_uuid() primary key,
  name text not null,
  email text not null,
  created_at timestamptz not null default now(),
  is_resolved boolean not null default false
);

-- Allow anyone (even unauthenticated waiters) to insert
alter table public.password_reset_requests enable row level security;
drop policy if exists "Anyone can insert reset requests" on public.password_reset_requests;
create policy "Anyone can insert reset requests" on public.password_reset_requests
  for insert to anon, authenticated
  with check (true);

-- Only authenticated users (manager/admin) can view/update
drop policy if exists "Authenticated can view reset requests" on public.password_reset_requests;
create policy "Authenticated can view reset requests" on public.password_reset_requests
  for select to authenticated using (true);

drop policy if exists "Authenticated can update reset requests" on public.password_reset_requests;
create policy "Authenticated can update reset requests" on public.password_reset_requests
  for update to authenticated using (true) with check (true);

-- ===== VERIFICATION ATTEMPTS TRACKING =====

create table if not exists public.verification_attempts (
  id uuid not null default gen_random_uuid() primary key,
  reference_code text not null default '',
  amount decimal(10,2) not null default 0,
  receiver_account text not null default '',
  transaction_date text not null default '',
  bank_name text not null default '',
  buyer_name text not null default '',
  failure_reason text not null default '',
  attempt_count int not null default 1,
  verified_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

alter table public.verification_attempts enable row level security;
drop policy if exists "Authenticated can insert attempts" on public.verification_attempts;
create policy "Authenticated can insert attempts" on public.verification_attempts
  for insert to authenticated with check (true);
drop policy if exists "Authenticated can view attempts" on public.verification_attempts;
create policy "Authenticated can view attempts" on public.verification_attempts
  for select to authenticated using (true);
