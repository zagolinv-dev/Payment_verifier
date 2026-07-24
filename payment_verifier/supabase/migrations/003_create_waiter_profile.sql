-- Add function to set owner_id and cafe_id on waiter profiles
-- (the auth trigger auto-creates the profile row but doesn't set owner_id
--  for waiter accounts created by the admin API)

CREATE OR REPLACE FUNCTION public.create_waiter_profile(
  waiter_id uuid,
  waiter_email text,
  waiter_name text,
  manager_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cafe_id uuid;
BEGIN
  -- Look up the manager's cafe_id
  SELECT cafe_id INTO v_cafe_id FROM public.profiles WHERE id = manager_id;

  UPDATE public.profiles
  SET
    owner_id = manager_id,
    cafe_id  = COALESCE(v_cafe_id, manager_id),
    email    = waiter_email,
    full_name = waiter_name
  WHERE id = waiter_id;
END;
$$;
