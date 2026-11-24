# Build log

Each build adds one entry. The zip of that build replaces the files it lists.

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
- Handed to others via issues: `money.dart` minimum deposit (Smaran), `min_deposit_amount` in `app_settings` and bookings snapshot (Srijan).
- Next (Phase 1, Mohan): auth, profile and ID upload with the ID gate guard, admin role guard, ID verification queue.
