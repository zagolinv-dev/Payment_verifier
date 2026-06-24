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
  role text check (role in ('ADMIN', 'WAITRESS')) default 'WAITRESS',
  created_at timestamptz default now() not null
);

-- Auto-create profile on signup
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, email, full_name, role)
  values (
    new.id,
    new.email,
    new.raw_user_meta_data->>'full_name',
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
  is_active boolean default true not null,
  created_at timestamptz default now() not null
);

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
  image_url text,
  created_at timestamptz default now() not null
);

-- ── 4. Row Level Security ─────────────────────────────────────────────────────

-- Profiles: users can read all, update their own
alter table public.profiles enable row level security;

create policy "Users can view all profiles" on public.profiles
  for select using (auth.role() = 'authenticated');

create policy "Users can update own profile" on public.profiles
  for update using (auth.uid() = id);

-- Bank Accounts: authenticated users can read/write
alter table public.bank_accounts enable row level security;

create policy "Authenticated users can view bank accounts" on public.bank_accounts
  for select using (auth.role() = 'authenticated');

create policy "Authenticated users can manage bank accounts" on public.bank_accounts
  for all using (auth.role() = 'authenticated');

-- Transactions: all authenticated can read; insert own; admin can read all
alter table public.transactions enable row level security;

create policy "Authenticated can view transactions" on public.transactions
  for select using (auth.role() = 'authenticated');

create policy "Authenticated can create transactions" on public.transactions
  for insert with check (auth.uid() = verified_by);

create policy "Admin can update transactions" on public.transactions
  for update using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'ADMIN'
    )
  );

-- ── 5. Indexes ────────────────────────────────────────────────────────────────
create index if not exists idx_transactions_created_at on public.transactions(created_at desc);
create index if not exists idx_transactions_status on public.transactions(status);
create index if not exists idx_transactions_bank on public.transactions(bank_name);
create index if not exists idx_transactions_verified_by on public.transactions(verified_by);

-- ── 6. First Admin User Setup ─────────────────────────────────────────────────
-- After creating your account, run this to make yourself admin:
-- UPDATE public.profiles SET role = 'ADMIN' WHERE email = 'your-email@example.com';
