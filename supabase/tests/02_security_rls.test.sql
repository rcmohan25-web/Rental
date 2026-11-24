-- pgTAP: Row Level Security and column protection.
-- Owner: Srijan. Run with `supabase test db`. Everything is rolled back at the end.
--
-- Each block pretends to be a different caller:
--   set_config('request.jwt.claims', ...) is what auth.uid() reads, and
--   set local role makes Postgres apply that role's grants and RLS policies.
-- `reset role` goes back to the database owner, who ignores RLS (used for set-up
-- and for checking what really changed).
begin;
select plan(54);

-- ---------------------------------------------------------------------------
-- Set-up (as the owner)
--   A  Sita      Renter (lender)           B  Bikash   Borrower
--   C  Chandra   stranger                  S  Sunil    suspended user
--   Z  Zara      admin
-- ---------------------------------------------------------------------------
insert into auth.users (id, email, raw_user_meta_data) values
  ('aaaaaaaa-1111-0000-0000-00000000000a', 'a@test.local', '{"full_name": "Sita", "phone": "9800000001"}'),
  ('aaaaaaaa-1111-0000-0000-00000000000b', 'b@test.local', '{"full_name": "Bikash", "phone": "9800000002"}'),
  ('aaaaaaaa-1111-0000-0000-00000000000c', 'c@test.local', '{"full_name": "Chandra", "phone": "9800000003"}'),
  ('aaaaaaaa-1111-0000-0000-00000000000d', 's@test.local', '{"full_name": "Sunil", "phone": "9800000004"}'),
  ('aaaaaaaa-1111-0000-0000-00000000000e', 'z@test.local', '{"full_name": "Zara", "phone": "9800000005"}');

update public.profiles set role = 'admin'      where id = 'aaaaaaaa-1111-0000-0000-00000000000e';
update public.profiles set status = 'suspended' where id = 'aaaaaaaa-1111-0000-0000-00000000000d';
update public.profiles set kyc_status = 'verified' where id = 'aaaaaaaa-1111-0000-0000-00000000000a';

insert into public.items (id, lender_id, title, category, condition, daily_price, declared_value, area, photo_paths, status) values
  ('bbbbbbbb-1111-0000-0000-000000000001', 'aaaaaaaa-1111-0000-0000-00000000000a', 'A active item',  'camera', 'good', 3500, 160000, 'Kathmandu', '{a.jpg}', 'active'),
  ('bbbbbbbb-1111-0000-0000-000000000002', 'aaaaaaaa-1111-0000-0000-00000000000a', 'A paused item',  'tools',  'good', 500,  12000,  'Lalitpur',  '{a.jpg}', 'paused'),
  ('bbbbbbbb-1111-0000-0000-000000000003', 'aaaaaaaa-1111-0000-0000-00000000000a', 'A deleted item', 'tools',  'good', 500,  12000,  'Lalitpur',  '{a.jpg}', 'deleted'),
  ('bbbbbbbb-1111-0000-0000-000000000004', 'aaaaaaaa-1111-0000-0000-00000000000b', 'B active item',  'music',  'good', 600,  25000,  'Kathmandu', '{a.jpg}', 'active');

insert into public.bookings (id, item_id, lender_id, borrower_id, start_date, end_date, status,
                             daily_price, rental_fee, deposit_amount, commission_rate, deposit_rate) values
  ('cccccccc-1111-0000-0000-000000000001', 'bbbbbbbb-1111-0000-0000-000000000001', 'aaaaaaaa-1111-0000-0000-00000000000a',
   'aaaaaaaa-1111-0000-0000-00000000000b', '2027-06-10', '2027-06-12', 'renter_accepted', 3500, 10500, 40000, 0.10, 0.25),
  ('cccccccc-1111-0000-0000-000000000002', 'bbbbbbbb-1111-0000-0000-000000000001', 'aaaaaaaa-1111-0000-0000-00000000000a',
   'aaaaaaaa-1111-0000-0000-00000000000b', '2027-06-20', '2027-06-22', 'requested', 3500, 10500, 40000, 0.10, 0.25),
  ('cccccccc-1111-0000-0000-000000000003', 'bbbbbbbb-1111-0000-0000-000000000002', 'aaaaaaaa-1111-0000-0000-00000000000a',
   'aaaaaaaa-1111-0000-0000-00000000000b', '2027-06-10', '2027-06-11', 'renter_accepted', 500, 1000, 3000, 0.10, 0.25);

-- ===========================================================================
-- A: the Renter (lender)
-- ===========================================================================
select set_config('request.jwt.claims', '{"sub": "aaaaaaaa-1111-0000-0000-00000000000a", "role": "authenticated"}', true);
set local role authenticated;

select is((select count(*)::int from public.profiles), 1,
          'profiles: a user sees only their own profile');

select throws_ok($$ update public.profiles set role = 'admin' where id = 'aaaaaaaa-1111-0000-0000-00000000000a' $$,
  '42501', null, 'profiles: a user cannot make themselves admin');

select throws_ok($$ update public.profiles set kyc_status = 'verified' where id = 'aaaaaaaa-1111-0000-0000-00000000000a' $$,
  '42501', null, 'profiles: a user cannot mark their own ID as verified');

select throws_ok($$ update public.profiles set status = 'active' where id = 'aaaaaaaa-1111-0000-0000-00000000000a' $$,
  '42501', null, 'profiles: a user cannot change their own account status');

select lives_ok($$ update public.profiles set full_name = 'Sita New', area = 'Bhaktapur'
                    where id = 'aaaaaaaa-1111-0000-0000-00000000000a' $$,
  'profiles: a user can edit their own name and area');

select lives_ok($$ update public.profiles set full_name = 'Hacked' where id = 'aaaaaaaa-1111-0000-0000-00000000000b' $$,
  'profiles: updating someone else matches no rows (no error, no change; checked below)');

select throws_ok($$ insert into public.profiles (id) values ('aaaaaaaa-1111-0000-0000-0000000000ff') $$,
  '42501', null, 'profiles: clients cannot insert profiles (the sign-up trigger does that)');

select throws_ok($$ delete from public.profiles where id = 'aaaaaaaa-1111-0000-0000-00000000000a' $$,
  '42501', null, 'profiles: clients cannot delete profiles');

select lives_ok($$ insert into public.items (lender_id, title, category, condition, daily_price, declared_value, area, photo_paths)
                   values ('aaaaaaaa-1111-0000-0000-00000000000a', 'A new item', 'tools', 'good', 400, 9000, 'Kathmandu', '{a.jpg}') $$,
  'items: a user can create their own listing');

select throws_ok($$ insert into public.items (lender_id, title, category, condition, daily_price, declared_value, area, photo_paths)
                    values ('aaaaaaaa-1111-0000-0000-00000000000b', 'Fake owner', 'tools', 'good', 400, 9000, 'Kathmandu', '{a.jpg}') $$,
  '42501', null, 'items: a user cannot create a listing for someone else');

select throws_ok($$ insert into public.items (lender_id, title, category, condition, daily_price, declared_value, area, photo_paths, status)
                    values ('aaaaaaaa-1111-0000-0000-00000000000a', 'Born deleted', 'tools', 'good', 400, 9000, 'Kathmandu', '{a.jpg}', 'deleted') $$,
  '42501', null, 'items: a new listing must start active or paused');

select lives_ok($$ update public.items set title = 'A active item (edited)' where id = 'bbbbbbbb-1111-0000-0000-000000000001' $$,
  'items: an owner can edit their listing');

select throws_ok($$ update public.items set lender_id = 'aaaaaaaa-1111-0000-0000-00000000000b'
                     where id = 'bbbbbbbb-1111-0000-0000-000000000001' $$,
  '42501', null, 'items: an owner cannot hand a listing to someone else');

select lives_ok($$ update public.items set title = 'Hijacked' where id = 'bbbbbbbb-1111-0000-0000-000000000004' $$,
  'items: updating someone else''s listing matches no rows (checked below)');

select is((select count(*)::int from public.items where id = 'bbbbbbbb-1111-0000-0000-000000000002'), 1,
          'items: an owner still sees their own paused listing');

select is((select count(*)::int from public.items where id = 'bbbbbbbb-1111-0000-0000-000000000003'), 0,
          'items: a soft-deleted listing is hidden from its owner');

select throws_ok($$ delete from public.items where id = 'bbbbbbbb-1111-0000-0000-000000000001' $$,
  '42501', null, 'items: listings are never hard-deleted by clients');

select is((select count(*)::int from public.get_item_blocked_dates('bbbbbbbb-1111-0000-0000-000000000002')), 1,
          'blocked dates: the owner sees dates of their own paused listing');

select is((select count(*)::int from public.bookings), 3,
          'bookings: the lender sees every booking on their items');

select throws_ok($$ insert into public.bookings (item_id, lender_id, borrower_id, start_date, end_date, daily_price,
                                                 rental_fee, deposit_amount, commission_rate, deposit_rate)
                    values ('bbbbbbbb-1111-0000-0000-000000000001', 'aaaaaaaa-1111-0000-0000-00000000000a',
                            'aaaaaaaa-1111-0000-0000-00000000000b', '2027-08-01', '2027-08-01', 3500, 3500, 0, 0.1, 0.25) $$,
  '42501', null, 'bookings: clients cannot create bookings directly (only the RPC can)');

select throws_ok($$ update public.bookings set status = 'payment_verified' where id = 'cccccccc-1111-0000-0000-000000000001' $$,
  '42501', null, 'bookings: a lender cannot move a booking to another status directly');

select throws_ok($$ delete from public.bookings where id = 'cccccccc-1111-0000-0000-000000000001' $$,
  '42501', null, 'bookings: clients cannot delete bookings');

select ok((select count(*) from public.app_settings) >= 4, 'app_settings: signed-in users can read settings');

select throws_ok($$ update public.app_settings set value = '0' where key = 'commission_rate' $$,
  '42501', null, 'app_settings: clients cannot change settings (admin RPC only)');

select throws_ok($$ insert into public.terms_documents (kind, version, title, body) values ('general', 99, 'Fake terms', 'text') $$,
  '42501', null, 'terms: clients cannot publish terms');

select is(public.is_admin(), false, 'is_admin() is false for a normal user');

-- ===========================================================================
-- B: the Borrower
-- ===========================================================================
reset role;
select set_config('request.jwt.claims', '{"sub": "aaaaaaaa-1111-0000-0000-00000000000b", "role": "authenticated"}', true);
set local role authenticated;

select is((select count(*)::int from public.bookings), 3, 'bookings: the borrower sees their own bookings');

select is((select count(*)::int from public.profiles where id = 'aaaaaaaa-1111-0000-0000-00000000000a'), 0,
          'profiles: a borrower cannot read the Renter''s private profile');

select is((select full_name from public.get_public_profiles(array['aaaaaaaa-1111-0000-0000-00000000000a']::uuid[])),
          'Sita New', 'get_public_profiles: other users can see a name');

select throws_ok($$ select phone from public.get_public_profiles(array['aaaaaaaa-1111-0000-0000-00000000000a']::uuid[]) $$,
  '42703', null, 'get_public_profiles: the phone number is not exposed');

-- ===========================================================================
-- C: a stranger
-- ===========================================================================
reset role;
select set_config('request.jwt.claims', '{"sub": "aaaaaaaa-1111-0000-0000-00000000000c", "role": "authenticated"}', true);
set local role authenticated;

select is((select count(*)::int from public.bookings), 0, 'bookings: a stranger sees none');

select is((select count(*)::int from public.items where id = 'bbbbbbbb-1111-0000-0000-000000000001'), 1,
          'items: everyone signed in sees an active listing');

select is((select count(*)::int from public.items where id in
           ('bbbbbbbb-1111-0000-0000-000000000002', 'bbbbbbbb-1111-0000-0000-000000000003')), 0,
          'items: paused and deleted listings are hidden from strangers');

select results_eq($$ select start_date, end_date from public.get_item_blocked_dates('bbbbbbbb-1111-0000-0000-000000000001') $$,
  $$ values ('2027-06-10'::date, '2027-06-12'::date) $$,
  'blocked dates: a stranger sees accepted dates only (a plain request does not block)');

select is((select count(*)::int from public.get_item_blocked_dates('bbbbbbbb-1111-0000-0000-000000000002')), 0,
          'blocked dates: nothing is revealed for a paused listing the caller cannot see');

select lives_ok($$ update public.items set title = 'Vandalised' where id = 'bbbbbbbb-1111-0000-0000-000000000001' $$,
  'items: a stranger''s update matches no rows (checked below)');

-- ===========================================================================
-- S: a suspended user
-- ===========================================================================
reset role;
select set_config('request.jwt.claims', '{"sub": "aaaaaaaa-1111-0000-0000-00000000000d", "role": "authenticated"}', true);
set local role authenticated;

select throws_ok($$ insert into public.items (lender_id, title, category, condition, daily_price, declared_value, area, photo_paths)
                    values ('aaaaaaaa-1111-0000-0000-00000000000d', 'Suspended listing', 'tools', 'good', 400, 9000, 'Kathmandu', '{a.jpg}') $$,
  '42501', null, 'items: a suspended user cannot create listings');

select lives_ok($$ update public.profiles set full_name = 'Still editing' where id = 'aaaaaaaa-1111-0000-0000-00000000000d' $$,
  'profiles: a suspended user''s edit matches no rows (checked below)');

select is(public.is_active_user(), false, 'is_active_user() is false for a suspended user');

-- ===========================================================================
-- anon: not signed in
-- ===========================================================================
reset role;
select set_config('request.jwt.claims', '', true);
set local role anon;

select throws_ok($$ select * from public.profiles $$, '42501', null, 'anon: cannot read profiles');
select throws_ok($$ select * from public.items $$, '42501', null, 'anon: cannot read items');
select throws_ok($$ select * from public.app_settings $$, '42501', null, 'anon: cannot read settings');
select throws_ok($$ select * from public.get_item_blocked_dates('bbbbbbbb-1111-0000-0000-000000000001') $$,
  '42501', null, 'anon: cannot call get_item_blocked_dates');
select ok((select count(*) from public.terms_documents) >= 3, 'anon: can read terms (the sign-up screen shows them)');

-- ===========================================================================
-- Z: the admin
-- ===========================================================================
reset role;
select set_config('request.jwt.claims', '{"sub": "aaaaaaaa-1111-0000-0000-00000000000e", "role": "authenticated"}', true);
set local role authenticated;

select is(public.is_admin(), true, 'is_admin() is true for an active admin');
select ok((select count(*) from public.profiles) >= 5, 'profiles: an admin can read every profile');
select is((select count(*)::int from public.items where id in
           ('bbbbbbbb-1111-0000-0000-000000000002', 'bbbbbbbb-1111-0000-0000-000000000003')), 2,
          'items: an admin sees paused and deleted listings');
select is((select count(*)::int from public.bookings where id::text like 'cccccccc-1111-%'), 3,
          'bookings: an admin can read every booking (test rows only; the seed adds others)');

select throws_ok($$ update public.profiles set role = 'admin' where id = 'aaaaaaaa-1111-0000-0000-00000000000c' $$,
  '42501', null, 'profiles: even an admin changes roles only through an RPC, not a direct update');

-- ===========================================================================
-- Check what really changed (as the owner, who ignores RLS)
-- ===========================================================================
reset role;

select is((select full_name from public.profiles where id = 'aaaaaaaa-1111-0000-0000-00000000000b'), 'Bikash',
          'unchanged: A could not rename B');
select is((select title from public.items where id = 'bbbbbbbb-1111-0000-0000-000000000004'), 'B active item',
          'unchanged: A could not edit B''s listing');
select is((select title from public.items where id = 'bbbbbbbb-1111-0000-0000-000000000001'), 'A active item (edited)',
          'unchanged: the stranger could not edit A''s listing');
select is((select full_name from public.profiles where id = 'aaaaaaaa-1111-0000-0000-00000000000d'), 'Sunil',
          'unchanged: the suspended user could not edit their profile');
select is((select role from public.profiles where id = 'aaaaaaaa-1111-0000-0000-00000000000a'), 'user',
          'unchanged: A is still a normal user');

select * from finish();
rollback;
