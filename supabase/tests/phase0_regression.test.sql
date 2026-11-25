-- Test-only prices/rates are examples, never operational configuration.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET search_path = public, extensions;
SELECT no_plan();

SELECT ok(NOT has_table_privilege('anon', 'public.bookings', 'TRUNCATE'), 'anon cannot truncate bookings');
SELECT ok(NOT has_table_privilege('authenticated', 'public.profiles', 'TRIGGER'), 'client cannot create profile triggers');
SELECT ok(NOT has_table_privilege('authenticated', 'public.bookings', 'UPDATE'), 'client has no booking update grant');
SELECT ok(NOT has_column_privilege('authenticated', 'public.profiles', 'role', 'UPDATE'), 'role protected by column grants');
SELECT ok(NOT has_column_privilege('authenticated', 'public.profiles', 'kyc_status', 'UPDATE'), 'KYC protected by column grants');
SELECT ok(NOT has_function_privilege('anon', 'public.admin_update_setting(text,jsonb)', 'EXECUTE'), 'anon cannot execute settings RPC');
SELECT ok(NOT has_function_privilege('authenticated', 'public.check_evidence_paths(uuid,text[])', 'EXECUTE'), 'internal helper not exposed');
SELECT ok(NOT has_schema_privilege('authenticated', 'rental_private', 'USAGE'), 'job schema not exposed');
SELECT has_fk('public', 'bookings', 'booking foreign keys retained');
SELECT ok(EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.bookings'::regclass AND conname = 'booking_item_owner_fk'), 'composite owner FK retained');
SELECT ok(EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.bookings'::regclass AND conname = 'prevent_double_booking'), 'overlap constraint retained');
SELECT is((SELECT count(*)::INTEGER FROM pg_trigger WHERE tgname IN ('profiles_set_updated_at','items_set_updated_at','bookings_set_updated_at','app_settings_set_updated_at')), 4, 'four timestamp triggers installed');

INSERT INTO auth.users(id, email, raw_user_meta_data) VALUES
('a2400000-0000-0000-0000-000000000001','audit-admin@test.invalid','{"display_name":"Admin"}'),
('a2400000-0000-0000-0000-000000000002','audit-lender@test.invalid','{"display_name":"Lender","role":"admin","kyc_status":"verified"}'),
('a2400000-0000-0000-0000-000000000003','audit-borrower@test.invalid','{"display_name":"Borrower"}'),
('a2400000-0000-0000-0000-000000000004','audit-stranger@test.invalid','{"display_name":"Stranger"}');
SELECT is((SELECT role FROM public.profiles WHERE id='a2400000-0000-0000-0000-000000000002'), 'user', 'signup ignores metadata role');
SELECT is((SELECT kyc_status FROM public.profiles WHERE id='a2400000-0000-0000-0000-000000000002'), 'none', 'signup ignores metadata verification');
UPDATE public.profiles SET role='admin' WHERE id='a2400000-0000-0000-0000-000000000001';
INSERT INTO public.items(id,lender_id,title,daily_rate,declared_value,pickup_area) VALUES
('b2400000-0000-0000-0000-000000000001','a2400000-0000-0000-0000-000000000002','Test camera',3500,160000,'Lalitpur');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims','{"sub":"a2400000-0000-0000-0000-000000000002","role":"authenticated"}',TRUE);
SELECT is((SELECT count(*)::INTEGER FROM public.profiles),1,'ordinary user sees own profile only');
SELECT throws_ok($$UPDATE public.profiles SET role='admin' WHERE id=auth.uid()$$,'42501',NULL,'cannot self-promote');
SELECT throws_ok($$UPDATE public.items SET status='active' WHERE id='b2400000-0000-0000-0000-000000000001'$$,'P0001','KYC_REQUIRED','publishing without KYC rejected');
SELECT throws_ok($$SELECT public.admin_update_setting('commission_rate','0.1')$$,'P0001','NOT_ADMIN','non-admin settings write rejected');
SELECT lives_ok($$INSERT INTO public.profile_private(user_id,phone,payout_details) VALUES(auth.uid(),'9800000000','{"bank":"fake"}')$$,'owner can save private profile');
SELECT throws_ok($$INSERT INTO public.profile_private(user_id,phone) VALUES('a2400000-0000-0000-0000-000000000003','bad')$$,'42501',NULL,'cannot write another private profile');
RESET ROLE;

SELECT set_config('request.jwt.claims','{"sub":"a2400000-0000-0000-0000-000000000001","role":"authenticated"}',TRUE);
SET LOCAL ROLE authenticated;
SELECT lives_ok($$SELECT public.admin_update_setting('commission_rate','0.10')$$,'admin can set test commission');
SELECT lives_ok($$SELECT public.admin_update_setting('deposit_rate','0.20')$$,'admin can set approved deposit');
SELECT lives_ok($$SELECT public.admin_update_setting('min_declared_value','2000')$$,'admin can set test minimum');
SELECT lives_ok($$SELECT public.admin_update_setting('auto_approve_orders','false')$$,'admin can set test auto approval');
SELECT throws_ok($$SELECT public.admin_update_setting('unknown_key','1')$$,'P0001','INVALID_KEY','unknown settings rejected');
SELECT throws_ok($$SELECT public.admin_update_setting('deposit_rate','1.1')$$,'P0001','INVALID_VALUE','out of range rate rejected');
SELECT throws_ok($$SELECT public.admin_update_setting('auto_approve_orders','"true"')$$,'P0001','INVALID_VALUE','string boolean rejected');
SELECT throws_ok($$SELECT public.admin_update_setting('commission_rate','0.12345')$$,'P0001','INVALID_VALUE','rate cannot silently lose snapshot precision');
SELECT lives_ok($$SELECT public.admin_publish_terms('renter','Test renter terms v1')$$,'publish renter terms');
SELECT lives_ok($$SELECT public.admin_publish_terms('borrower','Test borrower terms v1')$$,'publish borrower terms');
SELECT lives_ok($$SELECT public.admin_publish_terms('general','Test general terms v1')$$,'publish general terms');
SELECT ok((SELECT count(*) FROM public.audit_log WHERE actor_id=auth.uid()) >= 7,'admin changes audited');
RESET ROLE;

UPDATE public.profiles SET kyc_status='pending' WHERE id='a2400000-0000-0000-0000-000000000002';
INSERT INTO public.kyc_submissions(user_id,id_path,face_path) VALUES
('a2400000-0000-0000-0000-000000000002','a2400000-0000-0000-0000-000000000002/id.jpg','a2400000-0000-0000-0000-000000000002/face.jpg');
INSERT INTO storage.objects(bucket_id,name) VALUES
('kyc','a2400000-0000-0000-0000-000000000002/id.jpg'),('kyc','a2400000-0000-0000-0000-000000000002/face.jpg');
SET LOCAL ROLE authenticated;
SELECT throws_ok($$SELECT public.admin_review_kyc('a2400000-0000-0000-0000-000000000002','rejected','')$$,'P0001','REASON_REQUIRED','KYC rejection requires reason');
SELECT lives_ok($$SELECT public.admin_review_kyc('a2400000-0000-0000-0000-000000000002','verified')$$,'admin verifies pending KYC');
RESET ROLE;
UPDATE public.profiles SET kyc_status='verified' WHERE id='a2400000-0000-0000-0000-000000000003';
SELECT set_config('request.jwt.claims','{"sub":"a2400000-0000-0000-0000-000000000002","role":"authenticated"}',TRUE);
SET LOCAL ROLE authenticated;
SELECT throws_ok($$UPDATE public.items SET status='active' WHERE id='b2400000-0000-0000-0000-000000000001'$$,'P0001','INVALID_VALUE','active listing requires metadata/photos');
INSERT INTO storage.objects(bucket_id,name) VALUES('item-photos',auth.uid()::TEXT || '/camera.jpg');
SELECT lives_ok($$UPDATE public.items SET status='active',category='camera',condition='good',photo_paths=ARRAY[auth.uid()::TEXT || '/camera.jpg'] WHERE id='b2400000-0000-0000-0000-000000000001'$$,'eligible owner publishes complete listing');
SELECT lives_ok($$INSERT INTO public.item_pickup_details(item_id,exact_address) VALUES('b2400000-0000-0000-0000-000000000001','Private test address')$$,'owner saves pickup address');
RESET ROLE;

-- Explicit fixture for the older workflow regression; creation has its own suite.
INSERT INTO public.bookings(id,item_id,lender_id,borrower_id,start_date,end_date,
 commission_rate,deposit_rate,agreed_daily_rate,declared_value_snapshot,rental_fee,
 deposit_amount,commission_amount,lender_earning,snapshot_recorded_at,terms_version_ids)
SELECT 'c2400000-0000-0000-0000-000000000001','b2400000-0000-0000-0000-000000000001',
 'a2400000-0000-0000-0000-000000000002','a2400000-0000-0000-0000-000000000003',
 (NOW() AT TIME ZONE 'Asia/Kathmandu')::DATE,(NOW() AT TIME ZONE 'Asia/Kathmandu')::DATE+2,
 .10,.20,3500,160000,10500,32000,1050,9450,NOW(),array_agg(id)
 FROM public.terms_documents WHERE is_active;
INSERT INTO public.booking_terms(booking_id,audience,terms_document_id)
SELECT 'c2400000-0000-0000-0000-000000000001',audience,id FROM public.terms_documents WHERE is_active;
SELECT is((SELECT rental_days FROM public.bookings WHERE id='c2400000-0000-0000-0000-000000000001'),3,'inclusive duration');
SELECT throws_ok($$UPDATE public.bookings SET rental_fee=1 WHERE id='c2400000-0000-0000-0000-000000000001'$$,'P0001','SNAPSHOT_IMMUTABLE','snapshot cannot change');
SELECT throws_ok($$INSERT INTO public.bookings(item_id,lender_id,borrower_id,start_date,end_date,commission_rate,deposit_rate) VALUES('b2400000-0000-0000-0000-000000000001','a2400000-0000-0000-0000-000000000004','a2400000-0000-0000-0000-000000000003',CURRENT_DATE,CURRENT_DATE,0,0)$$,'23503',NULL,'wrong item owner rejected');
SELECT throws_ok($$INSERT INTO public.bookings(item_id,lender_id,borrower_id,start_date,end_date,commission_rate,deposit_rate) VALUES('b2400000-0000-0000-0000-000000000001','a2400000-0000-0000-0000-000000000002','a2400000-0000-0000-0000-000000000002',CURRENT_DATE,CURRENT_DATE,0,0)$$,'23514',NULL,'self booking rejected');
SET LOCAL ROLE authenticated;
SELECT throws_ok($$SELECT public.renter_decide_booking('c2400000-0000-0000-0000-000000000001',TRUE,FALSE)$$,'P0001','TERMS_NOT_ACCEPTED','accept requires checkbox');
SELECT lives_ok($$SELECT public.renter_decide_booking('c2400000-0000-0000-0000-000000000001',TRUE,TRUE,(SELECT terms_document_id FROM public.booking_terms WHERE booking_id='c2400000-0000-0000-0000-000000000001' AND audience='renter'),NULL,'test-1')$$,'lender accepts saved terms');
SELECT throws_ok($$UPDATE public.bookings SET status='completed' WHERE id='c2400000-0000-0000-0000-000000000001'$$,'42501',NULL,'client cannot skip states');
RESET ROLE;
SELECT throws_ok($$INSERT INTO public.bookings(item_id,lender_id,borrower_id,start_date,end_date,status,commission_rate,deposit_rate) SELECT item_id,lender_id,borrower_id,start_date,end_date,'renter_accepted',0,0 FROM public.bookings WHERE id='c2400000-0000-0000-0000-000000000001'$$,'23P01',NULL,'overlapping accepted booking rejected');
SELECT lives_ok($$INSERT INTO public.bookings(item_id,lender_id,borrower_id,start_date,end_date,status,commission_rate,deposit_rate) SELECT item_id,lender_id,borrower_id,end_date+1,end_date+2,'requested',0,0 FROM public.bookings WHERE id='c2400000-0000-0000-0000-000000000001'$$,'nonblocking request accepted');

SELECT set_config('request.jwt.claims','{"sub":"a2400000-0000-0000-0000-000000000004","role":"authenticated"}',TRUE);
SET LOCAL ROLE authenticated;
SELECT is((SELECT count(*)::INTEGER FROM public.bookings),0,'stranger cannot read bookings');
SELECT is((SELECT count(*)::INTEGER FROM public.profile_private),0,'stranger cannot read contacts/payouts');
SELECT is((SELECT count(*)::INTEGER FROM public.item_pickup_details),0,'stranger cannot read exact address');
SELECT is((SELECT count(*)::INTEGER FROM public.terms_acceptances),0,'stranger cannot read acceptances');
SELECT throws_ok($$SELECT public.renter_decide_booking('c2400000-0000-0000-0000-000000000001',FALSE,FALSE)$$,'P0001','NOT_ALLOWED','stranger cannot decide booking');
RESET ROLE;

SELECT set_config('request.jwt.claims','{"sub":"a2400000-0000-0000-0000-000000000001","role":"authenticated"}',TRUE);
SET LOCAL ROLE authenticated;
SELECT throws_ok($$SELECT public.admin_approve_order('c2400000-0000-0000-0000-000000000001',FALSE,'test')$$,'P0001','ORDER_REJECTION_NOT_APPROVED','undefined rejection is blocked');
SELECT lives_ok($$SELECT public.admin_approve_order('c2400000-0000-0000-0000-000000000001',TRUE)$$,'verified parties approved');
SELECT lives_ok($$SELECT public.admin_publish_terms('renter','Replacement renter terms')$$,'new terms preserve history');
SELECT lives_ok($$SELECT public.admin_update_setting('commission_rate','0.20')$$,'settings can change for future bookings');
RESET ROLE;
SELECT is((SELECT commission_rate FROM public.bookings WHERE id='c2400000-0000-0000-0000-000000000001'),.10::NUMERIC,'old rate unchanged');
SELECT throws_ok($$UPDATE public.terms_documents SET content='tampered' WHERE audience='renter' AND status='archived'$$,'P0001','TERMS_IMMUTABLE','historic terms immutable');

SELECT set_config('request.jwt.claims','{"sub":"a2400000-0000-0000-0000-000000000003","role":"authenticated"}',TRUE);
SET LOCAL ROLE authenticated;
SELECT is((SELECT count(*)::INTEGER FROM public.terms_documents WHERE audience='renter' AND status='archived'),1,'participant can reread archived terms');
SELECT lives_ok($$INSERT INTO storage.objects(bucket_id,name) VALUES('payment-proof',auth.uid()::TEXT || '/c2400000-0000-0000-0000-000000000001/proof.jpg')$$,'borrower uploads proof to booking path');
SELECT throws_ok($$SELECT public.submit_payment_proof('c2400000-0000-0000-0000-000000000001',TRUE,(SELECT terms_document_id FROM public.booking_terms WHERE booking_id='c2400000-0000-0000-0000-000000000001' AND audience='borrower'),'missing','ref','test')$$,'P0001','PROOF_MISSING','nonexistent proof rejected');
SELECT lives_ok($$SELECT public.submit_payment_proof('c2400000-0000-0000-0000-000000000001',TRUE,(SELECT terms_document_id FROM public.booking_terms WHERE booking_id='c2400000-0000-0000-0000-000000000001' AND audience='borrower'),auth.uid()::TEXT || '/c2400000-0000-0000-0000-000000000001/proof.jpg','ref','test')$$,'proof and borrower acceptance recorded atomically');
SELECT is((SELECT count(*)::INTEGER FROM public.booking_payments),1,'borrower reads own proof metadata');
RESET ROLE;

-- Test-only setup bypasses unimplemented code-delivery/payment verification.
-- Required evidence is explicit; this is not an end-to-end handover test.
UPDATE public.booking_payments SET status='verified',amount_received=42500,reviewed_at=NOW(),
 reviewed_by='a2400000-0000-0000-0000-000000000001' WHERE booking_id='c2400000-0000-0000-0000-000000000001';
INSERT INTO storage.objects(bucket_id,name) SELECT 'handover',
 'a2400000-0000-0000-0000-000000000002/c2400000-0000-0000-0000-000000000001/' || f
 FROM unnest(ARRAY['pickup.jpg','face.jpg','id.jpg']) f;
INSERT INTO public.handover_records(booking_id,stage,recorded_by,item_photo_paths,checklist,borrower_face_path,borrower_id_photo_path)
VALUES('c2400000-0000-0000-0000-000000000001','pickup','a2400000-0000-0000-0000-000000000002',
 ARRAY['a2400000-0000-0000-0000-000000000002/c2400000-0000-0000-0000-000000000001/pickup.jpg'],
 '{"condition_checked":true}',
 'a2400000-0000-0000-0000-000000000002/c2400000-0000-0000-0000-000000000001/face.jpg',
 'a2400000-0000-0000-0000-000000000002/c2400000-0000-0000-0000-000000000001/id.jpg');
UPDATE public.bookings SET status='handed_over' WHERE id='c2400000-0000-0000-0000-000000000001';
SET LOCAL ROLE authenticated;
SELECT lives_ok($$SELECT public.confirm_receipt('c2400000-0000-0000-0000-000000000001',TRUE)$$,'borrower confirms receipt');
SELECT throws_ok($$SELECT public.confirm_receipt('c2400000-0000-0000-0000-000000000001',TRUE)$$,'P0001','INVALID_STATE','second receipt confirmation rejected');
RESET ROLE;
SELECT set_config('request.jwt.claims','{"sub":"a2400000-0000-0000-0000-000000000002","role":"authenticated"}',TRUE);
SET LOCAL ROLE authenticated;
SELECT is((SELECT count(*)::INTEGER FROM public.booking_payments),0,'lender cannot read payment proof metadata');
SELECT is((SELECT count(*)::INTEGER FROM storage.objects WHERE bucket_id='payment-proof'),0,'lender cannot read proof objects');
SELECT lives_ok($$INSERT INTO storage.objects(bucket_id,name) VALUES('handover',auth.uid()::TEXT || '/c2400000-0000-0000-0000-000000000001/return.jpg')$$,'lender uploads return evidence');
SELECT is((SELECT count(*)::INTEGER FROM storage.objects WHERE bucket_id='handover'),0,'uploader cannot read admin-only evidence');
SELECT lives_ok($$SELECT public.record_return('c2400000-0000-0000-0000-000000000001',ARRAY[auth.uid()::TEXT || '/c2400000-0000-0000-0000-000000000001/return.jpg'],TRUE)$$,'return records server timestamp');
RESET ROLE;
SELECT set_config('request.jwt.claims','{"sub":"a2400000-0000-0000-0000-000000000001","role":"authenticated"}',TRUE);
SET LOCAL ROLE authenticated;
SELECT lives_ok($$SELECT public.settle_booking('c2400000-0000-0000-0000-000000000001')$$,'smooth settlement succeeds');
SELECT lives_ok($$SELECT public.settle_booking('c2400000-0000-0000-0000-000000000001')$$,'settlement retry succeeds without duplicate entries');
SELECT is((SELECT count(*)::INTEGER FROM public.ledger_entries WHERE booking_id='c2400000-0000-0000-0000-000000000001'),2,'exactly two settlement entries');
SELECT is((SELECT amount FROM public.ledger_entries WHERE booking_id='c2400000-0000-0000-0000-000000000001' AND kind='lender_earning'),9450::NUMERIC,'earning matches immutable snapshot');
SELECT is((SELECT amount FROM public.ledger_entries WHERE booking_id='c2400000-0000-0000-0000-000000000001' AND kind='deposit_refund'),32000::NUMERIC,'full smooth deposit refund');
SELECT throws_ok($$SELECT public.admin_set_user_status('a2400000-0000-0000-0000-000000000002','deleted','test')$$,'P0001','DELETION_NOT_APPROVED','undeclared retention decision blocked');
SELECT lives_ok($$SELECT public.admin_set_user_status('a2400000-0000-0000-0000-000000000002','suspended','test')$$,'admin suspends ordinary account');
SELECT throws_ok($$SELECT public.admin_set_user_status('a2400000-0000-0000-0000-000000000001','suspended','test')$$,'P0001','CANNOT_TARGET_ADMIN','admin target protected');
RESET ROLE;
SELECT set_config('request.jwt.claims','{"sub":"a2400000-0000-0000-0000-000000000002","role":"authenticated"}',TRUE);
SET LOCAL ROLE authenticated;
SELECT throws_ok($$INSERT INTO storage.objects(bucket_id,name) VALUES('kyc',auth.uid()::TEXT || '/another.jpg')$$,'42501',NULL,'suspended upload blocked');
SELECT is((SELECT count(*)::INTEGER FROM public.notifications WHERE user_id<>auth.uid()),0,'notifications are recipient-only');
RESET ROLE;
SET LOCAL ROLE anon;
SELECT throws_ok($$SELECT * FROM public.profiles$$,'42501',NULL,'anon cannot read profiles');
SELECT lives_ok($$SELECT * FROM public.items$$,'anon can browse public listings');
SELECT lives_ok($$SELECT * FROM public.terms_documents WHERE status='published'$$,'anon can read published terms');
RESET ROLE;

SELECT ok(NOT EXISTS (SELECT 1 FROM storage.buckets WHERE id IN ('kyc','handover','payment-proof') AND public),'private buckets remain private');
SELECT is((SELECT count(*)::INTEGER FROM storage.buckets WHERE id IN ('item-photos','kyc','handover','payment-proof') AND file_size_limit=5242879),4,'all buckets have limits');
SELECT is((SELECT count(*)::INTEGER FROM public.terms_acceptances WHERE booking_id='c2400000-0000-0000-0000-000000000001'),2,'both required acceptances recorded');

-- Additional state and security cases use a separate booking, not the settled row.
INSERT INTO public.bookings(id,item_id,lender_id,borrower_id,start_date,end_date,status,
 commission_rate,deposit_rate,agreed_daily_rate,declared_value_snapshot,rental_fee,
 deposit_amount,commission_amount,lender_earning,snapshot_recorded_at,returned_at,terms_version_ids)
VALUES ('c2400000-0000-0000-0000-000000000009','b2400000-0000-0000-0000-000000000001',
 'a2400000-0000-0000-0000-000000000002','a2400000-0000-0000-0000-000000000003',
 CURRENT_DATE-10,CURRENT_DATE-8,'returned',.10,.20,3500,160000,10500,32000,1050,9450,NOW(),NOW(),
 (SELECT array_agg(id) FROM public.terms_documents WHERE is_active));
INSERT INTO public.booking_terms(booking_id,audience,terms_document_id)
 SELECT 'c2400000-0000-0000-0000-000000000009',audience,id FROM public.terms_documents WHERE is_active;
INSERT INTO public.terms_acceptances(booking_id,user_id,role,terms_document_id,accepted_version,app_version)
 SELECT 'c2400000-0000-0000-0000-000000000009',
 CASE audience WHEN 'renter' THEN 'a2400000-0000-0000-0000-000000000002'::UUID ELSE 'a2400000-0000-0000-0000-000000000003'::UUID END,
 audience,id,version,'test' FROM public.terms_documents WHERE is_active AND audience<>'general';
INSERT INTO storage.objects(bucket_id,name) SELECT 'handover',
 'a2400000-0000-0000-0000-000000000002/c2400000-0000-0000-0000-000000000009/' || f
 FROM unnest(ARRAY['pickup.jpg','face.jpg','id.jpg','late.jpg']) f;
INSERT INTO storage.objects(bucket_id,name) VALUES('payment-proof',
 'a2400000-0000-0000-0000-000000000003/c2400000-0000-0000-0000-000000000009/proof.jpg');
INSERT INTO public.booking_payments(booking_id,submitted_by,proof_path,reference,status,amount_received,reviewed_at,reviewed_by)
 VALUES('c2400000-0000-0000-0000-000000000009','a2400000-0000-0000-0000-000000000003',
 'a2400000-0000-0000-0000-000000000003/c2400000-0000-0000-0000-000000000009/proof.jpg','test','verified',42500,NOW(),
 'a2400000-0000-0000-0000-000000000001');
INSERT INTO public.handover_records(booking_id,stage,recorded_by,item_photo_paths,checklist,borrower_face_path,borrower_id_photo_path)
 VALUES('c2400000-0000-0000-0000-000000000009','pickup','a2400000-0000-0000-0000-000000000002',
 ARRAY['a2400000-0000-0000-0000-000000000002/c2400000-0000-0000-0000-000000000009/pickup.jpg'],'{"condition_checked":true}',
 'a2400000-0000-0000-0000-000000000002/c2400000-0000-0000-0000-000000000009/face.jpg',
 'a2400000-0000-0000-0000-000000000002/c2400000-0000-0000-0000-000000000009/id.jpg');
INSERT INTO public.handover_records(booking_id,stage,recorded_by,item_photo_paths,no_issues)
VALUES ('c2400000-0000-0000-0000-000000000009','return','a2400000-0000-0000-0000-000000000002',
 ARRAY['a2400000-0000-0000-0000-000000000002/c2400000-0000-0000-0000-000000000009/late.jpg'],TRUE);
SELECT set_config('request.jwt.claims','{"sub":"a2400000-0000-0000-0000-000000000001","role":"authenticated"}',TRUE);
SET LOCAL ROLE authenticated;
SELECT throws_ok($$SELECT public.settle_booking('c2400000-0000-0000-0000-000000000009')$$,'P0001','LATE_RULE_NOT_APPROVED','late rule not guessed');
SELECT lives_ok($$SELECT public.admin_set_user_status('a2400000-0000-0000-0000-000000000002','active','test restoration')$$,'admin reactivates user');
RESET ROLE;
SELECT set_config('request.jwt.claims','{"sub":"a2400000-0000-0000-0000-000000000002","role":"authenticated"}',TRUE);
SET LOCAL ROLE authenticated;
SELECT throws_ok($$SELECT public.report_damage('c2400000-0000-0000-0000-000000000009','Broken',ARRAY['missing'],500)$$,'P0001','EVIDENCE_MISSING','damage needs real linked evidence');
SELECT lives_ok($$INSERT INTO storage.objects(bucket_id,name) VALUES('handover',auth.uid()::TEXT || '/c2400000-0000-0000-0000-000000000009/damage.jpg')$$,'damage upload linked to returned booking');
SELECT lives_ok($$SELECT public.report_damage('c2400000-0000-0000-0000-000000000009','Broken',ARRAY[auth.uid()::TEXT || '/c2400000-0000-0000-0000-000000000009/damage.jpg'],500)$$,'lender records damage report');
SELECT is((SELECT status FROM public.bookings WHERE id='c2400000-0000-0000-0000-000000000009'),'returned','lender report does not take admin transition');
SELECT throws_ok($$INSERT INTO public.reviews(booking_id,reviewer_id,target_user_id,comment) VALUES('c2400000-0000-0000-0000-000000000009',auth.uid(),'a2400000-0000-0000-0000-000000000003','test')$$,'42501',NULL,'unapproved review write contract stays disabled');
SELECT lives_ok($$INSERT INTO public.reports(reporter_id,reported_user_id,reason) VALUES(auth.uid(),'a2400000-0000-0000-0000-000000000003','test report')$$,'active user can report');
RESET ROLE;
SELECT set_config('request.jwt.claims','{"sub":"a2400000-0000-0000-0000-000000000001","role":"authenticated"}',TRUE);
SET LOCAL ROLE authenticated;
SELECT throws_ok($$SELECT public.settle_booking('c2400000-0000-0000-0000-000000000009')$$,'P0001','OPEN_CASE_EXISTS','damage blocks smooth settlement');
SELECT is((SELECT count(*)::INTEGER FROM public.ledger_entries WHERE booking_id='c2400000-0000-0000-0000-000000000009'),0,'failed settlement writes no ledger');
RESET ROLE;
SELECT throws_ok($$INSERT INTO public.terms_acceptances(booking_id,user_id,role,terms_document_id,accepted_version,app_version) SELECT 'c2400000-0000-0000-0000-000000000009','a2400000-0000-0000-0000-000000000003','borrower',id,'wrong','test' FROM public.terms_documents WHERE audience='borrower' AND is_active$$,'P0001','TERMS_VERSION_MISMATCH','wrong accepted version rejected');
SELECT throws_ok($$UPDATE public.terms_acceptances SET app_version='changed' WHERE booking_id='c2400000-0000-0000-0000-000000000001'$$,'P0001','TERMS_IMMUTABLE','acceptance audit cannot be rewritten');
UPDATE public.bookings SET expires_at=NOW()-INTERVAL '1 hour' WHERE status='requested' AND borrower_id='a2400000-0000-0000-0000-000000000003';
SELECT is(rental_private.expire_requests(),1,'expiry worker expires eligible request');
SELECT is(rental_private.expire_requests(),0,'expiry worker is repeat-safe');
SELECT throws_ok($$INSERT INTO public.bookings(item_id,lender_id,borrower_id,start_date,end_date,commission_rate,deposit_rate,agreed_daily_rate) VALUES('b2400000-0000-0000-0000-000000000001','a2400000-0000-0000-0000-000000000002','a2400000-0000-0000-0000-000000000003',CURRENT_DATE,CURRENT_DATE,0,0,100)$$,'23514',NULL,'partial financial snapshot rejected');
SELECT throws_ok($$INSERT INTO public.bookings(item_id,lender_id,borrower_id,start_date,end_date,commission_rate,deposit_rate,agreed_daily_rate,declared_value_snapshot,rental_fee,deposit_amount,commission_amount,lender_earning,snapshot_recorded_at) VALUES('b2400000-0000-0000-0000-000000000001','a2400000-0000-0000-0000-000000000002','a2400000-0000-0000-0000-000000000003',CURRENT_DATE,CURRENT_DATE,0,0,100,1000,999,0,0,999,NOW())$$,'23514',NULL,'inconsistent rental fee rejected');
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
