-- =============================================================================
-- DEV seed (local Supabase and the rental-dev project). Owner: Srijan.
-- Runs after the migrations on `supabase db reset`.
--
-- FAKE DATA ONLY. Names, phone numbers and emails are invented. All accounts
-- share the password below, which is for local development ONLY: never run this
-- file against rental-demo or any public project (use demo_seed.sql there).
--
--   admin@example.com      admin
--   sita@example.com       Renter (lender), ID verified
--   bikash@example.com     Renter (lender), ID verified
--   anita@example.com      Borrower, ID verified
--   dipesh@example.com     Borrower, ID not submitted yet
--   password for all:      Password123!
--
-- Safe to run twice (everything uses fixed ids and ON CONFLICT DO NOTHING).
-- =============================================================================

-- Auth users. Inserting directly into auth.users fires the sign-up trigger,
-- which creates the profiles. The raw_user_meta_data below is what the app sends.
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change
)
select
  '00000000-0000-0000-0000-000000000000', u.id, 'authenticated', 'authenticated', u.email,
  extensions.crypt('Password123!', extensions.gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  jsonb_build_object('full_name', u.full_name, 'phone', u.phone, 'area', u.area),
  now(), now(), '', '', '', ''
from (values
  ('11111111-1111-1111-1111-000000000001'::uuid, 'admin@example.com',  'Rental Admin',   '9800000000', 'Kathmandu'),
  ('11111111-1111-1111-1111-000000000002'::uuid, 'sita@example.com',   'Sita Shrestha',  '9800000001', 'Kathmandu'),
  ('11111111-1111-1111-1111-000000000003'::uuid, 'bikash@example.com', 'Bikash Tamang',  '9800000002', 'Lalitpur'),
  ('11111111-1111-1111-1111-000000000004'::uuid, 'anita@example.com',  'Anita Gurung',   '9800000003', 'Bhaktapur'),
  ('11111111-1111-1111-1111-000000000005'::uuid, 'dipesh@example.com', 'Dipesh Karki',   '9800000004', 'Kathmandu')
) as u(id, email, full_name, phone, area)
on conflict (id) do nothing;

-- Email sign-in needs an identity row for each user.
insert into auth.identities (provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
select u.id::text, u.id,
       jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true),
       'email', now(), now(), now()
from auth.users u
where u.email in ('admin@example.com', 'sita@example.com', 'bikash@example.com',
                  'anita@example.com', 'dipesh@example.com')
  and not exists (select 1 from auth.identities i where i.user_id = u.id and i.provider = 'email');

-- Roles and ID status are protected columns, so the seed sets them directly
-- (it runs as the database owner).
update public.profiles set role = 'admin' where id = '11111111-1111-1111-1111-000000000001';
update public.profiles
   set kyc_status = 'verified', kyc_submitted_at = now(), kyc_reviewed_at = now()
 where id in ('11111111-1111-1111-1111-000000000001',
              '11111111-1111-1111-1111-000000000002',
              '11111111-1111-1111-1111-000000000003',
              '11111111-1111-1111-1111-000000000004');

-- Listings. There are no real photo files in storage, so every item points at a
-- placeholder path; the apps show their image placeholder when it fails to load.
insert into public.items (id, lender_id, title, category, description, condition,
                          daily_price, declared_value, rules, area, photo_paths)
values
 ('22222222-2222-2222-2222-000000000001', '11111111-1111-1111-1111-000000000002',
  'Sony Alpha A7 III Mirrorless Camera', 'camera',
  'Full-frame body with 28-70mm lens, two batteries and a 64GB card. Pickup near Thamel.',
  'good', 3500, 160000, 'Handle with care. Return with batteries charged.', 'Kathmandu', '{seed/placeholder.jpg}'),
 ('22222222-2222-2222-2222-000000000002', '11111111-1111-1111-1111-000000000002',
  'Epson Full HD Projector', 'projector',
  'Bright 3500 lumen projector with HDMI cable and carry bag. Pickup in Jawalakhel.',
  'good', 2000, 70000, 'No outdoor use in rain.', 'Lalitpur', '{seed/placeholder.jpg}'),
 ('22222222-2222-2222-2222-000000000003', '11111111-1111-1111-1111-000000000003',
  'PlayStation 5 with 2 controllers', 'gaming',
  'Disc edition console, two controllers and three games. Pickup in Baneshwor.',
  'like_new', 1800, 90000, 'Do not install other accounts or games.', 'Kathmandu', '{seed/placeholder.jpg}'),
 ('22222222-2222-2222-2222-000000000004', '11111111-1111-1111-1111-000000000003',
  '4-person camping tent', 'camping',
  'Waterproof dome tent with pegs and carry bag. Pickup near Bhaktapur Durbar Square.',
  'good', 700, 18000, 'Return clean and dry.', 'Bhaktapur', '{seed/placeholder.jpg}'),
 ('22222222-2222-2222-2222-000000000005', '11111111-1111-1111-1111-000000000003',
  'Bosch cordless drill set', 'tools',
  'Drill, two batteries, charger and 30 bits. Pickup in Patan.',
  'good', 500, 12000, 'Return batteries charged.', 'Lalitpur', '{seed/placeholder.jpg}'),
 ('22222222-2222-2222-2222-000000000006', '11111111-1111-1111-1111-000000000002',
  'Yamaha acoustic guitar', 'music',
  'F310 guitar with soft case and spare strings. Pickup in Kathmandu.',
  'good', 600, 25000, 'Keep away from heat and damp.', 'Kathmandu', '{seed/placeholder.jpg}'),
 ('22222222-2222-2222-2222-000000000007', '11111111-1111-1111-1111-000000000002',
  'DJI Mini 3 drone', 'camera',
  'Drone with three batteries and a controller. Pickup in Bhaktapur.',
  'like_new', 3000, 110000, 'Fly only where it is legal and safe.', 'Bhaktapur', '{seed/placeholder.jpg}'),
 ('22222222-2222-2222-2222-000000000008', '11111111-1111-1111-1111-000000000003',
  'Portable PA speaker with mic', 'music',
  'Battery speaker with wireless microphone. Pickup in Kathmandu.',
  'fair', 1500, 35000, 'No use above 80 percent volume.', 'Kathmandu', '{seed/placeholder.jpg}'),
 ('22222222-2222-2222-2222-000000000009', '11111111-1111-1111-1111-000000000002',
  'Camping stove and cookset', 'camping',
  'Gas stove, pot set and two cylinders. Pickup in Lalitpur.',
  'good', 300, 6000, 'Return cylinders as found.', 'Lalitpur', '{seed/placeholder.jpg}'),
 ('22222222-2222-2222-2222-000000000010', '11111111-1111-1111-1111-000000000003',
  'Nintendo Switch OLED', 'gaming',
  'Console with dock, two Joy-Con and two games. Pickup in Bhaktapur.',
  'like_new', 1200, 55000, 'No account changes.', 'Bhaktapur', '{seed/placeholder.jpg}')
on conflict (id) do nothing;

-- A few bookings so the screens have something to show. Money uses the
-- placeholder settings (commission 10 percent, deposit 25 percent of declared value).
-- Dates are relative to today so the data never goes stale.
insert into public.bookings (id, item_id, lender_id, borrower_id, start_date, end_date, status,
                             daily_price, rental_fee, deposit_amount, commission_rate, deposit_rate,
                             terms_version_ids, expires_at)
select b.id, b.item_id, i.lender_id, b.borrower_id,
       public.today_kathmandu() + b.start_off, public.today_kathmandu() + b.end_off,
       b.status, i.daily_price, i.daily_price * (b.end_off - b.start_off + 1),
       round(i.declared_value * 0.25), 0.10, 0.25,
       (select coalesce(array_agg(t.id), '{}') from public.terms_documents t where t.is_active),
       case when b.status = 'requested' then now() + interval '48 hours' end
from (values
  ('33333333-3333-3333-3333-000000000001'::uuid, '22222222-2222-2222-2222-000000000001'::uuid,
   '11111111-1111-1111-1111-000000000004'::uuid, 10, 12, 'requested'),
  ('33333333-3333-3333-3333-000000000002'::uuid, '22222222-2222-2222-2222-000000000001'::uuid,
   '11111111-1111-1111-1111-000000000005'::uuid, 11, 13, 'requested'),
  ('33333333-3333-3333-3333-000000000003'::uuid, '22222222-2222-2222-2222-000000000002'::uuid,
   '11111111-1111-1111-1111-000000000004'::uuid, 20, 22, 'awaiting_payment'),
  ('33333333-3333-3333-3333-000000000004'::uuid, '22222222-2222-2222-2222-000000000004'::uuid,
   '11111111-1111-1111-1111-000000000004'::uuid, -20, -18, 'completed')
) as b(id, item_id, borrower_id, start_off, end_off, status)
join public.items i on i.id = b.item_id
on conflict (id) do nothing;
