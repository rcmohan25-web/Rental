-- pgTAP: storage buckets and storage policies.
-- Owner: Srijan. Run with `supabase test db`. Everything is rolled back at the end.
--
-- Objects are inserted straight into storage.objects. That is exactly the check
-- the Storage API makes before it accepts an upload, so a policy that blocks the
-- insert here blocks the real upload too.
begin;
select plan(31);

-- ---------------------------------------------------------------------------
-- Buckets
-- ---------------------------------------------------------------------------
select results_eq(
  $$ select id, public, file_size_limit from storage.buckets
      where id in ('item-photos', 'kyc-documents', 'handover-evidence', 'payment-proofs') order by id $$,
  $$ values ('handover-evidence'::text, false, 5242880::bigint),
            ('item-photos',             true,  5242880::bigint),
            ('kyc-documents',           false, 5242880::bigint),
            ('payment-proofs',          false, 5242880::bigint) $$,
  'four buckets exist: only item-photos is public, all are limited to 5 MB');

select is((select allowed_mime_types from storage.buckets where id = 'kyc-documents'),
          array['image/jpeg', 'image/png', 'image/webp'],
          'kyc-documents accepts images only');

-- ---------------------------------------------------------------------------
-- Set-up (as the owner)
--   A Renter, B Borrower, C stranger, S suspended, Z admin
-- ---------------------------------------------------------------------------
insert into auth.users (id, email, raw_user_meta_data) values
  ('aaaaaaaa-2222-0000-0000-00000000000a', 'a@test.local', '{"full_name": "Sita"}'),
  ('aaaaaaaa-2222-0000-0000-00000000000b', 'b@test.local', '{"full_name": "Bikash"}'),
  ('aaaaaaaa-2222-0000-0000-00000000000c', 'c@test.local', '{"full_name": "Chandra"}'),
  ('aaaaaaaa-2222-0000-0000-00000000000d', 's@test.local', '{"full_name": "Sunil"}'),
  ('aaaaaaaa-2222-0000-0000-00000000000e', 'z@test.local', '{"full_name": "Zara"}');
update public.profiles set role = 'admin'       where id = 'aaaaaaaa-2222-0000-0000-00000000000e';
update public.profiles set status = 'suspended' where id = 'aaaaaaaa-2222-0000-0000-00000000000d';

insert into public.items (id, lender_id, title, category, condition, daily_price, declared_value, area, photo_paths) values
  ('bbbbbbbb-2222-0000-0000-000000000001', 'aaaaaaaa-2222-0000-0000-00000000000a',
   'Storage test camera', 'camera', 'good', 1000, 40000, 'Kathmandu', '{a.jpg}');

insert into public.bookings (id, item_id, lender_id, borrower_id, start_date, end_date, status,
                             daily_price, rental_fee, deposit_amount, commission_rate, deposit_rate) values
  ('cccccccc-2222-0000-0000-000000000001', 'bbbbbbbb-2222-0000-0000-000000000001', 'aaaaaaaa-2222-0000-0000-00000000000a',
   'aaaaaaaa-2222-0000-0000-00000000000b', '2027-07-01', '2027-07-02', 'awaiting_payment', 1000, 2000, 10000, 0.1, 0.25),
  ('cccccccc-2222-0000-0000-000000000002', 'bbbbbbbb-2222-0000-0000-000000000001', 'aaaaaaaa-2222-0000-0000-00000000000a',
   'aaaaaaaa-2222-0000-0000-00000000000b', '2027-07-10', '2027-07-11', 'payment_verified', 1000, 2000, 10000, 0.1, 0.25),
  ('cccccccc-2222-0000-0000-000000000003', 'bbbbbbbb-2222-0000-0000-000000000001', 'aaaaaaaa-2222-0000-0000-00000000000a',
   'aaaaaaaa-2222-0000-0000-00000000000b', '2027-07-20', '2027-07-21', 'requested', 1000, 2000, 10000, 0.1, 0.25);

-- ===========================================================================
-- item-photos (public)
-- ===========================================================================
select set_config('request.jwt.claims', '{"sub": "aaaaaaaa-2222-0000-0000-00000000000a", "role": "authenticated"}', true);
set local role authenticated;

select lives_ok($$ insert into storage.objects (bucket_id, name, owner)
                   values ('item-photos', 'aaaaaaaa-2222-0000-0000-00000000000a/camera.jpg', 'aaaaaaaa-2222-0000-0000-00000000000a') $$,
  'item-photos: a user can upload into their own folder');

select throws_ok($$ insert into storage.objects (bucket_id, name, owner)
                    values ('item-photos', 'aaaaaaaa-2222-0000-0000-00000000000b/camera.jpg', 'aaaaaaaa-2222-0000-0000-00000000000a') $$,
  '42501', null, 'item-photos: a user cannot upload into someone else''s folder');

select lives_ok($$ insert into storage.objects (bucket_id, name, owner)
                   values ('item-photos', 'aaaaaaaa-2222-0000-0000-00000000000a/temp.jpg', 'aaaaaaaa-2222-0000-0000-00000000000a') $$,
  'item-photos: a second upload works');

select lives_ok($$ delete from storage.objects
                    where bucket_id = 'item-photos' and name = 'aaaaaaaa-2222-0000-0000-00000000000a/temp.jpg' $$,
  'item-photos: a user can delete their own photo');

select is((select count(*)::int from storage.objects
            where bucket_id = 'item-photos' and name = 'aaaaaaaa-2222-0000-0000-00000000000a/temp.jpg'), 0,
          'item-photos: the deleted photo is gone');

reset role;
select set_config('request.jwt.claims', '{"sub": "aaaaaaaa-2222-0000-0000-00000000000c", "role": "authenticated"}', true);
set local role authenticated;

select lives_ok($$ delete from storage.objects
                    where bucket_id = 'item-photos' and name = 'aaaaaaaa-2222-0000-0000-00000000000a/camera.jpg' $$,
  'item-photos: deleting someone else''s photo matches no rows (checked below)');

reset role;
select is((select count(*)::int from storage.objects
            where bucket_id = 'item-photos' and name = 'aaaaaaaa-2222-0000-0000-00000000000a/camera.jpg'), 1,
          'item-photos: the stranger could not delete A''s photo');

select set_config('request.jwt.claims', '', true);
set local role anon;

select is((select count(*)::int from storage.objects where bucket_id = 'item-photos'), 1,
          'item-photos: anyone, even not signed in, can see listing photos');

select throws_ok($$ insert into storage.objects (bucket_id, name)
                    values ('item-photos', 'aaaaaaaa-2222-0000-0000-00000000000a/anon.jpg') $$,
  '42501', null, 'item-photos: not signed in means no upload');

-- ===========================================================================
-- kyc-documents (private, admin read only)
-- ===========================================================================
reset role;
select set_config('request.jwt.claims', '{"sub": "aaaaaaaa-2222-0000-0000-00000000000a", "role": "authenticated"}', true);
set local role authenticated;

select lives_ok($$ insert into storage.objects (bucket_id, name, owner)
                   values ('kyc-documents', 'aaaaaaaa-2222-0000-0000-00000000000a/id-1.jpg', 'aaaaaaaa-2222-0000-0000-00000000000a') $$,
  'kyc: a user can upload their own ID photo');

select throws_ok($$ insert into storage.objects (bucket_id, name, owner)
                    values ('kyc-documents', 'aaaaaaaa-2222-0000-0000-00000000000b/id-1.jpg', 'aaaaaaaa-2222-0000-0000-00000000000a') $$,
  '42501', null, 'kyc: a user cannot upload into another user''s folder');

select is((select count(*)::int from storage.objects where bucket_id = 'kyc-documents'), 0,
          'kyc: even the owner cannot read ID photos back (admins only)');

select lives_ok($$ delete from storage.objects where bucket_id = 'kyc-documents' $$,
  'kyc: a user''s delete matches no rows (checked below)');

reset role;
select set_config('request.jwt.claims', '{"sub": "aaaaaaaa-2222-0000-0000-00000000000d", "role": "authenticated"}', true);
set local role authenticated;

select throws_ok($$ insert into storage.objects (bucket_id, name, owner)
                    values ('kyc-documents', 'aaaaaaaa-2222-0000-0000-00000000000d/id-1.jpg', 'aaaaaaaa-2222-0000-0000-00000000000d') $$,
  '42501', null, 'kyc: a suspended user cannot upload');

reset role;
select set_config('request.jwt.claims', '{"sub": "aaaaaaaa-2222-0000-0000-00000000000e", "role": "authenticated"}', true);
set local role authenticated;

select is((select count(*)::int from storage.objects where bucket_id = 'kyc-documents'), 1,
          'kyc: an admin can read ID photos (and the owner''s delete changed nothing)');

-- ===========================================================================
-- handover-evidence (private; booking Renter writes, Renter + Borrower + admin read)
-- ===========================================================================
reset role;
select set_config('request.jwt.claims', '{"sub": "aaaaaaaa-2222-0000-0000-00000000000a", "role": "authenticated"}', true);
set local role authenticated;

select lives_ok($$ insert into storage.objects (bucket_id, name, owner)
                   values ('handover-evidence', 'cccccccc-2222-0000-0000-000000000002/item-1.jpg', 'aaaaaaaa-2222-0000-0000-00000000000a') $$,
  'handover: the booking''s Renter can upload evidence once payment is verified');

select throws_ok($$ insert into storage.objects (bucket_id, name, owner)
                    values ('handover-evidence', 'cccccccc-2222-0000-0000-000000000003/item-1.jpg', 'aaaaaaaa-2222-0000-0000-00000000000a') $$,
  '42501', null, 'handover: no evidence upload while the booking is only requested');

select throws_ok($$ insert into storage.objects (bucket_id, name, owner)
                    values ('handover-evidence', 'not-a-booking-id/item-1.jpg', 'aaaaaaaa-2222-0000-0000-00000000000a') $$,
  '42501', null, 'handover: a folder that is not a booking id is rejected cleanly');

reset role;
select set_config('request.jwt.claims', '{"sub": "aaaaaaaa-2222-0000-0000-00000000000b", "role": "authenticated"}', true);
set local role authenticated;

select throws_ok($$ insert into storage.objects (bucket_id, name, owner)
                    values ('handover-evidence', 'cccccccc-2222-0000-0000-000000000002/borrower-1.jpg', 'aaaaaaaa-2222-0000-0000-00000000000b') $$,
  '42501', null, 'handover: the Borrower cannot upload handover evidence');

select is((select count(*)::int from storage.objects where bucket_id = 'handover-evidence'), 1,
          'handover: the Borrower can read the evidence of their booking');

reset role;
select set_config('request.jwt.claims', '{"sub": "aaaaaaaa-2222-0000-0000-00000000000c", "role": "authenticated"}', true);
set local role authenticated;

select is((select count(*)::int from storage.objects where bucket_id = 'handover-evidence'), 0,
          'handover: a stranger cannot read it');
select throws_ok($$ insert into storage.objects (bucket_id, name, owner)
                    values ('handover-evidence', 'cccccccc-2222-0000-0000-000000000002/x.jpg', 'aaaaaaaa-2222-0000-0000-00000000000c') $$,
  '42501', null, 'handover: a stranger cannot upload to it');

-- ===========================================================================
-- payment-proofs (private; booking Borrower writes, Borrower + admin read)
-- ===========================================================================
reset role;
select set_config('request.jwt.claims', '{"sub": "aaaaaaaa-2222-0000-0000-00000000000b", "role": "authenticated"}', true);
set local role authenticated;

select lives_ok($$ insert into storage.objects (bucket_id, name, owner)
                   values ('payment-proofs', 'cccccccc-2222-0000-0000-000000000001/proof-1.png', 'aaaaaaaa-2222-0000-0000-00000000000b') $$,
  'payment: the Borrower can upload proof while payment is due');

select throws_ok($$ insert into storage.objects (bucket_id, name, owner)
                    values ('payment-proofs', 'cccccccc-2222-0000-0000-000000000002/proof-1.png', 'aaaaaaaa-2222-0000-0000-00000000000b') $$,
  '42501', null, 'payment: no proof upload once payment is already verified');

select is((select count(*)::int from storage.objects where bucket_id = 'payment-proofs'), 1,
          'payment: the Borrower can read their own proof');

reset role;
select set_config('request.jwt.claims', '{"sub": "aaaaaaaa-2222-0000-0000-00000000000a", "role": "authenticated"}', true);
set local role authenticated;

select throws_ok($$ insert into storage.objects (bucket_id, name, owner)
                    values ('payment-proofs', 'cccccccc-2222-0000-0000-000000000001/proof-2.png', 'aaaaaaaa-2222-0000-0000-00000000000a') $$,
  '42501', null, 'payment: the Renter cannot upload payment proof');

select is((select count(*)::int from storage.objects where bucket_id = 'payment-proofs'), 0,
          'payment: the Renter cannot see payment proof');

reset role;
select set_config('request.jwt.claims', '{"sub": "aaaaaaaa-2222-0000-0000-00000000000e", "role": "authenticated"}', true);
set local role authenticated;

select is((select count(*)::int from storage.objects where bucket_id = 'payment-proofs'), 1,
          'payment: an admin can read payment proof');
select is((select count(*)::int from storage.objects where bucket_id = 'handover-evidence'), 1,
          'handover: an admin can read handover evidence');

reset role;
select * from finish();
rollback;
