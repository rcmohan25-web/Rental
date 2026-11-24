-- pgTAP: schema, constraints, sign-up trigger, reference data.
-- Owner: Srijan. Run with `supabase test db`. Everything is rolled back at the end.
begin;
select plan(46);

-- ---------------------------------------------------------------------------
-- Tables exist
-- ---------------------------------------------------------------------------
select has_table('public', 'profiles',        'profiles table exists');
select has_table('public', 'items',           'items table exists');
select has_table('public', 'bookings',        'bookings table exists');
select has_table('public', 'app_settings',    'app_settings table exists');
select has_table('public', 'terms_documents', 'terms_documents table exists');
select has_trigger('auth', 'users', 'on_auth_user_created', 'sign-up trigger is installed on auth.users');

-- ---------------------------------------------------------------------------
-- Sign-up trigger
-- ---------------------------------------------------------------------------
insert into auth.users (id, email, raw_user_meta_data) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'lender@test.local',
   '{"full_name": "  Sita Test  ", "phone": "9800000001", "area": "Lalitpur", "role": "admin", "status": "suspended", "kyc_status": "verified"}'),
  ('aaaaaaaa-0000-0000-0000-000000000002', 'borrower@test.local', null),
  ('aaaaaaaa-0000-0000-0000-000000000003', 'odd@test.local',
   '{"full_name": "Odd", "phone": "12", "area": "Pokhara"}');

select is((select count(*)::int from public.profiles
           where id in ('aaaaaaaa-0000-0000-0000-000000000001',
                        'aaaaaaaa-0000-0000-0000-000000000002',
                        'aaaaaaaa-0000-0000-0000-000000000003')),
          3, 'a profile is created for every new auth user');

select results_eq(
  $$ select full_name, phone, area from public.profiles where id = 'aaaaaaaa-0000-0000-0000-000000000001' $$,
  $$ values ('Sita Test'::text, '9800000001'::text, 'Lalitpur'::text) $$,
  'name, phone and area are copied from sign-up metadata (name is trimmed)');

select results_eq(
  $$ select role, status, kyc_status from public.profiles where id = 'aaaaaaaa-0000-0000-0000-000000000001' $$,
  $$ values ('user'::text, 'active'::text, 'not_submitted'::text) $$,
  'role, status and kyc_status in metadata are ignored');

select results_eq(
  $$ select full_name, phone, area from public.profiles where id = 'aaaaaaaa-0000-0000-0000-000000000002' $$,
  $$ values (null::text, null::text, null::text) $$,
  'a user with no metadata still gets a profile');

select results_eq(
  $$ select phone, area from public.profiles where id = 'aaaaaaaa-0000-0000-0000-000000000003' $$,
  $$ values (null::text, null::text) $$,
  'an unknown area and a too-short phone are dropped instead of blocking sign-up');

-- ---------------------------------------------------------------------------
-- Fixtures: two items and a helper to create bookings with a correct fee
-- ---------------------------------------------------------------------------
insert into public.items (id, lender_id, title, category, condition, daily_price, declared_value, area, photo_paths) values
  ('bbbbbbbb-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001',
   'Test camera', 'camera', 'good', 3500, 160000, 'Kathmandu', '{a.jpg}'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001',
   'Test tent', 'camping', 'good', 700, 18000, 'Bhaktapur', '{a.jpg}');

create function pg_temp.book(p_item uuid, p_start date, p_end date, p_status text,
                             p_borrower uuid default 'aaaaaaaa-0000-0000-0000-000000000002')
returns void language sql as $$
  insert into public.bookings (item_id, lender_id, borrower_id, start_date, end_date, status,
                               daily_price, rental_fee, deposit_amount, commission_rate, deposit_rate)
  select i.id, i.lender_id, p_borrower, p_start, p_end, p_status,
         i.daily_price, i.daily_price * (p_end - p_start + 1), 0, 0.10, 0.25
  from public.items i where i.id = p_item;
$$;

-- ---------------------------------------------------------------------------
-- Double-booking exclusion constraint
-- ---------------------------------------------------------------------------
select lives_ok(
  $$ select pg_temp.book('bbbbbbbb-0000-0000-0000-000000000001', '2027-03-06', '2027-03-08', 'renter_accepted') $$,
  'first accepted booking is stored');

select is((select days from public.bookings where start_date = '2027-03-06'), 3,
          'days are inclusive: 6 to 8 March is 3 days');

select throws_ok(
  $$ select pg_temp.book('bbbbbbbb-0000-0000-0000-000000000001', '2027-03-07', '2027-03-09', 'renter_accepted',
                         'aaaaaaaa-0000-0000-0000-000000000003') $$,
  '23P01', null, 'overlapping accepted booking is rejected');

select throws_ok(
  $$ select pg_temp.book('bbbbbbbb-0000-0000-0000-000000000001', '2027-03-08', '2027-03-10', 'awaiting_payment',
                         'aaaaaaaa-0000-0000-0000-000000000003') $$,
  '23P01', null, 'sharing only the last day is still an overlap (end date is inclusive)');

select throws_ok(
  $$ select pg_temp.book('bbbbbbbb-0000-0000-0000-000000000001', '2027-03-05', '2027-03-06', 'payment_verified',
                         'aaaaaaaa-0000-0000-0000-000000000003') $$,
  '23P01', null, 'sharing only the first day is also an overlap');

select lives_ok(
  $$ select pg_temp.book('bbbbbbbb-0000-0000-0000-000000000001', '2027-03-09', '2027-03-10', 'renter_accepted',
                         'aaaaaaaa-0000-0000-0000-000000000003') $$,
  'the day after the last booked day is free');

select lives_ok(
  $$ select pg_temp.book('bbbbbbbb-0000-0000-0000-000000000001', '2027-03-06', '2027-03-08', 'requested',
                         'aaaaaaaa-0000-0000-0000-000000000003') $$,
  'a plain request does not block dates (many people can ask for the same days)');

select lives_ok(
  $$ select pg_temp.book('bbbbbbbb-0000-0000-0000-000000000001', '2027-03-06', '2027-03-08', 'declined',
                         'aaaaaaaa-0000-0000-0000-000000000003') $$,
  'declined bookings do not block dates');

select lives_ok(
  $$ select pg_temp.book('bbbbbbbb-0000-0000-0000-000000000002', '2027-03-06', '2027-03-08', 'renter_accepted') $$,
  'the same dates on a different item are fine');

update public.bookings set status = 'cancelled'
 where item_id = 'bbbbbbbb-0000-0000-0000-000000000001' and start_date = '2027-03-06' and status = 'renter_accepted';

select lives_ok(
  $$ select pg_temp.book('bbbbbbbb-0000-0000-0000-000000000001', '2027-03-06', '2027-03-08', 'renter_accepted',
                         'aaaaaaaa-0000-0000-0000-000000000003') $$,
  'cancelling a booking frees its dates');

select throws_ok(
  $$ update public.bookings set status = 'renter_accepted'
      where item_id = 'bbbbbbbb-0000-0000-0000-000000000001' and start_date = '2027-03-06' and status = 'requested' $$,
  '23P01', null, 'accepting a request whose dates are now taken is rejected by the database');

-- ---------------------------------------------------------------------------
-- Other booking checks
-- ---------------------------------------------------------------------------
select throws_ok(
  $$ select pg_temp.book('bbbbbbbb-0000-0000-0000-000000000002', '2027-04-10', '2027-04-09', 'requested') $$,
  '23514', null, 'end date before start date is rejected');

select throws_ok(
  $$ select pg_temp.book('bbbbbbbb-0000-0000-0000-000000000002', '2027-04-01', '2027-04-02', 'requested',
                         'aaaaaaaa-0000-0000-0000-000000000001') $$,
  '23514', null, 'a Renter cannot book their own item');

select throws_ok(
  $$ insert into public.bookings (item_id, lender_id, borrower_id, start_date, end_date, daily_price,
                                  rental_fee, deposit_amount, commission_rate, deposit_rate)
     values ('bbbbbbbb-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001',
             'aaaaaaaa-0000-0000-0000-000000000002', '2027-05-01', '2027-05-03', 700, 1000, 0, 0.1, 0.25) $$,
  '23514', null, 'rental fee must equal days x daily price');

select throws_ok(
  $$ select pg_temp.book('bbbbbbbb-0000-0000-0000-000000000002', '2027-05-10', '2027-05-11', 'confirmed') $$,
  '23514', null, 'an unknown status is rejected');

select throws_ok(
  $$ insert into public.bookings (item_id, lender_id, borrower_id, start_date, end_date, daily_price,
                                  rental_fee, deposit_amount, commission_rate, deposit_rate)
     values ('bbbbbbbb-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001',
             'aaaaaaaa-0000-0000-0000-000000000002', '2027-05-01', '2027-05-01', 700, 700, 0, 1.5, 0.25) $$,
  '23514', null, 'commission rate must be a fraction between 0 and 1');

-- ---------------------------------------------------------------------------
-- Item checks
-- ---------------------------------------------------------------------------
select throws_ok(
  $$ insert into public.items (lender_id, title, category, condition, daily_price, declared_value, area, photo_paths)
     values ('aaaaaaaa-0000-0000-0000-000000000001', 'No photo', 'tools', 'good', 100, 1000, 'Kathmandu', '{}') $$,
  '23514', null, 'a listing needs at least one photo');

select throws_ok(
  $$ insert into public.items (lender_id, title, category, condition, daily_price, declared_value, area, photo_paths)
     values ('aaaaaaaa-0000-0000-0000-000000000001', 'Six photos', 'tools', 'good', 100, 1000, 'Kathmandu',
             '{1.jpg,2.jpg,3.jpg,4.jpg,5.jpg,6.jpg}') $$,
  '23514', null, 'a listing allows at most five photos');

select throws_ok(
  $$ insert into public.items (lender_id, title, category, condition, daily_price, declared_value, area, photo_paths)
     values ('aaaaaaaa-0000-0000-0000-000000000001', 'Free item', 'tools', 'good', 0, 1000, 'Kathmandu', '{a.jpg}') $$,
  '23514', null, 'daily price must be above zero');

select throws_ok(
  $$ insert into public.items (lender_id, title, category, condition, daily_price, declared_value, area, photo_paths)
     values ('aaaaaaaa-0000-0000-0000-000000000001', 'Odd place', 'tools', 'good', 100, 1000, 'Pokhara', '{a.jpg}') $$,
  '23514', null, 'area must be Kathmandu, Lalitpur or Bhaktapur');

select throws_ok(
  $$ insert into public.items (lender_id, title, category, condition, daily_price, declared_value, area, photo_paths)
     values ('aaaaaaaa-0000-0000-0000-000000000001', 'Odd type', 'cars', 'good', 100, 1000, 'Kathmandu', '{a.jpg}') $$,
  '23514', null, 'category must be one of the allowed values');

select throws_ok(
  $$ insert into public.items (lender_id, title, category, condition, daily_price, declared_value, area, photo_paths)
     values ('aaaaaaaa-0000-0000-0000-00000000ffff', 'Ghost owner', 'tools', 'good', 100, 1000, 'Kathmandu', '{a.jpg}') $$,
  '23503', null, 'an item must belong to an existing profile');

-- ---------------------------------------------------------------------------
-- app_settings
-- ---------------------------------------------------------------------------
select results_eq(
  $$ select key from public.app_settings order by key $$,
  $$ values ('auto_approve_orders'::text), ('commission_rate'), ('deposit_rate'), ('request_expiry_hours') $$,
  'the four baseline settings are seeded');

select throws_ok(
  $$ update public.app_settings set value = '1.5' where key = 'commission_rate' $$,
  '23514', null, 'commission rate above 1 is rejected');

select throws_ok(
  $$ update public.app_settings set value = '"yes"' where key = 'auto_approve_orders' $$,
  '23514', null, 'auto_approve_orders must be true or false');

select throws_ok(
  $$ update public.app_settings set value = '0' where key = 'request_expiry_hours' $$,
  '23514', null, 'request expiry must be above zero');

select lives_ok(
  $$ update public.app_settings set value = '0.12' where key = 'commission_rate' $$,
  'a valid commission rate is accepted');

-- ---------------------------------------------------------------------------
-- terms_documents
-- ---------------------------------------------------------------------------
select results_eq(
  $$ select kind, version, is_active from public.terms_documents order by kind $$,
  $$ values ('borrower'::text, 1, true), ('general', 1, true), ('renter', 1, true) $$,
  'one active version 1 exists for each of the three term sets');

select ok((select bool_and(body like 'Prototype terms, not legal advice.%') from public.terms_documents),
          'every seeded term set is marked as a prototype, not legal advice');

select throws_ok(
  $$ insert into public.terms_documents (kind, version, title, body, is_active)
     values ('general', 2, 'General v2', 'text', true) $$,
  '23505', null, 'two active versions of the same kind are not allowed');

select lives_ok(
  $$ update public.terms_documents set is_active = false where kind = 'general';
     insert into public.terms_documents (kind, version, title, body, is_active)
     values ('general', 2, 'General v2', 'text', true) $$,
  'publishing is: deactivate the old version, insert the new one as active');

select throws_ok(
  $$ update public.terms_documents set body = 'changed' where kind = 'borrower' and version = 1 $$,
  'P0001', 'terms_immutable', 'a published version cannot be edited');

select throws_ok(
  $$ delete from public.terms_documents where kind = 'renter' $$,
  'P0001', 'terms_immutable', 'a published version cannot be deleted');

-- ---------------------------------------------------------------------------
-- updated_at trigger
-- ---------------------------------------------------------------------------
update public.items set updated_at = '2020-01-01' where id = 'bbbbbbbb-0000-0000-0000-000000000002';
update public.items set title = 'Test tent 2' where id = 'bbbbbbbb-0000-0000-0000-000000000002';
select ok((select updated_at > now() - interval '1 minute' from public.items
            where id = 'bbbbbbbb-0000-0000-0000-000000000002'),
          'updated_at is refreshed by the trigger on every update');

select is(public.today_kathmandu(), (now() at time zone 'Asia/Kathmandu')::date,
          'today_kathmandu() uses Nepal time');

select * from finish();
rollback;
