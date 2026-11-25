BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET search_path=public,extensions;
SELECT plan(10);
SELECT is((SELECT deposit_amount FROM public.bookings WHERE id='f2400000-0000-0000-0000-000000000012'),999999::NUMERIC,'invalid history is preserved, not fabricated');
SELECT ok((SELECT snapshot_recorded_at IS NULL FROM public.bookings WHERE id='f2400000-0000-0000-0000-000000000011'),'legacy missing snapshot remains missing');
SELECT is((SELECT deposit_amount FROM public.bookings WHERE id='f2400000-0000-0000-0000-000000000013'),40000::NUMERIC,'historical 25 percent snapshot retained');
SELECT is((SELECT value FROM public.app_settings WHERE key='deposit_rate'),'0.3'::JSONB,'existing admin configuration not overwritten');
SELECT set_config('request.jwt.claims','{"sub":"f2400000-0000-0000-0000-000000000001","role":"authenticated"}',TRUE);
SET LOCAL ROLE authenticated;
SELECT is(public.admin_publish_terms('renter','New text')->>'version','8','legacy numeric title increments safely');
SELECT is((SELECT content FROM public.terms_documents WHERE title='renter terms' AND version='7'),'Historic text','legacy terms text unchanged');
SELECT throws_ok($$SELECT public.admin_approve_order('f2400000-0000-0000-0000-000000000011',TRUE)$$,'P0001','INVALID_SNAPSHOT','legacy incomplete approval blocked');
SELECT throws_ok($$SELECT public.settle_booking('f2400000-0000-0000-0000-000000000012')$$,'P0001','INVALID_SNAPSHOT','invalid historic money cannot settle');
RESET ROLE;
SELECT throws_ok($$UPDATE public.bookings SET agreed_daily_rate=3500,declared_value_snapshot=160000,rental_fee=10500,
 deposit_amount=40000,commission_amount=1050,lender_earning=9450,snapshot_recorded_at=NOW()
 WHERE id='f2400000-0000-0000-0000-000000000011'$$,'P0001','LEGACY_RECONCILIATION_REQUIRED','silent historical backfill blocked');
SELECT ok(NOT(SELECT public FROM storage.buckets WHERE id='kyc'),'private bucket drift repaired');
SELECT * FROM finish();
ROLLBACK;
