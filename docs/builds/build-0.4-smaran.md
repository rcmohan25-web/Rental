# Build 0.4, Smaran (Phase 1: minimum deposit, live Explore and Item details, terms checkbox)

**Merge order: after Mohan's zip** (it uses his `RentalBackend` seam and `ensureIdSubmitted`). Independent of Srijan's zip: without it the app simply stays on fakes (no keys) and everything runs; with it and the keys, Explore and Item details show live data.
Branch: `feature/phase1-borrower-money`. Label the PR `phase-1`.
The model files are frozen: open the PR with the label `contract-change` and get Mohan's and Srijan's approval (the change is additive: `minDepositAmount`, defaults to 0 / null).

## What this build delivers
- **Minimum deposit (the open Phase 0 issue)**: `Money.deposit(..., minDepositAmount)` and `Money.breakdown(..., minDepositAmount)` implement `deposit = max(round_half_up(declared x rate), minimum)`. `shared/fixtures/money_cases.json` has 14 breakdown cases (5 new: minimum applies, minimum not needed, small minimum, equal, zero). `money_test.dart` reads `minDepositAmount` from each case.
- **Models** (`contract-change`): `AppSettings.minDepositAmount` (from `min_deposit_amount`, null = not set), `Booking.minDepositAmount` (snapshot, 0 for older bookings). `FakeBookingRepository` uses it.
- **Explore and Item details on live data**: `catalog_providers.dart` takes items and settings from `RentalBackend` (Supabase with keys, fakes without). Item details shows the deposit with the minimum, calls the ID gate before sending, and while bookings are still fake (until Phase 2) shows a notice instead of a send button so nothing pretends to be sent.
- **`TermsCheckbox`** (`rental_core`): the reusable "I have read and accept" box with the honesty line, used in Phase 2 for the borrower and renter ticks.
- **Docs**: `docs/test-plan.md` (inventory, test log, manual checklist), `item_details/README.md`.

## Not in this build (on purpose)
- Live bookings, My bookings, payment screen: Phase 2 (they need `get_blocked_dates`, `admin_verify_payment` and the payment RPCs).
- Reviews, notifications screens, admin analytics and audit log: Phase 4.
- Late-fee rules stay provisional (not approved).

## Checked here, and what was not
- All 14 breakdown and 6 late-fee fixture cases pass through `money.dart` on the plain Dart SDK (34 checks), and the 14 breakdown cases give the same numbers from the SQL calculator on PostgreSQL 16 (0 mismatches). The Dart files pass the formatter (syntax).
- **Not run:** `flutter analyze` and `flutter test` (no Flutter SDK was available). Run them and send me the output.

## Done when (Smaran's gate)
Money tests pass with the new fixtures, the contract-change PR is approved and merged, Explore and Item details run on the phone in fake mode, and, once Srijan's zip is merged and the keys are set, they show the items a Renter published.
