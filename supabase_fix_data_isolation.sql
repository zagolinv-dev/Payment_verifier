-- ===== FIX: Data Isolation Between Cafes/Companies =====
-- Run this in Supabase SQL Editor

-- 0. SECURITY DEFINER helpers to avoid infinite recursion in RLS policies
CREATE OR REPLACE FUNCTION public.get_my_owner_name()
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT owner_name FROM public.profiles WHERE id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid();
$$;

-- 1. Add owner_name to transactions and bank_accounts
ALTER TABLE public.transactions ADD COLUMN IF NOT EXISTS owner_name TEXT;
ALTER TABLE public.bank_accounts ADD COLUMN IF NOT EXISTS owner_name TEXT;

-- 2. Backfill existing transactions with owner_name from the verifying user's profile
UPDATE public.transactions t
SET owner_name = p.owner_name
FROM public.profiles p
WHERE t.verified_by::uuid = p.id
AND t.owner_name IS NULL;

-- 3. Add created_by column to bank_accounts if missing and backfill owner_name
ALTER TABLE public.bank_accounts ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL;
UPDATE public.bank_accounts b
SET owner_name = p.owner_name
FROM public.profiles p
WHERE b.created_by = p.id
AND b.owner_name IS NULL;

-- 4. Drop ALL old permissive policies on all tables
-- Profiles
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
DROP POLICY IF EXISTS "Admins can view all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can view same company profiles" ON public.profiles;
-- Transactions
DROP POLICY IF EXISTS "All users can view transactions" ON public.transactions;
DROP POLICY IF EXISTS "Users can view same company transactions" ON public.transactions;
DROP POLICY IF EXISTS "Authenticated users can insert transactions" ON public.transactions;
DROP POLICY IF EXISTS "Authenticated can create transactions" ON public.transactions;
DROP POLICY IF EXISTS "Admin can delete transactions" ON public.transactions;
DROP POLICY IF EXISTS "Admin can update transactions" ON public.transactions;
DROP POLICY IF EXISTS "Users can insert own company transactions" ON public.transactions;
-- Bank accounts
DROP POLICY IF EXISTS "All users can view bank accounts" ON public.bank_accounts;
DROP POLICY IF EXISTS "Admin can read bank accounts" ON public.bank_accounts;
DROP POLICY IF EXISTS "Admin can insert bank accounts" ON public.bank_accounts;
DROP POLICY IF EXISTS "Admin can update bank accounts" ON public.bank_accounts;
DROP POLICY IF EXISTS "Admin can delete bank accounts" ON public.bank_accounts;
DROP POLICY IF EXISTS "Authenticated can manage bank accounts" ON public.bank_accounts;
DROP POLICY IF EXISTS "Authenticated users can insert bank accounts" ON public.bank_accounts;
DROP POLICY IF EXISTS "Authenticated users can delete bank accounts" ON public.bank_accounts;
DROP POLICY IF EXISTS "Users can view same company bank accounts" ON public.bank_accounts;
DROP POLICY IF EXISTS "Users can insert own company bank accounts" ON public.bank_accounts;

-- 5. Profiles: users see only their own company's profiles
CREATE POLICY "Users can view same company profiles" ON public.profiles
  FOR SELECT
  USING (
    auth.uid() = id
    OR (owner_name IS NOT NULL
        AND owner_name = public.get_my_owner_name()
       )
    OR public.get_my_role() = 'SUPER_ADMIN'
  );

-- 6. Transactions: users see only their own company's transactions
CREATE POLICY "Users can view same company transactions" ON public.transactions
  FOR SELECT
  USING (
    owner_name IS NOT NULL
    AND owner_name = public.get_my_owner_name()
    OR public.get_my_role() = 'SUPER_ADMIN'
  );

-- 7. Bank accounts: users see only their own company's bank accounts
-- Also shows unassigned accounts (owner_name IS NULL) until they're assigned to a company
CREATE POLICY "Users can view same company bank accounts" ON public.bank_accounts
  FOR SELECT
  USING (
    owner_name IS NULL
    OR owner_name = public.get_my_owner_name()
    OR public.get_my_role() = 'SUPER_ADMIN'
  );

-- 8. Insert policies — records must match the user's company
CREATE POLICY "Users can insert own company transactions" ON public.transactions
  FOR INSERT
  WITH CHECK (
    owner_name = public.get_my_owner_name()
    OR public.get_my_role() = 'SUPER_ADMIN'
  );

CREATE POLICY "Users can insert own company bank accounts" ON public.bank_accounts
  FOR INSERT
  WITH CHECK (
    owner_name = public.get_my_owner_name()
    OR public.get_my_role() = 'SUPER_ADMIN'
  );
