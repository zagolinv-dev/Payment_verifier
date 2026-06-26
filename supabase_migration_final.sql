-- ============================================================
-- T's Pay — Final Complete Supabase Migration
-- Idempotent — safe to run multiple times
-- Run this in Supabase SQL Editor (Dashboard → SQL Editor)
-- ============================================================

-- ═══════════════════════════════════════════════════════════════
-- SECTION 1: CORE TABLES (profiles, transactions, bank_accounts)
-- ═══════════════════════════════════════════════════════════════

-- ── 1a. Profiles (extends auth.users) ─────────────────────────────────────────
create table if not exists public.profiles (
  id uuid references auth.users(id) on delete cascade primary key,
  email text,
  full_name text,
  avatar_url text,
  role text check (role in ('ADMIN', 'WAITRESS')) default 'WAITRESS',
  status text check (status in ('PENDING', 'APPROVED', 'REJECTED')) default 'APPROVED',
  created_at timestamptz default now() not null
);

do $$ begin
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'profiles' and column_name = 'status') then
    alter table public.profiles add column status text check (status in ('PENDING', 'APPROVED', 'REJECTED')) default 'APPROVED';
  end if;
end $$;

-- Auto-create profile on signup
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

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ── 1b. Transactions ──────────────────────────────────────────────────────────
create table if not exists public.transactions (
  id uuid default gen_random_uuid() primary key,
  bank_name text not null,
  reference_code text not null,
  buyer_name text not null default 'Unknown',
  amount decimal(10, 2) not null check (amount >= 0),
  tip decimal(10, 2) default 0.00 check (tip >= 0),
  status text check (status in ('PENDING', 'VERIFIED', 'FAILED')) default 'PENDING' not null,
  verified_by uuid references public.profiles(id) on delete set null,
  receipt_image text,
  image_url text,
  risk_score decimal(5, 2) default 0,
  risk_flags text[] default '{}',
  order_total decimal(10, 2) default 0,
  created_at timestamptz default now() not null
);

-- ── 1c. Bank Accounts ─────────────────────────────────────────────────────────
create table if not exists public.bank_accounts (
  id uuid default gen_random_uuid() primary key,
  holder_name text not null,
  bank_name text not null,
  account_number text not null,
  account_holder text,
  phone text,
  notes text,
  is_active boolean default true not null,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz default now() not null
);

-- ── 1d. Notifications ─────────────────────────────────────────────────────────
create table if not exists public.notifications (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) on delete cascade not null,
  type text not null default 'info',
  title text not null,
  message text not null,
  transaction_id uuid references public.transactions(id) on delete set null,
  amount decimal(10, 2) default 0,
  is_read boolean default false,
  created_at timestamptz default now() not null
);

-- ═══════════════════════════════════════════════════════════════
-- SECTION 2: ADMIN PORTAL TABLES (merchants, settings, audit)
-- ═══════════════════════════════════════════════════════════════

-- ── 2a. Merchants / Companies ─────────────────────────────────────────────────
create table if not exists public.merchants (
  id uuid default gen_random_uuid() primary key,
  owner_id uuid references public.profiles(id) on delete set null,
  business_name text not null,
  business_email text,
  business_phone text,
  category text,
  bank_name text not null,
  account_number text not null,
  status text check (status in ('PENDING', 'APPROVED', 'SUSPENDED', 'REJECTED')) default 'PENDING',
  notes text,
  volume decimal(12, 2) default 0,
  submitted_at timestamptz default now() not null
);

-- ── 2b. Platform Settings ─────────────────────────────────────────────────────
create table if not exists public.platform_settings (
  id uuid default gen_random_uuid() primary key,
  commission_fee decimal(4, 2) default 1.00,
  min_payout decimal(10, 2) default 5000.00,
  ocr_confidence decimal(4, 2) default 85.00,
  auto_verify boolean default true,
  updated_at timestamptz default now() not null,
  updated_by uuid references public.profiles(id) on delete set null
);

-- ── 2c. Audit Logs ────────────────────────────────────────────────────────────
create table if not exists public.audit_logs (
  id uuid default gen_random_uuid() primary key,
  action text not null,
  target_type text,
  target_id text,
  operator_id uuid references public.profiles(id) on delete set null,
  details text,
  created_at timestamptz default now() not null
);

-- ═══════════════════════════════════════════════════════════════
-- SECTION 3: ROW LEVEL SECURITY POLICIES
-- Uses DO blocks so it never errors — safe to run repeatedly
-- ═══════════════════════════════════════════════════════════════

-- Ensure all columns referenced in policies exist regardless of table origin
do $$ begin
  if exists (select 1 from information_schema.tables where table_schema = 'public' and table_name = 'notifications')
    and not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'notifications' and column_name = 'user_id') then
    alter table public.notifications add column user_id uuid references auth.users(id) on delete cascade;
  end if;
end $$;

-- ── 3a. Profiles RLS ─────────────────────────────────────────────────────────
alter table public.profiles enable row level security;

do $$ begin
  if not exists (select 1 from pg_policies where policyname = 'Users can view all profiles' and tablename = 'profiles') then
    create policy "Users can view all profiles" on public.profiles for select using (auth.role() = 'authenticated');
  end if;
end $$;

do $$ begin
  if not exists (select 1 from pg_policies where policyname = 'Users can update own profile' and tablename = 'profiles') then
    create policy "Users can update own profile" on public.profiles for update using (auth.uid() = id);
  end if;
end $$;

do $$ begin
  if not exists (select 1 from pg_policies where policyname = 'Admins can update any profile' and tablename = 'profiles') then
    create policy "Admins can update any profile" on public.profiles for update using (
      exists (select 1 from public.profiles where id = auth.uid() and role = 'ADMIN')
    );
  end if;
end $$;

do $$ begin
  if not exists (select 1 from pg_policies where policyname = 'Admins can delete profiles' and tablename = 'profiles') then
    create policy "Admins can delete profiles" on public.profiles for delete using (
      exists (select 1 from public.profiles where id = auth.uid() and role = 'ADMIN')
    );
  end if;
end $$;

-- ── 3b. Transactions RLS ─────────────────────────────────────────────────────
alter table public.transactions enable row level security;

do $$ begin
  if not exists (select 1 from pg_policies where policyname = 'Authenticated can view transactions' and tablename = 'transactions') then
    create policy "Authenticated can view transactions" on public.transactions for select using (auth.role() = 'authenticated');
  end if;
end $$;

do $$ begin
  if not exists (select 1 from pg_policies where policyname = 'Authenticated can create transactions' and tablename = 'transactions') then
    create policy "Authenticated can create transactions" on public.transactions for insert with check (auth.role() = 'authenticated');
  end if;
end $$;

do $$ begin
  if not exists (select 1 from pg_policies where policyname = 'Admin can update transactions' and tablename = 'transactions') then
    create policy "Admin can update transactions" on public.transactions for update using (
      exists (select 1 from public.profiles where id = auth.uid() and role = 'ADMIN')
    );
  end if;
end $$;

-- ── 3c. Bank Accounts RLS ────────────────────────────────────────────────────
alter table public.bank_accounts enable row level security;

do $$ begin
  if not exists (select 1 from pg_policies where policyname = 'Authenticated can view bank accounts' and tablename = 'bank_accounts') then
    create policy "Authenticated can view bank accounts" on public.bank_accounts for select using (auth.role() = 'authenticated');
  end if;
end $$;

do $$ begin
  if not exists (select 1 from pg_policies where policyname = 'Authenticated can manage bank accounts' and tablename = 'bank_accounts') then
    create policy "Authenticated can manage bank accounts" on public.bank_accounts for all using (auth.role() = 'authenticated');
  end if;
end $$;

-- ── 3d. Notifications RLS ────────────────────────────────────────────────────
alter table public.notifications enable row level security;

do $$ begin
  if not exists (select 1 from pg_policies where policyname = 'Users can view own notifications' and tablename = 'notifications') then
    create policy "Users can view own notifications" on public.notifications for select using (auth.uid() = user_id);
  end if;
end $$;

do $$ begin
  if not exists (select 1 from pg_policies where policyname = 'Users can insert own notifications' and tablename = 'notifications') then
    create policy "Users can insert own notifications" on public.notifications for insert with check (auth.uid() = user_id);
  end if;
end $$;

do $$ begin
  if not exists (select 1 from pg_policies where policyname = 'Users can update own notifications' and tablename = 'notifications') then
    create policy "Users can update own notifications" on public.notifications for update using (auth.uid() = user_id);
  end if;
end $$;

-- ── 3e. Merchants RLS ────────────────────────────────────────────────────────
alter table public.merchants enable row level security;

do $$ begin
  if not exists (select 1 from pg_policies where policyname = 'Admins can manage merchants' and tablename = 'merchants') then
    create policy "Admins can manage merchants" on public.merchants for all using (
      exists (select 1 from public.profiles where id = auth.uid() and role = 'ADMIN')
    );
  end if;
end $$;

-- ── 3f. Platform Settings RLS ────────────────────────────────────────────────
alter table public.platform_settings enable row level security;

do $$ begin
  if not exists (select 1 from pg_policies where policyname = 'Admins can manage platform settings' and tablename = 'platform_settings') then
    create policy "Admins can manage platform settings" on public.platform_settings for all using (
      exists (select 1 from public.profiles where id = auth.uid() and role = 'ADMIN')
    );
  end if;
end $$;

-- ── 3g. Audit Logs RLS ───────────────────────────────────────────────────────
alter table public.audit_logs enable row level security;

do $$ begin
  if not exists (select 1 from pg_policies where policyname = 'Admins can view audit logs' and tablename = 'audit_logs') then
    create policy "Admins can view audit logs" on public.audit_logs for select using (
      exists (select 1 from public.profiles where id = auth.uid() and role = 'ADMIN')
    );
  end if;
end $$;

do $$ begin
  if not exists (select 1 from pg_policies where policyname = 'System can insert audit logs' and tablename = 'audit_logs') then
    create policy "System can insert audit logs" on public.audit_logs for insert with check (true);
  end if;
end $$;

-- ═══════════════════════════════════════════════════════════════
-- SECTION 4: STORAGE
-- ═══════════════════════════════════════════════════════════════

insert into storage.buckets (id, name, public) values ('receipts', 'receipts', true)
on conflict (id) do nothing;

do $$ begin
  if not exists (select 1 from pg_policies where policyname = 'Authenticated can upload receipts' and tablename = 'objects' and schemaname = 'storage') then
    create policy "Authenticated can upload receipts" on storage.objects for insert with check (auth.role() = 'authenticated');
  end if;
end $$;

do $$ begin
  if not exists (select 1 from pg_policies where policyname = 'Anyone can view receipts' and tablename = 'objects' and schemaname = 'storage') then
    create policy "Anyone can view receipts" on storage.objects for select using (true);
  end if;
end $$;

-- ═══════════════════════════════════════════════════════════════
-- SECTION 5: INDEXES
-- ═══════════════════════════════════════════════════════════════

do $$ begin create index if not exists idx_profiles_role on public.profiles(role); exception when others then null; end $$;
do $$ begin create index if not exists idx_transactions_created_at on public.transactions(created_at desc); exception when others then null; end $$;
do $$ begin create index if not exists idx_transactions_status on public.transactions(status); exception when others then null; end $$;
do $$ begin create index if not exists idx_transactions_bank on public.transactions(bank_name); exception when others then null; end $$;
do $$ begin create index if not exists idx_transactions_verified_by on public.transactions(verified_by); exception when others then null; end $$;
do $$ begin create index if not exists idx_notifications_user on public.notifications(user_id, is_read); exception when others then null; end $$;
do $$ begin create index if not exists idx_merchants_status on public.merchants(status); exception when others then null; end $$;
do $$ begin create index if not exists idx_merchants_owner on public.merchants(owner_id); exception when others then null; end $$;
do $$ begin create index if not exists idx_audit_logs_created on public.audit_logs(created_at desc); exception when others then null; end $$;

-- ═══════════════════════════════════════════════════════════════
-- SECTION 6: DEFAULT DATA
-- ═══════════════════════════════════════════════════════════════

insert into public.platform_settings (commission_fee, min_payout, ocr_confidence, auto_verify)
values (1.00, 5000.00, 85.00, true)
on conflict do nothing;

-- ═══════════════════════════════════════════════════════════════
-- SECTION 7: HOW TO MAKE YOURSELF ADMIN
-- ═══════════════════════════════════════════════════════════════
-- After creating your account, uncomment and run:
-- UPDATE public.profiles SET role = 'ADMIN' WHERE email = 'your-email@example.com';
-- ═══════════════════════════════════════════════════════════════
