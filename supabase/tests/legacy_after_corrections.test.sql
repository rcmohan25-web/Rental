BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET search_path=public,extensions;
SELECT plan(10);
-- Works both with the custom pre-migration runner and standalone pg_prove/CI.
SELECT set_config('rental_test.legacy_upgrade', EXISTS(SELECT 1 FROM public.bookings
 WHERE id='f2400000-0000-0000-0000-000000000012')::TEXT,TRUE);
DO $$ BEGIN
 IF current_setting('rental_test.legacy_upgrade')='false' THEN
  INSERT INTO auth.users(id,email) VALUES
   ('f2400000-0000-0000-0000-000000000001','legacy-admin@test.invalid'),
   ('f2400000-0000-0000-0000-000000000002','legacy-lender@test.invalid'),
   ('f2400000-0000-0000-0000-000000000003','legacy-borrower@test.invalid');
  UPDATE public.profiles SET kyc_status='verified' WHERE id IN
   ('f2400000-0000-0000-0000-000000000002','f2400000-0000-0000-0000-000000000003');
  INSERT INTO public.items(id,lender_id,title,daily_rate,declared_value,pickup_area)
   VALUES('f2400000-0000-0000-0000-000000000010','f2400000-0000-0000-0000-000000000002','Legacy item',3500,160000,'Lalitpur');
  INSERT INTO public.bookings(id,item_id,lender_id,borrower_id,start_date,end_date,status,commission_rate,deposit_rate)
   VALUES('f2400000-0000-0000-0000-000000000011','f2400000-0000-0000-0000-000000000010',
    'f2400000-0000-0000-0000-000000000002','f2400000-0000-0000-0000-000000000003','2000-01-01','2000-01-03','renter_accepted',.1,.25);
  INSERT INTO public.terms_documents(title,version,content,status,published_at)
   VALUES('renter terms','7','Historic text','published',NOW());
  INSERT INTO public.terms_documents(title,version,content,status,published_at,audience)
   SELECT 'Legacy fixture ' || a,'legacy-fixture','Fixture terms','published',NOW(),a
   FROM unnest(ARRAY['general','borrower','renter']) a;
  INSERT INTO public.bookings(id,item_id,lender_id,borrower_id,start_date,end_date,status,commission_rate,deposit_rate,
   agreed_daily_rate,declared_value_snapshot,rental_fee,deposit_amount,commission_amount,lender_earning,snapshot_recorded_at,terms_version_ids)
   VALUES('f2400000-0000-0000-0000-000000000013','f2400000-0000-0000-0000-000000000010',
    'f2400000-0000-0000-0000-000000000002','f2400000-0000-0000-0000-000000000003','2000-03-01','2000-03-03','completed',
    .1,.25,3500,160000,10500,40000,1050,9450,NOW(),
    (SELECT array_agg(id) FROM public.terms_documents WHERE version='legacy-fixture'));
  INSERT INTO public.booking_terms(booking_id,audience,terms_document_id)
   SELECT 'f2400000-0000-0000-0000-000000000013',audience,id FROM public.terms_documents WHERE version='legacy-fixture';
  INSERT INTO public.app_settings(key,value) VALUES('deposit_rate','0.3')
   ON CONFLICT(key) DO UPDATE SET value=EXCLUDED.value;
 END IF;
END $$;
-- This is fixture provisioning, before switching to the real client role.
UPDATE public.profiles SET role='admin',status='active' WHERE id='f2400000-0000-0000-0000-000000000001';
SELECT CASE WHEN current_setting('rental_test.legacy_upgrade')='true' THEN
 is((SELECT deposit_amount FROM public.bookings WHERE id='f2400000-0000-0000-0000-000000000012'),999999::NUMERIC,'invalid history is preserved, not fabricated')
ELSE throws_ok($test$
 INSERT INTO public.bookings(item_id,lender_id,borrower_id,start_date,end_date,commission_rate,deposit_rate,
  agreed_daily_rate,declared_value_snapshot,rental_fee,deposit_amount,commission_amount,lender_earning,snapshot_recorded_at)
 VALUES('f2400000-0000-0000-0000-000000000010','f2400000-0000-0000-0000-000000000002',
  'f2400000-0000-0000-0000-000000000003','2000-02-01','2000-02-03',.1,.25,3500,160000,10500,999999,1050,9450,NOW())
 $test$,'23514','new row for relation "bookings" violates check constraint "booking_financial_integrity"',
 'fresh chain rejects the intentionally invalid legacy deposit') END;
SELECT ok((SELECT snapshot_recorded_at IS NULL FROM public.bookings WHERE id='f2400000-0000-0000-0000-000000000011'),'legacy missing snapshot remains missing');
SELECT is((SELECT deposit_amount FROM public.bookings WHERE id='f2400000-0000-0000-0000-000000000013'),40000::NUMERIC,'historical 25 percent snapshot retained');
SELECT is((SELECT value FROM public.app_settings WHERE key='deposit_rate'),'0.3'::JSONB,
 CASE WHEN current_setting('rental_test.legacy_upgrade')='true' THEN 'existing admin configuration not overwritten'
 ELSE 'test-specific admin configuration remains readable' END);
SELECT set_config('request.jwt.claims','{"sub":"f2400000-0000-0000-0000-000000000001","role":"authenticated"}',TRUE);
SELECT set_config('request.jwt.claim.sub','f2400000-0000-0000-0000-000000000001',TRUE);
SET LOCAL ROLE authenticated;
SELECT is(public.admin_publish_terms('renter','New text')->>'version','8','legacy numeric title increments safely');
SELECT is((SELECT content FROM public.terms_documents WHERE title='renter terms' AND version='7'),'Historic text','legacy terms text unchanged');
SELECT throws_ok($$SELECT public.admin_approve_order('f2400000-0000-0000-0000-000000000011',TRUE)$$,'P0001','INVALID_SNAPSHOT','legacy incomplete approval blocked');
SELECT throws_ok(format('SELECT public.settle_booking(%L)',CASE WHEN current_setting('rental_test.legacy_upgrade')='true'
 THEN 'f2400000-0000-0000-0000-000000000012' ELSE 'f2400000-0000-0000-0000-000000000011' END),
 'P0001','INVALID_SNAPSHOT','invalid or missing historic snapshot cannot settle');
RESET ROLE;
SELECT throws_ok($$UPDATE public.bookings SET agreed_daily_rate=3500,declared_value_snapshot=160000,rental_fee=10500,
 deposit_amount=40000,commission_amount=1050,lender_earning=9450,snapshot_recorded_at=NOW()
 WHERE id='f2400000-0000-0000-0000-000000000011'$$,'P0001','LEGACY_RECONCILIATION_REQUIRED','silent historical backfill blocked');
SELECT ok(NOT(SELECT public FROM storage.buckets WHERE id='kyc'),'private bucket drift repaired');
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
