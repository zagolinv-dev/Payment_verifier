-- ── 1. Clean slate: drop all existing policies on our tables dynamically ─────
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN 
    SELECT policyname, tablename 
    FROM pg_policies 
    WHERE schemaname = 'public' 
      AND tablename IN ('profiles', 'bank_accounts', 'transactions')
  LOOP
    EXECUTE 'DROP POLICY IF EXISTS ' || quote_ident(r.policyname) || ' ON public.' || quote_ident(r.tablename);
  END LOOP;
END $$;

-- ── 2. Add columns if not exists ─────────────────────────────────────────────
ALTER TABLE public.profiles 
  ADD COLUMN IF NOT EXISTS cafe_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL;

ALTER TABLE public.bank_accounts 
  ADD COLUMN IF NOT EXISTS cafe_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL;

ALTER TABLE public.transactions 
  ADD COLUMN IF NOT EXISTS cafe_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL;

-- ── 3. Force enable Row Level Security (RLS) ──────────────────────────────────
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bank_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;

-- ── 4. Set up existing admin profiles as cafe roots ──────────────────────────
UPDATE public.profiles 
  SET cafe_id = id 
  WHERE role IN ('ADMIN', 'SUPER_ADMIN') AND cafe_id IS NULL;

-- ── 5. Migrate existing waitresses, bank accounts, and transactions ──────────
-- For bank accounts, if created_by is available, use it. Otherwise use the first admin.
UPDATE public.bank_accounts b 
  SET cafe_id = COALESCE(
    (SELECT p.cafe_id FROM public.profiles p WHERE p.id = b.created_by::uuid),
    (SELECT id FROM public.profiles WHERE role = 'ADMIN' ORDER BY created_at ASC LIMIT 1)
  )
  WHERE b.cafe_id IS NULL;

-- For transactions, if verified_by is available, use it. Otherwise use the first admin.
UPDATE public.transactions t 
  SET cafe_id = COALESCE(
    (SELECT p.cafe_id FROM public.profiles p WHERE p.id = t.verified_by::uuid),
    (SELECT id FROM public.profiles WHERE role = 'ADMIN' ORDER BY created_at ASC LIMIT 1)
  )
  WHERE t.cafe_id IS NULL;

-- For waitresses with null cafe_id, associate them with the first admin
UPDATE public.profiles p 
  SET cafe_id = (SELECT id FROM public.profiles WHERE role = 'ADMIN' ORDER BY created_at ASC LIMIT 1)
  WHERE p.role = 'WAITRESS' AND p.cafe_id IS NULL;

-- ── 6. Helper function to get current user's cafe_id ─────────────────────────
CREATE OR REPLACE FUNCTION public.get_my_cafe_id()
RETURNS UUID AS $$
  SELECT cafe_id FROM public.profiles WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER;

-- ── 7. Trigger function to set cafe_id automatically on insert ───────────────
CREATE OR REPLACE FUNCTION public.set_cafe_id_on_insert()
RETURNS trigger AS $$
BEGIN
  IF NEW.cafe_id IS NULL THEN
    NEW.cafe_id := public.get_my_cafe_id();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Attach triggers
DROP TRIGGER IF EXISTS trg_set_cafe_id_bank_accounts ON public.bank_accounts;
CREATE TRIGGER trg_set_cafe_id_bank_accounts
  BEFORE INSERT ON public.bank_accounts
  FOR EACH ROW
  EXECUTE FUNCTION public.set_cafe_id_on_insert();

DROP TRIGGER IF EXISTS trg_set_cafe_id_transactions ON public.transactions;
CREATE TRIGGER trg_set_cafe_id_transactions
  BEFORE INSERT ON public.transactions
  FOR EACH ROW
  EXECUTE FUNCTION public.set_cafe_id_on_insert();

-- ── 8. Update auth trigger to set cafe_id on user creation ───────────────────
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
DECLARE
  v_role TEXT;
  v_cafe_id UUID;
BEGIN
  v_role := COALESCE(NEW.raw_user_meta_data->>'role', 'WAITRESS');
  
  IF NEW.raw_user_meta_data->>'cafe_id' IS NOT NULL THEN
    v_cafe_id := (NEW.raw_user_meta_data->>'cafe_id')::UUID;
  ELSIF v_role IN ('ADMIN', 'SUPER_ADMIN') THEN
    v_cafe_id := NEW.id;
  ELSE
    v_cafe_id := NULL;
  END IF;

  INSERT INTO public.profiles (id, email, full_name, role, cafe_id)
  VALUES (
    NEW.id,
    NEW.email,
    NEW.raw_user_meta_data->>'full_name',
    v_role,
    v_cafe_id
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── 9. Update password reset notifications to be cafe-scoped ────────────────
CREATE OR REPLACE FUNCTION notify_admins_password_reset()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO notifications (user_id, type, title, message)
  SELECT
    p.id,
    'info',
    'Password Reset Requested',
    NEW.name || ' (' || NEW.email || ') requested a password reset.'
  FROM profiles p
  WHERE p.role IN ('ADMIN', 'SUPER_ADMIN')
    AND p.cafe_id = (SELECT cafe_id FROM profiles WHERE email = NEW.email LIMIT 1);
  RETURN NEW;
END;
$$;

-- ── 10. Re-apply Row Level Security (RLS) policies ───────────────────────────

-- Profiles policies
CREATE POLICY "Users can view profiles in same cafe" ON public.profiles
  FOR SELECT USING (
    cafe_id = public.get_my_cafe_id() OR auth.uid() = id
  );

CREATE POLICY "Allow public inserts for pending admins" ON public.profiles
  FOR INSERT WITH CHECK (
    role = 'ADMIN' AND status = 'PENDING'
  );

CREATE POLICY "Users can update profiles in same cafe or own profile" ON public.profiles
  FOR UPDATE USING (
    auth.uid() = id OR (
      cafe_id = public.get_my_cafe_id() AND EXISTS (
        SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('ADMIN', 'SUPER_ADMIN')
      )
    )
  );

CREATE POLICY "Admins can delete profiles in same cafe" ON public.profiles
  FOR DELETE USING (
    cafe_id = public.get_my_cafe_id() AND EXISTS (
      SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('ADMIN', 'SUPER_ADMIN')
    )
  );

-- Bank accounts policies
CREATE POLICY "Users can view own cafe bank accounts" ON public.bank_accounts
  FOR SELECT USING (
    cafe_id = public.get_my_cafe_id()
  );

CREATE POLICY "Users can insert own cafe bank accounts" ON public.bank_accounts
  FOR INSERT WITH CHECK (
    cafe_id = public.get_my_cafe_id()
  );

CREATE POLICY "Users can update own cafe bank accounts" ON public.bank_accounts
  FOR UPDATE USING (
    cafe_id = public.get_my_cafe_id()
  );

CREATE POLICY "Users can delete own cafe bank accounts" ON public.bank_accounts
  FOR DELETE USING (
    cafe_id = public.get_my_cafe_id()
  );

-- Transactions policies
CREATE POLICY "Users can view own cafe transactions" ON public.transactions
  FOR SELECT USING (
    cafe_id = public.get_my_cafe_id()
  );

CREATE POLICY "Users can insert own cafe transactions" ON public.transactions
  FOR INSERT WITH CHECK (
    cafe_id = public.get_my_cafe_id()
  );

CREATE POLICY "Admins can update own cafe transactions" ON public.transactions
  FOR UPDATE USING (
    cafe_id = public.get_my_cafe_id() AND EXISTS (
      SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('ADMIN', 'SUPER_ADMIN')
    )
  );

CREATE POLICY "Admins can delete own cafe transactions" ON public.transactions
  FOR DELETE USING (
    cafe_id = public.get_my_cafe_id() AND EXISTS (
      SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('ADMIN', 'SUPER_ADMIN')
    )
  );
