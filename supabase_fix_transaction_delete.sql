-- Run once in Supabase SQL Editor to fix manager transaction deletion.
-- The app was showing "deleted successfully" while RLS silently blocked deletes.

-- Allow admins to delete individual transactions
drop policy if exists "Admin can delete transactions" on public.transactions;
create policy "Admin can delete transactions" on public.transactions
  for delete using (
    exists (select 1 from public.profiles where id = auth.uid() and role in ('ADMIN', 'SUPER_ADMIN'))
  );

-- Optional bulk-clear RPC (used by dashboard "Clear All Data")
create or replace function public.clear_all_data()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1 from public.profiles where id = auth.uid() and role in ('ADMIN', 'SUPER_ADMIN')
  ) then
    raise exception 'Only admins can clear all data';
  end if;
  delete from public.notifications;
  delete from public.transactions;
end;
$$;

grant execute on function public.clear_all_data() to authenticated;
