-- Run this entire block in Supabase SQL Editor (Dashboard → SQL Editor → New query)
-- This creates a trigger that auto-inserts a profile row whenever a new auth user is created.
-- It reads full_name, role, and owner_id from the user's metadata.

-- 1. The trigger function
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, full_name, role, owner_id, status, created_at)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)),
    coalesce(new.raw_user_meta_data->>'role', 'WAITRESS'),
    (new.raw_user_meta_data->>'owner_id')::uuid,
    'APPROVED',
    now()
  )
  on conflict (id) do update
    set full_name = excluded.full_name,
        role      = excluded.role,
        owner_id  = excluded.owner_id,
        status    = 'APPROVED';
  return new;
end;
$$;

-- 2. Drop old trigger if exists, then create fresh
drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- 3. Also reload schema cache
notify pgrst, 'reload schema';
