-- Isolated-database fixtures installed after the original 15 follow-ups and
-- before the corrections. Deliberately includes invalid historic data.
INSERT INTO auth.users(id,email) VALUES
 ('f2400000-0000-0000-0000-000000000001','legacy-admin@test.invalid'),
 ('f2400000-0000-0000-0000-000000000002','legacy-lender@test.invalid'),
 ('f2400000-0000-0000-0000-000000000003','legacy-borrower@test.invalid');
UPDATE public.profiles SET role='admin' WHERE id='f2400000-0000-0000-0000-000000000001';
UPDATE public.profiles SET kyc_status='verified';
INSERT INTO public.items(id,lender_id,title,daily_rate,declared_value,pickup_area)
VALUES('f2400000-0000-0000-0000-000000000010','f2400000-0000-0000-0000-000000000002','Legacy item',3500,160000,'Lalitpur');
INSERT INTO public.bookings(id,item_id,lender_id,borrower_id,start_date,end_date,status,commission_rate,deposit_rate)
VALUES('f2400000-0000-0000-0000-000000000011','f2400000-0000-0000-0000-000000000010',
 'f2400000-0000-0000-0000-000000000002','f2400000-0000-0000-0000-000000000003','2000-01-01','2000-01-03','renter_accepted',.1,.25);
INSERT INTO public.bookings(id,item_id,lender_id,borrower_id,start_date,end_date,status,commission_rate,deposit_rate,
 agreed_daily_rate,declared_value_snapshot,rental_fee,deposit_amount,commission_amount,lender_earning,snapshot_recorded_at)
VALUES('f2400000-0000-0000-0000-000000000012','f2400000-0000-0000-0000-000000000010',
 'f2400000-0000-0000-0000-000000000002','f2400000-0000-0000-0000-000000000003','2000-02-01','2000-02-03','returned',
 .1,.25,3500,160000,10500,999999,1050,9450,NOW()),
 ('f2400000-0000-0000-0000-000000000013','f2400000-0000-0000-0000-000000000010',
 'f2400000-0000-0000-0000-000000000002','f2400000-0000-0000-0000-000000000003','2000-03-01','2000-03-03','completed',
 .1,.25,3500,160000,10500,40000,1050,9450,NOW());
INSERT INTO public.terms_documents(title,version,content,status,published_at)
VALUES('renter terms','7','Historic text','published',NOW());
INSERT INTO public.app_settings(key,value) VALUES('deposit_rate','0.3');
UPDATE storage.buckets SET public=TRUE WHERE id='kyc';
