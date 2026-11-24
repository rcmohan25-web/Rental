-- =============================================================================
-- Phase 0, migration 4 of 4: get_item_blocked_dates
-- Owner: Srijan. Used by Smaran's date picker on the item details screen.
--
-- Why an RPC: bookings are readable only by the people in them, but every
-- signed-in user needs to know which days of an item are already taken.
-- This function returns ONLY date ranges (no names, no prices, no booking ids).
-- The ranges are inclusive on both ends and cover bookings in a date-blocking
-- status, i.e. exactly the ones the double-booking constraint protects.
-- Ranges that already ended are left out.
-- =============================================================================

create or replace function public.get_item_blocked_dates(p_item_id uuid)
returns table (start_date date, end_date date)
language sql
stable
security definer
set search_path = ''
as $$
  select b.start_date, b.end_date
  from public.bookings b
  where b.item_id = p_item_id
    and b.end_date >= public.today_kathmandu()
    and b.status in (
      'renter_accepted', 'awaiting_payment', 'payment_submitted',
      'payment_verified', 'handed_over', 'returned', 'disputed', 'completed')
    -- only for people who can see the item (or admins)
    and exists (
      select 1 from public.items i
      where i.id = b.item_id
        and (i.status = 'active' or i.lender_id = (select auth.uid()) or public.is_admin())
    )
  order by b.start_date;
$$;

revoke all on function public.get_item_blocked_dates(uuid) from public, anon;
grant execute on function public.get_item_blocked_dates(uuid) to authenticated;

comment on function public.get_item_blocked_dates(uuid) is
  'Inclusive date ranges already taken for an item. Dates only, no personal data.';
