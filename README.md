# Rental by Sapati

**Rental** is a peer-to-peer item rental app for the Kathmandu Valley (Kathmandu, Lalitpur, Bhaktapur), owned and operated by **Sapati** (sapati.com).
Flutter-only frontend, Supabase backend, built for robustness at near-zero running cost.

- **Renter** = the person who lends the item. **Borrower** = the person who takes it. (Code and DB: `lender_id`, `borrower_id`.)
- Android app for Borrowers and Renters, Flutter Web admin panel (**Rental Admin**) for Sapati staff.
- Payments are manual in this prototype: the Borrower scans Sapati's static QR (eSewa, Khalti or bank) and uploads proof. See `docs/honesty-rules.md`.
- Sapati earns a commission from the rental fee. The Renter pays no fee. The security deposit is a percentage of the declared value with an admin-set minimum. See `docs/business-rules.md`.

The full plan is in `docs/reference/Rental_by_Sapati_Final_Implementation_Plan.docx`. Decisions made with the supervisor after the plan are in `docs/business-rules.md` and win over the plan.

## Status
Phase 0 (skeleton and contracts): repository, CI, theme and shared widgets done. Contract and first migration in progress. Tracked in `docs/BUILD_LOG.md` and the GitHub issues.

## Quick start
```bash
git clone <repo-url> && cd Rental
flutter pub get
cp env/dev.example.json env/dev.json     # fill in values (ask Srijan)
cd apps/mobile && flutter run --dart-define-from-file=../../env/dev.json
```
Use Flutter 3.47.3 (see `docs/setup/machine-setup.md`). New here? Read `docs/00-START-HERE.md`, then your own instruction file.

## Repository layout
```
apps/
  mobile/        Android app (Borrower + Renter)
  admin_web/     Flutter Web admin panel
packages/
  rental_core/   theme, shared widgets, formatters, constants, money.dart, terms_checkbox
  rental_data/   models, repositories (abstract, supabase/, fake/)
supabase/        migrations, Edge Function, seed, pgTAP tests   (Srijan only)
shared/          fixtures shared by Dart and SQL tests
docs/            setup guides, business rules, contract, data model, security, state machine, tests, evidence
scripts/ tools/  bootstrap, GitHub setup and helper scripts
env/             example config (real *.json files are git-ignored)
.github/         CODEOWNERS, rulesets, PR and issue templates, workflows
```

## Who owns what
| Person | Owns |
| --- | --- |
| **Mohan** (lead) | repo setup, CI, `rental_core` theme and widgets, mobile `auth` and `profile_kyc`, admin web (shell, users, ID queue, terms manager, settings, orders, payments, settlement, disputes), releases |
| **Smaran** | borrower features (`explore`, `item_details`, `borrower_bookings`, `notifications`, `reviews`), `money.dart`, `terms_checkbox`, admin analytics and audit log, test plan and QA |
| **Srijan** | `supabase/` (migrations, RLS, RPCs, jobs, Edge Function, seed), Supabase repositories, renter features (`renter_*`), pgTAP and security tests |

## Common commands
| Task | Command |
| --- | --- |
| Install dependencies | `flutter pub get` (repo root) |
| Format | `dart format .` |
| Analyze | `flutter analyze` |
| Test a package | `cd packages/rental_core && flutter test` |
| Run mobile | `cd apps/mobile && flutter run --dart-define-from-file=../../env/dev.json` |
| Run admin | `cd apps/admin_web && flutter run -d chrome --dart-define-from-file=../../env/dev.json` |
| Release APK | `cd apps/mobile && flutter build apk --release --dart-define-from-file=../../env/demo.json` |
| Build admin | `cd apps/admin_web && flutter build web --release --dart-define-from-file=../../env/demo.json` |
| Create labels and issues | `node scripts/setup_github.mjs --mohan <u> --smaran <u> --srijan <u>` |

## Build phases
0 Skeleton and contracts, 1 Identity and listing, 2 Request to payment, 3 Handover, return and settlement, 4 Automation and hardening, 5 Release.

## Rules in one minute
One owner per folder, `main` is protected, squash merge, keep PRs under about 400 lines, run `dart format .` before every push, never commit secrets.
Details: `CONTRIBUTING.md`.
