-- DEMO DATA for the demo project and for local testing. Fake names and items only.
--
-- Run seed.sql first. Then create FOUR accounts (sign up in the app, or Authentication
-- > Users in the dashboard) with exactly these e-mails and any password:
--     admin@sapati.test      (name: Sapati Admin)
--     renter1@sapati.test    (name: Prasanta Shrestha)
--     renter2@sapati.test    (name: Aayush Karki)
--     renter3@sapati.test    (name: Sita Maharjan)
--     borrower@sapati.test   (name: Bikash Thapa)   -- optional, a plain Borrower
-- Then paste this script into the SQL editor (it runs as the owner, so it may set
-- the protected columns role and kyc_status). Safe to run again: items are only added once.
--
-- The photo files do not exist: the rows only make the database checks pass, so the app
-- shows a grey placeholder. Add real photos by editing a listing in the app.
DO $$
DECLARE
    v_admin UUID; v_r1 UUID; v_r2 UUID; v_r3 UUID; v_b UUID;
    rec RECORD; v_owner UUID; v_id UUID; v_path TEXT;
BEGIN
    SELECT id INTO v_admin FROM auth.users WHERE email = 'admin@sapati.test';
    SELECT id INTO v_r1 FROM auth.users WHERE email = 'renter1@sapati.test';
    SELECT id INTO v_r2 FROM auth.users WHERE email = 'renter2@sapati.test';
    SELECT id INTO v_r3 FROM auth.users WHERE email = 'renter3@sapati.test';
    SELECT id INTO v_b FROM auth.users WHERE email = 'borrower@sapati.test';
    IF v_admin IS NULL OR v_r1 IS NULL OR v_r2 IS NULL OR v_r3 IS NULL THEN
        RAISE EXCEPTION 'Create admin@sapati.test and renter1, renter2, renter3 @sapati.test first';
    END IF;
    UPDATE public.profiles SET role = 'admin', kyc_status = 'verified' WHERE id = v_admin;
    UPDATE public.profiles SET kyc_status = 'verified' WHERE id IN (v_r1, v_r2, v_r3);
    IF v_b IS NOT NULL THEN UPDATE public.profiles SET kyc_status = 'verified' WHERE id = v_b; END IF;

    FOR rec IN SELECT * FROM (VALUES
        (1, 'Cameras', 'Sony Alpha A7 III Camera', 'Full-frame mirrorless camera with a 28-70mm lens, two batteries and a 64 GB card.', 'Like new', 160000, 3500, 'Jawalakhel Chowk, Lalitpur'),
        (2, 'Cameras', 'Canon EOS 90D with 18-135mm lens', 'DSLR kit with bag, charger and one battery.', 'Good', 120000, 2500, 'Baneshwor, Kathmandu'),
        (1, 'Projectors', 'Epson Full HD Projector', 'Bright 3,600 lumen projector. HDMI cable and screen stand included.', 'Good', 70000, 1800, 'Koteshwor, Kathmandu'),
        (2, 'Gaming consoles', 'PlayStation 5 Console', 'Disc edition with two controllers and three games.', 'Like new', 90000, 2000, 'Bhaktapur Durbar Square, Bhaktapur'),
        (3, 'Gaming consoles', 'Nintendo Switch OLED', 'With dock, two Joy-Con controllers and a carry case.', 'Good', 45000, 1200, 'Patan, Lalitpur'),
        (2, 'Camping gear', '4-Person Camping Tent', 'Waterproof dome tent with rain fly and groundsheet.', 'Good', 18000, 600, 'Thamel, Kathmandu'),
        (3, 'Camping gear', 'Hiking Backpack 65L', 'Comfortable trekking backpack with rain cover.', 'Fair', 12000, 400, 'Boudha, Kathmandu'),
        (1, 'Tools', 'Bosch Cordless Drill Set', 'Drill driver with two batteries, charger and bit set.', 'Good', 15000, 500, 'Kupondole, Lalitpur'),
        (2, 'Musical instruments', 'Yamaha F310 Acoustic Guitar', 'Steel-string acoustic guitar with a padded bag and strap.', 'Good', 25000, 700, 'Suryabinayak, Bhaktapur'),
        (3, 'Musical instruments', 'Casio Digital Piano 88 keys', 'Weighted keys, stand and sustain pedal included.', 'Like new', 60000, 1500, 'Lazimpat, Kathmandu'),
        (1, 'Cameras', 'DJI Mini 3 Drone', 'Under 250 g drone with three batteries and a carry bag.', 'Like new', 110000, 3000, 'Pulchowk, Lalitpur'),
        (2, 'Other', 'JBL PartyBox Speaker', 'Loud portable party speaker with lights and a microphone input.', 'Good', 50000, 1400, 'Maharajgunj, Kathmandu')
    ) AS t(owner_no, category, title, description, condition, declared, daily, area)
    LOOP
        v_owner := CASE rec.owner_no WHEN 1 THEN v_r1 WHEN 2 THEN v_r2 ELSE v_r3 END;
        CONTINUE WHEN EXISTS (SELECT 1 FROM public.items WHERE lender_id = v_owner AND title = rec.title);
        v_id := gen_random_uuid();
        v_path := v_owner::TEXT || '/demo-' || v_id::TEXT || '.jpg';
        INSERT INTO storage.objects(bucket_id, name) VALUES ('item-photos', v_path);
        INSERT INTO public.items(id, lender_id, title, description, daily_rate, declared_value, pickup_area,
            status, category, condition, photo_paths)
        VALUES (v_id, v_owner, rec.title, rec.description, rec.daily, rec.declared, rec.area,
            'active', rec.category, rec.condition, ARRAY[v_path]);
        INSERT INTO public.item_pickup_details(item_id, exact_address)
        VALUES (v_id, 'Demo address near ' || rec.area);
    END LOOP;
END $$;
