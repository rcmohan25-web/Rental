# Phase 0 Dart mapping (Smaran)

How the handwritten Dart code in `packages/rental_core` and `packages/rental_data` maps to the team's shared `docs/api-contract.md` (v0.3: financial rules approved, the rest not yet frozen). This file does not replace the contract; it records the choices made so far so they can be changed in one place when the open decisions are settled.

## 1. Rule used

Dart property names stay short and stable (`dailyPrice`, `pickupArea`, `renterEarning`). Only `fromJson` and `toJson` know the database names. When a column is renamed, change the mapping in one model file; screens and fakes do not change.

## 2. Money (contract section 1 and decision 1)

| Where | Representation | Why |
| --- | --- | --- |
| Database and wire | Whole NPR amounts; rates as fractions (`commission_rate` 0.1000, `deposit_rate` 0.2000, `late_fee_multiplier` 1.5) | What the committed schema and the team contract use |
| Inside Dart | `int` NPR; rates as basis points (1000 = 10%); multiplier x100 (150 = 1.5x) | Exact integer arithmetic, no floating-point drift |
| Conversion | `Money.bpsFromRate`, `Money.rateFromBps`, `Money.multiplierX100FromFactor` | The only place the two forms meet; tested against `money_cases.json` |
| Whole NPR check | `wholeNpr()` in `models/json_helpers.dart` refuses 3500.50 | Contract: amounts must be whole NPR |
| Rounding | Half up to whole NPR (`(amount x bps + 5000) ~/ 10000`) | **Approved in v0.3**; same as PostgreSQL `round()` on non-negative numbers. Negative input is rejected. |

If the team picks integer basis points in the database instead, only `rateToBps` and `bpsToRate` (and the JSON keys in `Booking` and `AppSettings`) change.

## 3. Entities

| Contract | Dart | Notes |
| --- | --- | --- |
| `profiles` (`display_name`, timestamps) | `Profile` | `display_name` fills `fullName`; `firstName` is its first word until `first_name` exists. Planned columns (phone, area, role, account status, KYC) are optional or default to the least-privilege value (`user`, `active`, `none`). |
| `items` (`daily_rate`, `declared_value`, `pickup_area`, `status`) | `Item` | `pickupArea` is free text and is shown as it is; `Item.area` is derived for the area filter. `status` draft/active/paused; only `active` is listed (`isActive`). `category`, `condition`, `photo_urls`, `rules` are planned columns and are read when present. `declared_value` is nullable in SQL; `null` reads as 0 ("not declared"). |
| `bookings` (`commission_rate`, `deposit_rate`, `terms_version_ids uuid[]`) | `Booking` | Snapshot columns use the contract's proposed names: `agreed_daily_rate`, `rental_days`, `declared_value_snapshot`, `rental_fee`, `deposit_amount`, `commission_amount`, `lender_earning`. `termsVersionIds` is a `List<String>` like the committed array. Late-fee snapshot and idempotency key are optional. |
| `app_settings` (`key`, `value jsonb`) | `AppSettings` | `fromRows` reads the table. Only the three approved settings (`commission_rate`, `deposit_rate`, `late_fee_multiplier`) are required; a missing or malformed one throws `FormatException`. The five unapproved settings are optional (null = not set), and a present value must still be valid. `AppSettings.fakeDefaults` holds just the three approved values and is for the fakes and tests only. |
| `terms_documents` (`title`, text `version`, `content`, `status`) | `TermsDocument` | `body` is `content`; `isActive` means published. `audience` is optional until the migration exists. |
| planned `terms_acceptances` | `TermsAcceptance` | `termsDocumentId`, text `version`, server-set `acceptedAt`. |
| planned `ledger_entries` | `LedgerEntry` | Shape is Smaran's proposal; no columns are fixed in the contract yet. |

## 4. Booking statuses and dates

- The 12 values match the initial schema; `BookingStatus.fromWire` rejects anything else.
- `BookingStatus.blocksDates` matches the committed `prevent_double_booking` constraint: `renter_accepted`, `awaiting_payment`, `payment_submitted`, `payment_verified`, `handed_over`, `returned`, `disputed` block; `requested`, `declined`, `expired`, `cancelled`, `completed` do not. The fake repository and its tests use it.
- `BookingStatus.borrowerCanCancel` (requested, renter_accepted, awaiting_payment) is a **proposal** until the cancellation RPC is approved (contract section 9, decision 8).
- Dates are date-only in Asia/Kathmandu with an inclusive end date; `Money.days` counts them.

## 5. Repositories and RPCs

| Contract RPC or read | Dart | State |
| --- | --- | --- |
| `create_booking_request` | `BookingRepository.createBookingRequest` | Fake applies the contract's error codes; no real implementation yet |
| cancellation (name to be approved) | `BookingRepository.cancelBooking` | Fake only |
| `get_blocked_dates` (proposed) | `BookingRepository.blockedDates` returns `List<DateRange>` | Fake only |
| Explore `items` read | `ItemRepository.listItems` (`ItemQuery`, keyset `ItemCursor`, `ItemPage`) | Fake only |
| `app_settings` read | `SettingsRepository.getSettings` | Fake only |

All of these are fakes. None of the RPCs are deployed; nothing in the app claims otherwise. Idempotency (`p_idempotency_key`) is a proposal in the contract; the fake and the screen already use it.

## 5b. Contract v0.3: financial rules (approved by Mohan)

| Rule | In the code |
| --- | --- |
| Deposit 20% of the declared value, commission 10% of the rental fee, late-fee multiplier 1.5 | `AppSettings.fakeDefaults` (2000, 1000, 150); fixtures |
| Rates stored as fractional `NUMERIC`, basis points inside Dart | `Money.bpsFromRate`, `Money.rateFromBps` |
| Half-up whole-NPR rounding for deposit and commission, `.5` included | `Money.applyRate`; fixtures include the approved boundary example (declared value 5 gives deposit 1; rental fee 5 gives commission 1) |
| Worked example | Fee 10,500, deposit 32,000, commission 1,050, renter earning 9,450, Borrower pays 42,500 |
| Settings changes affect new bookings only | Booking snapshots rates; `Booking` is never recalculated |

Still NOT approved, so provisional in the code: grace period, late-day rounding, the late-fee cap and how a late fee is deducted. `Money.lateDays`, `Money.lateFee` and the `lateFee` fixtures say so. Do not show a late fee in the UI until these are decided.

Note for the SQL tests: at a 20% deposit and whole-NPR declared values, the deposit can never land exactly on .5 (it moves in steps of 0.2), so the deposit boundary examples are 7 gives 1 (1.4) and 8 gives 2 (1.6). A real .5 tie happens for the commission when the rental fee ends in 5 (fee 5 gives 0.5, fee 1005 gives 100.5).

## 6. Left out on purpose

- No plaintext handover code anywhere. The contract keeps the hash-only rule and leaves delivery open (decision 5); nothing in the Dart code depends on it.
- No `avatars` or `damage` buckets, no `get_handover_code`: those were in an earlier draft and are not in the team contract.
- No account-deletion code (decision 6).

## 7. When a decision goes the other way

| Decision (contract section 9) | What changes in Dart |
| --- | --- |
| 1 Money (representation and rounding are settled; late-fee rules are open) | `Money.lateDays`, `Money.lateFee` and the `lateFee` fixtures |
| 2 Field naming | `fromJson` / `toJson` of the affected model only |
| 3 Terms audience and versions | `TermsDocument`, `TermsAcceptance`, `Booking.termsVersionIds` |
| 4 Availability after return | `BookingStatus.blocksDates` and its test |
| 8 Extra RPC names | method names in `BookingRepository` |
| 9 Idempotency and errors | `createBookingRequest` signature; `friendlyBookingError` |
