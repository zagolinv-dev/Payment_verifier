-- =============================================================================
-- FIX: Superadmin Profile, Cafe RLS, and Registration Notifications
-- Run this in your Supabase SQL Editor (Dashboard -> SQL Editor)
-- This file is idempotent and safe to run multiple times.
-- =============================================================================

-- ── 1. Create helper functions with SECURITY DEFINER to avoid RLS recursion ──

CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS text
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION public.get_my_cafe_id()
RETURNS uuid
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT cafe_id FROM public.profiles WHERE id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION public.get_user_cafe_id(target_user_id uuid)
RETURNS uuid
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT cafe_id FROM public.profiles WHERE id = target_user_id;
$$;

CREATE OR REPLACE FUNCTION public.is_super_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'SUPER_ADMIN');
$$;

CREATE OR REPLACE FUNCTION public.get_my_owner_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(owner_id, id) FROM public.profiles WHERE id = auth.uid();
$$;


-- ── 2. Create the missing SUPER_ADMIN profile for the owner ──

INSERT INTO public.profiles (id, email, full_name, role, status, cafe_id, owner_id)
VALUES (
  '3a8511d7-5995-4478-8bd8-2d5ca7352d8b',
  'zagolinv@gmail.com',
  'Super Admin',
  'SUPER_ADMIN',
  'APPROVED',
  '3a8511d7-5995-4478-8bd8-2d5ca7352d8b',
  '3a8511d7-5995-4478-8bd8-2d5ca7352d8b'
)
ON CONFLICT (id) DO UPDATE SET
  email = EXCLUDED.email,
  role = EXCLUDED.role,
  status = EXCLUDED.status,
  cafe_id = COALESCE(public.profiles.cafe_id, EXCLUDED.cafe_id),
  owner_id = COALESCE(public.profiles.owner_id, EXCLUDED.owner_id);


-- ── 3. Backfill cafe_id and owner_id fields for existing admin profiles ──

UPDATE public.profiles 
  SET cafe_id = id, owner_id = id 
  WHERE role IN ('ADMIN', 'SUPER_ADMIN') AND (cafe_id IS NULL OR owner_id IS NULL);

UPDATE public.profiles p
  SET owner_id = cafe_id 
  WHERE p.role = 'WAITRESS' AND p.owner_id IS NULL AND p.cafe_id IS NOT NULL;


-- ── 4. Update handle_new_user() trigger function to correctly set cafe_id and owner_id ──

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger 
LANGUAGE plpgsql 
SECURITY DEFINER 
SET search_path = public 
AS $$
DECLARE 
  v_role text;
  v_cafe_id uuid;
BEGIN
  v_role := coalesce(new.raw_user_meta_data->>'role', 'WAITRESS');
  
  IF new.raw_user_meta_data->>'cafe_id' IS NOT NULL THEN
    v_cafe_id := (new.raw_user_meta_data->>'cafe_id')::uuid;
  ELSIF v_role IN ('ADMIN', 'SUPER_ADMIN') THEN
    v_cafe_id := new.id;
  ELSE
    v_cafe_id := null;
  END IF;

  INSERT INTO public.profiles (id, email, full_name, role, status, phone, owner_name, address, description, cafe_id, owner_id)
  VALUES (
    new.id,
    new.email,
    new.raw_user_meta_data->>'full_name',
    v_role,
    CASE WHEN v_role IN ('ADMIN', 'SUPER_ADMIN') THEN 'PENDING' ELSE 'APPROVED' END,
    new.raw_user_meta_data->>'phone',
    new.raw_user_meta_data->>'owner_name',
    new.raw_user_meta_data->>'address',
    new.raw_user_meta_data->>'description',
    v_cafe_id,
    v_cafe_id
  )
  ON CONFLICT (id) DO UPDATE SET
    email = excluded.email,
    role = excluded.role,
    status = CASE WHEN public.profiles.status = 'PENDING' THEN 'PENDING' ELSE excluded.status END,
    phone = coalesce(public.profiles.phone, excluded.phone),
    owner_name = coalesce(public.profiles.owner_name, excluded.owner_name),
    address = coalesce(public.profiles.address, excluded.address),
    description = coalesce(public.profiles.description, excluded.description),
    cafe_id = coalesce(public.profiles.cafe_id, excluded.cafe_id),
    owner_id = coalesce(public.profiles.owner_id, excluded.owner_id);
  RETURN new;
END;
$$;


-- ── 5. Add trigger to notify all SUPER_ADMINs when a new merchant registers ──

CREATE OR REPLACE FUNCTION public.notify_superadmins_new_merchant()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Fire only if status is PENDING and either it is a new row or status/role has changed
  IF (TG_OP = 'INSERT' AND NEW.role = 'ADMIN' AND NEW.status = 'PENDING') OR
     (TG_OP = 'UPDATE' AND NEW.role = 'ADMIN' AND NEW.status = 'PENDING' AND (OLD.status IS DISTINCT FROM 'PENDING' OR OLD.role IS DISTINCT FROM 'ADMIN')) THEN
     
    -- Avoid duplicate notifications for the same merchant profile within a short time window
    IF NOT EXISTS (
      SELECT 1 FROM public.notifications 
      WHERE title = 'New Merchant Registration' 
        AND message LIKE NEW.full_name || '%'
        AND created_at > now() - interval '5 minutes'
    ) THEN
      INSERT INTO public.notifications (user_id, type, title, message)
      SELECT
        p.id,
        'info',
        'New Merchant Registration',
        NEW.full_name || ' registered as a merchant.'
      FROM public.profiles p
      WHERE p.role = 'SUPER_ADMIN';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_new_merchant_notify_superadmins ON public.profiles;
CREATE TRIGGER trg_new_merchant_notify_superadmins
  AFTER INSERT OR UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_superadmins_new_merchant();


-- ── 6. Clean profiles RLS policies ──

DROP POLICY IF EXISTS "Users can view profiles in same cafe" ON public.profiles;
DROP POLICY IF EXISTS "Allow public inserts for pending admins" ON public.profiles;
DROP POLICY IF EXISTS "Users can update profiles in same cafe" ON public.profiles;
DROP POLICY IF EXISTS "Admins can delete profiles in same cafe" ON public.profiles;
DROP POLICY IF EXISTS "Anyone can submit pending application" ON public.profiles;
DROP POLICY IF EXISTS "Admins can view all profiles" ON public.profiles;

CREATE POLICY "Users can view profiles in same cafe" ON public.profiles
  FOR SELECT USING (
    auth.uid() = id
    OR owner_id = public.get_my_owner_id()
    OR public.is_super_admin()
  );

CREATE POLICY "Anyone can submit pending application" ON public.profiles
  FOR INSERT TO anon, authenticated
  WITH CHECK (
    status = 'PENDING' AND role IN ('ADMIN', 'SUPER_ADMIN')
  );

CREATE POLICY "Users can update profiles in same cafe" ON public.profiles
  FOR UPDATE USING (
    auth.uid() = id
    OR (owner_id = public.get_my_owner_id() AND public.get_my_role() IN ('ADMIN', 'SUPER_ADMIN'))
    OR public.is_super_admin()
  );

CREATE POLICY "Admins can delete profiles in same cafe" ON public.profiles
  FOR DELETE USING (
    (owner_id = public.get_my_owner_id() AND public.get_my_role() IN ('ADMIN', 'SUPER_ADMIN'))
    OR public.is_super_admin()
  );


-- ── 7. Clean notifications RLS policies ──

DROP POLICY IF EXISTS "Users can view own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can insert own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can update own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can delete own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Admins can view all notifications" ON public.notifications;
DROP POLICY IF EXISTS "Admins can update notifications" ON public.notifications;

CREATE POLICY "Users can view own notifications" ON public.notifications
  FOR SELECT USING (
    auth.uid() = user_id
    OR public.is_super_admin()
  );

CREATE POLICY "Users can insert own notifications" ON public.notifications
  FOR INSERT WITH CHECK (
    auth.uid() = user_id
    OR public.is_super_admin()
  );

CREATE POLICY "Users can update own notifications" ON public.notifications
  FOR UPDATE USING (
    auth.uid() = user_id
    OR public.is_super_admin()
  );

CREATE POLICY "Users can delete own notifications" ON public.notifications
  FOR DELETE USING (
    auth.uid() = user_id
    OR public.is_super_admin()
  );
