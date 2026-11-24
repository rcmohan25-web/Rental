-- =============================================================================
-- DEMO / CLOUD seed (rental-dev and rental-demo). Owner: Srijan.
--
-- Paste into the Supabase dashboard > SQL Editor and run. Safe to run twice.
--
-- This file creates NO logins and contains NO passwords, because the repository is
-- public. Create the accounts yourself first (dashboard > Authentication > Users >
-- Add user > "Auto Confirm User"), with strong passwords kept out of the repo,
-- then put their email addresses below.
--
-- Use fake or consented people only (honesty rule 7).
-- =============================================================================

do $$
declare
  -- EDIT THESE: emails of users you already created in the dashboard.
  v_admin_email    text := 'admin@your-team.example';
  v_renter1_email  text := 'renter1@your-team.example';
  v_renter2_email  text := 'renter2@your-team.example';
  v_borrower_email text := 'borrower@your-team.example';

  v_admin    uuid;
  v_renter1  uuid;
  v_renter2  uuid;
  v_borrower uuid;
begin
  select id into v_admin    from public.profiles where id = (select id from auth.users where email = v_admin_email);
  select id into v_renter1  from public.profiles where id = (select id from auth.users where email = v_renter1_email);
  select id into v_renter2  from public.profiles where id = (select id from auth.users where email = v_renter2_email);
  select id into v_borrower from public.profiles where id = (select id from auth.users where email = v_borrower_email);

  if v_admin is null or v_renter1 is null or v_renter2 is null or v_borrower is null then
    raise exception 'Create the four users in Authentication > Users first, then edit the emails at the top of this file.';
  end if;

  -- Roles and ID status are protected columns; this script runs as the database owner.
  update public.profiles set role = 'admin' where id = v_admin;
  update public.profiles
     set kyc_status = 'verified', kyc_submitted_at = now(), kyc_reviewed_at = now()
   where id in (v_admin, v_renter1, v_renter2, v_borrower);

  -- Users added in the dashboard have no sign-up metadata, so give them fake display
  -- names and areas (only where still empty). Edit freely.
  update public.profiles set full_name = coalesce(full_name, 'Rental Admin'),   area = coalesce(area, 'Kathmandu') where id = v_admin;
  update public.profiles set full_name = coalesce(full_name, 'Sita Shrestha'),  area = coalesce(area, 'Kathmandu') where id = v_renter1;
  update public.profiles set full_name = coalesce(full_name, 'Bikash Tamang'),  area = coalesce(area, 'Lalitpur')   where id = v_renter2;
  update public.profiles set full_name = coalesce(full_name, 'Anita Gurung'),   area = coalesce(area, 'Bhaktapur')  where id = v_borrower;

  -- Ten items. No real photo files exist, so each points at a placeholder path
  -- (the apps show their image placeholder). Upload real photos later and update photo_paths.
  insert into public.items (id, lender_id, title, category, description, condition,
                            daily_price, declared_value, rules, area, photo_paths)
  values
   ('22222222-2222-2222-2222-100000000001', v_renter1, 'Sony Alpha A7 III Mirrorless Camera', 'camera',
    'Full-frame body with 28-70mm lens, two batteries and a 64GB card.', 'good', 3500, 160000,
    'Handle with care. Return with batteries charged.', 'Kathmandu', '{demo/placeholder.jpg}'),
   ('22222222-2222-2222-2222-100000000002', v_renter1, 'Epson Full HD Projector', 'projector',
    'Bright 3500 lumen projector with HDMI cable and carry bag.', 'good', 2000, 70000,
    'No outdoor use in rain.', 'Lalitpur', '{demo/placeholder.jpg}'),
   ('22222222-2222-2222-2222-100000000003', v_renter2, 'PlayStation 5 with 2 controllers', 'gaming',
    'Disc edition console, two controllers and three games.', 'like_new', 1800, 90000,
    'Do not install other accounts or games.', 'Kathmandu', '{demo/placeholder.jpg}'),
   ('22222222-2222-2222-2222-100000000004', v_renter2, '4-person camping tent', 'camping',
    'Waterproof dome tent with pegs and carry bag.', 'good', 700, 18000,
    'Return clean and dry.', 'Bhaktapur', '{demo/placeholder.jpg}'),
   ('22222222-2222-2222-2222-100000000005', v_renter2, 'Bosch cordless drill set', 'tools',
    'Drill, two batteries, charger and 30 bits.', 'good', 500, 12000,
    'Return batteries charged.', 'Lalitpur', '{demo/placeholder.jpg}'),
   ('22222222-2222-2222-2222-100000000006', v_renter1, 'Yamaha acoustic guitar', 'music',
    'F310 guitar with soft case and spare strings.', 'good', 600, 25000,
    'Keep away from heat and damp.', 'Kathmandu', '{demo/placeholder.jpg}'),
   ('22222222-2222-2222-2222-100000000007', v_renter1, 'DJI Mini 3 drone', 'camera',
    'Drone with three batteries and a controller.', 'like_new', 3000, 110000,
    'Fly only where it is legal and safe.', 'Bhaktapur', '{demo/placeholder.jpg}'),
   ('22222222-2222-2222-2222-100000000008', v_renter2, 'Portable PA speaker with mic', 'music',
    'Battery speaker with wireless microphone.', 'fair', 1500, 35000,
    'No use above 80 percent volume.', 'Kathmandu', '{demo/placeholder.jpg}'),
   ('22222222-2222-2222-2222-100000000009', v_renter1, 'Camping stove and cookset', 'camping',
    'Gas stove, pot set and two cylinders.', 'good', 300, 6000,
    'Return cylinders as found.', 'Lalitpur', '{demo/placeholder.jpg}'),
   ('22222222-2222-2222-2222-100000000010', v_renter2, 'Nintendo Switch OLED', 'gaming',
    'Console with dock, two Joy-Con and two games.', 'like_new', 1200, 55000,
    'No account changes.', 'Bhaktapur', '{demo/placeholder.jpg}')
  on conflict (id) do nothing;

  -- Two open requests on the camera so the Renter inbox has something to show.
  -- Money uses the current placeholder settings (commission 10%, deposit 25% of declared value).
  -- Both are plain requests, so they do not block dates and may overlap.
  insert into public.bookings (id, item_id, lender_id, borrower_id, start_date, end_date, status,
                               daily_price, rental_fee, deposit_amount, commission_rate, deposit_rate,
                               terms_version_ids, expires_at)
  select b.id, i.id, i.lender_id, v_borrower,
         public.today_kathmandu() + b.start_off, public.today_kathmandu() + b.end_off, 'requested',
         i.daily_price, i.daily_price * (b.end_off - b.start_off + 1),
         round(i.declared_value * 0.25), 0.10, 0.25,
         (select coalesce(array_agg(t.id), '{}') from public.terms_documents t where t.is_active),
         now() + interval '48 hours'
  from (values
    ('33333333-3333-3333-3333-100000000001'::uuid, '22222222-2222-2222-2222-100000000001'::uuid, 10, 12),
    ('33333333-3333-3333-3333-100000000002'::uuid, '22222222-2222-2222-2222-100000000002'::uuid, 15, 16)
  ) as b(id, item_id, start_off, end_off)
  join public.items i on i.id = b.item_id
  on conflict (id) do nothing;
end;
$$;
