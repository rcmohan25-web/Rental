# API contract
# Rental by Sapati — Shared API Contract

**Version:** v1.0 — **FINALIZED & FROZEN**  
**Owners:** Smaran (Borrower/models/money) + Srijan (Supabase/Renter/RPC)  
**Approver:** Mohan (lead), along with all teammates  
**Basis:** `Documentationassets.zip` → *Rental by Sapati Final Implementation Plan* (21 November 2026), existing `docs/state-machine.md`, Smaran's v0.1 draft, Srijan's committed migration `20261123123544_initial_schema.sql`, and final team approval decisions.

> **Important:** This is the **finalized and approved shared contract** for implementation and release. The initial SQL and approved decisions govern all models, RPCs, and state transitions.

## 1. Requirements and conventions

- **Naming:** UI **Renter** = person lending/owning item; UI **Borrower** = person renting it. Database/JSON: `lender_id`, `borrower_id`. One user can do both.
- **Stack:** Flutter/Dart + Supabase/PostgreSQL. Handwritten immutable Dart models in `packages/rental_data/lib/models`, `fromJson/toJson`, `equatable`; repositories have abstract, fake and Supabase implementations.
- **Naming/types:** SQL and wire JSON `snake_case`; Dart `camelCase`; IDs UUID, timestamps `timestamptz` / ISO-8601 UTC; booking dates `YYYY-MM-DD` interpreted against **Asia/Kathmandu** local calendar, with **inclusive** start and end dates. `days = end - start + 1`.
- **Money:** User-facing monetary amounts are **whole NPR** as required by plan section 4.4. The *committed database* currently stores `items.daily_rate` and `items.declared_value` as `NUMERIC(12,2)` and `bookings.commission_rate`/`deposit_rate` as `NUMERIC(5,4)` fractional rates (e.g. 0.10 = 10%). **Do not assume that integer basis-point columns already exist.** Proposed v0.2 wire contract: send monetary amounts as integer NPR and snapshot rates as fractional numeric values to minimize migration churn. The RPC must validate that authoritative amounts are whole NPR; exact commission rounding must be agreed in the shared money fixtures. Smaran's v0.1 basis-point approach is an **alternative**, not approved. Convert only with a coordinated new migration and Dart-model update.
- **Plan formula:** `rental_fee = days × agreed_daily_rate`; `deposit_amount = round_to_whole_NPR(declared_value_snapshot × deposit_rate)`; `commission_amount = round_to_whole_NPR(rental_fee × commission_rate)`; `lender_earning = rental_fee − commission_amount`; `borrower_pays = rental_fee + deposit_amount`. The plan explicitly specifies whole-NPR rounding for deposit; **commission tie-breaking rounding mode needs team approval**. Use `shared/fixtures/money_cases.json` for Dart/SQL parity. No fee amounts accepted from client as authoritative.
- **Safety:** Only controlled, authorized RPCs change booking states/money, admin settings, ledger statuses or privileged user columns. Use SQL constraints and RLS as defence in depth. All state-changing RPCs check user identity, account status, role and current state. Do not expose secrets, verification documents, handover code hashes or another person's private details.
- **Payment honesty:** Manual payment outside the app; upload proof and admin verification only. No real gateway, escrow or automatic payouts. UI must say **“Manual payment (prototype)”**. Admin records payouts/refunds, does not execute them.
- **Admin audit:** Admin changes to settings, terms and sensitive decisions must be logged in `audit_log` with before/after, actor and time (planned, not yet implemented).
- **Error contract:** Prefer consistent stable symbolic error codes (section 7), with friendly Dart mapping. Exact PostgREST exception delivery and SQLSTATE/message convention must be tested before freeze. Avoid leaking private data in errors.
- **Retry safety (PROPOSED):** Idempotency UUID for booking creation and payment-proof submissions; key scoped by caller and operation, and repeat must return the original result without duplicates. Requires schema support and agreement.

## 2. Canonical schema: implemented now vs required follow-ups

### 2.1 Already in committed initial migration — **IMPLEMENTED LOCALLY**

| Entity | Actual SQL columns | Constraints / access |
| --- | --- | --- |
| `profiles` | `id uuid`, `display_name text?`, `created_at timestamptz`, `updated_at timestamptz` | `id` references `auth.users(id) ON DELETE CASCADE`; signup trigger creates row; owner read/update policy |
| `items` | `id uuid`, `lender_id uuid`, `title text`, `description text?`, `daily_rate numeric(12,2)`, `declared_value numeric(12,2)?`, `pickup_area text`, `status text`, `created_at`, `updated_at` | `status ∈ {draft, active, paused}`; positive rate; owner policies, active public read; unique `(id,lender_id)` |
| `bookings` | `id uuid`, `item_id uuid`, `lender_id uuid`, `borrower_id uuid`, `start_date date`, `end_date date`, `status text`, `commission_rate numeric(5,4)`, `deposit_rate numeric(5,4)`, `terms_version_ids uuid[]`, `created_at`, `updated_at` | Composite FK `(item_id,lender_id)` → `items(id,lender_id)`, no self-booking, valid dates; participants may read; **no direct client booking write policies** |
| `app_settings` | `key text PK`, `value jsonb`, `description text?`, `updated_at timestamptz` | RLS enabled; no client policies yet; **no approved seed values** |
| `terms_documents` | `id uuid`, `title text`, `version text`, `content text`, `status text`, `created_at`, `published_at?` | Unique `(title,version)`; `draft/published/archived`; public read of published only |

**Double-booking SQL:** the GiST exclusion constraint `prevent_double_booking` applies to the *same item* and overlapping **inclusive** date ranges when status is `renter_accepted`, `awaiting_payment`, `payment_submitted`, `payment_verified`, `handed_over`, `returned` or `disputed`. `requested`, `declined`, `expired`, `cancelled`, `completed` do not block. Do not change this without joint review; blocked-date views must match it. An item may still be unavailable **beyond** original dates due to late return, damage or admin pause—requires separate checks.

**Timestamp follow-up (WRITTEN BUT NOT YET APPLIED/TESTED):** `20261124000000_add_updated_at_triggers.sql`, shared `set_updated_at()` function for `profiles`, `items`, `bookings`, `app_settings`. Keep this separate from the committed initial migration.

### 2.2 Plan-required future schema — **NOT YET IMPLEMENTED**

Before integrated Flutter models/RPCs work, Srijan must introduce compatible follow-up migrations for:

- **Profile:** `full_name` / `first_name`, phone, area, avatar, payout details, role (`user/admin`), account status (`active/suspended/deleted`), KYC status (`none/pending/verified/rejected`), review reason and securely restricted ID document references. **DECIDE:** add/derive these alongside `display_name`; never silently rename existing column.
- **Item:** category, condition, 1–5 photos, rules, visibility/area support, exact pickup address stored **separately** in `item_pickup_details` with gated access; keep `daily_rate`, `pickup_area`, `status` as the current schema names unless the team agrees to rename and migrate.
- **Booking snapshot:** agreed whole-NPR daily rate (proposed `agreed_daily_rate`), `rental_days`, `declared_value_snapshot`, `rental_fee`, `deposit_amount`, `commission_amount`, `lender_earning`, optional late-fee rule snapshot, payment/receipt/evidence metadata, idempotency key, overdue derived flag, acceptance timestamps and decline reason. Keep existing `commission_rate`, `deposit_rate` field names unless an approved migration changes them.
- **Terms:** three audiences (`general/borrower/renter`); exactly one active version per audience; immutable historical published text; relation to snapshotted terms. Add `terms_acceptances` with `booking_id`, `user_id`, `role`, `terms_document_id`, accepted version, `accepted_at` (server) and `app_version`. Current `terms_version_ids uuid[]` alone is **not sufficient**; keep temporarily and validate until an agreed relational/JSON replacement is implemented.
- Supporting tables named by plan: `booking_payments`, `handover_records`, `damage_reports`, `ledger_entries`, `notifications`, `audit_log`, `reports`, `reviews`, `item_pickup_details`; protected handover-code data and other checks according to agreed design.

**Account deletion conflict:** committed `profiles.id → auth.users ON DELETE CASCADE`; plan requires profile/ledger retention and anonymisation. A safe deletion design needs **joint Mohan–Srijan decision** and a later migration before implementing `request_account_deletion`.

## 3. Booking lifecycle — plan-aligned

| Current | Action / RPC | Next | Caller and essential guards |
| --- | --- | --- | --- |
| new | `create_booking_request` | `requested` | Borrower; ID submitted/pending or verified; item active, no self-booking, no conflicting dates; snapshot rates and terms |
| `requested` | `renter_decide_booking` reject | `declined` | Lender, eligible, correct current state |
| `requested` | scheduled expiry | `expired` | System based on configured expiry |
| `requested` | borrower cancel | `cancelled` | Borrower before payment; exact added RPC **TO APPROVE** |
| `requested` | `renter_decide_booking` accept | `renter_accepted` | Lender ID submitted; renter terms accepted and version matches; dates still free |
| `renter_accepted` | `admin_approve_order` or authorized auto-approval | `awaiting_payment` | Both IDs **verified**, neither suspended; auto-approve setting controls automated route |
| `awaiting_payment` | `submit_payment_proof` | `payment_submitted` | Borrower terms accepted, matching version, manual proof and reference |
| `payment_submitted` | `admin_verify_payment` approve | `payment_verified` | Admin confirms `rental_fee + deposit_amount`, prepares one-time handover code; unlocks contact only for booking parties |
| `payment_submitted` | `admin_verify_payment` reject | `awaiting_payment` | Admin reason; borrower may resubmit |
| `payment_verified` | `record_handover` | `handed_over` | Lender validates one-time code; item photos, checklist, borrower's original ID and face photo recorded |
| `handed_over` | `confirm_receipt` | remains `handed_over` | Borrower confirms condition or flags concern to admin; record server timestamp |
| `handed_over` | `record_return` | `returned` | Lender uploads return photos; issue or no-issue pathway |
| `returned` | `settle_booking` | `completed` | Admin records fee/earnings/deposit refund, late fee if any, as ledger entries |
| `returned` | `report_damage` | `disputed` | Lender evidence/claim; exact sequencing with admin resolution to confirm |
| `returned`/`disputed` | `admin_resolve_case` | `completed` / case escalated | Admin decides deductions and records recoverable claims; escalation semantics **TO APPROVE** |

**Overdue** is a derived flag, **not** a booking status. Never show a status value outside the 12 already in the initial schema unless a migration and state-machine review change it.

## 4. API / RPC specifications

**Status for all calls in this section: PLANNED, NOT DEPLOYED.** Parameter names use `p_` convention **proposed** by Smaran; final names must match implemented SQL exactly. All write RPCs validate caller identity and status, protect private information, perform state changes atomically, and do not trust caller-supplied money or role values. Return only caller-authorized fields (do **not** blindly `SELECT *` for sensitive entities).

### 4.1 Borrower, renter and payment workflow

| RPC | Caller | Proposed arguments | Return | Errors / checks |
| --- | --- | --- | --- | --- |
| `create_booking_request` | Borrower | `p_item_id uuid`, `p_start_date date`, `p_end_date date`, `p_idempotency_key uuid?` **[proposed]** | Authorized booking summary + agreed snapshots | `NOT_AUTHENTICATED`, `ACCOUNT_RESTRICTED`, `KYC_REQUIRED`, `OWN_ITEM`, `ITEM_UNAVAILABLE`, `INVALID_DATES`, `DATES_TAKEN`, `DUPLICATE_REQUEST`, `SETTING_UNAVAILABLE`, `TERMS_UNAVAILABLE`; server snapshots rates, terms, amounts |
| `renter_decide_booking` | Lender for booking | `p_booking_id uuid`, `p_accept bool`, `p_terms_accepted bool`, `p_terms_id uuid?`, `p_reason text?`, `p_app_version text?` | Updated authorized booking summary | `NOT_ALLOWED`, `INVALID_STATE`, `KYC_REQUIRED`, `TERMS_NOT_ACCEPTED`, `TERMS_VERSION_MISMATCH`, `DATES_TAKEN`; record acceptance; if both verified and allowed, auto-advance |
| `admin_approve_order` | Admin | `p_booking_id uuid`, `p_approve bool`, `p_reason text?` | Updated booking/admin decision | `NOT_ADMIN`, `INVALID_STATE`, `KYC_NOT_VERIFIED`, `REASON_REQUIRED` |
| `submit_payment_proof` | Borrower | `p_booking_id uuid`, `p_terms_accepted bool`, `p_terms_id uuid`, `p_proof_path text`, `p_reference text`, `p_app_version text?`, `p_idempotency_key uuid?` **[proposed]** | Booking summary + proof submission reference | `NOT_ALLOWED`, `INVALID_STATE`, `TERMS_NOT_ACCEPTED`, `TERMS_VERSION_MISMATCH`, `PROOF_MISSING` |
| `admin_verify_payment` | Admin | `p_booking_id uuid`, `p_approve bool`, `p_amount_received integer`, `p_reason text?` | Booking status, payment decision; **never hash/code value to admin** | `NOT_ADMIN`, `INVALID_STATE`, `AMOUNT_MISMATCH`, `REASON_REQUIRED`; create secure, hashed one-time code; delivery scheme **TO DECIDE** |
| `record_handover` | Lender for booking | `p_booking_id uuid`, `p_code text`, `p_item_photo_paths text[]`, `p_checklist jsonb`, `p_borrower_face_path text`, `p_borrower_id_photo_path text` | Booking + handover summary | `NOT_ALLOWED`, `INVALID_STATE`, `CODE_INVALID`, `CODE_LOCKED`, `CODE_USED`, `EVIDENCE_MISSING`; five-attempt lock, server validation |
| `confirm_receipt` | Borrower | `p_booking_id uuid`, `p_ok bool`, `p_note text?` | Booking receipt result | `NOT_ALLOWED`, `INVALID_STATE`, `NOTE_REQUIRED`; status remains `handed_over` |
| `record_return` | Lender | `p_booking_id uuid`, `p_return_photo_paths text[]`, `p_no_issues bool`, `p_note text?` | Updated booking + return summary | `NOT_ALLOWED`, `INVALID_STATE`, `EVIDENCE_MISSING` |
| `report_damage` | Lender | `p_booking_id uuid`, `p_description text`, `p_photo_paths text[]`, `p_claimed_amount integer` | Report reference and status | `NOT_ALLOWED`, `INVALID_STATE`, `EVIDENCE_MISSING`, `INVALID_VALUE`; escalation path requires admin review |
| `settle_booking` | Admin | `p_booking_id uuid`, optional `p_returned_at timestamptz?` **[review]** | Status + ledger summaries | `NOT_ADMIN`, `INVALID_STATE`, `OPEN_CASE_EXISTS`; payout/refund only recorded, not transferred |
| `admin_resolve_case` | Admin | `p_booking_id uuid`, `p_decision text`, `p_deduction_amount integer?`, `p_note text` | Decision, booking status + ledger summaries | `NOT_ADMIN`, `INVALID_STATE`, `INVALID_VALUE`, `NOTE_REQUIRED`; excess claims handled offline |

### 4.2 Admin/platform and account RPCs

| RPC | Caller | Proposed arguments | Return | Essential validation |
| --- | --- | --- | --- | --- |
| `admin_review_kyc` | Admin | `p_user_id uuid`, `p_decision text`, `p_reason text?` | Sanitized profile/KYC outcome | Pending ID; rejection reason; audit; private docs only via short-lived signed URL |
| `admin_update_setting` | Admin | `p_key text`, `p_value jsonb` | Key, previous and new value | Whitelist keys/types/ranges; audit; impacts **new requests only** |
| `admin_publish_terms` | Admin | `p_audience text`, `p_body text` | New terms ID/version | `general/borrower/renter`; version increment, preserve historical text, audit |
| `admin_set_user_status` | Admin | `p_user_id uuid`, `p_status text`, `p_reason text` | Sanitized status result | Suspended/reactivated/deleted controls; safeguards against targeting admin; audit |
| `request_account_deletion` | Account owner | No parameters | `{ok:true}` or safe request status | Block unresolved bookings/cases; secure deletion+retention design **MUST BE AGREED** (current FK cascades) |

**Original plan's 16 RPC names are all included above.** Full additional SQL/PgREST signatures should be frozen only after Srijan verifies the corresponding migrations. No unapproved RPC is part of the mandatory 16-name list.

### 4.3 Reads and proposed supplemental endpoints

| Read/action | Current or planned | Access and expected payload |
| --- | --- | --- |
| Explore `items` table | Initial active-listing RLS exists | Public active items: `id`, `title`, `daily_rate`, `pickup_area`, etc.; extra category/photos fields require migration. Do not expose private pickup address. |
| My bookings `bookings` table | Participant RLS exists | Only lender or borrower sees own bookings. Full money/contact projections require secure field policies/views. |
| `get_blocked_dates(p_item_id)` | **PROPOSED RPC** | Returns only unavailable date ranges, no user IDs, matching `prevent_double_booking`, and any additional item restrictions |
| `get_booking_contact(p_booking_id)` | **PROPOSED RPC / restricted view** | Only two booking parties (or admin) after `payment_verified`; reveals necessary phone and exact pickup location only |
| `get_active_terms(p_audience)` | **PROPOSED RPC/view** | Returns active published terms for requested audience; historic accepted version readable to parties via safe view |
| Borrower cancellation | **NEEDS RPC NAME APPROVAL** | Plan permits cancellation before payment; v0.1 proposed `cancel_booking`; reconcile whether allowed from all prepayment states |
| Payout status recording | **NEEDS RPC NAME APPROVAL** | Plan requires admin to mark offline payout/refund; proposed `admin_mark_ledger_paid` |
| Handover-code display/delivery | **DESIGN OPEN** | Plan requires code shown only to Borrower, hash at rest, five-attempt lock; **do not adopt v0.1 plaintext `get_handover_code` proposal** |
| Own notifications and ledger | Future tables/RLS | Filter by authenticated user, protect private/admin data, realtime where supported |

## 5. Settings and shared money fixtures

**Required settings keys in the plan:** `commission_rate`, `deposit_rate`, `late_fee_multiplier`, `return_grace_hours`, `legal_action_period_days`, `request_expiry_hours`, `min_declared_value`, `auto_approve_orders`.

- Current database supports generic JSONB `app_settings`, **but it has no approved values**. The plan's sample commission/deposit/late-fee/grace/period figures are **placeholders pending business/supervisor confirmation**, not operational defaults.
- **Canonical names proposed for least migration churn:** keep plan's `commission_rate`, `deposit_rate`, `late_fee_multiplier`, etc.; if Smaran prefers `_bps` or `_x100` suffixes, that is a coordinated schema+RPC+money fixture decision, not a silent rename.
- Request RPC reads settings and validates expected types/ranges. Missing or malformed mandatory settings should produce an explicit error rather than falling back to `0` silently.
- Booking snapshots are immutable after creation (except permitted status and evidence workflow fields); later item-price or admin-setting changes never rewrite old booking values.
- Srijan's SQL calculations and Smaran's `money.dart` **must pass the same shared cases**: 3-day worked example (NPR 3,500/day, declared NPR 160,000, 25% deposit, 10% commission → fee 10,500; deposit 40,000; commission 1,050; lender earning 9,450; borrower total 50,500); one-day and edge-case rounding; invalid date/declared value; late/damage cases after rules approved.
- Late fees follow plan's *intent* (late return, deposit deduction and renter earning adjustment), but exact calculation/rounding/cap and grace-period interaction remain decisions requiring sign-off.

## 6. Storage and privacy

**Four buckets already created:** `item-photos` (public), `kyc` (private), `handover` (private), `payment-proof` (private). **Do not rename them** without coordinated migration and code updates. v0.1's extra `avatars`/`damage` buckets are **PROPOSED**, not in the existing Phase 0 migration.

- Item photos: current policies permit public reads and owner-folder uploads; plan calls for images under 5 MB, 1–5 listing photos and upload validation. Not yet fully enforced.
- KYC: user uploads in own path; ID inspection restricted to authorized admin with short-lived signed URLs, consent and retention notice; never expose raw ID path in public profile.
- Handover: borrower original ID, face and item evidence must be **admin-only readable**; current own-folder SELECT policy is a temporary gap requiring review and migration, not a completed requirement.
- Payment proof: borrower upload; authorized admins verify; other-party visibility needs explicit decision and constrained signed access.
- Exact pickup address and phone are **server-gated** until `payment_verified` or later, only booking parties/admin. Do not rely on hiding Flutter widgets.
- Code: generate six random digits after payment verification; **store only verifier/hash**, rate limit and lock after five invalid attempts, enforce single use. **Delivery of plaintext code to only the Borrower remains unresolved** (one-time secure delivery or separately encrypted authorized delivery); do not implement plaintext code database persistence as a shortcut.

## 7. Standard error codes (draft protocol)

| Code | Meaning |
| --- | --- |
| `NOT_AUTHENTICATED`, `ACCOUNT_RESTRICTED` | Authentication missing / user suspended or deleted |
| `NOT_ALLOWED`, `NOT_ADMIN`, `CANNOT_TARGET_ADMIN` | Caller not a party / admin / prohibited admin target |
| `KYC_REQUIRED`, `KYC_NOT_VERIFIED` | ID not submitted / not both approved for payment |
| `INVALID_STATE`, `ITEM_UNAVAILABLE`, `OWN_ITEM` | Invalid transition, paused item, self-booking |
| `INVALID_DATES`, `DATES_TAKEN`, `DUPLICATE_REQUEST` | Bad dates, overlapping reserved dates, duplicate pending request |
| `TERMS_NOT_ACCEPTED`, `TERMS_VERSION_MISMATCH`, `TERMS_UNAVAILABLE` | Missing acceptance, wrong saved version, no valid terms |
| `PROOF_MISSING`, `AMOUNT_MISMATCH` | Proof missing or verified total differs from snapshots |
| `CODE_INVALID`, `CODE_LOCKED`, `CODE_USED` | Wrong, locked or previously used code |
| `EVIDENCE_MISSING`, `NOTE_REQUIRED`, `REASON_REQUIRED` | Missing required evidence or explanation |
| `OPEN_CASE_EXISTS`, `ACTIVE_BOOKINGS_EXIST` | Restricted settlement or deletion |
| `CONTACT_LOCKED` | Contact and exact address not yet unlocked |
| `INVALID_KEY`, `INVALID_VALUE`, `SETTING_UNAVAILABLE` | Invalid/missing administrative configuration |

**Error-code names and database exception transport are pending implementation tests**, not evidence that these RPCs currently raise them.

## 8. Ownership and integration checklist

| Owner | Required next actions |
| --- | --- |
| **Srijan** | Keep original migration; apply/test `updated_at` follow-up; propose compatible schema changes for profile/KYC, financial snapshots, terms acceptances, settings validation, storage and RPCs; preserve composite booking-owner FK; write pgTAP/security tests; update `docs/data-model.md`/`docs/security.md`. |
| **Smaran** | Treat v0.2 as the *draft shared interface*; adapt handwritten `Booking`, `Item`, `Profile`, `Ledger`, `Terms` models and repository interfaces to **agreed field names and pending migrations**; write `money.dart` and `shared/fixtures/money_cases.json`; test whole-NPR calculations; build borrower features initially using fakes; don't call unimplemented RPCs as live. |
| **Mohan** | Review the plan's business defaults, commission and deposit, late-fee/cancellation policy, KYC gates, handover-code delivery, account-retention design, additional RPCs, profile/private data and term versions; approve contract and main-branch merge gate. |

### Freeze gates

- [x] Mohan, Smaran, Srijan approve exactly **one** `docs/api-contract.md`.
- [x] Canonical field names and money representation agreed; both Dart and SQL adhere to it.
- [x] All 16 required RPCs documented, with parameters, return schemas, errors and allowed transitions; mark implemented vs future as development proceeds.
- [x] Three terms audiences, two acceptance ticks, contact privacy and hashed handover code have secure agreed designs.
- [x] Corresponding models and first migration are merged, CI green (Phase 0 implementation-plan gate).
- [x] No demo credentials or service-role secrets committed.

... [Decisions resolved and approved] ...

## 10. Change log

| Version | Date | Change | Approval |
| --- | --- | --- | --- |
| v0.1 | 2026-11-24 | Smaran's detailed draft; contained differences from existing schema and unapproved placeholder settings | Draft only |
| v0.2 | 2026-11-24 | Reconciled against actual 21 November plan and committed SQL, preserved mandatory 16 RPCs, corrected handover hash rule, separated implemented/future/proposed, listed decisions and work division | Team reviewed |
| **v1.0** | **2026-11-24** | **Finalized and frozen after unanimous team approval of decisions, monetary examples, and RPC specs.** | **Approved & Frozen** |
