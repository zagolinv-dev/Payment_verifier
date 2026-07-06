-- Add cafe ownership boundaries so each manager can only see their own cafe's data.

alter table public.profiles
  add column if not exists owner_id uuid references auth.users(id);

alter table public.bank_accounts
  add column if not exists owner_id uuid references auth.users(id);

alter table public.transactions
  add column if not exists owner_id uuid references auth.users(id);

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
    coalesce(new.raw_user_meta_data->>'role', 'WAITRESS')
  );
  return new;
end;
$$;

drop policy if exists "Users can view all profiles" on public.profiles;
drop policy if exists "Users can update own profile" on public.profiles;
drop policy if exists "Admins can view all profiles" on public.profiles;
drop policy if exists "Admins can update any profile" on public.profiles;
drop policy if exists "Admins can delete profiles" on public.profiles;

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

drop policy if exists "Authenticated users can view bank accounts" on public.bank_accounts;
drop policy if exists "Authenticated users can manage bank accounts" on public.bank_accounts;

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

drop policy if exists "Authenticated can view transactions" on public.transactions;
drop policy if exists "Authenticated can create transactions" on public.transactions;
drop policy if exists "Admin can update transactions" on public.transactions;

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

create index if not exists idx_transactions_owner_id on public.transactions(owner_id);
create index if not exists idx_bank_accounts_owner_id on public.bank_accounts(owner_id);
create index if not exists idx_profiles_owner_id on public.profiles(owner_id);