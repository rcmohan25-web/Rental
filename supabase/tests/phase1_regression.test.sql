-- Build 0.4 (Phase 1): minimum deposit, public settings, public item cards,
-- soft delete. Test-only prices and rates are examples, never configuration.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET search_path = public, extensions;
SELECT no_plan();

-- Money: minimum deposit (api-contract section 1 and 3.4)
SELECT is(rental_private.calculate_money(1,100,2000,.1,.2,1000),
 '{"rental_fee":100,"deposit_amount":1000,"commission_amount":10,"lender_earning":90,"borrower_total":1100}'::JSONB,
 'minimum applies: 20 percent of 2000 is 400, deposit is 1000');
SELECT is(rental_private.calculate_money(1,100,2000,.1,.2,300),
 '{"rental_fee":100,"deposit_amount":400,"commission_amount":10,"lender_earning":90,"borrower_total":500}'::JSONB,
 'minimum not needed');
SELECT is(rental_private.calculate_money(3,3500,160000,.1,.2,1000),
 '{"rental_fee":10500,"deposit_amount":32000,"commission_amount":1050,"lender_earning":9450,"borrower_total":42500}'::JSONB,
 'worked example is unchanged by a small minimum');
SELECT is(rental_private.calculate_money(3,3500,160000,.1,.2),
 rental_private.calculate_money(3,3500,160000,.1,.2,0),'5-argument form means no minimum');
SELECT is(rental_private.calculate_money(1,5,5,.1,.2,0)->>'deposit_amount','1','approved boundary still gives 1');
SELECT throws_ok($$SELECT rental_private.calculate_money(1,100,2000,.1,.2,-1)$$,'P0001','INVALID_MONEY','negative minimum rejected');
SELECT throws_ok($$SELECT rental_private.calculate_money(1,100,2000,.1,.2,10.5)$$,'P0001','INVALID_MONEY','fractional minimum rejected');
SELECT throws_ok($$SELECT rental_private.calculate_money(1,100,2000,.1,.2,'NaN')$$,'P0001','INVALID_MONEY','NaN minimum rejected');
SELECT throws_ok($$SELECT rental_private.calculate_money(1,100,2000,.1,.2,NULL)$$,'P0001','INVALID_MONEY','missing minimum rejected');

INSERT INTO auth.users(id,email,raw_user_meta_data) VALUES
 ('a3400000-0000-0000-0000-000000000001','p1-admin@test.invalid','{"display_name":"Admin"}'),
 ('a3400000-0000-0000-0000-000000000002','p1-lender@test.invalid','{"display_name":"Lena Lender"}'),
 ('a3400000-0000-0000-0000-000000000003','p1-borrower@test.invalid','{"display_name":"Bikash Borrower"}'),
 ('a3400000-0000-0000-0000-000000000004','p1-other@test.invalid','{"display_name":"Other Person"}');
UPDATE public.profiles SET role='admin' WHERE id='a3400000-0000-0000-0000-000000000001';
UPDATE public.profiles SET kyc_status='verified' WHERE id IN
 ('a3400000-0000-0000-0000-000000000002','a3400000-0000-0000-0000-000000000003');

-- Settings: whitelist and cross-check
SELECT set_config('request.jwt.claims','{"sub":"a3400000-0000-0000-0000-000000000001","role":"authenticated"}',TRUE);
SET LOCAL ROLE authenticated;
SELECT lives_ok($$SELECT public.admin_update_setting('min_declared_value','2000')$$,'admin sets minimum declared value');
SELECT lives_ok($$SELECT public.admin_update_setting('min_deposit_amount','1000')$$,'admin sets minimum deposit');
SELECT throws_ok($$SELECT public.admin_update_setting('min_deposit_amount','3000')$$,'P0001','INVALID_VALUE','minimum deposit above minimum declared value rejected');
SELECT throws_ok($$SELECT public.admin_update_setting('min_declared_value','500')$$,'P0001','INVALID_VALUE','minimum declared value below minimum deposit rejected');
SELECT throws_ok($$SELECT public.admin_update_setting('min_deposit_amount','10.5')$$,'P0001','INVALID_VALUE','fractional minimum deposit rejected');
SELECT throws_ok($$SELECT public.admin_update_setting('min_deposit_amount','"1000"')$$,'P0001','INVALID_VALUE','string minimum deposit rejected');
SELECT lives_ok($$SELECT public.admin_update_setting('auto_approve_orders','true')$$,'admin sets a non-public setting');
SELECT is(public.get_public_settings()->'min_deposit_amount','1000'::JSONB,'public settings include the minimum deposit');
SELECT ok(NOT (public.get_public_settings() ? 'auto_approve_orders'),'public settings leave out internal keys');
RESET ROLE;
SELECT set_config('request.jwt.claims','{"sub":"a3400000-0000-0000-0000-000000000003","role":"authenticated"}',TRUE);
SET LOCAL ROLE authenticated;
SELECT throws_ok($$SELECT public.admin_update_setting('min_deposit_amount','0')$$,'P0001','NOT_ADMIN','non-admin cannot change settings');
SELECT is(public.get_public_settings()->'min_declared_value','2000'::JSONB,'any signed-in user can read public settings');
RESET ROLE;
SELECT ok(NOT has_function_privilege('anon','public.get_public_settings()','EXECUTE'),'anon cannot read settings');
SELECT ok(NOT has_function_privilege('anon','public.delete_item(uuid)','EXECUTE'),'anon cannot delete items');

-- Public item cards
INSERT INTO storage.objects(bucket_id,name) VALUES
 ('item-photos','a3400000-0000-0000-0000-000000000002/one.jpg'),
 ('item-photos','a3400000-0000-0000-0000-000000000002/two.jpg');
INSERT INTO public.items(id,lender_id,title,daily_rate,declared_value,pickup_area,status,category,condition,photo_paths) VALUES
 ('b3400000-0000-0000-0000-000000000001','a3400000-0000-0000-0000-000000000002','Card one',100,2000,'Jawalakhel, Lalitpur','active','camera','good',ARRAY['a3400000-0000-0000-0000-000000000002/one.jpg']),
 ('b3400000-0000-0000-0000-000000000002','a3400000-0000-0000-0000-000000000002','Card two',200,2000,'Thamel, Kathmandu','active','camera','good',ARRAY['a3400000-0000-0000-0000-000000000002/two.jpg']),
 ('b3400000-0000-0000-0000-000000000003','a3400000-0000-0000-0000-000000000002','Paused card',300,2000,'Patan, Lalitpur','paused','camera','good','{}');
INSERT INTO public.item_pickup_details(item_id,exact_address) VALUES
 ('b3400000-0000-0000-0000-000000000001','Secret house number 7');
SET LOCAL ROLE anon;
SELECT is((SELECT count(*)::INTEGER FROM public.public_items),2,'anon sees the two active cards only');
SELECT is((SELECT lender_first_name FROM public.public_items WHERE title='Card one'),'Lena','card shows the Renter first name only');
SELECT throws_ok($$SELECT * FROM public.profiles$$,'42501',NULL,'anon still cannot read profiles');
SELECT throws_ok($$SELECT * FROM public.item_pickup_details$$,'42501',NULL,'anon cannot read exact addresses');
RESET ROLE;
SELECT ok(NOT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='public_items'
 AND column_name IN ('exact_address','instructions','phone','display_name')),'card view has no address, phone or full name');

-- Soft delete
SELECT set_config('request.jwt.claims','{"sub":"a3400000-0000-0000-0000-000000000003","role":"authenticated"}',TRUE);
SET LOCAL ROLE authenticated;
SELECT throws_ok($$SELECT public.delete_item('b3400000-0000-0000-0000-000000000001')$$,'P0001','NOT_ALLOWED','only the owner can delete');
SELECT throws_ok($$DELETE FROM public.items WHERE id='b3400000-0000-0000-0000-000000000001'$$,'42501',NULL,'direct DELETE is not granted');
RESET ROLE;
INSERT INTO public.bookings(id,item_id,lender_id,borrower_id,start_date,end_date,status,commission_rate,deposit_rate) VALUES
 ('c3400000-0000-0000-0000-000000000001','b3400000-0000-0000-0000-000000000001','a3400000-0000-0000-0000-000000000002','a3400000-0000-0000-0000-000000000003',CURRENT_DATE+1,CURRENT_DATE+2,'renter_accepted',.1,.2),
 ('c3400000-0000-0000-0000-000000000002','b3400000-0000-0000-0000-000000000002','a3400000-0000-0000-0000-000000000002','a3400000-0000-0000-0000-000000000003',CURRENT_DATE+1,CURRENT_DATE+2,'requested',.1,.2);
SELECT set_config('request.jwt.claims','{"sub":"a3400000-0000-0000-0000-000000000002","role":"authenticated"}',TRUE);
SET LOCAL ROLE authenticated;
SELECT throws_ok($$SELECT public.delete_item('b3400000-0000-0000-0000-000000000001')$$,'P0001','ACTIVE_BOOKINGS_EXIST','accepted booking blocks deletion');
SELECT lives_ok($$SELECT public.delete_item('b3400000-0000-0000-0000-000000000002')$$,'item with only a pending request can be deleted');
SELECT throws_ok($$SELECT public.delete_item('b3400000-0000-0000-0000-000000000002')$$,'P0001','NOT_ALLOWED','second delete refused');
SELECT is((SELECT count(*)::INTEGER FROM public.items WHERE id='b3400000-0000-0000-0000-000000000002'),0,'owner no longer sees the deleted item');
RESET ROLE;
SELECT is((SELECT status || '/' || decline_reason FROM public.bookings WHERE id='c3400000-0000-0000-0000-000000000002'),'declined/item_deleted','pending request auto-declined');
SELECT ok((SELECT deleted_at IS NOT NULL AND status='paused' FROM public.items WHERE id='b3400000-0000-0000-0000-000000000002'),'row kept as a soft delete');
SET LOCAL ROLE anon;
SELECT is((SELECT count(*)::INTEGER FROM public.public_items),1,'deleted card leaves the public list');
RESET ROLE;

-- Booking snapshot carries the minimum
INSERT INTO public.items(id,lender_id,title,daily_rate,declared_value,pickup_area,status) VALUES
 ('b3400000-0000-0000-0000-000000000009','a3400000-0000-0000-0000-000000000002','Low value',100,2000,'Thamel, Kathmandu','draft');
SELECT is((SELECT min_deposit_amount FROM public.bookings WHERE id='c3400000-0000-0000-0000-000000000001'),0::NUMERIC,'older bookings default to no minimum');
SELECT throws_ok($$INSERT INTO public.bookings(item_id,lender_id,borrower_id,start_date,end_date,commission_rate,deposit_rate,min_deposit_amount,
 agreed_daily_rate,declared_value_snapshot,rental_fee,deposit_amount,commission_amount,lender_earning,snapshot_recorded_at)
 VALUES('b3400000-0000-0000-0000-000000000009','a3400000-0000-0000-0000-000000000002','a3400000-0000-0000-0000-000000000003',
 CURRENT_DATE+10,CURRENT_DATE+10,.1,.2,1000,100,2000,100,400,10,90,NOW())$$,'23514',NULL,'snapshot deposit below the stored minimum rejected');
INSERT INTO public.bookings(id,item_id,lender_id,borrower_id,start_date,end_date,commission_rate,deposit_rate,min_deposit_amount,
 agreed_daily_rate,declared_value_snapshot,rental_fee,deposit_amount,commission_amount,lender_earning,snapshot_recorded_at)
 VALUES('c3400000-0000-0000-0000-000000000009','b3400000-0000-0000-0000-000000000009','a3400000-0000-0000-0000-000000000002','a3400000-0000-0000-0000-000000000003',
 CURRENT_DATE+10,CURRENT_DATE+10,.1,.2,1000,100,2000,100,1000,10,90,NOW());
SELECT is((SELECT deposit_amount FROM public.bookings WHERE id='c3400000-0000-0000-0000-000000000009'),1000::NUMERIC,'snapshot with the minimum applied is accepted');
SELECT throws_ok($$UPDATE public.bookings SET min_deposit_amount=0 WHERE id='c3400000-0000-0000-0000-000000000009'$$,'P0001','SNAPSHOT_IMMUTABLE','the stored minimum cannot be changed');

SELECT * FROM finish();
ROLLBACK;
