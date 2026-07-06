-- ============================================================
-- T's Pay — Supabase Database Schema
-- Run this in your Supabase SQL Editor (Dashboard → SQL Editor)
-- ============================================================

-- ── 1. Profiles (extends auth.users) ─────────────────────────────────────────
create table if not exists public.profiles (
  id uuid references auth.users(id) on delete cascade primary key,
  email text,
  full_name text,
  avatar_url text,
  owner_id uuid references auth.users(id),
  role text check (role in ('ADMIN', 'WAITRESS', 'SUPER_ADMIN')) default 'WAITRESS',
  created_at timestamptz default now() not null
);

alter table public.profiles
  add column if not exists owner_id uuid references auth.users(id);

-- Auto-create profile on signup
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, email, full_name, owner_id, role)
  values (
    new.id,
    new.email,
    new.raw_user_meta_data->>'full_name',
    coalesce((new.raw_user_meta_data->>'owner_id')::uuid, new.id),
    'WAITRESS'
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ── 2. Bank Accounts ──────────────────────────────────────────────────────────
create table if not exists public.bank_accounts (
  id uuid default gen_random_uuid() primary key,
  holder_name text not null,
  bank_name text not null,
  account_number text not null,
  phone text,
  notes text,
  owner_id uuid references auth.users(id),
  is_active boolean default true not null,
  created_at timestamptz default now() not null
);

alter table public.bank_accounts
  add column if not exists owner_id uuid references auth.users(id);

-- ── 3. Transactions ───────────────────────────────────────────────────────────
create table if not exists public.transactions (
  id uuid default gen_random_uuid() primary key,
  bank_name text not null,
  reference_code text not null,
  buyer_name text not null default 'Unknown',
  amount decimal(10, 2) not null check (amount >= 0),
  tip decimal(10, 2) default 0.00 check (tip >= 0),
  status text check (status in ('PENDING', 'VERIFIED', 'FAILED')) default 'PENDING' not null,
  verified_by uuid references public.profiles(id) on delete set null,
  owner_id uuid references auth.users(id),
  image_url text,
  created_at timestamptz default now() not null
);

alter table public.transactions
  add column if not exists owner_id uuid references auth.users(id);

-- ── 4. Row Level Security ─────────────────────────────────────────────────────

-- Profiles: users can read all, update their own
alter table public.profiles enable row level security;

create policy "Users can view their cafe profiles" on public.profiles
  for select using (
    auth.uid() = id
    or owner_id = auth.uid()
    or exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'SUPER_ADMIN'
    )
  );

create policy "Users can update cafe profiles" on public.profiles
  for update using (
    auth.uid() = id
    or owner_id = auth.uid()
    or exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'SUPER_ADMIN'
    )
  );

-- Bank Accounts: authenticated users can read/write
alter table public.bank_accounts enable row level security;

create policy "Cafe owners can view bank accounts" on public.bank_accounts
  for select using (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid()
        and (p.role = 'ADMIN' or p.role = 'SUPER_ADMIN')
        and (p.id = owner_id or p.owner_id = owner_id)
    )
  );

create policy "Cafe owners can manage bank accounts" on public.bank_accounts
  for all using (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid()
        and (p.role = 'ADMIN' or p.role = 'SUPER_ADMIN')
        and (p.id = owner_id or p.owner_id = owner_id)
    )
  )
  with check (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid()
        and (p.role = 'ADMIN' or p.role = 'SUPER_ADMIN')
        and (p.id = owner_id or p.owner_id = owner_id)
    )
  );

-- Transactions: all authenticated can read; insert own; admin can read all
alter table public.transactions enable row level security;

create policy "Cafe members can view transactions" on public.transactions
  for select using (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid()
        and (p.id = owner_id or p.owner_id = owner_id)
    )
    or exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'SUPER_ADMIN'
    )
  );

create policy "Cafe members can create transactions" on public.transactions
  for insert with check (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid()
        and (p.id = owner_id or p.owner_id = owner_id)
    )
    or exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'SUPER_ADMIN'
    )
  );

create policy "Cafe owners can update transactions" on public.transactions
  for update using (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid()
        and p.role = 'ADMIN'
        and (p.id = owner_id or p.owner_id = owner_id)
    )
    or exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'SUPER_ADMIN'
    )
  );

create policy "Cafe owners can delete transactions" on public.transactions
  for delete using (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid()
        and p.role = 'ADMIN'
        and (p.id = owner_id or p.owner_id = owner_id)
    )
    or exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'SUPER_ADMIN'
    )
  );

-- ── 5. Indexes ────────────────────────────────────────────────────────────────
create index if not exists idx_transactions_created_at on public.transactions(created_at desc);
create index if not exists idx_transactions_status on public.transactions(status);
create index if not exists idx_transactions_bank on public.transactions(bank_name);
create index if not exists idx_transactions_verified_by on public.transactions(verified_by);
create index if not exists idx_transactions_owner_id on public.transactions(owner_id);
create index if not exists idx_bank_accounts_owner_id on public.bank_accounts(owner_id);
create index if not exists idx_profiles_owner_id on public.profiles(owner_id);

-- ── 6. First Admin User Setup ─────────────────────────────────────────────────
-- After creating your account, run this to make yourself admin:
-- UPDATE public.profiles SET role = 'ADMIN' WHERE email = 'your-email@example.com';
