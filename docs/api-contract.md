# API contract

**Owners: Smaran + Srijan. Frozen after Phase 0** (changes need a PR approved by all three).

Fill in, per RPC: name, params, result, errors, who may call it, status transition.
RPC names from the plan: `create_booking_request`, `renter_decide_booking` (terms_accepted flag), `admin_approve_order`,
`submit_payment_proof` (terms_accepted flag), `admin_verify_payment`, `record_handover`, `confirm_receipt`, `record_return`,
`report_damage`, `admin_resolve_case`, `settle_booking`, `admin_review_kyc`, `admin_update_setting`, `admin_publish_terms`,
`admin_set_user_status`, `request_account_deletion`.

Entities to define first: Booking, Item, Profile, Ledger, Terms.

Naming: in code and database use `lender_id` (the Renter) and `borrower_id`; the UI shows "Renter" and "Borrower".


# API contract

**Owners: Smaran + Srijan. Frozen after Phase 0** (changes need a PR approved by all three).

Status: **DRAFT v0.1** for review. Items marked **[PROPOSED]** are not in the plan and need agreement before the freeze.
Items marked **[DECIDE]** are open questions listed in section 9.

---

## 1. Conventions

| Topic | Rule |
| --- | --- |
| Naming | Database and JSON use `snake_case`. Dart uses `camelCase`. In code and database use `lender_id` (the Renter) and `borrower_id`; the UI shows "Renter" and "Borrower". |
| IDs | `uuid` everywhere. |
| Money | Whole NPR as integers. Never decimals. Rates are basis points (`1000` = 10%), late-fee multiplier is x100 (`150` = 1.5x). Formulas: plan section 4.4, implemented in `rental_core/money/money.dart` and mirrored in SQL; both tested against `shared/fixtures/money_cases.json`. |
| Dates | `date` type, `YYYY-MM-DD`, interpreted in Asia/Kathmandu. End date is inclusive (6 to 8 Nov = 3 days). |
| Timestamps | `timestamptz`, sent as ISO 8601 UTC. |
| Who changes data | Clients never write `bookings`, `ledger_entries`, `app_settings`, `terms_documents`, or the columns `role`, `status`, `kyc_status` directly. Every change goes through the RPCs below. |
| Calling an RPC | `supabase.rpc('name', params: {...})`. Parameters are prefixed `p_`. |
| Errors | The function raises an exception whose **message is exactly one code** from section 7 (for example `DATES_TAKEN`). Dart reads it from `PostgrestException.message` and maps it to a friendly message in `rental_core/errors`. |
| Idempotency | Calls that create a record take a client-generated `p_idempotency_key uuid`; repeating the call returns the original result. |
| Atomicity | Each RPC is one transaction. Status change, acceptance rows, ledger rows, notifications and audit rows are written together or not at all. |
| Audit | Every `admin_*` RPC writes to `audit_log` with before and after values. |
| Notifications | RPCs insert rows into `notifications` for the other party. Clients only read them (realtime) and mark their own as read. |

---

## 2. Enums

| Enum | Values |
| --- | --- |
| `user_role` | `user`, `admin` |
| `account_status` | `active`, `suspended`, `deleted` |
| `kyc_status` | `none`, `pending`, `verified`, `rejected` |
| `area` | `kathmandu`, `lalitpur`, `bhaktapur` |
| `terms_audience` | `general`, `borrower`, `renter` |
| `booking_status` | `requested`, `declined`, `expired`, `cancelled`, `renter_accepted`, `awaiting_payment`, `payment_submitted`, `payment_verified`, `handed_over`, `returned`, `completed`, `disputed` |
| `payment_status` | `submitted`, `verified`, `rejected` |
| `ledger_entry_type` **[PROPOSED]** | `rental_fee`, `commission`, `renter_earning`, `late_fee`, `damage_deduction`, `deposit_refund`, `claim_recoverable` |
| `ledger_status` **[PROPOSED]** | `on_hold`, `due`, `paid`, `cancelled` |

Overdue is **not** a status. It is the boolean flag `bookings.is_overdue`, set by a scheduled job. A disputed case that passes the legal action period gets `bookings.is_escalated = true` **[DECIDE]**.

---

## 3. Entities (shared models in `rental_data/lib/models`)

Hand-written immutable classes with `equatable`, `fromJson` and `toJson`. No code generation.

### 3.1 Profile

| Field | Type | Notes |
| --- | --- | --- |
| `id` | uuid | = auth user id |
| `full_name` | text | |
| `first_name` | text | Shown to the other party before payment is verified |
| `phone` | text | Hidden from the other party until `payment_verified` |
| `area` | `area` | |
| `avatar_url` | text? | |
| `role` | `user_role` | Not client-writable |
| `account_status` | `account_status` | Not client-writable |
| `kyc_status` | `kyc_status` | Not client-writable |
| `kyc_reject_reason` | text? | Shown to the user when rejected |
| `payout_details` | text? | Visible only to the account owner and admins |
| `created_at` | timestamptz | |

Never in the client model: `kyc_doc_path` (admin only, signed URL).

### 3.2 Item

| Field | Type | Notes |
| --- | --- | --- |
| `id` | uuid | |
| `lender_id` | uuid | |
| `category` | text | From a fixed category list |
| `title` | text | |
| `description` | text | |
| `condition` | text | |
| `declared_value` | int | NPR, at least `min_declared_value` |
| `daily_price` | int | NPR, at least 1 |
| `area` | `area` | Shown before payment |
| `photo_urls` | text[] | 1 to 5 |
| `rules` | text? | |
| `is_active` | bool | Paused when false |
| `created_at` | timestamptz | |

Exact pickup address and pickup note live in `item_pickup_details` (not in this model). They are returned only by `get_booking_contact` once the booking is `payment_verified` or later.

Derived for display (computed with `Money`, not stored on the item): deposit = `declared_value` x current `deposit_rate_bps`.

### 3.3 Booking

| Field | Type | Notes |
| --- | --- | --- |
| `id` | uuid | |
| `item_id` | uuid | |
| `lender_id` | uuid | Renter |
| `borrower_id` | uuid | |
| `start_date`, `end_date` | date | Inclusive |
| `status` | `booking_status` | Only RPCs change it |
| `days` | int | Snapshot |
| `daily_price` | int | Snapshot |
| `declared_value` | int | Snapshot |
| `rental_fee` | int | Snapshot, days x daily_price |
| `deposit` | int | Snapshot |
| `commission_rate_bps` | int | Snapshot |
| `deposit_rate_bps` | int | Snapshot |
| `commission_amount` | int | Snapshot |
| `renter_earning` | int | Snapshot, fee - commission |
| `late_fee_multiplier_x100` | int | **[PROPOSED]** snapshot so late fees are reproducible |
| `return_grace_hours` | int | **[PROPOSED]** snapshot |
| `terms_version_ids` | jsonb | `{general, borrower, renter}` version ids snapshotted at request time |
| `decline_reason` | text? | |
| `receipt_confirmed_at` | timestamptz? | Set by `confirm_receipt` (status stays `handed_over`) |
| `is_overdue` | bool | Set by scheduled job |
| `is_escalated` | bool | **[DECIDE]** |
| `has_damage_report` | bool | |
| `idempotency_key` | uuid | Unique with `borrower_id` |
| `created_at`, `updated_at` | timestamptz | |

Computed in Dart: `borrowerPays = rental_fee + deposit`.

### 3.4 Ledger (`ledger_entries`)

| Field | Type | Notes |
| --- | --- | --- |
| `id` | uuid | |
| `booking_id` | uuid | |
| `user_id` | uuid? | Who the money is due to or from |
| `entry_type` | `ledger_entry_type` | |
| `amount` | int | NPR, always positive; direction is given by the type |
| `status` | `ledger_status` | Only admins change it |
| `note` | text? | |
| `paid_reference` | text? | Offline payout or refund reference recorded by admin |
| `created_at`, `paid_at` | timestamptz | |

Smooth case example (plan worked example): `rental_fee` 10,500, `commission` 1,050, `renter_earning` 9,450 (due), `deposit_refund` 40,000 (due).

### 3.5 Terms

`TermsDocument`

| Field | Type | Notes |
| --- | --- | --- |
| `id` | uuid | |
| `audience` | `terms_audience` | |
| `version` | int | Increments on each edit |
| `body` | text | |
| `is_active` | bool | Exactly one active version per audience |
| `published_by` | uuid | |
| `created_at`, `archived_at` | timestamptz | |

`TermsAcceptance`

| Field | Type | Notes |
| --- | --- | --- |
| `id` | uuid | |
| `booking_id` | uuid | |
| `user_id` | uuid | |
| `role` | text | `renter` or `borrower` |
| `terms_id` | uuid | |
| `version` | int | |
| `accepted_at` | timestamptz | |
| `app_version` | text | |

### 3.6 Supporting models (shape agreed now, details with the feature)

`BookingPayment`, `HandoverRecord`, `DamageReport`, `AppSettings`, `AppNotification`, `Review`, `Report`.

---

## 4. Settings keys (`app_settings`, admin-edited, never hard-coded)

| Key | Type | Default | Unit |
| --- | --- | --- | --- |
| `commission_rate_bps` | int | 1000 | basis points (10%) |
| `deposit_rate_bps` | int | 2500 | basis points (25%) |
| `late_fee_multiplier_x100` | int | 150 | x100 (1.5x) |
| `return_grace_hours` | int | 24 | hours |
| `legal_action_period_days` | int | 14 | days |
| `request_expiry_hours` | int | 48 | hours |
| `min_declared_value` | int | 2000 | NPR |
| `auto_approve_orders` | bool | true | |

Defaults are placeholders to confirm with the supervisor.

---

## 5. Status machine

Full diagram and rules: `docs/state-machine.md` (agreed together with this contract). Summary of allowed transitions:

| # | From | To | RPC | Caller |
| --- | --- | --- | --- | --- |
| 1 | (new) | `requested` | `create_booking_request` | Borrower |
| 2a | `requested` | `declined` | `renter_decide_booking` (accept = false) | Renter |
| 2b | `requested` | `expired` | scheduled job (not callable by clients) | System |
| 2c | `requested`, `renter_accepted`, `awaiting_payment` | `cancelled` | `cancel_booking` **[PROPOSED]** | Borrower |
| 3 | `requested` | `renter_accepted` | `renter_decide_booking` (accept = true) | Renter |
| 4 | `renter_accepted` | `awaiting_payment` | `admin_approve_order`, or automatically inside transition 3 when both IDs are verified and `auto_approve_orders` is on | Admin / system |
| 4b | `renter_accepted` | `cancelled` | `admin_approve_order` (approve = false) | Admin |
| 5 | `awaiting_payment` | `payment_submitted` | `submit_payment_proof` | Borrower |
| 6a | `payment_submitted` | `payment_verified` | `admin_verify_payment` (approve = true) | Admin |
| 6b | `payment_submitted` | `awaiting_payment` | `admin_verify_payment` (approve = false, reason) so the Borrower can resubmit | Admin |
| 7 | `payment_verified` | `handed_over` | `record_handover` | Renter |
| 8 | `handed_over` | `handed_over` + `receipt_confirmed_at` | `confirm_receipt` | Borrower |
| 9 | `handed_over` | `returned` | `record_return` | Renter |
| 10a | `returned` | `completed` | `settle_booking` (smooth or late) | Admin |
| 10b | `returned` | `disputed` | `report_damage` | Renter |
| 11 | `returned`, `disputed` | `completed` or stays `disputed` | `admin_resolve_case` | Admin |

Every RPC checks the caller's role and the current status; any other combination raises `INVALID_STATE`.

---

## 6. RPC reference

Common checks for all non-admin RPCs: caller is signed in (`NOT_AUTHENTICATED`) and `account_status = 'active'` (`ACCOUNT_RESTRICTED`).

### 6.1 Booking flow

#### `create_booking_request`
| | |
| --- | --- |
| Caller | Borrower |
| Transition | (new) to `requested` |
| Params | `p_item_id uuid`, `p_start_date date`, `p_end_date date`, `p_idempotency_key uuid` |
| Returns | The new `bookings` row, including all snapshot columns |
| Server checks | Borrower `kyc_status` is not `none`; item active and not removed; not own item; start not in the past (Kathmandu date); end not before start; no accepted or later booking overlaps; no duplicate pending request by this borrower for overlapping dates. Computes every amount server-side and snapshots rates, settings and active terms ids. |
| Errors | `NOT_AUTHENTICATED`, `ACCOUNT_RESTRICTED`, `KYC_REQUIRED`, `ITEM_UNAVAILABLE`, `OWN_ITEM`, `INVALID_DATES`, `DATES_TAKEN`, `DUPLICATE_REQUEST` |

#### `renter_decide_booking`
| | |
| --- | --- |
| Caller | Renter of the booking |
| Transition | `requested` to `renter_accepted` (accept) or `declined` (decline) |
| Params | `p_booking_id uuid`, `p_accept bool`, `p_terms_accepted bool`, `p_terms_id uuid?`, `p_reason text?`, `p_app_version text?` |
| Returns | Updated booking row |
| Server checks | Caller is the booking's `lender_id`; status is `requested`; on accept: `p_terms_accepted` is true, `p_terms_id` equals the renter terms id snapshotted on the booking, renter `kyc_status` is not `none`, dates still free. Writes a `terms_acceptances` row. If both users are `verified` and `auto_approve_orders` is true, moves straight to `awaiting_payment` in the same transaction. On decline: stores `p_reason`. |
| Errors | `NOT_ALLOWED`, `INVALID_STATE`, `KYC_REQUIRED`, `TERMS_NOT_ACCEPTED`, `TERMS_VERSION_MISMATCH`, `DATES_TAKEN` |

#### `cancel_booking` **[PROPOSED]**
| | |
| --- | --- |
| Caller | Borrower of the booking |
| Transition | `requested` / `renter_accepted` / `awaiting_payment` to `cancelled` |
| Params | `p_booking_id uuid`, `p_reason text?` |
| Returns | Updated booking row |
| Errors | `NOT_ALLOWED`, `INVALID_STATE` |
| Note | The plan says the Borrower may cancel before payment but lists no RPC for it. |

#### `admin_approve_order`
| | |
| --- | --- |
| Caller | Admin |
| Transition | `renter_accepted` to `awaiting_payment` (approve) or `cancelled` (reject) |
| Params | `p_booking_id uuid`, `p_approve bool`, `p_reason text?` |
| Returns | Updated booking row |
| Server checks | Both users `verified` for approval; neither suspended; status is `renter_accepted` |
| Errors | `NOT_ADMIN`, `INVALID_STATE`, `KYC_NOT_VERIFIED` |

#### `submit_payment_proof`
| | |
| --- | --- |
| Caller | Borrower of the booking |
| Transition | `awaiting_payment` to `payment_submitted` |
| Params | `p_booking_id uuid`, `p_terms_accepted bool`, `p_terms_id uuid`, `p_proof_path text`, `p_reference text`, `p_app_version text?`, `p_idempotency_key uuid` |
| Returns | Updated booking row and the `booking_payments` row |
| Server checks | Caller is the booking's `borrower_id`; status is `awaiting_payment`; `p_terms_accepted` true and `p_terms_id` equals the borrower terms id on the booking; proof file exists in the caller's folder of the private payment-proof bucket; reference not empty. Writes a `terms_acceptances` row. |
| Errors | `NOT_ALLOWED`, `INVALID_STATE`, `TERMS_NOT_ACCEPTED`, `TERMS_VERSION_MISMATCH`, `PROOF_MISSING` |

#### `admin_verify_payment`
| | |
| --- | --- |
| Caller | Admin |
| Transition | `payment_submitted` to `payment_verified` (approve) or back to `awaiting_payment` (reject) |
| Params | `p_booking_id uuid`, `p_approve bool`, `p_amount_received int`, `p_reason text?` |
| Returns | Updated booking row. **Never returns the handover code.** |
| Server checks | `p_amount_received` equals `rental_fee + deposit` from the snapshot; on approve, generates the 6-digit handover code, creates the `handover_codes` row (see section 9, question 1) and notifies the Borrower. On reject, a reason is required and the Borrower is notified. |
| Errors | `NOT_ADMIN`, `INVALID_STATE`, `AMOUNT_MISMATCH`, `REASON_REQUIRED` |

#### `get_handover_code` **[PROPOSED]**
| | |
| --- | --- |
| Caller | Borrower of the booking |
| Params | `p_booking_id uuid` |
| Returns | `{ code: text }` (6 digits) |
| Server checks | Caller is the borrower; status is `payment_verified` or `handed_over`; code not yet used |
| Errors | `NOT_ALLOWED`, `INVALID_STATE` |
| Note | Needed because the admin triggers code generation, so the Borrower cannot receive the code in an RPC response. See section 9, question 1. |

#### `record_handover`
| | |
| --- | --- |
| Caller | Renter of the booking |
| Transition | `payment_verified` to `handed_over` |
| Params | `p_booking_id uuid`, `p_code text`, `p_item_photo_paths text[]`, `p_checklist jsonb`, `p_borrower_face_path text`, `p_borrower_id_photo_path text` |
| Returns | Updated booking row and the `handover_records` row |
| Server checks | Caller is the `lender_id`; status is `payment_verified`; code matches and is unused; attempts below 5; all evidence paths exist in the caller's folder of the private handover bucket; evidence timestamps set by the server |
| Errors | `NOT_ALLOWED`, `INVALID_STATE`, `CODE_INVALID`, `CODE_LOCKED`, `CODE_USED`, `EVIDENCE_MISSING` |

#### `confirm_receipt`
| | |
| --- | --- |
| Caller | Borrower of the booking |
| Transition | none (sets `receipt_confirmed_at`), or flags a dispute to admin |
| Params | `p_booking_id uuid`, `p_ok bool`, `p_note text?` |
| Returns | Updated booking row |
| Server checks | Caller is the borrower; status is `handed_over`. If `p_ok` is false, a note is required and an admin notification is created. |
| Errors | `NOT_ALLOWED`, `INVALID_STATE`, `NOTE_REQUIRED` |

#### `record_return`
| | |
| --- | --- |
| Caller | Renter of the booking |
| Transition | `handed_over` to `returned` |
| Params | `p_booking_id uuid`, `p_return_photo_paths text[]`, `p_no_issues bool`, `p_note text?` |
| Returns | Updated booking row |
| Server checks | Caller is the `lender_id`; status is `handed_over`; at least one return photo. If `p_no_issues` is false the renter must call `report_damage` afterwards. |
| Errors | `NOT_ALLOWED`, `INVALID_STATE`, `EVIDENCE_MISSING` |

#### `report_damage`
| | |
| --- | --- |
| Caller | Renter of the booking |
| Transition | `returned` to `disputed` |
| Params | `p_booking_id uuid`, `p_description text`, `p_photo_paths text[]`, `p_claimed_amount int` |
| Returns | The `damage_reports` row |
| Server checks | Caller is the `lender_id`; status is `returned`; at least one photo; `p_claimed_amount` is at least 1 |
| Errors | `NOT_ALLOWED`, `INVALID_STATE`, `EVIDENCE_MISSING`, `INVALID_VALUE` |

### 6.2 Settlement and money (admin)

#### `settle_booking`
| | |
| --- | --- |
| Caller | Admin |
| Transition | `returned` to `completed` (no damage report open) |
| Params | `p_booking_id uuid`, `p_returned_at timestamptz?` (defaults to the recorded return time) |
| Returns | Updated booking row and the ledger entries created |
| Server checks | Status is `returned` and no open damage report. Computes any late fee with the same rule as `Money.lateDays` and `Money.lateFee` (capped at the deposit). In the same transaction writes ledger entries: `rental_fee`, `commission`, `renter_earning` (including the late fee), and `deposit_refund` (deposit minus late fee). |
| Errors | `NOT_ADMIN`, `INVALID_STATE`, `OPEN_CASE_EXISTS` |

#### `admin_resolve_case`
| | |
| --- | --- |
| Caller | Admin |
| Transition | `returned` or `disputed` to `completed`, or remains `disputed` (escalated) |
| Params | `p_booking_id uuid`, `p_decision text` (`no_deduction`, `deduct_from_deposit`, `escalate`), `p_deduction_amount int?`, `p_note text` |
| Returns | Updated booking row and the ledger entries created |
| Server checks | Status is `returned` or `disputed`; deduction does not exceed the deposit; any excess is recorded as a `claim_recoverable` entry. A note is required. |
| Errors | `NOT_ADMIN`, `INVALID_STATE`, `INVALID_VALUE`, `NOTE_REQUIRED` |

#### `admin_mark_ledger_paid` **[PROPOSED]**
| | |
| --- | --- |
| Caller | Admin |
| Params | `p_ledger_entry_id uuid`, `p_paid_reference text` |
| Returns | The updated ledger entry |
| Errors | `NOT_ADMIN`, `INVALID_STATE` |
| Note | The plan has admins record payouts and refunds but no RPC for it. |

### 6.3 Users, ID and platform

#### `admin_review_kyc`
| | |
| --- | --- |
| Caller | Admin |
| Params | `p_user_id uuid`, `p_decision text` (`verified` or `rejected`), `p_reason text?` |
| Returns | The updated profile (`kyc_status`) |
| Server checks | Current `kyc_status` is `pending`; reason required when rejecting. Notifies the user. |
| Errors | `NOT_ADMIN`, `INVALID_STATE`, `REASON_REQUIRED` |

#### `admin_update_setting`
| | |
| --- | --- |
| Caller | Admin |
| Params | `p_key text`, `p_value jsonb` |
| Returns | `{ key, old_value, new_value }` |
| Server checks | Key is one of section 4; value type and range valid (rates 0 to 3000 bps for commission, 0 to 10000 for deposit; hours and days at least 0; `min_declared_value` at least 1). Applies to **new requests only**. Writes `audit_log`. |
| Errors | `NOT_ADMIN`, `INVALID_KEY`, `INVALID_VALUE` |

#### `admin_publish_terms`
| | |
| --- | --- |
| Caller | Admin |
| Params | `p_audience terms_audience`, `p_body text` |
| Returns | The new `TermsDocument` |
| Server checks | Body not empty; creates version + 1 and deactivates the previous active version in one transaction. Existing bookings keep the version they snapshotted. Writes `audit_log`. |
| Errors | `NOT_ADMIN`, `INVALID_VALUE` |

#### `admin_set_user_status`
| | |
| --- | --- |
| Caller | Admin |
| Params | `p_user_id uuid`, `p_status account_status` (`active` or `suspended`; `deleted` only through `request_account_deletion`), `p_reason text` |
| Returns | The updated profile |
| Server checks | Target is not an admin; reason required. On suspend: pauses the user's listings, cancels their requests that have not reached payment, leaves bookings that are paid or later for admin review. Writes `audit_log`. |
| Errors | `NOT_ADMIN`, `CANNOT_TARGET_ADMIN`, `REASON_REQUIRED` |

#### `request_account_deletion`
| | |
| --- | --- |
| Caller | Any user, for their own account |
| Params | none |
| Returns | `{ ok: true }` |
| Server checks | Blocked while the user has active bookings (any status from `requested` to `returned`) or open cases. Soft delete: removes personal fields and private files, anonymises the profile, keeps bookings and ledger. The Edge Function `delete-user` then deletes the auth user. |
| Errors | `ACTIVE_BOOKINGS_EXIST`, `OPEN_CASE_EXISTS` |

### 6.4 Read-side contract (not RPCs unless stated)

| Name | Type | Used by | Returns |
| --- | --- | --- | --- |
| Explore feed | Table query on `items` (RLS) | Borrower explore | Active, not removed items. Keyset pagination: order by `created_at desc, id desc`, page size 12, "older than last item". Filters: `area`, `category`, price range, `title ilike`. Selects only card columns. |
| `get_blocked_dates` **[PROPOSED]** | RPC | Date picker | `p_item_id uuid` returns the dates of bookings in status `renter_accepted` or later that block the item. |
| `get_booking_contact` **[PROPOSED]** | RPC | Both parties | `p_booking_id uuid` returns the other party's phone and the exact pickup address, **only** if the caller is a party and status is `payment_verified` or later. Otherwise raises `CONTACT_LOCKED`. |
| `get_active_terms` **[PROPOSED]** | RPC or view | Terms sheets | `p_audience` returns the active `TermsDocument`. |
| My bookings | Table query on `bookings` (RLS) | Borrower and Renter | Rows where the caller is borrower or lender; realtime subscription on the same filter. |
| Notifications | Table query and realtime on `notifications` | Everyone | Own rows only; marking read updates own `is_read` through RLS. |
| Ledger and earnings | Table query on `ledger_entries` (RLS) | Renter earnings, admin | Own rows for users; all rows for admins. |

---

## 7. Error codes

Message text of the raised exception. The app maps each code to a friendly message in `rental_core/errors`.

| Code | Meaning |
| --- | --- |
| `NOT_AUTHENTICATED` | Not signed in |
| `NOT_ALLOWED` | Caller is not the right party for this booking |
| `NOT_ADMIN` | Admin only |
| `CANNOT_TARGET_ADMIN` | Admins cannot be suspended through the app |
| `ACCOUNT_RESTRICTED` | Caller is suspended or deleted |
| `KYC_REQUIRED` | ID not submitted yet |
| `KYC_NOT_VERIFIED` | Both IDs must be verified for this step |
| `INVALID_STATE` | Booking status does not allow this action |
| `ITEM_UNAVAILABLE` | Item paused, removed or missing |
| `OWN_ITEM` | Cannot rent your own item |
| `INVALID_DATES` | Past start date or end before start |
| `DATES_TAKEN` | Overlaps a confirmed booking |
| `DUPLICATE_REQUEST` | Same borrower already has a pending request for these dates |
| `TERMS_NOT_ACCEPTED` | Checkbox flag was false |
| `TERMS_VERSION_MISMATCH` | Version is not the one snapshotted on the booking |
| `PROOF_MISSING` | Payment proof file or reference missing |
| `AMOUNT_MISMATCH` | Amount received differs from fee + deposit |
| `CODE_INVALID` | Wrong handover code |
| `CODE_LOCKED` | 5 wrong attempts; admin must reset |
| `CODE_USED` | Handover code already used |
| `EVIDENCE_MISSING` | Required photos or checklist missing |
| `NOTE_REQUIRED`, `REASON_REQUIRED` | A text field is required |
| `OPEN_CASE_EXISTS` | A dispute or damage report is open |
| `ACTIVE_BOOKINGS_EXIST` | Account has active bookings |
| `CONTACT_LOCKED` | Contact details not yet unlocked |
| `INVALID_KEY`, `INVALID_VALUE` | Setting key or value not allowed |

---

## 8. Storage buckets

| Bucket | Visibility | Contents | Rules |
| --- | --- | --- | --- |
| `item-photos` | Public read | Listing photos | Images only, 5 MB max, path `uid/...` |
| `avatars` | Public read | Profile photos | Images only, 5 MB max, path `uid/...` |
| `kyc` | Private | ID photos | Uploader writes own folder; admins read through short-lived signed URLs |
| `payment-proof` | Private | Payment screenshots | Borrower writes own folder; parties and admins read via signed URL |
| `handover` | Private | Item, face and ID evidence photos | Renter writes own folder; admins only read |
| `damage` **[PROPOSED]** | Private | Return and damage photos | Renter writes own folder; parties and admins read via signed URL |

Photos are compressed on the phone to about 1080 px and under 300 KB, and location metadata is stripped.

---

## 9. Open questions (settle before the freeze)

1. **Handover code storage.** The plan says the code is stored hashed, but the Borrower must be able to see it, and the Admin (not the Borrower) triggers the generation. A hash cannot be shown. Proposal: store the 6-digit code in `handover_codes` readable only by the Borrower (RLS, through `get_handover_code`), with attempt counter and `used_at`, and drop the hash. A 6-digit hash is trivially brute-forced anyway, so protection comes from the attempt limit and RLS.
2. **Cancel RPC.** Add `cancel_booking` for transition 2c?
3. **Ledger payout RPC.** Add `admin_mark_ledger_paid`?
4. **Damage flow.** Keep `record_return` then `report_damage` as two calls, or one call with an optional damage payload?
5. **Escalation.** Is escalation a flag on the booking (`is_escalated`) or a separate case status?
6. **Late fee rule.** Late days = whole days after (end of the end date + `return_grace_hours`), part days round up; fee = late days x daily price x multiplier, capped at the deposit; no commission on the late fee. Confirm with the supervisor.
7. **Settings snapshot.** Also snapshot `late_fee_multiplier_x100` and `return_grace_hours` on the booking?
8. **Rate storage.** Basis points in `app_settings` (proposed) or percent as numeric?
9. **Money fixtures.** Srijan's SQL test loads `shared/fixtures/money_cases.json`; Smaran owns the file.

---

## 10. Change log

| Version | Date | Change | Approved by |
| --- | --- | --- | --- |
| 0.1 | 2026-11 | First draft | |