-- =============================================================================
-- Phase 0, migration 2 of 4: Row Level Security, grants and helpers
-- Owner: Srijan.
--
-- Two layers protect the tables:
--   1. GRANTs decide which COLUMNS a signed-in user may write at all.
--      Role, status and kyc_* on profiles, and every column of bookings and
--      app_settings, are not writable by clients. Only SECURITY DEFINER RPCs
--      (Phase 1 and later) and the service role can change them.
--   2. RLS policies decide which ROWS a user may read or write.
-- Default-deny: a table with RLS on and no policy for an action rejects it.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Helper functions used inside policies
-- -----------------------------------------------------------------------------

-- True when the caller is an active admin. SECURITY DEFINER so the lookup in
-- profiles is not itself blocked (or recursively re-checked) by RLS.
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = (select auth.uid())
      and role = 'admin'
      and status = 'active'
  );
$$;

-- True when the caller has an account that is not suspended or deleted.
create or replace function public.is_active_user()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = (select auth.uid())
      and status = 'active'
  );
$$;

revoke all on function public.is_admin()       from public, anon;
revoke all on function public.is_active_user() from public, anon;
grant execute on function public.is_admin()       to authenticated;
grant execute on function public.is_active_user() to authenticated;

-- -----------------------------------------------------------------------------
-- Turn RLS on everywhere
-- -----------------------------------------------------------------------------

alter table public.profiles        enable row level security;
alter table public.items           enable row level security;
alter table public.bookings        enable row level security;
alter table public.app_settings    enable row level security;
alter table public.terms_documents enable row level security;

-- -----------------------------------------------------------------------------
-- GRANTs: start from nothing, then add exactly what the apps need.
-- Supabase gives anon and authenticated full access to new tables by default,
-- so everything is revoked first.
-- -----------------------------------------------------------------------------

revoke all on public.profiles        from anon, authenticated;
revoke all on public.items           from anon, authenticated;
revoke all on public.bookings        from anon, authenticated;
revoke all on public.app_settings    from anon, authenticated;
revoke all on public.terms_documents from anon, authenticated;

-- profiles: read own row; edit only name, phone and area.
-- No INSERT (the sign-up trigger does it) and no DELETE (soft delete via RPC).
grant select on public.profiles to authenticated;
grant update (full_name, phone, area) on public.profiles to authenticated;

-- items: Renters create and edit their own. No DELETE: set status = 'deleted'.
grant select on public.items to authenticated;
grant insert (lender_id, title, category, description, condition, daily_price,
              declared_value, rules, area, photo_paths, status)
  on public.items to authenticated;
grant update (title, category, description, condition, daily_price,
              declared_value, rules, area, photo_paths, status)
  on public.items to authenticated;

-- bookings: read only. Every change is an RPC.
grant select on public.bookings to authenticated;

-- app_settings: read only. Changes go through admin_update_setting.
grant select on public.app_settings to authenticated;

-- terms_documents: public content (the sign-up screen shows the general terms).
grant select on public.terms_documents to anon, authenticated;

-- -----------------------------------------------------------------------------
-- Policies: profiles
-- -----------------------------------------------------------------------------

create policy profiles_select_own_or_admin
  on public.profiles for select to authenticated
  using (id = (select auth.uid()) or public.is_admin());

create policy profiles_update_own
  on public.profiles for update to authenticated
  using (id = (select auth.uid()) and status = 'active')
  with check (id = (select auth.uid()));

-- -----------------------------------------------------------------------------
-- Policies: items
-- -----------------------------------------------------------------------------

-- Everyone signed in sees active listings. A Renter also sees their own paused
-- ones. Admins see everything. Soft-deleted items are visible to admins only.
create policy items_select_visible
  on public.items for select to authenticated
  using (
    status = 'active'
    or (lender_id = (select auth.uid()) and status <> 'deleted')
    or public.is_admin()
  );

create policy items_insert_own
  on public.items for insert to authenticated
  with check (
    lender_id = (select auth.uid())
    and status in ('active', 'paused')
    and public.is_active_user()
  );

create policy items_update_own
  on public.items for update to authenticated
  using (
    lender_id = (select auth.uid())
    and status <> 'deleted'
    and public.is_active_user()
  )
  with check (lender_id = (select auth.uid()));

-- -----------------------------------------------------------------------------
-- Policies: bookings (read only; borrower, lender or admin)
-- -----------------------------------------------------------------------------

create policy bookings_select_participants
  on public.bookings for select to authenticated
  using (
    borrower_id = (select auth.uid())
    or lender_id = (select auth.uid())
    or public.is_admin()
  );

-- -----------------------------------------------------------------------------
-- Policies: app_settings and terms_documents (read only)
-- -----------------------------------------------------------------------------

create policy app_settings_select_all
  on public.app_settings for select to authenticated
  using (true);

create policy terms_documents_select_all
  on public.terms_documents for select to anon, authenticated
  using (true);

-- -----------------------------------------------------------------------------
-- get_public_profiles: the safe, public face of a profile
-- Other people may see a name, area and whether the ID is verified, but never
-- the phone number or ID file paths (contact details unlock after payment).
-- This is a function rather than a view because Supabase's security advisor
-- flags SECURITY DEFINER views. The function returns only the columns listed.
-- -----------------------------------------------------------------------------

create or replace function public.get_public_profiles(p_user_ids uuid[])
returns table (id uuid, full_name text, area text, is_verified boolean)
language sql
stable
security definer
set search_path = ''
as $$
  select p.id,
         p.full_name,
         p.area,
         (p.kyc_status = 'verified') as is_verified
  from public.profiles p
  where p.id = any (p_user_ids)
    and p.status = 'active';
$$;

revoke all on function public.get_public_profiles(uuid[]) from public, anon;
grant execute on function public.get_public_profiles(uuid[]) to authenticated;

comment on function public.get_public_profiles(uuid[]) is
  'Name, area and verified badge of active users. Safe to show to other signed-in users. No phone, no ID paths.';

-- -----------------------------------------------------------------------------
-- Realtime: the renter and borrower screens update live when a booking changes.
-- Realtime applies the RLS policies above, so a user only receives their own rows.
-- -----------------------------------------------------------------------------

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1 from pg_publication_tables
       where pubname = 'supabase_realtime'
         and schemaname = 'public' and tablename = 'bookings') then
    alter publication supabase_realtime add table public.bookings;
  end if;
end;
$$;
