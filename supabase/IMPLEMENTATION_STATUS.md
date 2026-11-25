# Backend implementation status

Updated 25 November 2026. Source: Final Implementation Plan (21 November,
Documentationassets.zip), reconciled API Contract v0.2, and existing migrations.

This is a partial backend implementation with explicit decision blockers. It is
not an end-to-end working rental service. The approved financial defaults are
seeded; required operational settings such as request expiry and auto-approval
remain unconfigured. The shared API contract still needs coordinated correction:
it contains a 25% worked example and describes the business rates as unapproved.

## Execution and preservation

- Branch: srijan/backend; baseline commit d535dda.
- Initial migration unchanged (Git blob 8935673e115670f1b1bd63f96ce1c8e3d89cb6a5).
- Existing timestamp migration unchanged.
- Composite booking/item-owner FK and existing exclusion constraint unchanged.
- All 12 booking statuses and all four bucket names retained.
- This continuation applied and tested migrations only in uniquely named isolated
  local test databases. No persistent database was reset or changed; no database
  was deleted, and no cloud migration, commit, push or merge was performed.

## Stage coverage

| Stage | Source implemented | Remaining dependency |
| --- | --- | --- |
| 1 Privileges | Explicit table/column grants; removed client TRUNCATE/TRIGGER and booking writes | Integration checks through real API clients |
| 2 Roles/KYC | Protected role/status/KYC fields; active-admin helpers; KYC submission and review RPCs | Real API integration checks; no direct client verification writes |
| 3 Private information | profile_private and admin-only kyc_submissions | Public first-name DTO, avatar storage, gated contact helper approval |
| 4 Audit | Admin-only append-through-RPC audit_log | Future admin functions must also audit |
| 5 Settings | Eight recognized keys, type/range checks, audited admin update; approved financial defaults seeded | Operational values for request expiry, minimum declared value and auto-approval |
| 6 Snapshots | Complete-or-empty financial snapshots, generated duration, immutable snapshot trigger; server calculator and half-up whole-NPR rounding | Coordinated wire convention and retry contract |
| 7 Terms | Audience/publication/history, booking_terms, terms_acceptances, publication RPC; request RPC captures three published versions | Legacy terms classification/backfill |
| 8 Items | Category/condition/rules/photo paths; publish checks; private pickup details | Category/condition vocabulary, actual uploaded-photo linkage, contact delivery |
| 9 Booking | Request creation, accept/decline and admin approval; original overlap constraint retained | Cancellation, availability helper, future-date overdue/damage policy |
| 10 Payments | Proof records, submission/terms transaction and secure object access | Verification blocked by code delivery; retry key contract and rejection RPC path |
| 11 Handover/return | Admin-only evidence, receipt confirmation, return and damage report RPCs | Hash verifier/generation/delivery/lockout/reset and record_handover deferred together |
| 12 Settlement | Idempotent on-time undisputed settlement; private earning/refund ledger | Late/grace formula, case resolution/deductions, paid-marking helper, broader ledger events |
| 13 Accounts | Audited suspension/reactivation | Deletion/anonymization/retention/FK design; original Auth FK retained |
| 14 Extras | Recipient notifications, realtime publication, private reports/review foundation, internal expiry worker | Job schedules, overdue/escalation/reminders/retention; review rating/write/public-read contract |

## New migrations

All filenames are under supabase/migrations, ordered after the pre-existing
20261124000000_add_updated_at_triggers.sql:

1. 20261124010000_restrict_client_privileges.sql
2. 20261124010100_profile_authorization.sql
3. 20261124010200_private_profiles.sql
4. 20261124010300_audit_and_kyc_review.sql
5. 20261124010400_settings_validation.sql
6. 20261124010500_booking_snapshots.sql
7. 20261124010600_terms_relations.sql
8. 20261124010700_listing_details.sql
9. 20261124010800_booking_decisions.sql
10. 20261124010900_payment_records.sql
11. 20261124011000_evidence_records.sql
12. 20261124011100_storage_security.sql
13. 20261124011200_ledger_and_smooth_settlement.sql
14. 20261124011300_account_status.sql
15. 20261124011400_notifications_reports_reviews.sql
16. 20261124011500_approved_financial_integrity.sql
17. 20261124011600_booking_creation_and_terms_integrity.sql
18. 20261124011700_kyc_and_security_corrections.sql
19. 20261124011800_approval_and_settlement_integrity.sql

## Tables and constraints

New tables: profile_private, kyc_submissions, audit_log, booking_terms,
terms_acceptances, item_pickup_details, booking_payments, handover_records,
damage_reports, receipt_confirmations, ledger_entries, notifications, reports,
reviews. Every new table has RLS and explicit grants. Client writes are limited
to own private-profile fields, own pickup details, notification read_at and reports.
All other new tables are read-only or admin-only for authenticated clients.

profiles adds role (user/admin), status (active/suspended/deleted), kyc_status
(none/pending/verified/rejected). Existing signup ignores privileged metadata.
No new full_name rename or public profile projection has been introduced.

bookings adds rental_days (generated), agreed_daily_rate,
declared_value_snapshot, rental_fee, deposit_amount, commission_amount,
lender_earning, snapshot_recorded_at, expires_at, receipt_confirmed_at,
returned_at, decline_reason, is_overdue. Existing rates remain fractional NUMERIC;
their silent zero defaults are removed. Old rows remain unsnapshotted, not
backfilled from today's prices. Amounts remain NUMERIC; exact RPC calculation
is enforced by the internal calculator: deposit is 20% of declared value and
commission is 10% of rental fees by default, both rounded to whole NPR using
half-up behavior for nonnegative amounts. The 1.5 late-fee multiplier is seeded
but not applied while late/grace rules remain undecided. A complete snapshot must
match the calculator; changing saved financial inputs fails. Integer wire
conversion remains a coordinated contract decision.

terms_documents adds audience, is_active and archived_at. One active row per
audience is enforced; the publishing transaction replaces it atomically. Numeric
versions increment in the existing TEXT column. Drafts remain editable; published
content cannot be edited/deleted. Existing audience=NULL terms are not guessed
or automatically relabelled. Linking such legacy terms needs an approved migration.
booking_terms validates audience, published history and membership in the existing
UUID array. Acceptance records have composite FKs, actor/version validation,
server time, app_version and uniqueness; they cannot be updated/deleted.

items adds category, condition, rules and photo_paths. New/updated active listings
need eligible KYC, configured minimum declared value, category/condition and 1-5
uploader-prefixed photos. Existing active rows are not silently rewritten; their
next update must meet the new requirements. Photo count/path checks do not prove
that the files exist; that integration validation remains necessary.

Indexes cover explore filters, pending KYC/payment uniqueness, open damage cases,
booking terms/acceptance uniqueness, per-stage evidence, settlement uniqueness,
and notification recipient/time.

## Implemented RPC signatures

All below are SECURITY DEFINER with empty search_path, explicit authenticated
EXECUTE grants, caller checks and restricted JSON responses. P0001 exception
messages carry symbolic codes; raw constraint errors can still occur.

- admin_review_kyc(p_user_id uuid, p_decision text, p_reason text default null).
  Decisions are verified/rejected; requires an existing pending submission.
- admin_update_setting(p_key text, p_value jsonb).
- admin_publish_terms(p_audience text, p_body text).
- create_booking_request(p_item_id uuid, p_start_date date, p_end_date date).
  Calculates and snapshots money and links all three published terms versions;
  requires configured operational settings and does not accept client totals.
- submit_kyc(p_id_path text, p_face_path text) and get_my_kyc_status().
  Submission checks ownership and uploaded objects; status returns a sanitized
  response without exposing evidence paths.
- renter_decide_booking(p_booking_id uuid, p_accept boolean,
  p_terms_accepted boolean, p_terms_id uuid default null,
  p_reason text default null, p_app_version text default null).
  Accept requires app version, complete snapshot, saved renter terms, and an
  explicitly configured auto_approve_orders. Decline does not require terms.
- admin_approve_order(p_booking_id uuid, p_approve boolean,
  p_reason text default null). Only approval is implemented; false/null returns
  ORDER_REJECTION_NOT_APPROVED, because no rejection destination is agreed.
- submit_payment_proof(p_booking_id uuid, p_terms_accepted boolean,
  p_terms_id uuid, p_proof_path text, p_reference text,
  p_app_version text default null). App version is required at runtime.
  Optional idempotency key from the draft is not implemented.
- confirm_receipt(p_booking_id uuid, p_ok boolean, p_note text default null).
- record_return(p_booking_id uuid, p_return_photo_paths text[],
  p_no_issues boolean, p_note text default null). Return time is server-supplied.
- report_damage(p_booking_id uuid, p_description text, p_photo_paths text[],
  p_claimed_amount integer). Creates an open case; leaves booking returned.
  Plan section 5 reserves the disputed transition for Admin.
- settle_booking(p_booking_id uuid). No optional caller-supplied return time.
  Only returns on/before the booked end date (Kathmandu calendar), with no issue
  or unresolved receipt concern, are settled. Later dates return
  LATE_RULE_NOT_APPROVED; cases return OPEN_CASE_EXISTS. Sequential retries
  return already_settled=true without duplicate ledger entries.
- admin_set_user_status(p_user_id uuid, p_status text, p_reason text).
  Active/suspended only; admin targets forbidden; deletion explicitly blocked.

Missing required RPCs: admin_verify_payment, record_handover, admin_resolve_case,
request_account_deletion. Supplemental availability/contact/cancellation/code-delivery/
payout-marking helpers remain unapproved and unimplemented. is_admin,
is_active_user and can_rent are policy helpers, not public data projections.

## Storage behavior

Bucket names unchanged. All four accept JPEG/PNG/WebP only and have a byte limit
of 5 MiB minus one byte. KYC and handover SELECT policies are admin-only.
Payment proof is readable by its uploader/admin, never the other booking party.
Writes require active accounts. New proof/evidence paths are:

    <uploader-user-id>/<booking-id>/<file>

Existing files are not moved or deleted. Inserts check the booking participant
and stage. RPCs check object existence and matching path. Private object overwrite
and delete remain unavailable to ordinary clients. Signed URL generation and
actual Storage HTTP upload/download behavior have not been tested in this run.

## Executed tests and practical limits

Verified 25 November 2026 against the running local Supabase Docker PostgreSQL
container. All test databases were uniquely named and isolated; none was reset
or deleted. The complete migrations were applied in the isolated databases.

- `python -B supabase/tests/run_local_regression.py fresh`: PASS, 101
  `phase0_regression.test.sql` assertions and 85
  `corrections_regression.test.sql` assertions; 0 failures.
  Database: `rental_test_20261124185410_45653e`.
- `python -B supabase/tests/run_local_regression.py legacy`: PASS, 10
  `legacy_after_corrections.test.sql` assertions; 0 failures. Populated legacy
  rows were inserted before migration 115 and remained preserved/guarded.
  Database: `rental_test_20261124185423_c8a254`.
- `python -B supabase/tests/check_concurrent_overlap.py rental_test_20261124185410_45653e`:
  PASS. Concurrent renter decisions produced one accepted and one overlap-rejected
  booking; concurrent settlement produced one first settlement and one idempotent
  retry, exactly two ledger entries and one settlement audit.

Logs are retained under `supabase/tests/results/`. These are SQL-level tests in
the local PostgreSQL server, not a second Supabase HTTP stack. Service-owner
default privileges are omitted from the fresh schema bootstrap; existing
service-object grants are retained. Fixtures explicitly supply records for the
unimplemented payment-verification/handover steps, so these results are not
end-to-end coverage.

Not implemented or verified: Dart/money.dart parity and integer wire conversion;
handover-code generation/delivery/lockout; dispute resolution; late/grace policy;
Auth/file deletion; actual Storage HTTP behavior; realtime delivery; scheduled
execution; and real API-client integration. Existing config's missing seed.sql
remains a separate issue before using the repository's reset-based CI workflow.

## Integration work

Smaran: use the existing field names, nullable legacy snapshots, exact implemented
RPC signatures above, and narrow response objects (often id/status rather than a
full Booking). Do not call deferred RPCs. Decimal wire conversion and money.dart
fixtures must be agreed before authoritative creation is enabled. Reports and
reviews have no public browse contract yet. Notification payloads contain only
booking reference/event, not contacts or evidence.

Mohan: admin status comes from protected profiles.role/status. Private profile,
KYC and evidence tables have distinct access scopes. Configure reviewed settings
explicitly; publish all three terms audiences; never use a service key in Flutter.
KYC submission, code delivery/reset, payment verification, case resolution,
payout marking and account deletion still need their dependent decisions/work.

Before integration: approve the remaining decisions, complete blocked features,
update the shared contract/models together, run real API/storage/device tests,
review privileges and data migration/backfill behavior, then authorize persistent
local application and any later commit/cloud steps separately.
