# Phase 0 package for Smaran

This zip mirrors the repository layout. It is NOT part of the repo: copy the folders over your clone, review with `git status`, then commit in the order below.

## What is inside

| Path | New or changed | Owner (CODEOWNERS) |
| --- | --- | --- |
| `packages/rental_core/lib/money/money.dart` | **replaces the stub** | Smaran + Srijan |
| `packages/rental_core/test/money_test.dart` | new | Smaran + Srijan |
| `shared/fixtures/money_cases.json` | **replaces the placeholder** | Smaran + Srijan |
| `packages/rental_data/lib/models/*.dart` (11 files) | **models.dart replaced**, 10 new | all three |
| `packages/rental_data/lib/repositories/*.dart` | **repositories.dart replaced**, 3 new | Smaran + Srijan |
| `packages/rental_data/lib/repositories/fake/*.dart` | new (5 files) | Smaran + Srijan |
| `packages/rental_data/lib/rental_data.dart` | changed (also exports fakes) | default owner |
| `packages/rental_data/pubspec.yaml` | changed (adds `rental_core` dependency) | default owner |
| `packages/rental_data/test/*.dart` | new (2 files) | Smaran + Srijan |
| `apps/mobile/lib/features/explore/**` | `presentation/explore_screen.dart` replaced, others new | Smaran + Srijan |
| `apps/mobile/lib/features/item_details/**` | `presentation/item_details_screen.dart` and `routes.dart` replaced, others new | Smaran + Srijan |
| `apps/mobile/test/explore_screen_test.dart`, `item_details_screen_test.dart` | new | Smaran + Srijan |
| `docs/phase0-dart-mapping.md` | new | Smaran |
| `docs/test-plan.md`, `docs/BUILD_LOG.md` | replaced | see CODEOWNERS |
| `AGENTS.md`, `CLAUDE.md` | new at repo root | Mohan reviews |

The existing `.gitkeep` files in `application/` folders can stay.

**`docs/api-contract.md` is NOT in this zip on purpose.** The team's v0.3 is the shared contract (financial rules approved: 20% deposit, 10% commission, 1.5x multiplier, half-up rounding); the Dart code in this package was aligned to it (committed schema names, rates as fractions, no default settings, `blocksDates` matching the `prevent_double_booking` constraint). Do not overwrite the team's file.

## Apply

```
git checkout main && git pull
git checkout -b feature/phase0-smaran
# copy the contents of rental-phase0-smaran\ over the repo root, then:
flutter pub get
dart format --output=none --set-exit-if-changed apps packages
flutter analyze
cd packages\rental_core && flutter test && cd ..\..
cd packages\rental_data && flutter test && cd ..\..
cd apps\mobile && flutter test && cd ..\..
```

## What was and was not verified (be honest in your PR)

Verified outside Flutter, on the Dart SDK 3.14.1:
- `money.dart` against all 15 fixture cases: 0 failures (40 money tests pass with a stand-in test runner).
- Models, repositories and fakes pass `dart analyze` with the repo's lint rules; 55 tests pass using a stand-in test runner and a stand-in `equatable`.
- All files pass `dart format` with language version 3.6 (the style the repo uses).

NOT verified (Flutter and the pub packages were not available):
- The two screens and their widget tests were never compiled or run.
- Riverpod 3 usage (`Notifier`, `NotifierProvider`, `FutureProvider.autoDispose.family`, `overrideWithValue`), `material_ui` exports (`Badge`, `IconButton.outlined`, `showDateRangePicker`), and `equatable` 3.0 were used from knowledge, not checked.
- If the analyzer reports something, fix it in the PR and note it in `docs/BUILD_LOG.md`.

## Suggested commits and PRs (small, one reviewer each)

1. `feat: add money library and shared fixtures` (money.dart, money_test.dart, money_cases.json). Reviewer: Srijan (SQL parity).
2. `feat: add shared models and repository interfaces with fakes` (rental_data, pubspec change). Reviewer: Srijan, plus Mohan for the pubspec line.
3. `feat: add explore and item details on fake repositories` (apps/mobile). Reviewer: Srijan.
4. `docs: dart mapping, test plan, build log, AGENTS.md`. Reviewer: Srijan and Mohan.

The nine decisions in the team contract's section 9 still need answers before the freeze. `docs/phase0-dart-mapping.md` section 7 shows what changes in Dart for each.

## Things to tell Mohan

- `rental_data` now depends on `rental_core` (one pubspec line, as CONTRIBUTING allows). `rental_core` does not depend on `rental_data`, so there is no cycle.
- `catalog_providers.dart` (in `explore/application`) is where fakes will later be swapped for Supabase repositories.
- The Phase 0 skeleton link `/item-details` still works; `/item-details/:id` is new.
