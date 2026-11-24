# API contract

**Owners: Smaran + Srijan. Frozen after Phase 0** (changes need a PR approved by all three, see CONTRIBUTING rule 4).

**Status: DRAFT v0.2, written by Srijan, waiting for Smaran's review.** Nothing below is agreed until Smaran and Mohan approve the PR.
Items marked **PROPOSED** are not in the plan's RPC list and need an explicit yes or no.

Naming: in code and database use `lender_id` (the Renter) and `borrower_id`; the UI shows "Renter" and "Borrower".
Dates are date-only, interpreted in `Asia/Kathmandu`. The **end date is inclusive** (6 to 8 Nov = 3 days).
All JSON keys are `snake_case` (the column names). Hand-written Dart models map them in `fromJson`.

Legend for the "Built" column: **live** = in the Phase 0 migrations and tested, **later** = function arrives in the phase shown.

---

## 1. How the apps talk to the database

| Need | Way | Notes |
| --- | --- | --- |
| Read your own profile, edit name / phone / area | table `profiles` (select, update) | Only `full_name`, `phone`, `area` are writable. |
| Read active listings, create / edit / pause / delete your listing | table `items` (select, insert, update) | "Delete" = update `status` to `deleted`. Clients never run SQL `delete`. |
| Read your bookings (as Renter or Borrower) | table `bookings` (select only) | Every change to a booking is an RPC below. |
| Read settings and terms | tables `app_settings`, `terms_documents` (select only) | Terms are also readable before sign-in. |
| Anything that changes a booking, ID status, settings or terms | RPC (`supabase.rpc(name, params: {...})`) | Server checks the caller and the current status. |
| Live updates | Realtime on `bookings` | Subscribe with a filter `lender_id=eq.<uid>` or `borrower_id=eq.<uid>`. RLS means you only receive your own rows. |
| Photos and files | Storage buckets, see section 5 | |

The Flutter screens never call Supabase directly. Smaran's repository interfaces are implemented by Srijan under
`packages/rental_data/lib/repositories/supabase/`.

## 2. Entities

### 2.1 Profile (table `profiles`)

| Field | Dart type | Notes |
| --- | --- | --- |
| `id` | `String` (uuid) | Same as the auth user id. |
| `role` | `String` | `user` or `admin`. Never writable by the app. |
| `status` | `String` | `active`, `suspended`, `deleted`. |
| `full_name`, `phone`, `area` | `String?` | `area` is one of Kathmandu, Lalitpur, Bhaktapur. Copied from sign-up metadata. |
| `kyc_status` | `String` | `not_submitted`, `pending`, `verified`, `rejected`. |
| `kyc_id_path`, `kyc_face_path` | `String?` | Paths in the private `kyc-documents` bucket. Only admins can open the files. |
| `kyc_rejection_reason` | `String?` | |
| `kyc_submitted_at`, `kyc_reviewed_at`, `deleted_at`, `created_at`, `updated_at` | `DateTime?` | |

Other people's profiles are read through `get_public_profiles` (name, area, verified badge only). A user can never read another
user's row in `profiles`.

### 2.2 Item (table `items`)

| Field | Dart type | Notes |
| --- | --- | --- |
| `id` | `String` | |
| `lender_id` | `String` | The Renter. |
| `title` | `String` | 3 to 100 characters. |
| `category` | `String` | `camera`, `projector`, `gaming`, `camping`, `tools`, `music`, `electronics`, `other`. |
| `description`, `rules` | `String` | 2000 / 1000 characters at most. May be empty. |
| `condition` | `String` | `new`, `like_new`, `good`, `fair`. |
| `daily_price` | `num` | NPR, above 0. |
| `declared_value` | `num` | NPR, above 0. The deposit is a percentage of this (`deposit_rate`). |
| `area` | `String` | Pickup area: Kathmandu, Lalitpur or Bhaktapur. The exact address is a later table (`item_pickup_details`) hidden until payment is verified. |
| `photo_paths` | `List<String>` | 1 to 5 paths in the public `item-photos` bucket. Public URL = `getPublicUrl(path)`. |
| `status` | `String` | `active`, `paused`, `deleted`. |
| `created_at`, `updated_at` | `DateTime` | |

Who sees what: everyone signed in sees `active` items. A Renter also sees their own `paused` items. `deleted` items are visible to admins only.

### 2.3 Booking (table `bookings`, read only for apps)

| Field | Dart type | Notes |
| --- | --- | --- |
| `id`, `item_id`, `lender_id`, `borrower_id` | `String` | |
| `start_date`, `end_date` | `DateTime` (date only) | End date inclusive. |
| `days` | `int` | Computed by the database: `end - start + 1`. Do not send it. |
| `status` | `String` | One of the 12 values in section 3. |
| `daily_price` | `num` | Snapshot of the item price when the request was made. |
| `rental_fee` | `num` | `days x daily_price`. The database rejects any other value. Matches `money.dart`. |
| `deposit_amount` | `num` | Refundable deposit, snapshot. |
| `commission_rate`, `deposit_rate` | `num` | Snapshots of `app_settings` (fractions, 0.10 = 10%). |
| `terms_version_ids` | `List<String>` | `terms_documents.id` values that applied when requested. |
| `decline_reason` | `String?` | |
| `expires_at` | `DateTime?` | A request nobody answers expires at this time. |
| `receipt_confirmed_at` | `DateTime?` | Borrower confirmed receipt (status stays `handed_over`). |
| `is_overdue` | `bool` | Derived flag set by a scheduled job. Not a status. |
| `created_at`, `updated_at` | `DateTime` | |

**Double booking:** the database refuses two bookings of one item whose dates overlap while both are in a date-blocking status
(`renter_accepted` and every later status except the ended ones: see section 3). A plain `requested` booking does **not** block dates.
`get_item_blocked_dates` returns exactly the blocked ranges.

### 2.4 Terms (table `terms_documents`)

| Field | Dart type | Notes |
| --- | --- | --- |
| `id` | `String` | |
| `kind` | `String` | `general`, `borrower`, `renter`. |
| `version` | `int` | 1, 2, 3 ... per kind. |
| `title`, `body` | `String` | Plain text. Seeded v1 texts are marked "prototype, not legal advice" (honesty rules 5 and 8). |
| `is_active` | `bool` | Exactly one active version per kind. |
| `published_by`, `published_at`, `created_at` | | |

A published version is immutable (edit or delete is rejected with `terms_immutable`). A new version is published by `admin_publish_terms`.

### 2.5 Setting (table `app_settings`)

`key` (text), `value` (jsonb), `description`, `updated_by`, `updated_at`.
Keys: `commission_rate` (0 to 1), `deposit_rate` (0 to 1), `auto_approve_orders` (bool), `request_expiry_hours` (number above 0).
**The seeded commission (0.10) and deposit (0.25) are placeholders.** The business notes decide the real values; an admin can change
them, and existing bookings keep the value they started with.

### 2.6 Ledger entry (table `ledger_entries`, **later, Phase 3**; shape proposed for `renter_earnings`)

| Field | Dart type | Notes |
| --- | --- | --- |
| `id`, `booking_id`, `user_id` | `String` | `user_id` is the person the money belongs to. |
| `kind` | `String` | `rental_fee`, `commission`, `renter_earning`, `deposit_hold`, `deposit_refund`, `deposit_deduction`, `late_fee`. |
| `amount` | `num` | NPR. Positive = owed to the user. |
| `state` | `String` | `on_hold`, `due`, `paid`. Matches the three numbers on the earnings screen. |
| `reference` | `String?` | Payment reference typed by the admin (payouts are recorded, not executed: honesty rule 2). |
| `created_at`, `paid_at` | `DateTime` | |

---

## 3. Booking status

Statuses: `requested`, `declined`, `expired`, `cancelled`, `renter_accepted`, `awaiting_payment`, `payment_submitted`,
`payment_verified`, `handed_over`, `returned`, `completed`, `disputed`.

- **Date-blocking** (dates are reserved): `renter_accepted`, `awaiting_payment`, `payment_submitted`, `payment_verified`, `handed_over`, `returned`, `disputed`, `completed`.
- **Not blocking:** `requested`, `declined`, `expired`, `cancelled`.
- The allowed transitions, who may do each, and the RPC that does it are in `docs/state-machine.md` and `shared/fixtures/status_transitions.json`.

## 4. RPCs

Conventions:

- Call: `supabase.rpc('name', params: {...})`. Parameter names start with `p_`.
- Every RPC is `SECURITY DEFINER`, checks `auth.uid()`, the caller's role and the booking's **current** status, then changes the row.
  Calling it at the wrong time fails with an error instead of doing nothing.
- A failed RPC raises an exception whose **message is a short error code** (list in section 6). Show your own friendly text per code.
- "Returns booking" means the full updated Booking row (section 2.3).

### 4.1 Live in Phase 0

| RPC | Params | Returns | Who | Errors |
| --- | --- | --- | --- | --- |
| `get_item_blocked_dates` | `p_item_id uuid` | rows of `{start_date, end_date}` (both inclusive; ended ranges left out) | any signed-in user, for items they can see | none (an unknown or hidden item returns no rows) |
| `get_public_profiles` | `p_user_ids uuid[]` | rows of `{id, full_name, area, is_verified}` for active users | any signed-in user | none |

### 4.2 Booking flow (Phase 1 to 3)

| # | RPC | Params | Returns | Who | Transition | Main errors |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `create_booking_request` | `p_item_id uuid`, `p_start_date date`, `p_end_date date` | booking | Borrower | (new) to `requested` | `not_authenticated`, `account_not_active`, `id_required`, `item_not_available`, `own_item`, `invalid_dates`, `dates_in_past`, `dates_unavailable` |
| 2 | `renter_decide_booking` | `p_booking_id uuid`, `p_decision text` (`accept` / `decline`), `p_terms_accepted boolean default false`, `p_decline_reason text default null` | booking | the booking's Renter | `requested` to `renter_accepted` or `declined` | `not_your_booking`, `invalid_status`, `id_required`, `terms_not_accepted`, `terms_version_changed`, `dates_unavailable` |
| 3 | `admin_approve_order` | `p_booking_id uuid` | booking | admin (also run by the system when `auto_approve_orders` is true) | `renter_accepted` to `awaiting_payment` | `not_admin`, `invalid_status`, `id_not_verified`, `user_suspended` |
| 4 | `submit_payment_proof` | `p_booking_id uuid`, `p_proof_path text`, `p_reference text`, `p_method text` (`esewa` / `khalti` / `bank`), `p_terms_accepted boolean` | booking | the booking's Borrower | `awaiting_payment` to `payment_submitted` | `not_your_booking`, `invalid_status`, `terms_not_accepted`, `proof_missing`, `reference_missing` |
| 5 | `admin_verify_payment` | `p_booking_id uuid`, `p_approved boolean`, `p_reason text default null` | booking | admin | approved: `payment_submitted` to `payment_verified` (6-digit handover code created, contact details unlock). Rejected: back to `awaiting_payment` so the Borrower can resubmit. | `not_admin`, `invalid_status`, `amount_mismatch`, `reason_required` |
| 6 | `record_handover` | `p_booking_id uuid`, `p_code text`, `p_checklist jsonb`, `p_item_photo_paths text[]`, `p_borrower_face_path text`, `p_borrower_id_path text` | booking | the booking's Renter | `payment_verified` to `handed_over` | `not_your_booking`, `invalid_status`, `wrong_code`, `code_locked`, `evidence_missing` |
| 7 | `confirm_receipt` | `p_booking_id uuid`, `p_ok boolean default true`, `p_note text default null` | booking | the booking's Borrower | none (sets `receipt_confirmed_at`; `p_ok = false` flags the booking for an admin) | `not_your_booking`, `invalid_status` |
| 8 | `record_return` | `p_booking_id uuid`, `p_photo_paths text[]`, `p_has_damage boolean`, `p_note text default null` | booking | the booking's Renter | `handed_over` to `returned` | `not_your_booking`, `invalid_status`, `evidence_missing` |
| 9 | `report_damage` | `p_booking_id uuid`, `p_description text`, `p_photo_paths text[]`, `p_estimated_cost numeric` | the new damage report row | the booking's Renter | none (opens a case for the admin) | `not_your_booking`, `invalid_status`, `evidence_missing` |
| 10 | `admin_resolve_case` | `p_booking_id uuid`, `p_decision text` (`completed` / `disputed`), `p_deposit_deduction numeric default 0`, `p_note text default null` | booking | admin | `returned` to `completed` or `disputed` (ledger entries written in the same transaction); `disputed` to `completed` when closed | `not_admin`, `invalid_status`, `deduction_too_large` |
| 11 | `settle_booking` | `p_booking_id uuid`, `p_kind text` (`renter_payout` / `deposit_refund`), `p_reference text` | the updated ledger rows | admin | none (marks money as `paid`; the payment itself happens outside the app) | `not_admin`, `invalid_status`, `already_settled`, `reference_missing` |

### 4.3 People, settings and terms (Phase 1 to 2)

| RPC | Params | Returns | Who | Errors |
| --- | --- | --- | --- | --- |
| `admin_review_kyc` | `p_user_id uuid`, `p_approve boolean`, `p_reason text default null` | profile | admin | `not_admin`, `invalid_status`, `reason_required` |
| `admin_update_setting` | `p_key text`, `p_value jsonb` | setting row | admin | `not_admin`, `unknown_setting`, `invalid_value` |
| `admin_publish_terms` | `p_kind text`, `p_title text`, `p_body text` | the new terms row (next version, active; the old one is deactivated) | admin | `not_admin`, `invalid_kind` |
| `admin_set_user_status` | `p_user_id uuid`, `p_status text` (`active` / `suspended`), `p_reason text` | profile | admin | `not_admin`, `cannot_change_self`, `reason_required` |
| `request_account_deletion` | none | void (profile anonymised, status `deleted`; the Edge Function `delete-user` then removes the login) | the caller | `has_open_bookings` |

### 4.4 PROPOSED additions (not in the plan's list, need Smaran's and Mohan's yes or no)

| RPC | Why it is needed | Params | Returns | Who |
| --- | --- | --- | --- | --- |
| `submit_kyc` | The `kyc_*` columns cannot be written by the app, so the ID-upload screen (Mohan, Phase 1) needs an RPC. | `p_id_path text`, `p_face_path text` | profile (`kyc_status = pending`) | the caller |
| `cancel_booking` | `docs/state-machine.md` row 2 says the Borrower can cancel, but no RPC is named. | `p_booking_id uuid` | booking | the booking's Borrower |
| `get_booking_contact` | Phone numbers unlock only from `payment_verified`; they must not be readable from the tables. | `p_booking_id uuid` | `{full_name, phone}` of the **other** person | Renter or Borrower of a booking in `payment_verified` or later |
| `get_earnings_summary` | The earnings screen needs the three totals without downloading every ledger row. | none | `{on_hold, due, paid}` in NPR for the caller | any signed-in user |
| `expire_stale_requests` | Moves `requested` bookings past `expires_at` to `expired` and sets `is_overdue`. Run by a schedule, **not callable by apps**. | none | number of rows changed | system only |

## 5. Storage

Upload with a **new file name each time** (for example a timestamp or uuid). Overwriting and deleting private files is not allowed.
Limits enforced by the bucket: 5 MB per file, images only (`image/jpeg`, `image/png`, `image/webp`); `payment-proofs` also accepts `application/pdf`.
Compress to about 1080 px on the long side before upload (`AppConstants.targetImageLongSide`).

| Bucket | Public | Path | Who uploads | Who reads |
| --- | --- | --- | --- | --- |
| `item-photos` | yes | `<user_id>/<file>` | the Renter, into their own folder | everyone (public URL) |
| `kyc-documents` | no | `<user_id>/<file>` | the user, into their own folder | admins only |
| `handover-evidence` | no | `<booking_id>/<file>` | the booking's Renter, once the booking is `payment_verified` or later | the booking's Renter and Borrower, admins |
| `payment-proofs` | no | `<booking_id>/<file>` | the booking's Borrower, while `awaiting_payment` or `payment_submitted` | the Borrower and admins (never the Renter) |

Store the **path** (not a URL) in the database. The paths are what `photo_paths`, `kyc_id_path`, `p_proof_path` and the handover RPC parameters hold.
Private files are opened with a signed URL.

## 6. Error codes

An RPC raises `RAISE EXCEPTION '<code>'` (SQLSTATE `P0001`). In `supabase_flutter` this arrives as `PostgrestException.message`.
Postgres' own errors keep their normal codes: `23P01` = overlapping dates (double booking caught by the constraint), `23514` = a value broke a check
(for example a fee that does not match the days), `42501` = not allowed (RLS or missing grant).

| Code | Meaning |
| --- | --- |
| `not_authenticated` | No signed-in user. |
| `not_admin` | Caller is not an active admin. |
| `not_your_booking` | Caller is not the Renter / Borrower this action needs. |
| `account_not_active` / `user_suspended` | Account is suspended or deleted. |
| `id_required` / `id_not_verified` | ID not submitted / not yet verified by an admin. |
| `item_not_available` / `own_item` | Item is paused, deleted or missing / Renter tried to book their own item. |
| `invalid_dates` / `dates_in_past` | End before start / start before today (Kathmandu date). |
| `dates_unavailable` | The dates overlap an already accepted booking. |
| `invalid_status` | The booking is not in a status that allows this action. |
| `terms_not_accepted` / `terms_version_changed` | Box not ticked / the active terms changed since the request. |
| `proof_missing` / `reference_missing` / `evidence_missing` / `reason_required` | A required input is empty. |
| `amount_mismatch` | Payment amount is not fee + deposit from the booking snapshot. |
| `wrong_code` / `code_locked` | Handover code wrong / locked after 5 wrong tries. |
| `deduction_too_large` | Deposit deduction is more than the deposit. |
| `already_settled` | That payout or refund is already marked paid. |
| `has_open_bookings` | Account has unfinished bookings. |
| `unknown_setting` / `invalid_value` / `invalid_kind` / `cannot_change_self` | Bad admin input. |
| `terms_immutable` | Someone tried to edit or delete a published terms version. |

## 7. Open questions (need a decision before the contract is frozen)

1. **Handover code display.** `docs/security.md` plans a hashed, single-use code. The Borrower must still be able to read it to give it to the Renter.
   Suggestion: store the hash for checking, and let the Borrower read the plain code from a dedicated RPC while the booking is `payment_verified`. Needs Mohan's and Smaran's agreement.
2. **Cancel after accept.** State machine row 2 only lets the Borrower cancel a `requested` booking. If the Borrower never pays, the dates stay blocked.
   Suggestion: allow `cancel_booking` also from `renter_accepted` and `awaiting_payment`, and add a payment deadline.
3. **Commission and deposit rates.** The seeded 10% and 25% are placeholders; the business notes decide the real values (and the late-fee rule for `money.dart`).
4. **Auto-approve.** Confirm that `admin_approve_order` is run by the database itself when both IDs are verified and `auto_approve_orders` is true, so the app never calls it in that case.

## 8. Change process

Ask for changes with a GitHub issue labelled `backend-request`. After approval, Srijan adds a new migration (never edit a merged one) and updates this file in the same PR.
