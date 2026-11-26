# Build log

Each build adds one entry. The zip of that build replaces the files it lists.

## Build 0.1, Phase 0 skeleton (Mohan)
- Added: full monorepo folder structure from plan Section 9, Dart workspace, shared lint rules.
- Added: `.github` (CODEOWNERS, PR template, issue templates, 5 workflows).
- Added: `packages/rental_core` (brand theme, shared widgets, formatters, honesty texts), `packages/rental_data` (empty barrels).
- Added: `apps/mobile` and `apps/admin_web` with placeholder screens for every feature, routers, admin shell and side nav.
- Added: README files, setup instructions, bootstrap scripts, `docs/` placeholders.
- Placeholders owned by others: `money.dart`, `terms_checkbox.dart` (Smaran), models and contract (Smaran + Srijan), `supabase/` (Srijan).
- Next (Phase 1, Mohan): auth, profile and ID upload with the ID gate guard, admin shell role guard, ID verification queue.

## Build 0.2, Phase 0 Smaran part
- Added: `packages/rental_core/lib/money/money.dart` (days, fee, deposit, commission, renter earning, late days, late fee, and conversion of the database fractions to basis points) with `test/money_test.dart` and `shared/fixtures/money_cases.json` (15 cases: 9 breakdown and 6 provisional late-fee; case 1 is the plan's worked example with the approved 20% deposit, fee 10,500, deposit 32,000, commission 1,050, renter earning 9,450, Borrower pays 42,500; each breakdown case lists the rates both as basis points and as database fractions).
- Added: `packages/rental_data/lib/models/` (Profile, Item, Booking, LedgerEntry, TermsDocument, TermsAcceptance, AppSettings, DateRange, enums) aligned to the team's `docs/api-contract.md` (v0.3 financial rules applied: 20% deposit, 10% commission, 1.5x multiplier, half-up whole-NPR rounding): JSON keys follow the committed schema and the contract's proposed names, rates travel as fractions, `AppSettings` requires only the three approved settings and has no silent defaults; late-fee code is marked provisional. Tests included.
- Added: repository interfaces (`ItemRepository`, `BookingRepository`, `SettingsRepository`) and in-memory fakes with 12 sample Kathmandu Valley items.
- Added: `apps/mobile` Explore (search, category chips, filter sheet, keyset pagination, loading, empty, error states) and Item details (photo carousel, deposit shown separately, blocked dates, cost breakdown, idempotent request) running on the fakes, with widget tests.
- Added: `docs/phase0-dart-mapping.md` (how the Dart code maps to the team contract and what changes if a decision goes the other way).
- Changed: `packages/rental_data/pubspec.yaml` (one line: depends on `rental_core` for `Money` and `AppException`), `packages/rental_data/lib/rental_data.dart` (also exports the fakes), `apps/mobile/lib/features/item_details/routes.dart` (adds `/item-details/:id`), `docs/test-plan.md`.
- Not changed: `docs/api-contract.md` (the team's version stays as it is).
- Not done yet: contract freeze (nine decisions in the contract's section 9), real Supabase repositories (Srijan), `borrower_bookings` and `notifications`.
- Next (Smaran): borrower_bookings (status timeline, terms tick, payment proof), notifications, then swap fakes for Supabase repositories as RPCs land.
