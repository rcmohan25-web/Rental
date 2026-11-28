# Test plan and log

**Owner: Smaran.** Levels: unit, SQL (pgTAP), widget, security, integration, manual (see the plan, Section 14).
Definition of done: works on a physical device, handles loading/empty/error states, no analyzer warnings, tests pass, reviewed by the CODEOWNER, merged and listed in the demo script or test log.

## How to run

```
cd packages\rental_core && flutter test      # money rules (reads shared/fixtures/money_cases.json), widgets
cd packages\rental_data && flutter test      # models, fake repositories
cd apps\mobile && flutter test               # auth, profile, listings, Explore and Item details screens
cd apps\admin_web && flutter test            # admin guard and ID queue
flutter analyze
dart format --output=none --set-exit-if-changed apps packages
python -B supabase\tests\run_local_regression.py fresh   # SQL, Srijan (Docker + local Supabase)
```

## Test inventory

| Area | File | What it proves |
| --- | --- | --- |
| Money | `packages/rental_core/test/money_test.dart` | Every case in `money_cases.json` (14 breakdown cases, 6 late-fee cases). Worked example 3 days x NPR 3,500, declared 160,000: fee 10,500, deposit 32,000, commission 1,050, earning 9,450, Borrower pays 42,500. **Minimum deposit** (Build 0.4): `deposit = max(20% of declared value, minimum)`; minimum applies, minimum not needed, minimum equal to the percentage, small minimum leaves the worked example unchanged, 0 means no minimum, negative throws. Half-up rounding boundaries, inclusive days, invalid input. |
| Money, SQL parity | `shared/fixtures/money_cases.json` and `supabase/tests/phase1_regression.test.sql` | The same minimum cases (1 day, NPR 100, declared 2,000: deposit 1,000 with minimum 1,000, 400 with minimum 300) must give the same numbers in `rental_private.calculate_money` |
| Late fee (provisional) | `money_test.dart`, `money_cases.json` `lateFee` | NOT approved (grace, rounding, cap); documents the current assumption only. |
| Models | `packages/rental_data/test/models_test.dart`, `min_deposit_models_test.dart` | Schema-shaped rows readable, money with paise refused, rates round trip, settings rows, `blocksDates` equals the overlap constraint; `min_deposit_amount` read from settings and bookings (missing = unset or 0, 10.5 and negative refused). |
| Fake repositories | `fake_repositories_test.dart`, `min_deposit_models_test.dart` | Pagination, filters, `create_booking_request` rules and error codes, minimum deposit snapshotted. |
| Identity and listings (Mohan, Srijan) | `identity_fakes_test.dart`, `listing_fakes_test.dart` | Sign-up, ID submit, admin approve or reject, listing rules. |
| Terms checkbox | `packages/rental_core/test/terms_checkbox_test.dart` | Reports the tick, shows the honesty line, optional read link and error, disabled box ignores taps. |
| Explore screen | `apps/mobile/test/explore_screen_test.dart` | List shows items, category chip filters, empty state. |
| Item details | `item_details_screen_test.dart`, `item_details_live_mode_test.dart` | Price and deposit shown separately, booked dates, unknown item, no-item state; deposit uses the minimum; no send button when requests are off (live backend). |

## Test log

| Date | Who | What | Result |
| --- | --- | --- | --- |
| 2026-11-25 | Smaran | Money logic and fixtures on the Dart SDK outside Flutter (15 cases, v0.3 rules) | 0 failures |
| 2026-11-26 | Smaran | `flutter test` in `apps/mobile` on Flutter 3.47.3: 5 passed, 3 failed (small test screen, fixed with a tall test surface) | fix to be re-run |
| 2026-11-27 | Build 0.4 author (Claude) | Money rules with minimum deposit: all 14 breakdown and 6 late-fee fixture cases through `money.dart` on the plain Dart SDK 3.14.1 (34 checks, including the rate conversions) | 0 failures |
| 2026-11-27 | Build 0.4 author (Claude) | The same 14 breakdown fixtures through SQL `rental_private.calculate_money` (6-argument form) on PostgreSQL 16 | 0 mismatches |
| 2026-11-27 | Build 0.4 author (Claude) | `dart format` on every Dart file of the three zips (syntax only). No `flutter analyze` or `flutter test`: no Flutter SDK in that environment | syntax OK, **not compiled** |
| 2026-11-28 | Smaran | `flutter analyze` at the repo root on Flutter 3.47.3, first run after copying the Build 0.4 files onto an unmerged `main`: 5 errors, all from the missing `RentalBackend` and `apps/mobile/lib/shared/id_gate.dart` (Mohan's phase 1 PR #29, not pulled yet) | 5 errors, cause found |
| 2026-11-28 | Smaran | Merged `origin/main` (Mohan's #29) into `feature/phase1-borrower-money`, `flutter pub get`, then `flutter analyze` | No issues found |
| | Smaran | `flutter test` in rental_core, rental_data, apps/mobile after applying Build 0.4 | **to do** |
| | Smaran | Physical device: Explore and Item details on live data (needs Srijan's zip and the keys) | **to do** |

## Manual checklist, Explore and Item details (fake data, then live)

- [✓] Explore loads with a spinner, then shows 12 items; scrolling to the bottom shows no duplicates.
- [✓] Search narrows the list after a short pause; clearing it restores the list.
- [✓] Category chips, filter sheet (area, price, sort) and "Reset" work; the badge on the filter button shows the count.
- [✓] No match shows "No items found" and "Clear filters" works.
- [✓] Item details shows price per day and the refundable deposit separately.
- [✓] **Minimum deposit:** an item with a low declared value shows the minimum as its deposit (set `min_deposit_amount` higher than 20% of the value in the settings, or use the fake settings in a test).
- [✓] Choosing dates that overlap "Already booked" shows the error and clears the selection (fake mode).
- [✓] Choosing 3 free days of the camera shows NPR 10,500 + NPR 32,000, total NPR 42,500.
- [✓] **ID gate:** signed in without an ID, tapping "Send rental request" shows "Submit your ID first" and leads to Verify identity (fake mode).
- [✓] "Send rental request" shows "Requested" and that nothing was charged; tapping twice quickly creates one request (fake mode).
- [ ] **Live mode:** Explore shows the Renter's published items (first name, no address); Item details shows the notice "Rental requests open in the next build" instead of the send button.
- [✓] Text scale 130% and a small phone: no overflow.