# AGENTS.md: Rental by Sapati

Handover notes for AI coding assistants (Claude Code, Cursor, Codex) and for teammates.
Read this first. Update **Current state**, **Changelog** and **Next** after every change.
(Root files belong to Mohan in CODEOWNERS; get his review before merging this file.)

## Project in one paragraph
Peer-to-peer item rental app for Kathmandu, Lalitpur and Bhaktapur. Flutter mobile app (Borrower and Renter in one account) plus a Flutter Web admin panel. Backend is Supabase (Postgres, Auth, Storage, Realtime, pg_cron). All business rules are Postgres functions (RPC). Payments are manual and simulated and must be labelled "Manual payment (prototype)".

## Repo layout (monorepo)
- `apps/mobile`: mobile app, one folder per feature in `lib/features/` (`presentation/`, `application/`, `routes.dart`)
- `apps/admin_web`: admin web, one folder per page
- `packages/rental_core`: theme, `money`, formatters, errors, shared widgets
- `packages/rental_data`: models, repository interfaces, `fake/` repositories (and `supabase/` later)
- `supabase/`: migrations, seed, tests, edge function (Srijan)
- `shared/fixtures`: `money_cases.json`, `status_transitions.json` (Dart and SQL tests both read these)
- `docs/`: `api-contract.md` (the team's shared contract, v0.3: financial rules approved, the rest not frozen), `state-machine.md`, `test-plan.md`, `phase0-dart-mapping.md`, `BUILD_LOG.md`

Run the mobile app from `apps/mobile`, not the repo root.

## Rules every change must follow
1. **Money:** whole NPR as `int`, never `double`. The database and the contract use fractions (`commission_rate` 0.1000, `deposit_rate` 0.2000, `late_fee_multiplier` 1.5); inside Dart they are basis points (1000 = 10%) and x100 (150 = 1.5x), converted only with `Money.bpsFromRate` and friends. All formulas live in `packages/rental_core/lib/money/money.dart`. Never calculate money in a widget. Approved by Mohan (contract v0.3): 20% deposit, 10% commission, 1.5x late-fee multiplier, half-up whole-NPR rounding for deposit and commission. NOT approved: grace period, late-day rounding, late-fee cap and deduction; `Money.lateDays`/`lateFee` and the `lateFee` fixtures are provisional. The other five settings are not approved or seeded, so `AppSettings` treats them as optional (null).
2. **Dates:** `date` only, inclusive end date, Asia/Kathmandu.
3. **Naming:** snake_case in database and JSON, camelCase in Dart. `lender_id` is the Renter, `borrower_id` the Borrower; the UI says "Renter" and "Borrower".
4. **Status changes** only through RPCs in `docs/api-contract.md`. The app never writes status, role, kyc_status or money columns. The RPCs are planned, not deployed: do not call them as if they were live, and do not claim they work.
5. **Screens never call Supabase.** Widget to Riverpod notifier to repository interface. The only place that picks a repository implementation is `apps/mobile/lib/features/explore/application/catalog_providers.dart`.
6. **Riverpod:** keep failures in state (or return a result object); a provider that throws is retried automatically in Riverpod 3.
7. **Models** are hand-written with `equatable`, `fromJson`, `toJson`. No code generation (`freezed`, `build_runner`). Dart names are short and stable; only `fromJson`/`toJson` know database names (see `docs/phase0-dart-mapping.md`). Settings have no silent defaults: a missing key throws.
8. **Every screen** handles loading, data, empty and error states.
9. **No colour literals** outside `packages/rental_core/lib/theme`. Use `BrandColors` and `Theme.of(context)`.
10. **No secrets in Git.** Only the project URL and publishable key go in run config (`--dart-define`).
11. **Ownership:** do not edit folders you do not own (`.github/CODEOWNERS`). Only Srijan applies `supabase/migrations`. The contract and models are frozen after Phase 0 and then need all three approvals.
12. **Format and lint:** `dart format` with the package language version (3.6 style), `flutter analyze` must be clean (infos count), single quotes, trailing commas, `unawaited(...)` for fire-and-forget futures.
13. **Honesty:** anything simulated is labelled simulated (`HonestyTexts`).

## Ownership (Smaran's areas)
`explore`, `item_details`, `borrower_bookings`, `notifications`, `reviews`, `rental_core/lib/money`, `terms_checkbox.dart`, admin `analytics` and `audit_log`, `integration_test`, `docs/test-plan.md`, `docs/api-contract.md` (with Srijan), `rental_data/lib/models` and `repositories` (with Srijan).

## Commands
```
scripts\bootstrap.ps1                                  # first time
flutter pub get                                        # repo root
cd packages\rental_core && flutter test                # money
cd packages\rental_data && flutter test                # models and fakes
cd apps\mobile && flutter test                         # widget tests
cd apps\mobile && flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
flutter analyze
dart format --output=none --set-exit-if-changed apps packages
```

---

## Current state (update after every change)
Last updated: 2026-11-24

| Item | State |
| --- | --- |
| Team contract `docs/api-contract.md` | **Team v0.3 is the source of truth** (Smaran's v0.1 is superseded). Financial rules approved; the other decisions in its section 9 are open. Later local migrations and `supabase/IMPLEMENTATION_STATUS.md` exist but were not shared with this package: check field names against them. |
| `rental_core/lib/money/money.dart`, `money_cases.json`, `money_test.dart` | Written. Logic run on Dart SDK 3.14.1 against all 15 fixture cases: 0 failures. Test file (40 tests) run with a stand-in test runner: pass. **Not yet run with real `flutter test`.** |
| `rental_data` models, repository interfaces, fakes, tests | Aligned to the team contract (committed schema names, fractional rates, no default settings). `dart analyze` clean with the repo's lint rules (stand-in `equatable`); 55 tests pass with a stand-in test runner. **Not yet run with the real packages.** |
| `rental_data/pubspec.yaml` | Adds `rental_core` path dependency (needed for `Money` and `AppException`). Needs `flutter pub get`. |
| Explore and Item details (`apps/mobile`) | Written against fakes, formatted and parsed. **Not compiled or run**: needs `flutter analyze`, `flutter test`, and a device check. Riverpod 3 and `material_ui` APIs were used by analogy with the repo, not verified. |
| `docs/state-machine.md` | Needs the cancel, reject, re-submit and damage paths from the contract |
| Supabase repositories and RPCs | Not started or not deployed (Srijan). Migration `20261124000000_add_updated_at_triggers.sql` is written but not applied. |

## Changelog
| Date | File or area | What changed |
| --- | --- | --- |
| 2026-11-24 | `rental_core/lib/money`, `test/money_test.dart`, `shared/fixtures/money_cases.json` | Money library, 13 fixture cases (7 breakdown, 6 late fee), tests |
| 2026-11-24 | `rental_data/lib/models/*`, `repositories/*`, `fake/*` | Models, repository interfaces, fakes with 12 sample items |
| 2026-11-24 | `apps/mobile/lib/features/explore/*`, `item_details/*`, `test/*` | Explore and Item details screens on the fakes, widget tests |
| 2026-11-25 | models, fakes, fixtures, tests, screens | **Aligned to the team contract v0.2**: JSON keys `daily_rate`, `pickup_area`, `status`, `agreed_daily_rate`, `rental_days`, `lender_earning`, `content`; rates as fractions (`Money.bpsFromRate`); `AppSettings` read from `app_settings` rows with no defaults; `Item.pickupArea` replaces `Item.area` (area is derived); `ItemStatus` and `TermsStatus` added; `blocksDates` now includes `returned` and `disputed`; terms versions are text; `Booking.termsVersionIds` is a list |
| 2026-11-25 | money, settings, fixtures, fakes, tests | **Contract v0.3 financial rules applied**: deposit 20% (worked example is now fee 10,500, deposit 32,000, commission 1,050, renter earning 9,450, Borrower pays 42,500), half-up rounding approved, fixtures rebuilt (9 breakdown cases including the approved boundary example, 6 provisional late-fee cases), `AppSettings` requires only the three approved settings, `fakeDefaults` holds only those three, late-fee code marked provisional |
| 2026-11-25 | `docs/phase0-dart-mapping.md` | New: mapping of the Dart code to the contract and what changes if a decision goes the other way |
| 2026-11-25 | `docs/api-contract.md` | Removed from this package: the team's version stays |

## Next (in order)
1. Apply the zip to the repo on a branch (do NOT touch `docs/api-contract.md`), run `flutter pub get`, `flutter analyze`, the three `flutter test` runs and `dart format --output=none --set-exit-if-changed apps packages`. Fix whatever the real toolchain reports (most likely: Riverpod 3 API details, `material_ui` exports, `equatable` 3.0 API).
2. Open PRs in this order: money (Srijan reviews SQL parity), models and repositories, Explore and Item details, docs.
3. Give Srijan and Mohan your answers on the contract's section 9. Money representation and rounding are settled. Still open: grace period, late-day rounding and cap; field names; terms; availability; handover-code delivery; extra RPC names; idempotency.
4. Check `shared/fixtures/money_cases.json` against Srijan's SQL (both the basis-point and fraction fields).
5. Update `docs/state-machine.md` with the cancel, reject, re-submit and damage paths.
6. Ask Mohan: add `@Smaran-Aryal` to `docs/state-machine.md` and lines for `supabase/tests/` and `supabase/seed/` in CODEOWNERS; review this `AGENTS.md`.
7. Add `table_calendar` to `apps/mobile/pubspec.yaml` and replace the built-in date range picker so taken dates are greyed out before selection.
8. Move `friendlyBookingError` into `rental_core/errors` (Mohan) when he agrees.
9. Phase 1: `borrower_bookings` (status timeline, borrower terms tick with `TermsCheckbox`, payment proof upload, receipt, refund status), then `notifications`.
10. When Srijan's migrations and RPCs land, add Supabase repository classes and change only the three providers in `catalog_providers.dart`.

## Known risks and open questions
- The late-fee formula (whole days after the end of the end date plus grace hours, part days round up, capped at the deposit, no commission) is an assumption, not an agreed rule (only the 1.5x multiplier is approved). The old 25% deposit example is obsolete.
- Handover code: hash only at rest, delivery to the Borrower is an open decision (contract section 9). Nothing in the Dart code depends on it.
- Item photos in the fakes use `picsum.photos` placeholders.
- Docker and the Supabase CLI are not needed until the first migration is merged.

## How to update this file
After each generated or changed file add one row to **Changelog**, update **Current state**, and rewrite **Next** so item 1 is the very next action.
