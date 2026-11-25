"""Real authenticated booking-decision and settlement RPC races, local tests only.

Creates synthetic rows and retains them. Never modifies the main local database.
"""
from concurrent.futures import ThreadPoolExecutor
import re
import sys
import threading
import uuid
from datetime import datetime, timezone
from pathlib import Path
sys.dont_write_bytecode = True
from run_local_regression import psql

database = sys.argv[1]
if not re.fullmatch(r"rental_test_[0-9]{14}_[a-f0-9]{6}", database):
    raise SystemExit("Only a database created by run_local_regression.py fresh is allowed")
admin, lender, borrower, other, item = [str(uuid.uuid4()) for _ in range(5)]
psql(database, f"""
BEGIN;
INSERT INTO auth.users(id,email) VALUES ('{admin}','{admin}@test.invalid'),
 ('{lender}','{lender}@test.invalid'), ('{borrower}','{borrower}@test.invalid'), ('{other}','{other}@test.invalid');
UPDATE public.profiles SET role='admin' WHERE id='{admin}';
UPDATE public.profiles SET kyc_status='verified' WHERE id IN('{lender}','{borrower}','{other}');
SELECT set_config('request.jwt.claims','{{"sub":"{admin}","role":"authenticated"}}',TRUE);
SELECT public.admin_update_setting('min_declared_value','2000');
SELECT public.admin_update_setting('request_expiry_hours','48');
SELECT public.admin_update_setting('auto_approve_orders','false');
SELECT public.admin_publish_terms('renter','Concurrency renter terms');
SELECT public.admin_publish_terms('borrower','Concurrency borrower terms');
SELECT public.admin_publish_terms('general','Concurrency general terms');
INSERT INTO storage.objects(bucket_id,name) VALUES('item-photos','{lender}/{item}.jpg');
INSERT INTO public.items(id,lender_id,title,daily_rate,declared_value,pickup_area,status,category,condition,photo_paths)
VALUES ('{item}','{lender}','Concurrent test',100,2000,'Kathmandu','active','camera','good',ARRAY['{lender}/{item}.jpg']);
COMMIT;
""")


def create_request(user):
    output = psql(database, f"""BEGIN; SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims','{{"sub":"{user}","role":"authenticated"}}',TRUE);
SELECT public.create_booking_request('{item}',CURRENT_DATE+1,CURRENT_DATE+3)->>'id'; COMMIT;""")
    return next(line for line in output.splitlines() if re.fullmatch(r'[0-9a-f-]{36}', line))


first, second = create_request(borrower), create_request(other)
barrier = threading.Barrier(2)


def accept(booking):
    barrier.wait()
    try:
        psql(database, f"""BEGIN; SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims','{{"sub":"{lender}","role":"authenticated"}}',TRUE);
SELECT public.renter_decide_booking('{booking}',TRUE,TRUE,
 (SELECT terms_document_id FROM public.booking_terms WHERE booking_id='{booking}' AND audience='renter'),NULL,'race');
SELECT pg_sleep(1); COMMIT;""")
        return "accepted"
    except RuntimeError as error:
        if 'DATES_TAKEN' in str(error):
            return "overlap_rejected"
        raise


with ThreadPoolExecutor(max_workers=2) as pool:
    outcomes = list(pool.map(accept, [first, second]))
if sorted(outcomes) != ['accepted', 'overlap_rejected']:
    raise RuntimeError(outcomes)
count = psql(database, f"SELECT count(*) FROM public.bookings WHERE item_id='{item}' AND status='renter_accepted';").strip()
assert count == '1', count
winner = psql(database, f"SELECT id FROM public.bookings WHERE item_id='{item}' AND status='renter_accepted';").strip()
winner_borrower = borrower if winner == first else other
assert psql(database, f"SELECT count(*) FROM public.terms_acceptances WHERE booking_id IN('{first}','{second}');").strip() == '1'
# Explicit fixture supplies records for the still-unimplemented payment/code RPCs.
prefix = f'{lender}/{winner}/'
proof = f'{winner_borrower}/{winner}/proof.jpg'
psql(database, f"""BEGIN;
INSERT INTO public.terms_acceptances(booking_id,user_id,role,terms_document_id,accepted_version,app_version)
 SELECT '{winner}','{winner_borrower}','borrower',t.id,t.version,'race'
 FROM public.booking_terms bt JOIN public.terms_documents t ON t.id=bt.terms_document_id
 WHERE bt.booking_id='{winner}' AND bt.audience='borrower';
INSERT INTO storage.objects(bucket_id,name) VALUES('payment-proof','{proof}');
INSERT INTO public.booking_payments(booking_id,submitted_by,proof_path,reference,status,amount_received,reviewed_at,reviewed_by)
 SELECT id,borrower_id,'{proof}','test','verified',rental_fee+deposit_amount,NOW(),'{admin}' FROM public.bookings WHERE id='{winner}';
INSERT INTO storage.objects(bucket_id,name) SELECT 'handover','{prefix}' || f FROM unnest(ARRAY['item.jpg','face.jpg','id.jpg','return.jpg']) f;
INSERT INTO public.handover_records(booking_id,stage,recorded_by,item_photo_paths,checklist,borrower_face_path,borrower_id_photo_path)
 VALUES('{winner}','pickup','{lender}',ARRAY['{prefix}item.jpg'],'{{"checked":true}}','{prefix}face.jpg','{prefix}id.jpg');
INSERT INTO public.handover_records(booking_id,stage,recorded_by,item_photo_paths,no_issues)
 VALUES('{winner}','return','{lender}',ARRAY['{prefix}return.jpg'],TRUE);
UPDATE public.bookings SET status='returned',returned_at=NOW() WHERE id='{winner}';
COMMIT;""")
barrier = threading.Barrier(2)


def settle(_):
    barrier.wait()
    output = psql(database, f"""BEGIN; SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims','{{"sub":"{admin}","role":"authenticated"}}',TRUE);
SELECT public.settle_booking('{winner}')->>'already_settled'; SELECT pg_sleep(1); COMMIT;""")
    return next(line for line in output.splitlines() if line in ('true','false'))


with ThreadPoolExecutor(max_workers=2) as pool:
    settlement = list(pool.map(settle, [1, 2]))
assert sorted(settlement) == ['false', 'true'], settlement
assert psql(database, f"SELECT count(*) FROM public.ledger_entries WHERE booking_id='{winner}';").strip() == '2'
assert psql(database, f"SELECT count(*) FROM public.audit_log WHERE action='settle_booking' AND target_id='{winner}';").strip() == '1'
message = f'database={database}\nPASS: concurrent renter_decide_booking: {outcomes}; losing acceptance rolled back.\nPASS: concurrent settle_booking: {settlement}; exactly two ledger entries and one settlement audit.\n'
results = Path(__file__).parent / 'results'
results.mkdir(exist_ok=True)
log = results / (datetime.now(timezone.utc).strftime('%Y%m%d%H%M%S') + '_concurrent_rpcs.log')
log.write_text(message, encoding='utf-8')
print(message + f'log={log}')
