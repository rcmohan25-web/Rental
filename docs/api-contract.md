# Rental by Sapati — Shared API Contract

**Version:** v1.0 — **FROZEN**
**Frozen on:** 2026-11-26 (date of the merge of the freeze PR; update if merged later)
**Owners:** Smaran (models, money, Borrower) · Srijan (Supabase, RPCs, Renter) · Mohan (lead, auth/ID, admin panel)
**Approved by:** see section 14
**Basis:** Final Implementation Plan (21 Nov 2026) · supervisor decisions (23 Nov 2026, `docs/business-rules.md`) · Contract v0.3 (financial rules approved) · Mohan's reply to v0.2 (agreed by all three) · `supabase/IMPLEMENTATION_STATUS.md` (25 Nov 2026) for what already exists on `srijan/backend`.

## 0. What "frozen" means

- This file and the models in `packages/rental_data/lib/models` are the single shared interface. Flutter code is written against it; SQL must match it.
- **To change it:** open a PR labelled `contract-change`, get **all three** approvals, bump the version, add a change-log row (section 14). No one edits it as a side effect of another PR.
- **Versions:** `v1.0.x` wording or clarification with no behaviour change; `v1.1` additive (new RPC, new optional field); `v2.0` breaking.
- **Precedence:** supervisor decisions (`docs/business-rules.md`) > this contract > the plan.
- **Status legend** used in every table:
  - **IMPLEMENTED**: exists in the migrations on `srijan/backend` and passed the local SQL tests of 25 Nov 2026. Not yet merged to `main` and not yet exercised through a real API client.
  - **DELTA**: implemented, but differs from this contract. The fix is listed in section 12.
  - **PLANNED**: agreed here, not implemented yet.
  - **DEFERRED**: intentionally postponed (section 13).
- A name in this file is final even when its status is PLANNED. Argument names, return keys and error codes may not change without a contract change.

## 1. Conventions

- **Naming:** UI **Renter** = lends the item; UI **Borrower** = takes it. Database and JSON: `lender_id`, `borrower_id`. One account can act as both.
- **Stack:** Flutter/Dart + Supabase/PostgreSQL. Hand-written immutable Dart models (`equatable`, `fromJson`/`toJson`, no generated code). Every repository has an abstract interface, a fake and a Supabase implementation.
- **Casing and types:** SQL and wire JSON `snake_case`; Dart `camelCase`. IDs are UUID. Timestamps are `timestamptz` in ISO-8601 UTC. Booking dates are `YYYY-MM-DD`, interpreted in **Asia/Kathmandu**, start and end **inclusive**: `days = end − start + 1`.
- **Existing column names are kept** (`daily_rate`, `pickup_area`, `status`, `display_name`, `content`, text `version`). Dart models map them. No renames.
- **Money is whole NPR.** Percentage rates are stored as fractional `NUMERIC(5,4)` (`0.2000`). Inside Dart, parse each rate into **integer basis points** (`0.2000` → `2000`) and never multiply doubles. Conversion happens only at the repository boundary.
- **Formulas (approved):**

```
days               = end_date - start_date + 1
rental_fee         = days x agreed_daily_rate
deposit_amount     = max( round_half_up(declared_value_snapshot x deposit_rate), min_deposit_amount )
commission_amount  = round_half_up(rental_fee x commission_rate)
lender_earning     = rental_fee - commission_amount
borrower_pays      = rental_fee + deposit_amount
```

  - `round_half_up` rounds to **whole NPR**, including exact `.5`. PostgreSQL `round(x, 0)` on non-negative numeric does this. In Dart use integer arithmetic: `(amount * rateBps + 5000) ~/ 10000`.
  - `min_deposit_amount` is admin-set (supervisor decision). `admin_update_setting` must reject a value above `min_declared_value`.
  - The Renter pays **no fee**. Sapati earns only `commission_amount`.
  - Negative, fractional, NaN or out-of-range inputs are rejected with `INVALID_MONEY`.
  - The server calculates every amount. A total sent by the client is never trusted.
- **Snapshot rule:** `create_booking_request` copies `commission_rate`, `deposit_rate`, `min_deposit_amount`, the agreed daily rate, the declared value, all computed amounts and the three terms versions into the booking. Later setting, price or terms changes never alter that booking.
- **Late fee: DEFERRED** (section 13). The `1.5` multiplier is approved as a setting, but no late-fee amount is calculated until the late-return policy is approved.
- **Safety:** only controlled, authorised RPCs change booking status, money, settings, ledger status or privileged profile columns. SQL constraints and RLS are defence in depth. Every state-changing RPC checks identity, account status, role and current state, runs atomically, and returns only fields the caller may see. No RPC returns secrets, ID documents, code hashes or another person's private details.
- **Payment honesty:** payments are manual (eSewa, Khalti or bank, by static QR, to the Sapati company account). Every payment screen shows **"Manual payment (prototype)"**. No gateway, escrow or insurance. An admin records payouts and refunds; the app executes none.
- **Audit:** every admin change to settings, terms, users, KYC, orders and cases writes `audit_log` with actor, action, target, before and after.
- **Error transport:** a failed RPC raises `RAISE EXCEPTION '<CODE>'` (SQLSTATE `P0001`), so the **message is the symbolic code** from section 11. Dart maps the message to `AppException(code)`. PostgREST delivery to a real client still needs one integration test before Phase 2 ends (section 12, item 13).
- **Retry safety:** `create_booking_request` and `submit_payment_proof` accept an optional `p_idempotency_key uuid`. A repeat with the same key by the same caller and operation returns the original result. PLANNED for Phase 2 (section 12, item 12).

## 2. Data model

### 2.1 Tables

| Table | Purpose | Status |
| --- | --- | --- |
| `profiles` | Public-facing account state: `id`, `display_name`, `role` (`user`/`admin`), `status` (`active`/`suspended`/`deleted`), `kyc_status` (`none`/`pending`/`verified`/`rejected`), timestamps. `id` references `auth.users`. | IMPLEMENTED (+ DELTA: FK, `avatar_path`) |
| `profile_private` | Owner and admin only: `user_id`, `phone`, `area`, `payout_details` (jsonb). | IMPLEMENTED (+ PLANNED `full_name`) |
| `kyc_submissions` | `id_path`, `face_path`, `status`, `reason`, `reviewed_by`, timestamps. Admin read only. | IMPLEMENTED |
| `items` | `id`, `lender_id`, `title`, `description`, `daily_rate`, `declared_value`, `pickup_area`, `status` (`draft`/`active`/`paused`), `category`, `condition`, `rules`, `photo_paths text[]` (1 to 5). | IMPLEMENTED (+ PLANNED `deleted_at`) |
| `item_pickup_details` | Exact address and instructions. Owner and admin only until the booking gate opens. | IMPLEMENTED |
| `bookings` | See 2.2. | IMPLEMENTED (+ DELTA `min_deposit_amount`) |
| `terms_documents` | `audience`, `title`, `version`, `content`, `status`, `is_active`, `published_at`, `archived_at`. | IMPLEMENTED (+ PLANNED `reviewed_by`, `reviewed_at`) |
| `booking_terms` | The three terms versions snapshotted on a booking: `(booking_id, audience, terms_document_id)`, one row per audience. | IMPLEMENTED |
| `terms_acceptances` | `booking_id`, `user_id`, `role`, `terms_document_id`, `accepted_version`, `accepted_at` (server), `app_version`. Immutable. | IMPLEMENTED (+ DELTA: general terms row) |
| `booking_payments` | `proof_path`, `reference`, `status` (`submitted`/`verified`/`rejected`), `amount_received`, `reason`, reviewer. | IMPLEMENTED (+ DELTA `channel`) |
| `handover_records` | `stage` (`pickup`/`return`), item photos, checklist, borrower face and ID photo paths, `no_issues`, `note`. Admin read only. | IMPLEMENTED |
| `booking_handover_codes` | `booking_id`, `nonce`, `code_hash`, `attempts`, `locked_at`, `used_at`, `reset_count`. Table name proposed; RPC behaviour in section 8 is the contract. | PLANNED |
| `receipt_confirmations` | Borrower receipt and condition note. | IMPLEMENTED |
| `damage_reports` | Renter claim: description, photo paths, `claimed_amount`, `status` (`open`/`resolved`/`escalated`), `escalated_at`. | IMPLEMENTED (+ PLANNED `escalated_at`) |
| `ledger_entries` | `kind` (`lender_earning`/`deposit_refund`), `amount`, `status` (`on_hold`/`due`/`paid`), `reference`, `paid_at`. | IMPLEMENTED |
| `app_settings` | `key`, `value jsonb`. Admin write through RPC only. | IMPLEMENTED (+ DELTA new key) |
| `notifications` | Recipient-only `event`, `booking_id`, `read_at`; realtime. | IMPLEMENTED |
| `audit_log` | Append through RPCs; admin read. | IMPLEMENTED |
| `reports` | Reports against an item or user. | IMPLEMENTED |
| `reviews` | Private foundation only; write contract is DEFERRED. | IMPLEMENTED (read only) |
| `idempotency_keys` | `user_id`, `operation`, `key`, `result`. | PLANNED |

Helpers and views: `is_admin()`, `is_active_user()`, `can_rent()`, `item_is_public(item_id)`, view `admin_booking_attention`. They are policy helpers, not data projections.

### 2.2 `bookings` columns

Identity and dates: `id`, `item_id`, `lender_id`, `borrower_id`, `start_date`, `end_date`, `rental_days` (generated), `status` (one of the 12 below).

Snapshot (all set together or all null): `commission_rate`, `deposit_rate`, `min_deposit_amount` (DELTA), `agreed_daily_rate`, `declared_value_snapshot`, `rental_fee`, `deposit_amount`, `commission_amount`, `lender_earning`, `snapshot_recorded_at`. Immutable after creation. Legacy rows without a snapshot are never back-filled.

Workflow: `expires_at`, `receipt_confirmed_at`, `returned_at`, `decline_reason`, `is_overdue` (derived flag set by a job, not a status), `terms_version_ids uuid[]` (kept for compatibility, validated against `booking_terms`).

**The 12 statuses** (no others): `requested`, `declined`, `expired`, `cancelled`, `renter_accepted`, `awaiting_payment`, `payment_submitted`, `payment_verified`, `handed_over`, `returned`, `completed`, `disputed`.

## 3. Business rules

### 3.1 Settings (`app_settings`, admin-set, never hard-coded)

| Key | Type | Meaning | Initial value |
| --- | --- | --- | --- |
| `commission_rate` | number 0–1, 4 dp | Sapati share of the rental fee | **0.1000** (approved) |
| `deposit_rate` | number 0–1, 4 dp | Deposit as a share of declared value | **0.2000** (approved) |
| `min_deposit_amount` | whole NPR ≥ 0 | Fixed minimum deposit for low-value items. Must be ≤ `min_declared_value`. | set by admin; not seeded |
| `late_fee_multiplier` | number ≥ 0 | Late fee multiplier | **1.5** (approved; not applied yet) |
| `return_grace_hours` | number ≥ 0 | Grace after `end_date` before a return is late or non-return | set by admin |
| `legal_action_period_days` | number > 0 | Days before a non-return case is marked escalated | set by admin |
| `request_expiry_hours` | number > 0 | Time before an unanswered request expires | set by admin |
| `min_declared_value` | whole NPR ≥ 0 | Smallest declared value allowed for a listing | set by admin |
| `auto_approve_orders` | boolean | Move to `awaiting_payment` automatically when both IDs are verified | set by admin |

- Migrations seed only the three approved values. Anything unset makes the dependent RPC fail with `SETTING_UNAVAILABLE`; it never falls back to `0`.
- Dev and demo databases may set the rest in `supabase/seed/seed.sql` (suggested: grace 24 h, legal period 14 days, expiry 48 h, minimum declared value 2,000, auto-approve on). Migrations must not.
- Changes apply only to bookings created afterwards.

### 3.2 ID verification gate (supervisor decision)

ID is required for everyone before the first request. The user submits an ID, an admin verifies or declines it, and once verified the request moves ahead.

| Moment | Rule |
| --- | --- |
| No ID submitted (`kyc_status = none`) | Blocks `create_booking_request`, publishing a listing and `renter_decide_booking` accept, with `KYC_REQUIRED`. |
| ID submitted (`pending`) | The request can be created and the Renter can accept it. The order waits in the admin ID queue. No payment instructions are shown. |
| Admin verifies | `admin_review_kyc` sets `verified`. When **both** parties are verified, the order moves to `awaiting_payment` (automatically if `auto_approve_orders` is on, otherwise through `admin_approve_order`). |
| Admin declines | `admin_review_kyc` sets `rejected` with a reason. The user sees the reason and may resubmit. The order stays where it is and cannot reach payment. |
| Stuck order | An admin may decline a waiting order with a reason (`admin_approve_order` with `p_approve = false`, result `cancelled`). |

"Verified" always means "checked by an admin". No automatic face matching is claimed.

### 3.3 Payments

- Channels: `esewa`, `khalti`, `bank`. The app shows a **static QR** for each; every payment goes to the Sapati company account, also in the demo.
- The Borrower pays `rental_fee + deposit_amount`, uploads a screenshot and a payment reference, and selects the channel.
- The admin compares the amount with the snapshot (`AMOUNT_MISMATCH` otherwise) and verifies or rejects with a reason. A rejected Borrower may resubmit.

### 3.4 Shared money fixtures (`shared/fixtures/money_cases.json`)

Dart `money.dart` and the SQL calculator must both match every row. Rates are given as basis points.

| Case | Days | Daily | Declared | Comm bps | Dep bps | Min deposit | Fee | Deposit | Commission | Earning | Borrower pays |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| approved_three_days | 3 | 3,500 | 160,000 | 1000 | 2000 | 0 | 10,500 | 32,000 | 1,050 | 9,450 | 42,500 |
| low_value_min_applies | 1 | 100 | 2,000 | 1000 | 2000 | 1,000 | 100 | 1,000 | 10 | 90 | 1,100 |
| low_value_min_not_needed | 1 | 100 | 2,000 | 1000 | 2000 | 300 | 100 | 400 | 10 | 90 | 500 |
| approved_boundary | 1 | 5 | 5 | 1000 | 2000 | 0 | 5 | 1 | 1 | 4 | 6 |
| below_half | 1 | 4 | 2 | 1000 | 2000 | 0 | 4 | 0 | 0 | 4 | 4 |
| above_half | 1 | 6 | 3 | 1000 | 2000 | 0 | 6 | 1 | 1 | 5 | 7 |

Also required: invalid cases (zero days, negative, fractional, rate above 100%, overflow) must be rejected by both implementations. Late-fee cases are added when the policy is approved.

## 4. Booking lifecycle

Every transition is an RPC (or a scheduled job) that checks caller, current status and guards. The app never writes `status` directly.

| # | From | Trigger | To | Caller and guards | Status |
| --- | --- | --- | --- | --- | --- |
| 1 | new | `create_booking_request` | `requested` | Borrower; ID submitted (`pending` or `verified`), not suspended; item active; not own item; dates free; settings and terms available; snapshot taken | IMPLEMENTED |
| 2 | `requested` | `renter_decide_booking` (decline) | `declined` | Renter | IMPLEMENTED |
| 3 | `requested` | scheduled expiry | `expired` | System after `request_expiry_hours` | IMPLEMENTED (job not scheduled) |
| 4 | `requested` / `renter_accepted` / `awaiting_payment` | `cancel_booking` | `cancelled` | Borrower, before payment is submitted | PLANNED |
| 5 | `requested` | `renter_decide_booking` (accept) | `renter_accepted` | Renter ID submitted; renter terms ticked and version matches snapshot; dates still free. Overlapping pending requests are auto-declined with reason `dates_taken`. | IMPLEMENTED (+ DELTA auto-decline) |
| 6 | `renter_accepted` | auto-approval or `admin_approve_order` (approve) | `awaiting_payment` | Both IDs `verified`; neither user suspended | IMPLEMENTED |
| 7 | `renter_accepted` | `admin_approve_order` (decline) | `cancelled` | Admin with reason | DELTA |
| 8 | `awaiting_payment` | `submit_payment_proof` | `payment_submitted` | Borrower; borrower terms ticked and matching; proof file, reference and channel | IMPLEMENTED (+ DELTA `p_channel`) |
| 9 | `payment_submitted` | `admin_verify_payment` (approve) | `payment_verified` | Admin; amount equals `rental_fee + deposit_amount`; handover code prepared; contact details unlock for the two parties | PLANNED |
| 10 | `payment_submitted` | `admin_verify_payment` (reject) | `awaiting_payment` | Admin with reason; Borrower may resubmit | PLANNED |
| 11 | `payment_verified` | `record_handover` | `handed_over` | Renter; correct unused code; item photos, checklist, Borrower face photo and original ID photo | PLANNED |
| 12 | `handed_over` | `confirm_receipt` | stays `handed_over` | Borrower confirms or flags a concern to admin | IMPLEMENTED |
| 13 | `handed_over` | `record_return` | `returned` | Renter; return photos; no-issues flag | IMPLEMENTED |
| 14 | `handed_over` | scheduled job | `disputed` | System after `end_date + return_grace_hours` with no return; sets `is_overdue`; earning on hold | PLANNED |
| 15 | `returned` | `report_damage` | stays `returned` | Renter files an open damage report with evidence; it appears in `admin_booking_attention` | IMPLEMENTED |
| 16 | `returned` | `admin_resolve_case` (`open_dispute`) | `disputed` | Admin starts the review | PLANNED |
| 17 | `returned` | `settle_booking` | `completed` | Admin; verified payment, evidence and terms present; no open case; returned on or before `end_date`; writes 2 ledger entries; idempotent | IMPLEMENTED (late returns return `LATE_RULE_NOT_APPROVED`) |
| 18 | `returned` / `disputed` | `admin_resolve_case` (`no_deduction`, `deduct`, `escalate`) | `completed`, or case escalated | Admin decides a deduction up to the deposit; excess is a recoverable claim handled offline; `escalate` sets `escalated_at` after `legal_action_period_days` | PLANNED |

**Overdue** is a derived flag, never a status. **Escalated** is a timestamp on the case, never a status.

## 5. RPC specification

Parameter names use the `p_` prefix. Every RPC is `SECURITY DEFINER` with an empty `search_path`, granted to `authenticated` only (never `anon`), and returns a narrow JSON object.

### 5.1 The 16 plan RPCs

| RPC | Caller | Arguments | Returns | Errors | Status |
| --- | --- | --- | --- | --- | --- |
| `create_booking_request` | Borrower | `p_item_id uuid`, `p_start_date date`, `p_end_date date`, `p_idempotency_key uuid?` | Booking summary with snapshots | `NOT_AUTHENTICATED`, `ACCOUNT_RESTRICTED`, `KYC_REQUIRED`, `OWN_ITEM`, `ITEM_UNAVAILABLE`, `INVALID_DATES`, `DATES_TAKEN`, `DUPLICATE_REQUEST`, `SETTING_UNAVAILABLE`, `TERMS_UNAVAILABLE`, `INVALID_MONEY` | IMPLEMENTED (+ DELTA idempotency, min deposit, open-ended availability) |
| `renter_decide_booking` | Renter of the booking | `p_booking_id uuid`, `p_accept boolean`, `p_terms_accepted boolean`, `p_terms_id uuid?`, `p_reason text?`, `p_app_version text?` | `{id, status}` | `NOT_ALLOWED`, `INVALID_STATE`, `KYC_REQUIRED`, `TERMS_NOT_ACCEPTED`, `TERMS_VERSION_MISMATCH`, `DATES_TAKEN`, `ITEM_UNAVAILABLE` | IMPLEMENTED |
| `admin_approve_order` | Admin | `p_booking_id uuid`, `p_approve boolean`, `p_reason text?` | `{id, status}` | `NOT_ADMIN`, `INVALID_STATE`, `KYC_NOT_VERIFIED`, `REASON_REQUIRED` | DELTA (decline path) |
| `submit_payment_proof` | Borrower | `p_booking_id uuid`, `p_terms_accepted boolean`, `p_terms_id uuid`, `p_proof_path text`, `p_reference text`, `p_channel text`, `p_app_version text?`, `p_idempotency_key uuid?` | `{id, status, payment_id}` | `NOT_ALLOWED`, `INVALID_STATE`, `KYC_NOT_VERIFIED`, `TERMS_NOT_ACCEPTED`, `TERMS_VERSION_MISMATCH`, `PROOF_MISSING`, `INVALID_VALUE` | DELTA (`p_channel`) |
| `admin_verify_payment` | Admin | `p_booking_id uuid`, `p_approve boolean`, `p_amount_received integer`, `p_reason text?` | `{id, status, payment_status}`; never the code | `NOT_ADMIN`, `INVALID_STATE`, `AMOUNT_MISMATCH`, `REASON_REQUIRED` | PLANNED |
| `record_handover` | Renter of the booking | `p_booking_id uuid`, `p_code text`, `p_item_photo_paths text[]`, `p_checklist jsonb`, `p_borrower_face_path text`, `p_borrower_id_photo_path text` | `{id, status, handover_id}` | `NOT_ALLOWED`, `INVALID_STATE`, `CODE_INVALID`, `CODE_LOCKED`, `CODE_USED`, `EVIDENCE_MISSING` | PLANNED |
| `confirm_receipt` | Borrower | `p_booking_id uuid`, `p_ok boolean`, `p_note text?` | `{id, status, receipt_confirmed_at, condition_ok}` | `NOT_ALLOWED`, `INVALID_STATE`, `NOTE_REQUIRED`, `INVALID_VALUE` | IMPLEMENTED |
| `record_return` | Renter | `p_booking_id uuid`, `p_return_photo_paths text[]`, `p_no_issues boolean`, `p_note text?` | `{id, status, returned_at}` | `NOT_ALLOWED`, `INVALID_STATE`, `EVIDENCE_MISSING` | IMPLEMENTED |
| `report_damage` | Renter | `p_booking_id uuid`, `p_description text`, `p_photo_paths text[]`, `p_claimed_amount integer` | `{report_id, status, booking_status}` | `NOT_ALLOWED`, `INVALID_STATE`, `EVIDENCE_MISSING`, `INVALID_VALUE` | IMPLEMENTED |
| `settle_booking` | Admin | `p_booking_id uuid` | `{id, status, already_settled, ledger[]}` | `NOT_ADMIN`, `INVALID_STATE`, `OPEN_CASE_EXISTS`, `PAYMENT_NOT_VERIFIED`, `HANDOVER_MISSING`, `RETURN_EVIDENCE_MISSING`, `TERMS_NOT_ACCEPTED`, `LATE_RULE_NOT_APPROVED`, `LEDGER_MISMATCH` | IMPLEMENTED |
| `admin_resolve_case` | Admin | `p_booking_id uuid`, `p_decision text` (`open_dispute`, `no_deduction`, `deduct`, `escalate`), `p_deduction_amount integer?`, `p_note text` | Decision, booking status, ledger summary | `NOT_ADMIN`, `INVALID_STATE`, `INVALID_VALUE`, `NOTE_REQUIRED` | PLANNED |
| `admin_review_kyc` | Admin | `p_user_id uuid`, `p_decision text` (`verified`/`rejected`), `p_reason text?` | `{user_id, kyc_status}` | `NOT_ADMIN`, `INVALID_VALUE`, `REASON_REQUIRED`, `INVALID_STATE`, `EVIDENCE_MISSING` | IMPLEMENTED |
| `admin_update_setting` | Admin | `p_key text`, `p_value jsonb` | `{key, previous_value, value}` | `NOT_ADMIN`, `INVALID_KEY`, `INVALID_VALUE` | IMPLEMENTED (+ DELTA `min_deposit_amount`) |
| `admin_publish_terms` | Admin | `p_audience text`, `p_body text` | `{id, version, audience}` | `NOT_ADMIN`, `INVALID_VALUE` | IMPLEMENTED |
| `admin_set_user_status` | Admin | `p_user_id uuid`, `p_status text` (`active`/`suspended`), `p_reason text` | `{user_id, status}` | `NOT_ADMIN`, `CANNOT_TARGET_ADMIN`, `REASON_REQUIRED`, `INVALID_STATE`, `INVALID_VALUE` | IMPLEMENTED |
| `request_account_deletion` | Account owner | none | `{ok: true}` | `NOT_AUTHENTICATED`, `ACTIVE_BOOKINGS_EXIST`, `OPEN_CASE_EXISTS` | PLANNED |

### 5.2 Supplemental RPCs (approved names)

| RPC | Caller | Arguments | Returns | Status |
| --- | --- | --- | --- | --- |
| `submit_kyc` | User | `p_id_path text`, `p_face_path text` | `{submission_id, kyc_status}`. Both files must be the caller's own uploads in the `kyc` bucket and different from each other. | IMPLEMENTED |
| `get_my_kyc_status` | User | none | `{kyc_status, reason, submitted_at, reviewed_at}`; never file paths; `reason` only when rejected | IMPLEMENTED |
| `cancel_booking` | Borrower | `p_booking_id uuid`, `p_reason text?` | `{id, status}` | PLANNED |
| `get_blocked_dates` | Signed-in user | `p_item_id uuid` | Unavailable ranges `[{start_date, end_date}]` plus `blocked_from date?` for the open-ended case (section 6). No user ids. | PLANNED |
| `get_booking_contact` | Booking parties, admin | `p_booking_id uuid` | `{first_name, area, unlocked, phone?, exact_address?}`. Always returns first name and area; phone and address are null until `payment_verified`. No `CONTACT_LOCKED` error here. | PLANNED |
| `get_active_terms` | Signed-in user | `p_audience text` | `{id, audience, version, content, published_at}` | PLANNED |
| `get_handover_code` | Borrower only | `p_booking_id uuid` | `{code}` six digits; only in `payment_verified`, not used, not locked | PLANNED |
| `admin_reset_handover_code` | Admin | `p_booking_id uuid`, `p_reason text` | `{booking_id, reset_count}` | PLANNED |
| `admin_mark_ledger_paid` | Admin | `p_ledger_entry_id uuid`, `p_reference text`, `p_proof_path text?` | `{id, status, paid_at}` | PLANNED |
| `get_public_settings` | Signed-in user | none | Whitelisted keys only: `commission_rate`, `deposit_rate`, `min_deposit_amount`, `late_fee_multiplier`, `return_grace_hours`, `request_expiry_hours`, `min_declared_value` | PLANNED |

### 5.3 Direct reads (RLS, no RPC)

| Read | Who | Notes |
| --- | --- | --- |
| `items` | Anyone: active items of active, eligible owners. Owner: own items. Admin: all. | Never includes the exact pickup address. |
| `bookings` | Borrower, Renter of the booking, admin | Own bookings only. Phone and address come only from `get_booking_contact`. |
| `booking_terms`, `terms_acceptances`, `terms_documents` | Parties of the booking and admin; anyone for published terms | Parties can re-read the version they accepted, including archived text. |
| `profile_private` | Owner and admin | Never another user's. |
| `notifications` | Recipient only (`read_at` writable) | Realtime. |
| `ledger_entries` | Entry owner and admin | |
| `booking_payments` | The Borrower who submitted and admin | The Renter never sees payment proof. |
| `reports` | Reporter (insert, read own) and admin | |

Admin SELECT policies (through `is_admin()`) exist for profiles, profile_private, kyc_submissions, items, bookings, booking_payments, handover_records, damage_reports, ledger_entries, app_settings, terms_documents, audit_log and reports. Admin writes go only through RPCs.

## 6. Availability rules

- `prevent_double_booking` (GiST exclusion) is kept exactly as committed. It blocks overlapping inclusive ranges for the same item in `renter_accepted`, `awaiting_payment`, `payment_submitted`, `payment_verified`, `handed_over`, `returned` and `disputed`. `requested`, `declined`, `expired`, `cancelled` and `completed` do not block.
- `returned` keeps blocking its original dates until the admin completes the booking. `completed` releases them.
- Many `requested` bookings may coexist. The first accept wins; accepting one auto-declines overlapping pending requests with reason `dates_taken`, and a second accept fails with `DATES_TAKEN`.
- **Open-ended block:** the constraint cannot say "from today onward". So `create_booking_request` and `get_blocked_dates` also treat an item as unavailable from today while it has an overdue `handed_over` booking or any `disputed` booking.
- Pausing an item blocks new requests only. Existing accepted bookings continue.
- Deleting an item is a soft delete (`deleted_at`). It is refused while an accepted-or-later booking exists; pending requests are auto-declined.
- **Cancellation:** the Borrower may cancel from `requested`, `renter_accepted` and `awaiting_payment`, never from `payment_submitted`. The Renter may decline only from `requested`.

## 7. Terms acceptance

- Three audiences: `general`, `borrower`, `renter`. Exactly **one published and active version per audience** (partial unique index). Publishing a new version archives the previous one. Published and archived text is immutable.
- `create_booking_request` snapshots the three active versions into `booking_terms` (one row per audience). This is the canonical snapshot; `terms_version_ids` remains only for compatibility.
- **Renter tick:** inside `renter_decide_booking` (accept), after tapping Accept. **Borrower tick:** inside `submit_payment_proof`, before the proof is accepted. Each tick is one checkbox covering the role terms and the general terms.
- Each tick records an immutable `terms_acceptances` row with user, booking, terms id, accepted version, server time and app version. The server rejects the step when the flag is false or the document id is not the one snapshotted on the booking.
- A tick is a recorded acceptance, not a certified e-signature.
- Sapati's legal team reviews wording. `reviewed_by` and `reviewed_at` on `terms_documents` record the sign-off; terms stay labelled "Prototype terms, not legal advice" until then.

## 8. Handover code

- Generated when the admin approves a payment. The six-digit code is **derived**: `HMAC-SHA256(secret, booking_id || nonce)` read as a decimal number modulo 1,000,000, zero-padded. The secret lives in Supabase Vault and is readable only by security-definer functions. The plaintext code is never stored.
- `booking_handover_codes` stores the `nonce`, a `code_hash` (verifier), `attempts`, `locked_at`, `used_at` and `reset_count`.
- `get_handover_code` is callable only by the Borrower of the booking, only in `payment_verified`, and returns the derived code. The admin has no way to read it.
- `record_handover` recomputes and compares in constant time. A wrong code increments `attempts`; the fifth failure sets `locked_at` and returns `CODE_LOCKED`. Success sets `used_at`; a second use returns `CODE_USED`.
- `admin_reset_handover_code` rotates the nonce, clears `attempts` and `locked_at`, increments `reset_count` and audits the action.
- pgTAP must cover: wrong code, lock at five, reuse rejected, admin cannot read the code, non-Borrower cannot read it.

## 9. Account deletion and retention

- `profiles.id → auth.users ON DELETE CASCADE` is **dropped** in a follow-up migration so deleting the auth user cannot delete the profile.
- `request_account_deletion` refuses with `ACTIVE_BOOKINGS_EXIST` or `OPEN_CASE_EXISTS`. Otherwise it **anonymises** the profile: `display_name` becomes "Deleted user"; name, phone, area, avatar, payout details and KYC paths are cleared; KYC files are removed; items are soft-deleted; `status` becomes `deleted`.
- The `delete-user` Edge Function then deletes the auth user, using the service-role key from Edge Function secrets only.
- Bookings, ledger entries and audit rows keep pointing at the anonymised profile id.
- Handover ID and face photos follow the retention job (deleted a set number of days after an undisputed completion, never while a case is open). Sapati's legal team confirms the periods.
- Admin accounts cannot self-delete.

## 10. Storage and privacy

| Bucket | Visibility | Rule |
| --- | --- | --- |
| `item-photos` | public read | Path `<user_id>/<file>`; images only, under 5 MB; owner writes; referenced photos cannot be overwritten or deleted. |
| `avatars` | public read | PLANNED. Owner folder write, small images. |
| `kyc` | private | Path `<user_id>/<file>`; owner uploads; **admin read only**. |
| `handover` | private | Path `<uploader_id>/<booking_id>/<file>`; the Renter uploads during `payment_verified` or later; **admin read only**. Damage photos use the same bucket under a `damage/` file prefix. |
| `payment-proof` | private | Path `<borrower_id>/<booking_id>/<file>`; the Borrower uploads while `awaiting_payment` or `payment_submitted`; readable by the uploader and admin, never the Renter. |

- All buckets accept JPEG, PNG and WebP only, 5 MiB maximum.
- Private files are served only by short-lived signed URLs. Location metadata is stripped before upload.
- Phone numbers and exact pickup addresses are **server-gated** until `payment_verified`, for the two parties and admins only. Hiding widgets is never enough.
- Until `payment_verified`: the Borrower sees the item, its area and the Renter's first name; the Renter sees the Borrower's first name.
- Secrets: the apps use only the anon key. The service-role key exists only in Edge Function secrets and the lead's password manager.

## 11. Error codes

| Code | Meaning |
| --- | --- |
| `NOT_AUTHENTICATED`, `ACCOUNT_RESTRICTED` | Not signed in / suspended or deleted account |
| `NOT_ALLOWED`, `NOT_ADMIN`, `CANNOT_TARGET_ADMIN` | Not a party / not an admin / admin target forbidden |
| `KYC_REQUIRED`, `KYC_NOT_VERIFIED` | No ID submitted / not both verified |
| `INVALID_STATE`, `ITEM_UNAVAILABLE`, `OWN_ITEM` | Wrong status for the action / item not bookable / own item |
| `INVALID_DATES`, `DATES_TAKEN`, `DUPLICATE_REQUEST` | Bad range / dates reserved / identical live request |
| `TERMS_NOT_ACCEPTED`, `TERMS_VERSION_MISMATCH`, `TERMS_UNAVAILABLE` | Tick missing / not the snapshotted version / no published terms |
| `PROOF_MISSING`, `AMOUNT_MISMATCH` | No proof file / amount differs from the snapshot |
| `CODE_INVALID`, `CODE_LOCKED`, `CODE_USED` | Wrong, locked or already-used handover code |
| `EVIDENCE_MISSING`, `NOTE_REQUIRED`, `REASON_REQUIRED` | Required files or text missing |
| `OPEN_CASE_EXISTS`, `ACTIVE_BOOKINGS_EXIST` | Settlement or deletion blocked |
| `CONTACT_LOCKED` | Reserved. Direct address or phone requests before the gate opens. |
| `INVALID_KEY`, `INVALID_VALUE`, `INVALID_MONEY`, `SETTING_UNAVAILABLE` | Bad setting, input or money value / required setting missing |

Internal integrity codes may also appear. Clients show a generic message for them and log the code: `INVALID_SNAPSHOT`, `SNAPSHOT_IMMUTABLE`, `TERMS_SNAPSHOT_INCOMPLETE`, `TERMS_IMMUTABLE`, `LEGACY_RECONCILIATION_REQUIRED`, `PAYMENT_NOT_VERIFIED`, `HANDOVER_MISSING`, `RETURN_EVIDENCE_MISSING`, `LEDGER_MISMATCH`, `LATE_RULE_NOT_APPROVED`.

`ORDER_REJECTION_NOT_APPROVED` and `DELETION_NOT_APPROVED` exist in the current SQL and are **retired** by section 12 items 2 and 9.

## 12. Implementation deltas to close (Srijan unless stated)

The target is this contract. These changes bring the code on `srijan/backend` into line. Each becomes a follow-up migration or test; the initial migration is never edited.

| # | Delta | Owner |
| --- | --- | --- |
| 1 | Add `min_deposit_amount` to the `app_settings` whitelist, to `calculate_money`, to the booking snapshot columns and validity check, and add the rule `min_deposit_amount ≤ min_declared_value` in `admin_update_setting`. | Srijan |
| 2 | `admin_approve_order` with `p_approve = false`: cancel the booking with the reason instead of `ORDER_REJECTION_NOT_APPROVED`. | Srijan |
| 3 | `submit_payment_proof`: add `p_channel` and `booking_payments.channel` (`esewa`/`khalti`/`bank`). | Srijan |
| 4 | Record the general-terms acceptance with the same tick (second `terms_acceptances` row, role-compatible). | Srijan |
| 5 | Open-ended availability check in `create_booking_request` and the new `get_blocked_dates`; auto-decline overlapping requests on accept. | Srijan |
| 6 | Implement `admin_verify_payment`, the handover code table and RPCs (section 8), and `record_handover`. | Srijan |
| 7 | Implement `admin_resolve_case` (`open_dispute`, `no_deduction`, `deduct`, `escalate`) and `damage_reports.escalated_at`. | Srijan |
| 8 | Implement `cancel_booking`, `get_booking_contact`, `get_active_terms`, `admin_mark_ledger_paid`, `get_public_settings`. | Srijan |
| 9 | Drop the `profiles` → `auth.users` cascade and implement `request_account_deletion`. | Srijan |
| 10 | Scheduled jobs: expire requests, flag overdue, `handed_over → disputed` after grace, retention. | Srijan |
| 11 | Add `items.deleted_at`, `profiles.avatar_path`, `profile_private.full_name`, `terms_documents.reviewed_by` and `reviewed_at`, and the `avatars` bucket. | Srijan |
| 12 | Add `idempotency_keys` and the optional key arguments (Phase 2). | Srijan |
| 13 | Test error delivery through a real PostgREST client and confirm the message-equals-code convention. | Srijan + Smaran |
| 14 | Models and repository interfaces for Booking, Item, Profile, Ledger and Terms matching sections 2 to 5; `money.dart` and `money_cases.json` matching 1 and 3.4. | Smaran |
| 15 | Admin gate, ID queue, settings and terms screens built on the repository interfaces, with a "Minimum security deposit (NPR)" field. | Mohan |

## 13. Deferred (not part of the freeze)

- **Late-return policy:** late-day calculation, grace interaction, fee cap and where the fee goes. Proposed only: `late_days x agreed_daily_rate x late_fee_multiplier`, rounded half up, capped at the deposit, deducted from the deposit and paid entirely to the Renter. Needs supervisor approval. Until then `settle_booking` rejects late returns. Add the cases to the fixtures when approved (contract change, v1.1).
- **Reviews:** rating scale, public visibility and the write contract.
- **Notifications beyond booking events**, reminders and push.
- **Real payment gateway, escrow, insurance, automated KYC**, in-app chat, Nepali language, iOS release (future work in the report).

## 14. Ownership, approval and change log

| Owner | Responsibility under this contract |
| --- | --- |
| **Srijan** | Section 12 items 1 to 13 on `srijan/backend`; pgTAP and security tests; `docs/data-model.md`, `docs/security.md`, `docs/state-machine.md`. |
| **Smaran** | Models, repository interfaces, `money.dart`, `shared/fixtures/money_cases.json`; Borrower features on fakes until RPCs are merged; do not call PLANNED RPCs as live. |
| **Mohan** | Auth, profile and ID gate, admin panel; CODEOWNERS and merge gates; freeze process. |

### Freeze approval

- [ ] Mohan approves
- [ ] Smaran approves
- [ ] Srijan approves
- [ ] Tag `api-contract-v1.0` created after merge

### Change log

| Version | Date | Change | Approval |
| --- | --- | --- | --- |
| v0.1 | 2026-11-24 | Smaran's draft | Draft |
| v0.2 | 2026-11-24 | Reconciled with the plan and the committed SQL (Srijan) | Reviewed |
| v0.3 | 2026-11-24 | Financial rules approved: 20% deposit, 10% commission, 1.5x multiplier, basis points in Dart, half-up whole-NPR rounding | Mohan |
| **v1.0** | 2026-11-26 | Frozen. Adds minimum deposit, ID gate, payment channel, handover code design, availability, deletion and retention, terms, supplemental RPCs, error transport, implementation deltas; deferred late-fee policy. | Pending the three approvals above |
