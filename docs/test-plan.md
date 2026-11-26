# Test plan and log

**Owner: Smaran.** Levels: unit, SQL (pgTAP), widget, security, integration, manual (see the plan, Section 14).
Definition of done: works on a physical device, handles loading/empty/error states, no analyzer warnings, tests pass, reviewed by the CODEOWNER, merged and listed in the demo script or test log.

## How to run

```
cd packages\rental_core && flutter test      # money rules (reads shared/fixtures/money_cases.json)
cd packages\rental_data && flutter test      # models, fake repositories
cd apps\mobile && flutter test               # Explore and Item details screens
flutter analyze
dart format --output=none --set-exit-if-changed apps packages
```

## Phase 0 test inventory (Smaran)

| Area | File | What it proves |
| --- | --- | --- |
| Money | `packages/rental_core/test/money_test.dart` | Every case in `money_cases.json` (plan worked example: 3 days x NPR 3,500, declared value 160,000 gives fee 10,500, deposit 32,000 at the approved 20%, commission 1,050, renter earning 9,450, Borrower pays 42,500). Inclusive days, half-up rounding including the approved boundary examples (declared value 5 gives deposit 1; rental fee 5 gives commission 1),  month and year boundaries, late days and late fee cap, invalid input throws, and the database fractions (0.10, 0.25, 1.5) convert to the basis points the cases use. |
| Models | `packages/rental_data/test/models_test.dart` | Rows shaped like the committed schema are readable (`daily_rate` numeric, free-text `pickup_area`, `display_name` only, terms `content`), money with paise is refused, rates round trip as fractions, `app_settings` rows with a missing or malformed key are an error, JSON round trip for every model, `blocksDates` equals the `prevent_double_booking` statuses, date range overlap is inclusive. |
| Late fee (provisional) | `money_test.dart`, `money_cases.json` `lateFee` | Grace period, late-day rounding and the cap are NOT approved; these cases document the current assumption only and must be redone when the rules are approved. |
| Fake repositories | `packages/rental_data/test/fake_repositories_test.dart` | Pagination never repeats items, filters and sorting, `create_booking_request` rules: worked-example amounts, idempotency, DATES_TAKEN, DUPLICATE_REQUEST, INVALID_DATES, OWN_ITEM, ITEM_UNAVAILABLE, KYC_REQUIRED, which booking statuses block dates, cancel, stream updates. |
| Explore screen | `apps/mobile/test/explore_screen_test.dart` | List shows items, category chip filters, empty state. |
| Item details screen | `apps/mobile/test/item_details_screen_test.dart` | Price and deposit shown separately, booked dates shown, unknown item message, no-item state. |

## Test log

| Date | Who | What | Result |
| --- | --- | --- | --- |
| 2026-11-25 | Smaran | Money logic and fixtures run on the Dart SDK outside Flutter (15 fixture cases, v0.3 financial rules) | 0 failures |
| 2026-11-25 | Smaran | `dart analyze` and the rental_core (40) and rental_data (55) tests on a stand-in test runner after applying the contract v0.3 financial rules | clean, 0 failures |
| 2026-11-26 | Smaran | `flutter test` in `apps/mobile` on the real toolchain (Flutter 3.47.3): 5 passed, 3 failed. The failures were the test screen being too small (800x600): lazily built list items and the details page below the first screen were not found by `find.text`. Not a screen bug. Fixed with a tall test surface. | fix to be re-run |
| | Smaran | `flutter test` in `packages/rental_core`, `packages/rental_data`, `apps/mobile` after the fix | **to do** |
| | | Physical device check of Explore and Item details | **to do** |

## Manual checklist (Explore and Item details, fake data)

- [ ] Explore loads with a spinner, then shows 12 items; scrolling to the bottom shows no duplicates.
- [ ] Search narrows the list after a short pause; clearing it restores the list.
- [ ] Category chips, filter sheet (area, price, sort) and "Reset" work; the badge on the filter button shows the count.
- [ ] No match shows "No items found" and "Clear filters" works.
- [ ] Item details shows price per day and the refundable deposit separately.
- [ ] Choosing dates that overlap "Already booked" shows the error and clears the selection.
- [ ] Choosing 3 free days of the camera shows NPR 10,500 + NPR 32,000, total NPR 42,500.
- [ ] "Send rental request" shows "Requested" and that nothing was charged; tapping twice quickly creates one request.
- [ ] Text scale 130% and a small phone: no overflow.
