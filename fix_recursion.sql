create or replace function public.get_my_role()
returns text
language sql
security definer
set search_path = public
as $$
  select role from public.profiles where id = auth.uid();
$$;

create or replace function public.get_my_cafe_id()
returns uuid
language sql
security definer
set search_path = public
as $$
  select cafe_id from public.profiles where id = auth.uid();
$$;

create or replace function public.get_user_cafe_id(target_user_id uuid)
returns uuid
language sql
security definer
set search_path = public
as $$
  select cafe_id from public.profiles where id = target_user_id;
$$;

drop policy if exists "Admins can view all profiles" on public.profiles;
create policy "Admins can view all profiles" on public.profiles
  for select using ( 
    public.get_my_role() = 'SUPER_ADMIN' 
    OR 
    (public.get_my_role() = 'ADMIN' AND cafe_id = public.get_my_cafe_id())
  );

drop policy if exists "Admins can view all transactions" on public.transactions;
create policy "Admins can view all transactions" on public.transactions
  for select using ( 
    public.get_my_role() = 'SUPER_ADMIN' 
    OR 
    (public.get_my_role() = 'ADMIN' AND cafe_id = public.get_my_cafe_id())
  );

drop policy if exists "Admins can view all notifications" on public.notifications;
create policy "Admins can view all notifications" on public.notifications
  for select using ( 
    public.get_my_role() = 'SUPER_ADMIN' 
    OR 
    (public.get_my_role() = 'ADMIN' AND public.get_user_cafe_id(user_id) = public.get_my_cafe_id())
  );

drop policy if exists "Admins can update notifications" on public.notifications;
create policy "Admins can update notifications" on public.notifications
  for update using ( 
    public.get_my_role() = 'SUPER_ADMIN' 
    OR 
    (public.get_my_role() = 'ADMIN' AND public.get_user_cafe_id(user_id) = public.get_my_cafe_id())
  );
