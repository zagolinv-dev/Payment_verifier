-- ===== FIX: Cafe Data Isolation via RLS =====
-- Run this in Supabase SQL Editor
-- This ensures each cafe can only see its own data

-- 1. Add owner_id columns if missing (used by the Flutter app for filtering)
-- NOTE: No FK constraint to auth.users because profiles can exist without auth users (pending applications)
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS owner_id UUID;
ALTER TABLE public.transactions ADD COLUMN IF NOT EXISTS owner_id UUID;
ALTER TABLE public.bank_accounts ADD COLUMN IF NOT EXISTS owner_id UUID;

-- 2. Backfill owner_id on existing rows where it's NULL
-- Profiles: admins own themselves
UPDATE public.profiles SET owner_id = id WHERE role IN ('ADMIN', 'SUPER_ADMIN') AND owner_id IS NULL;
-- Waitresses: try to derive owner_id from cafe_id first (if cafe_id migration was run)
UPDATE public.profiles p SET owner_id = cafe_id
  WHERE p.role = 'WAITRESS' AND p.owner_id IS NULL AND p.cafe_id IS NOT NULL;
-- Waitresses: fallback - associate with first admin if no other info
UPDATE public.profiles p SET owner_id = (SELECT id FROM public.profiles WHERE role = 'ADMIN' LIMIT 1)
  WHERE p.role = 'WAITRESS' AND p.owner_id IS NULL;
-- Transactions & bank_accounts: copy from verified_by / created_by if owner_id is null
-- transactions.verified_by is TEXT, profiles.id is UUID — cast both to text
UPDATE public.transactions t SET owner_id = p.owner_id
  FROM public.profiles p WHERE t.verified_by = p.id::text AND t.owner_id IS NULL AND p.owner_id IS NOT NULL;
UPDATE public.bank_accounts b SET owner_id = p.owner_id
  FROM public.profiles p WHERE b.created_by = p.id AND b.owner_id IS NULL AND p.owner_id IS NOT NULL;

-- 3. Helper function to get the current user's owner_id (SECURITY DEFINER avoids recursion)
CREATE OR REPLACE FUNCTION public.get_my_owner_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(owner_id, id) FROM public.profiles WHERE id = auth.uid();
$$;

-- 4. Helper function to check if current user is SUPER_ADMIN
CREATE OR REPLACE FUNCTION public.is_super_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'SUPER_ADMIN');
$$;

-- 5. Drop all existing permissive policies
-- Transactions
DROP POLICY IF EXISTS "Authenticated can view transactions" ON public.transactions;
DROP POLICY IF EXISTS "Authenticated can create transactions" ON public.transactions;
DROP POLICY IF EXISTS "Admin can update transactions" ON public.transactions;
DROP POLICY IF EXISTS "Admin can delete transactions" ON public.transactions;
DROP POLICY IF EXISTS "Users can view own cafe transactions" ON public.transactions;
DROP POLICY IF EXISTS "Users can insert own cafe transactions" ON public.transactions;
DROP POLICY IF EXISTS "Admins can update own cafe transactions" ON public.transactions;
DROP POLICY IF EXISTS "Admins can delete own cafe transactions" ON public.transactions;
DROP POLICY IF EXISTS "Users can view same company transactions" ON public.transactions;
DROP POLICY IF EXISTS "Users can insert own company transactions" ON public.transactions;

-- Bank accounts
DROP POLICY IF EXISTS "Authenticated can view bank accounts" ON public.bank_accounts;
DROP POLICY IF EXISTS "Authenticated can manage bank accounts" ON public.bank_accounts;
DROP POLICY IF EXISTS "Users can view same company bank accounts" ON public.bank_accounts;
DROP POLICY IF EXISTS "Users can insert own company bank accounts" ON public.bank_accounts;
DROP POLICY IF EXISTS "Users can view own cafe bank accounts" ON public.bank_accounts;
DROP POLICY IF EXISTS "Users can insert own cafe bank accounts" ON public.bank_accounts;
DROP POLICY IF EXISTS "Users can update own cafe bank accounts" ON public.bank_accounts;
DROP POLICY IF EXISTS "Users can delete own cafe bank accounts" ON public.bank_accounts;

-- Profiles
DROP POLICY IF EXISTS "Users can view all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Admins can update any profile" ON public.profiles;
DROP POLICY IF EXISTS "Admins can delete profiles" ON public.profiles;
DROP POLICY IF EXISTS "Anyone can submit pending application" ON public.profiles;
DROP POLICY IF EXISTS "Users can view profiles in same cafe" ON public.profiles;
DROP POLICY IF EXISTS "Allow public inserts for pending admins" ON public.profiles;
DROP POLICY IF EXISTS "Users can update profiles in same cafe or own profile" ON public.profiles;
DROP POLICY IF EXISTS "Admins can delete profiles in same cafe" ON public.profiles;
DROP POLICY IF EXISTS "Users can view same company profiles" ON public.profiles;

-- 6. TRANSACTIONS RLS — isolate by owner_id
CREATE POLICY "Users can view own cafe transactions" ON public.transactions
  FOR SELECT USING (
    owner_id = public.get_my_owner_id()
    OR public.is_super_admin()
  );

CREATE POLICY "Users can insert own cafe transactions" ON public.transactions
  FOR INSERT WITH CHECK (
    owner_id = public.get_my_owner_id()
    OR public.is_super_admin()
  );

CREATE POLICY "Admins can update own cafe transactions" ON public.transactions
  FOR UPDATE USING (
    owner_id = public.get_my_owner_id()
    AND EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('ADMIN', 'SUPER_ADMIN'))
    OR public.is_super_admin()
  );

CREATE POLICY "Admins can delete own cafe transactions" ON public.transactions
  FOR DELETE USING (
    owner_id = public.get_my_owner_id()
    AND EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('ADMIN', 'SUPER_ADMIN'))
    OR public.is_super_admin()
  );

-- 7. BANK ACCOUNTS RLS — isolate by owner_id
CREATE POLICY "Users can view own cafe bank accounts" ON public.bank_accounts
  FOR SELECT USING (
    owner_id = public.get_my_owner_id()
    OR public.is_super_admin()
  );

CREATE POLICY "Users can insert own cafe bank accounts" ON public.bank_accounts
  FOR INSERT WITH CHECK (
    owner_id = public.get_my_owner_id()
    OR public.is_super_admin()
  );

CREATE POLICY "Users can update own cafe bank accounts" ON public.bank_accounts
  FOR UPDATE USING (
    owner_id = public.get_my_owner_id()
    OR public.is_super_admin()
  );

CREATE POLICY "Users can delete own cafe bank accounts" ON public.bank_accounts
  FOR DELETE USING (
    owner_id = public.get_my_owner_id()
    OR public.is_super_admin()
  );

-- 8. PROFILES RLS — users see own profile + others in their cafe
CREATE POLICY "Users can view profiles in same cafe" ON public.profiles
  FOR SELECT USING (
    auth.uid() = id
    OR owner_id = public.get_my_owner_id()
    OR public.is_super_admin()
  );

CREATE POLICY "Allow public inserts for pending admins" ON public.profiles
  FOR INSERT TO anon, authenticated
  WITH CHECK (
    role = 'ADMIN' AND status = 'PENDING'
  );

CREATE POLICY "Users can update profiles in same cafe" ON public.profiles
  FOR UPDATE USING (
    auth.uid() = id
    OR (owner_id = public.get_my_owner_id()
        AND EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('ADMIN', 'SUPER_ADMIN'))
       )
    OR public.is_super_admin()
  );

CREATE POLICY "Admins can delete profiles in same cafe" ON public.profiles
  FOR DELETE USING (
    owner_id = public.get_my_owner_id()
    AND EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('ADMIN', 'SUPER_ADMIN'))
    OR public.is_super_admin()
  );

-- 9. Ensure RLS is enabled
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bank_accounts ENABLE ROW LEVEL SECURITY;
