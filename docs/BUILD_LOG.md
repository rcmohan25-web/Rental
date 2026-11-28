# Build log

Each build adds one entry. Each member's zip replaces the files it lists.

## Build 0.1, Phase 0 skeleton (Mohan)
- Added: full monorepo folder structure from plan Section 9, Dart workspace, shared lint rules.
- Added: `.github` (CODEOWNERS, PR template, issue templates, 5 workflows).
- Added: `packages/rental_core` (brand theme, shared widgets, formatters, honesty texts), `packages/rental_data` (empty barrels).
- Added: `apps/mobile` and `apps/admin_web` with placeholder screens for every feature, routers, admin shell and side nav.
- Added: README files, setup instructions, bootstrap scripts, `docs/` placeholders.
- Placeholders owned by others: `money.dart`, `terms_checkbox.dart` (Smaran), models and contract (Smaran + Srijan), `supabase/` (Srijan).
- Fixed after first CI run: stray root Flutter files removed, Android Gradle plugin raised to 9.1.1.

## Build 0.2, Phase 0 completion (Mohan)
- Supervisor decisions recorded in `docs/business-rules.md` (minimum fixed deposit, no renter fee, static QR payments, Sapati legal review).
- Added: `SettingKeys` and `PaymentChannel` in `rental_core`, new honesty texts, widget and constant tests.
- Added: Rental branding for the admin web (title, manifest, theme colour) and the Android launch splash (brand navy).
- Added: `assets/payment_qr/` guide for the static eSewa, Khalti and bank QR images.
- Added: branch ruleset file, Dependabot for Actions, `scripts/setup_github.mjs` (labels and Phase 0/1 issues), CI Flutter version in one place.
- Updated: README files, setup guides (`docs/setup/`), `docs/00-START-HERE.md`, `docs/honesty-rules.md`.

## Build 0.3, API contract v1.0 freeze (Mohan)
- Added: `docs/api-contract.md` v1.0 (frozen on merge), updated `docs/business-rules.md` (20% deposit example), `docs/state-machine.md`, `scripts/setup_github.mjs` money issue text.
- Process: changes to the contract or models need a PR labelled `contract-change` and all three approvals.
- Delivered in parallel by the others (already on GitHub): Smaran's `money.dart`, fixtures, models, fakes, Explore and Item details; Srijan's 19 backend migrations and 3 SQL test suites on `srijan/backend` (see `supabase/IMPLEMENTATION_STATUS.md`).

## Build 0.4, Phase 1: identity and listing (three zips, one per member)
Merge order: **Mohan, then Srijan and Smaran** (those two do not depend on each other).

- **Mohan** (`build-0.4-mohan.zip`): auth and sign-up with optional ID step, profile and Verify identity, ID gate helper, bottom navigation, photo selector with compression, admin sign-in and role guard, admin ID verification queue, identity repository interfaces and fakes, `RentalBackend` seam (stub), INTERNET permission. Manifest: `docs/builds/build-0.4-mohan.md`.
- **Srijan** (`build-0.4-srijan.zip`): Supabase implementations of every repository (replaces the `RentalBackend` stub), migrations for the public items view, soft delete, public settings and the minimum deposit, listings repository and the renter listings screens, dev seed, tests, data model and security docs. Manifest: `docs/builds/build-0.4-srijan.md`.
- **Smaran** (`build-0.4-smaran.zip`): minimum deposit in `money.dart`, fixtures, settings and booking models (a `contract-change` PR), Explore and Item details switched to `RentalBackend` with the ID gate, `TermsCheckbox` widget, test plan. Manifest: `docs/builds/build-0.4-smaran.md`.

Phase 1 gate: sign up, submit ID, renter lists an item, borrower sees it.

Next (Build 0.5, Phase 2): request to payment. Booking and payment repositories live, renter inbox with the terms tick, borrower payment screen with QR and proof upload, admin order queue and payment verification, terms manager and platform settings screens, `admin_verify_payment` and the handover code RPCs.
