BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET search_path=public,extensions;
SELECT no_plan();
SELECT is((SELECT value FROM public.app_settings WHERE key='deposit_rate'),'0.2'::JSONB,'approved initial deposit');
SELECT is((SELECT value FROM public.app_settings WHERE key='commission_rate'),'0.1'::JSONB,'approved initial commission');
SELECT is((SELECT value FROM public.app_settings WHERE key='late_fee_multiplier'),'1.5'::JSONB,'approved initial multiplier');
SELECT is(rental_private.calculate_money(3,3500,160000,.1,.2),
 '{"rental_fee":10500,"deposit_amount":32000,"commission_amount":1050,"lender_earning":9450,"borrower_total":42500}'::JSONB,'approved worked example');
SELECT is(rental_private.calculate_money(1,5,1,.1,.5)->>'commission_amount','1','commission half-up tie');
SELECT is(rental_private.calculate_money(1,5,1,.1,.5)->>'deposit_amount','1','deposit half-up tie at test-only 50 percent');
SELECT is(rental_private.calculate_money(1,4,2,.1,.2)->>'deposit_amount','0','deposit below half');
SELECT is(rental_private.calculate_money(1,6,3,.1,.2)->>'deposit_amount','1','deposit above half');
SELECT is(rental_private.calculate_money(1,4,0,.1,.2)->>'commission_amount','0','commission below half');
SELECT is(rental_private.calculate_money(1,6,0,.1,.2)->>'commission_amount','1','commission above half');
SELECT is(rental_private.calculate_money(1,1,0,1,0)->>'lender_earning','0','100 percent commission boundary');
SELECT lives_ok($$SELECT rental_private.calculate_money(1,9999999999,9999999999,0,1)$$,'largest supported item amounts');
SELECT throws_ok($$SELECT rental_private.calculate_money(0,10,10,.1,.2)$$,'P0001','INVALID_MONEY','zero days rejected');
SELECT throws_ok($$SELECT rental_private.calculate_money(1,-1,10,.1,.2)$$,'P0001','INVALID_MONEY','negative price rejected');
SELECT throws_ok($$SELECT rental_private.calculate_money(1,1,-1,.1,.2)$$,'P0001','INVALID_MONEY','negative declared value rejected');
SELECT throws_ok($$SELECT rental_private.calculate_money(1,1.001,10,.1,.2)$$,'P0001','INVALID_MONEY','raw fractional price rejected before column rounding');
SELECT throws_ok($$SELECT rental_private.calculate_money(1,1,10.5,.1,.2)$$,'P0001','INVALID_MONEY','fractional declared value rejected');
SELECT throws_ok($$SELECT rental_private.calculate_money(1,1,10,1000,2000)$$,'P0001','INVALID_MONEY','bps cannot be passed as SQL fractions');
SELECT throws_ok($$SELECT rental_private.calculate_money(1,1,10,.10001,.2)$$,'P0001','INVALID_MONEY','rate precision rejected');
SELECT throws_ok($$SELECT rental_private.calculate_money(1,'NaN',10,.1,.2)$$,'P0001','INVALID_MONEY','NaN rejected');
SELECT throws_ok($$SELECT rental_private.calculate_money(1,1,'Infinity',.1,.2)$$,'P0001','INVALID_MONEY','infinity rejected');
SELECT throws_ok($$SELECT rental_private.calculate_money(1,NULL,10,.1,.2)$$,'P0001','INVALID_MONEY','missing value rejected');
SELECT throws_ok($$SELECT rental_private.calculate_money(100000,9999999999,10,.1,.2)$$,'P0001','INVALID_MONEY','overflow rejected');
SELECT ok(NOT has_function_privilege('anon','public.notify_booking_status()','EXECUTE'),'trigger execution revoked');
SELECT ok(NOT has_function_privilege('authenticated','public.validate_booking_terms()','EXECUTE'),'internal terms execution revoked');
CREATE FUNCTION public.test_default_acl_probe() RETURNS INTEGER LANGUAGE sql AS 'SELECT 1';
SELECT ok(NOT has_function_privilege('anon','public.test_default_acl_probe()','EXECUTE'),'new functions are private globally');

INSERT INTO auth.users(id,email) VALUES
 ('d2400000-0000-0000-0000-000000000001','correction-admin@test.invalid'),
 ('d2400000-0000-0000-0000-000000000002','correction-lender@test.invalid'),
 ('d2400000-0000-0000-0000-000000000003','correction-borrower@test.invalid'),
 ('d2400000-0000-0000-0000-000000000004','correction-other@test.invalid');
UPDATE public.profiles SET role='admin' WHERE id='d2400000-0000-0000-0000-000000000001';
UPDATE public.profiles SET kyc_status='verified' WHERE id IN('d2400000-0000-0000-0000-000000000002','d2400000-0000-0000-0000-000000000003');
SELECT set_config('request.jwt.claims','{"sub":"d2400000-0000-0000-0000-000000000001","role":"authenticated"}',TRUE);
-- A valid baseline title/version must not prevent new publication.
INSERT INTO public.terms_documents(title,version,content,status,published_at) VALUES('renter terms','1','legacy immutable text','published',NOW());
SELECT is(public.admin_publish_terms('renter','New renter terms')->>'version','2','legacy title collision avoided');
SELECT is((SELECT content FROM public.terms_documents WHERE title='renter terms' AND version='1'),'legacy immutable text','legacy content preserved');
SELECT public.admin_publish_terms('borrower','Borrower terms');
SELECT public.admin_publish_terms('general','General terms');
SELECT public.admin_update_setting('min_declared_value','2000');
SELECT public.admin_update_setting('min_deposit_amount','0');
SELECT public.admin_update_setting('auto_approve_orders','false');

CREATE FUNCTION pg_temp.fixture(p_state TEXT DEFAULT 'returned',p_renter BOOLEAN DEFAULT TRUE,
    p_borrower BOOLEAN DEFAULT TRUE,p_payment BOOLEAN DEFAULT TRUE,p_pickup BOOLEAN DEFAULT TRUE,
    p_return BOOLEAN DEFAULT TRUE,p_bad_deposit BOOLEAN DEFAULT FALSE)
RETURNS UUID LANGUAGE plpgsql AS $$
DECLARE b UUID:=gen_random_uuid(); i UUID:=gen_random_uuid();
    lender UUID:='d2400000-0000-0000-0000-000000000002'; borrower UUID:='d2400000-0000-0000-0000-000000000003';
    prefix TEXT:=lender::TEXT || '/' || b::TEXT || '/'; proof TEXT:=borrower::TEXT || '/' || b::TEXT || '/proof.jpg';
BEGIN
    INSERT INTO public.items(id,lender_id,title,daily_rate,declared_value,pickup_area)
        VALUES(i,lender,'Fixture',3500,160000,'Lalitpur');
    INSERT INTO public.bookings(id,item_id,lender_id,borrower_id,start_date,end_date,status,commission_rate,deposit_rate,
        agreed_daily_rate,declared_value_snapshot,rental_fee,deposit_amount,commission_amount,lender_earning,
        snapshot_recorded_at,returned_at,terms_version_ids)
    VALUES(b,i,lender,borrower,(NOW() AT TIME ZONE 'Asia/Kathmandu')::DATE,(NOW() AT TIME ZONE 'Asia/Kathmandu')::DATE+2,
        p_state,.1,.2,3500,160000,10500,CASE WHEN p_bad_deposit THEN 999999 ELSE 32000 END,1050,9450,NOW(),
        CASE WHEN p_state='returned' THEN NOW() END,(SELECT array_agg(id) FROM public.terms_documents WHERE is_active));
    INSERT INTO public.booking_terms SELECT b,audience,id FROM public.terms_documents WHERE is_active;
    INSERT INTO public.terms_acceptances(booking_id,user_id,role,terms_document_id,accepted_version,app_version)
        SELECT b,CASE audience WHEN 'renter' THEN lender ELSE borrower END,audience,id,version,'test'
        FROM public.terms_documents WHERE is_active AND ((audience='renter' AND p_renter) OR (audience='borrower' AND p_borrower));
    INSERT INTO storage.objects(bucket_id,name) SELECT 'handover',prefix || f
        FROM unnest(ARRAY['item.jpg','face.jpg','id.jpg','return.jpg']) f;
    INSERT INTO storage.objects(bucket_id,name) VALUES('payment-proof',proof);
    IF p_payment THEN
        INSERT INTO public.booking_payments(booking_id,submitted_by,proof_path,reference,status,amount_received,reviewed_at,reviewed_by)
        VALUES(b,borrower,proof,'manual test','verified',42500,NOW(),'d2400000-0000-0000-0000-000000000001');
    END IF;
    IF p_pickup THEN
        INSERT INTO public.handover_records(booking_id,stage,recorded_by,item_photo_paths,checklist,borrower_face_path,borrower_id_photo_path)
            VALUES(b,'pickup',lender,ARRAY[prefix || 'item.jpg'],'{"checked":true}',prefix || 'face.jpg',prefix || 'id.jpg');
    END IF;
    IF p_return THEN
        INSERT INTO public.handover_records(booking_id,stage,recorded_by,item_photo_paths,no_issues)
            VALUES(b,'return',lender,ARRAY[prefix || 'return.jpg'],TRUE);
    END IF;
    RETURN b;
END;
$$;
CREATE TEMP TABLE cases(name TEXT PRIMARY KEY,id UUID);
GRANT SELECT ON cases TO authenticated;
INSERT INTO cases VALUES('good',pg_temp.fixture()),('no_payment',pg_temp.fixture(p_payment=>FALSE)),
 ('no_handover',pg_temp.fixture(p_pickup=>FALSE)),('no_return',pg_temp.fixture(p_return=>FALSE)),
 ('no_borrower_terms',pg_temp.fixture(p_borrower=>FALSE)),('no_renter_terms',pg_temp.fixture(p_renter=>FALSE)),
 ('approval_missing_terms',pg_temp.fixture(p_state=>'renter_accepted',p_renter=>FALSE)),
 ('bad_payment',pg_temp.fixture()),('bad_evidence',pg_temp.fixture()),('ledger_bad',pg_temp.fixture()),
 ('issue',pg_temp.fixture(p_state=>'handed_over',p_return=>FALSE));
SELECT throws_ok($$SELECT pg_temp.fixture(p_bad_deposit=>TRUE)$$,'23514',NULL,'incorrect deposit blocked by table constraint');
CREATE FUNCTION pg_temp.invalid_snapshot(p_kind TEXT) RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE b public.bookings;
BEGIN
    SELECT * INTO b FROM public.bookings WHERE id=(SELECT id FROM cases WHERE name='good');
    IF p_kind='commission' THEN b.commission_amount:=1051; b.lender_earning:=9449;
    ELSIF p_kind='fractional' THEN b.agreed_daily_rate:=100.5;b.rental_fee:=301.5;b.commission_amount:=30;b.lender_earning:=271.5;
    ELSIF p_kind='negative' THEN b.deposit_amount:=-1;
    ELSIF p_kind='nan' THEN b.deposit_amount:='NaN';
    ELSE b.lender_earning:=b.lender_earning+1; END IF;
    INSERT INTO public.bookings(item_id,lender_id,borrower_id,start_date,end_date,commission_rate,deposit_rate,
        agreed_daily_rate,declared_value_snapshot,rental_fee,deposit_amount,commission_amount,lender_earning,snapshot_recorded_at)
    VALUES(b.item_id,b.lender_id,b.borrower_id,b.start_date,b.end_date,b.commission_rate,b.deposit_rate,
        b.agreed_daily_rate,b.declared_value_snapshot,b.rental_fee,b.deposit_amount,b.commission_amount,b.lender_earning,NOW());
END;
$$;
SELECT throws_ok($$SELECT pg_temp.invalid_snapshot('commission')$$,'23514',NULL,'incorrect commission rejected by constraint');
SELECT throws_ok($$SELECT pg_temp.invalid_snapshot('fractional')$$,'23514',NULL,'fractional payable snapshot rejected by constraint');
SELECT throws_ok($$SELECT pg_temp.invalid_snapshot('negative')$$,'23514',NULL,'negative deposit rejected by constraint');
SELECT throws_ok($$SELECT pg_temp.invalid_snapshot('nan')$$,'23514',NULL,'NaN snapshot rejected by constraint');
SELECT throws_ok($$SELECT pg_temp.invalid_snapshot('earning')$$,'23514',NULL,'incorrect earnings rejected by constraint');
UPDATE public.booking_payments SET amount_received=1 WHERE booking_id=(SELECT id FROM cases WHERE name='bad_payment');
UPDATE public.handover_records SET borrower_face_path=borrower_id_photo_path WHERE stage='pickup' AND booking_id=(SELECT id FROM cases WHERE name='bad_evidence');
SET LOCAL ROLE authenticated;
SELECT throws_ok($$SELECT public.settle_booking((SELECT id FROM cases WHERE name='no_payment'))$$,'P0001','PAYMENT_NOT_VERIFIED','missing verified payment blocks settlement');
SELECT throws_ok($$SELECT public.settle_booking((SELECT id FROM cases WHERE name='bad_payment'))$$,'P0001','PAYMENT_NOT_VERIFIED','wrong verified amount blocks settlement');
SELECT throws_ok($$SELECT public.settle_booking((SELECT id FROM cases WHERE name='no_handover'))$$,'P0001','HANDOVER_MISSING','missing pickup blocks settlement');
SELECT throws_ok($$SELECT public.settle_booking((SELECT id FROM cases WHERE name='bad_evidence'))$$,'P0001','HANDOVER_MISSING','same identity photos rejected');
SELECT throws_ok($$SELECT public.settle_booking((SELECT id FROM cases WHERE name='no_return'))$$,'P0001','RETURN_EVIDENCE_MISSING','missing return blocks settlement');
SELECT throws_ok($$SELECT public.settle_booking((SELECT id FROM cases WHERE name='no_borrower_terms'))$$,'P0001','TERMS_NOT_ACCEPTED','borrower acceptance required');
SELECT throws_ok($$SELECT public.settle_booking((SELECT id FROM cases WHERE name='no_renter_terms'))$$,'P0001','TERMS_NOT_ACCEPTED','renter acceptance required');
SELECT throws_ok($$SELECT public.admin_approve_order((SELECT id FROM cases WHERE name='approval_missing_terms'),TRUE)$$,'P0001','TERMS_NOT_ACCEPTED','admin cannot bypass renter terms');
SELECT lives_ok($$SELECT public.settle_booking((SELECT id FROM cases WHERE name='good'))$$,'fully evidenced settlement succeeds');
SELECT is(public.settle_booking((SELECT id FROM cases WHERE name='good'))->>'already_settled','true','settlement retry returns original result');
SELECT is((SELECT count(*) FROM public.ledger_entries WHERE booking_id=(SELECT id FROM cases WHERE name='good')),2::BIGINT,'retry creates no duplicates');
SELECT is((SELECT sum(amount) FROM public.ledger_entries WHERE booking_id=(SELECT id FROM cases WHERE name='good')),41450::NUMERIC,'payout/refund total excludes commission');
SELECT is((SELECT count(*) FROM public.ledger_entries WHERE booking_id IN(SELECT id FROM cases WHERE name<>'good')),0::BIGINT,'failed settlements create no ledger rows');
SELECT throws_ok($$SELECT public.admin_approve_order((SELECT id FROM cases WHERE name='good'),TRUE)$$,'P0001','INVALID_STATE','approval rejects completed booking');
RESET ROLE;
INSERT INTO cases VALUES('approval',pg_temp.fixture(p_state=>'renter_accepted'));
UPDATE public.profiles SET kyc_status='pending' WHERE id='d2400000-0000-0000-0000-000000000003';
SELECT throws_ok($$SELECT public.admin_approve_order((SELECT id FROM cases WHERE name='approval'),TRUE)$$,'P0001','KYC_NOT_VERIFIED','approval requires both verified');
UPDATE public.profiles SET kyc_status='verified',status='suspended' WHERE id='d2400000-0000-0000-0000-000000000003';
SELECT throws_ok($$SELECT public.admin_approve_order((SELECT id FROM cases WHERE name='approval'),TRUE)$$,'P0001','KYC_NOT_VERIFIED','approval rejects restricted borrower');
UPDATE public.profiles SET status='active' WHERE id='d2400000-0000-0000-0000-000000000003';
-- Prove transaction rollback after ledger/status writes, not only precondition failures.
INSERT INTO cases VALUES('audit_failure',pg_temp.fixture());
CREATE FUNCTION pg_temp.reject_test_audit() RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN IF NEW.action='settle_booking' THEN RAISE EXCEPTION 'TEST_AUDIT_FAILURE'; END IF; RETURN NEW; END;
$$;
CREATE TRIGGER test_audit_failure BEFORE INSERT ON public.audit_log FOR EACH ROW EXECUTE FUNCTION pg_temp.reject_test_audit();
SELECT throws_ok($$SELECT public.settle_booking((SELECT id FROM cases WHERE name='audit_failure'))$$,'P0001','TEST_AUDIT_FAILURE','failure after ledger insertion aborts settlement');
SELECT is((SELECT count(*) FROM public.ledger_entries WHERE booking_id=(SELECT id FROM cases WHERE name='audit_failure')),0::BIGINT,'ledger inserts rolled back after audit error');
SELECT is((SELECT status FROM public.bookings WHERE id=(SELECT id FROM cases WHERE name='audit_failure')),'returned','completion rolled back after audit error');
DROP TRIGGER test_audit_failure ON public.audit_log;
INSERT INTO public.ledger_entries(booking_id,user_id,kind,amount)
 SELECT id,'d2400000-0000-0000-0000-000000000004','lender_earning',9450 FROM cases WHERE name='ledger_bad';
INSERT INTO public.ledger_entries(booking_id,user_id,kind,amount)
 SELECT id,'d2400000-0000-0000-0000-000000000003','deposit_refund',32000 FROM cases WHERE name='ledger_bad';
UPDATE public.bookings SET status='completed' WHERE id=(SELECT id FROM cases WHERE name='ledger_bad');
SELECT throws_ok($$SELECT public.settle_booking((SELECT id FROM cases WHERE name='ledger_bad'))$$,'P0001','LEDGER_MISMATCH','two rows with wrong recipient do not count as settled');

SELECT set_config('request.jwt.claims','{"sub":"d2400000-0000-0000-0000-000000000003","role":"authenticated"}',TRUE);
SET LOCAL ROLE authenticated;
SELECT public.confirm_receipt((SELECT id FROM cases WHERE name='issue'),FALSE,'Condition differs');
SELECT is((SELECT count(*) FROM public.admin_booking_attention),0::BIGINT,'issue queue hidden from non-admin');
SELECT throws_ok($$UPDATE public.profiles SET kyc_status='verified' WHERE id=auth.uid()$$,'42501',NULL,'client cannot set KYC');
SELECT throws_ok($$UPDATE public.profiles SET status='active' WHERE id=auth.uid()$$,'42501',NULL,'client cannot set account status');
RESET ROLE;
SELECT set_config('request.jwt.claims','{"sub":"d2400000-0000-0000-0000-000000000001","role":"authenticated"}',TRUE);
SET LOCAL ROLE authenticated;
SELECT is((SELECT count(*) FROM public.admin_booking_attention WHERE reason='receipt_disagreement'),1::BIGINT,'receipt disagreement in admin queue');
SELECT is((SELECT count(*) FROM public.notifications WHERE event='receipt_disagreement'),1::BIGINT,'admin notified of disagreement');
RESET ROLE;

SELECT set_config('request.jwt.claims','{"sub":"d2400000-0000-0000-0000-000000000004","role":"authenticated"}',TRUE);
SET LOCAL ROLE authenticated;
INSERT INTO storage.objects(bucket_id,name) VALUES('kyc',auth.uid()::TEXT || '/id.jpg'),('kyc',auth.uid()::TEXT || '/face.jpg');
SELECT throws_ok($$SELECT public.submit_kyc('someone/id.jpg','someone/face.jpg')$$,'P0001','EVIDENCE_MISSING','cross-user KYC rejected');
SELECT lives_ok($$SELECT public.submit_kyc(auth.uid()::TEXT || '/id.jpg',auth.uid()::TEXT || '/face.jpg')$$,'own uploaded KYC submitted');
SELECT is(public.get_my_kyc_status()->>'kyc_status','pending','own sanitized pending status');
SELECT ok(NOT(public.get_my_kyc_status() ? 'id_path'),'sanitized response excludes ID path');
SELECT is((SELECT count(*) FROM public.kyc_submissions),0::BIGINT,'submitter cannot read sensitive submission table');
SELECT throws_ok($$SELECT public.submit_kyc(auth.uid()::TEXT || '/id.jpg',auth.uid()::TEXT || '/face.jpg')$$,'P0001','INVALID_STATE','duplicate pending KYC blocked');
RESET ROLE;
SELECT set_config('request.jwt.claims','{"sub":"d2400000-0000-0000-0000-000000000001","role":"authenticated"}',TRUE);
SELECT public.admin_review_kyc('d2400000-0000-0000-0000-000000000004','rejected','Please upload a clearer image');
SELECT set_config('request.jwt.claims','{"sub":"d2400000-0000-0000-0000-000000000004","role":"authenticated"}',TRUE);
SET LOCAL ROLE authenticated;
SELECT is(public.get_my_kyc_status()->>'reason','Please upload a clearer image','rejected user sees reason');
SELECT lives_ok($$SELECT public.submit_kyc(auth.uid()::TEXT || '/id.jpg',auth.uid()::TEXT || '/face.jpg')$$,'rejected user can resubmit');
SELECT ok(public.get_my_kyc_status()->>'reason' IS NULL,'pending status does not leak stale reason');
SELECT throws_ok($$SELECT public.admin_review_kyc(auth.uid(),'verified')$$,'P0001','NOT_ADMIN','user cannot approve own KYC');
RESET ROLE;

-- Live request uses real calculation, settings and terms rather than supplied totals.
INSERT INTO storage.objects(bucket_id,name) VALUES('item-photos','d2400000-0000-0000-0000-000000000002/live.jpg');
INSERT INTO public.items(id,lender_id,title,daily_rate,declared_value,pickup_area,status,category,condition,photo_paths)
 VALUES('e2400000-0000-0000-0000-000000000001','d2400000-0000-0000-0000-000000000002','Live',3500,160000,'Lalitpur','active','camera','good',
 ARRAY['d2400000-0000-0000-0000-000000000002/live.jpg']);
SELECT set_config('request.jwt.claims','{"sub":"d2400000-0000-0000-0000-000000000003","role":"authenticated"}',TRUE);
SET LOCAL ROLE authenticated;
SELECT throws_ok($$SELECT public.create_booking_request('e2400000-0000-0000-0000-000000000001',CURRENT_DATE+1,CURRENT_DATE+3)$$,
 'P0001','SETTING_UNAVAILABLE','unapproved expiry is not invented');
RESET ROLE;
-- Only test configuration: 48 is not seeded by a migration or approved as a default.
SELECT set_config('request.jwt.claims','{"sub":"d2400000-0000-0000-0000-000000000001","role":"authenticated"}',TRUE);
SELECT public.admin_update_setting('request_expiry_hours','48');
SELECT set_config('request.jwt.claims','{"sub":"d2400000-0000-0000-0000-000000000003","role":"authenticated"}',TRUE);
SET LOCAL ROLE authenticated;
SELECT is(public.create_booking_request('e2400000-0000-0000-0000-000000000001',CURRENT_DATE+1,CURRENT_DATE+3)->>'deposit_amount','32000.00','creation calculates approved deposit');
SELECT throws_ok($$SELECT public.create_booking_request('e2400000-0000-0000-0000-000000000001',CURRENT_DATE+1,CURRENT_DATE+3)$$,'P0001','DUPLICATE_REQUEST','duplicate request rejected');
RESET ROLE;
SELECT set_config('request.jwt.claims','{"sub":"d2400000-0000-0000-0000-000000000001","role":"authenticated"}',TRUE);
SELECT public.admin_update_setting('deposit_rate','0.3');
SELECT is((SELECT deposit_amount FROM public.bookings WHERE item_id='e2400000-0000-0000-0000-000000000001'),32000::NUMERIC,'setting change leaves old snapshot untouched');
-- The owner cannot remove referenced listing photos, even with a valid session.
SELECT set_config('request.jwt.claims','{"sub":"d2400000-0000-0000-0000-000000000002","role":"authenticated"}',TRUE);
SET LOCAL ROLE authenticated;
WITH changed AS (UPDATE storage.objects SET name=name WHERE bucket_id='item-photos' AND name=auth.uid()::TEXT || '/live.jpg' RETURNING 1)
SELECT is(count(*),0::BIGINT,'referenced photo overwrite blocked') FROM changed;
RESET ROLE;
SELECT set_config('request.jwt.claims','{"sub":"d2400000-0000-0000-0000-000000000001","role":"authenticated"}',TRUE);
SELECT public.admin_set_user_status('d2400000-0000-0000-0000-000000000002','suspended','test');
SET LOCAL ROLE anon;
SELECT is((SELECT count(*) FROM public.items WHERE id='e2400000-0000-0000-0000-000000000001'),0::BIGINT,'suspended owner listing hidden publicly');
RESET ROLE;
-- Timestamp trigger must overwrite a supplied old time on update.
UPDATE public.profiles SET display_name='Timestamp test',updated_at='2000-01-01' WHERE id='d2400000-0000-0000-0000-000000000003';
SELECT is((SELECT updated_at FROM public.profiles WHERE id='d2400000-0000-0000-0000-000000000003'),NOW(),'profile timestamp updated by trigger');
UPDATE public.bookings SET updated_at='2000-01-01' WHERE id=(SELECT id FROM cases WHERE name='good');
SELECT is((SELECT updated_at FROM public.bookings WHERE id=(SELECT id FROM cases WHERE name='good')),NOW(),'booking timestamp updated by trigger');
UPDATE public.items SET updated_at='2000-01-01' WHERE id=(SELECT item_id FROM public.bookings WHERE id=(SELECT id FROM cases WHERE name='good'));
SELECT is((SELECT updated_at FROM public.items WHERE id=(SELECT item_id FROM public.bookings WHERE id=(SELECT id FROM cases WHERE name='good'))),NOW(),'item timestamp updated by trigger');
UPDATE public.app_settings SET updated_at='2000-01-01' WHERE key='deposit_rate';
SELECT is((SELECT updated_at FROM public.app_settings WHERE key='deposit_rate'),NOW(),'settings timestamp updated by trigger');
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
