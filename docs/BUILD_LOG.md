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

## Build 0.2, Phase 0 database and contract (Srijan)
- Added: `supabase/migrations/` (4 files): `profiles` with the sign-up trigger, `items`, `bookings` with the double-booking exclusion constraint, `app_settings`, `terms_documents` (seeded terms v1, prototype templates); RLS and column grants; four storage buckets (public `item-photos`; private `kyc-documents`, `handover-evidence`, `payment-proofs`) with policies; RPCs `get_item_blocked_dates` and `get_public_profiles`.
- Added: `supabase/seed/seed.sql` (local only) and `demo_seed.sql` (cloud, no passwords in the file), `supabase/tests/` (3 pgTAP files, 131 tests).
- Replaced: `docs/api-contract.md` (DRAFT v0.2: all 16 planned RPC names with params, returns, errors, callers and transitions; entities; storage rules; error codes; open questions), `docs/data-model.md`, `docs/security.md`, `shared/fixtures/status_transitions.json`, `supabase/README.md`.
- Added: `docs/setup/supabase-setup-srijan.md`, `docs/evidence/phase0-pgtap-results.md`.
- Needs a decision: the PROPOSED RPCs (`submit_kyc`, `cancel_booking`, `get_booking_contact`, `get_earnings_summary`, `expire_stale_requests`) and the four open questions in `docs/api-contract.md` section 7. The contract is not frozen until Smaran and Mohan approve.
- Placeholders: commission 10% and deposit 25% are placeholder values until the business notes confirm them; terms v1 are templates ("prototype, not legal advice").
- Not yet done: `supabase init` (creates `config.toml`), `supabase test db` on the real local stack, pushing to `rental-dev` and `rental-demo`. Steps are in `docs/setup/supabase-setup-srijan.md`.
- Next (Phase 1): `submit_kyc`, `admin_review_kyc`, listing photo upload, `create_booking_request` (Srijan); ID gate and KYC queue (Mohan).
