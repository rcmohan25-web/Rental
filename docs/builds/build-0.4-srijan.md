# Build 0.4, Srijan (Phase 1: data layer, public items, listings)

**Merge order: SECOND, after Mohan's zip** (it replaces Mohan's `RentalBackend` stub and implements his interfaces). Independent of Smaran's zip.
Branch: `feature/phase1-data-listings`. Label the PR `phase-1`. The SQL part can also go as its own PR first (`feature/phase1-sql`); it does not need Mohan's zip.

## What this build delivers
**Database (additive, nothing from earlier migrations is edited)**
- `20261126010000_phase1_items_and_public_settings.sql`: `items.deleted_at`; `item_is_public` hides deleted items; owner sees only non-deleted rows; direct DELETE removed; `delete_item` RPC; view `public_items` (Renter first name, no address); `get_public_settings()`; `min_deposit_amount` in the settings whitelist and cross-checked with `min_declared_value`.
- `20261126010100_min_deposit_snapshot.sql`: `bookings.min_deposit_amount`; 6-argument `calculate_money` (`max(round_half_up(declared x rate), minimum)`, 5-argument form kept); snapshot validity and immutability include the minimum; `create_booking_request` reads, validates and stores it (fails closed with `SETTING_UNAVAILABLE`).
- `supabase/seed/seed.sql` (placeholder operational settings, prototype terms in all three audiences) and `demo_seed.sql` (12 Kathmandu valley items for demo accounts).
- `supabase/tests/phase1_regression.test.sql` (40 assertions).

**Dart data layer** (`packages/rental_data`)
- Supabase repositories: auth, profile, KYC, admin KYC, items (keyset pagination on the `public_items` view), settings, listings; error mapping (`RAISE EXCEPTION '<CODE>'` becomes `AppException(code)`).
- `RentalBackend` (replaces Mohan's stub): `initialize(url, anonKey)`, `isLive`, factories for every repository.
- `ListingRepository` interface, `FakeListingRepository`, tests.

**Mobile** (`renter_listings`): Listings tab (status chips, pause, publish, edit, delete), Add and Edit form with 1 to 5 photos, private pickup address, ID gate before adding or publishing.

**Docs**: `docs/data-model.md` (ER diagram), `docs/security.md`, `docs/proposals/contract-v1.1-phase1.md` (the `contract-change` PR text).

## Checked here, and what was not
- The two migrations and `phase1_regression.test.sql` were run on a local PostgreSQL 16 with pgTAP against a **reduced stub** of the earlier schema (profiles, items, bookings, settings, the functions this build replaces): 40 of 40 assertions pass, and both seed files run (the demo seed twice, so it is repeatable).
- **Not run:** the full migration chain, the older suites after the two test patches, `check_concurrent_overlap.py`, anything against a real Supabase project, and all Dart beyond the formatter. Run `python -B supabase/tests/run_local_regression.py fresh` (expect 101 + 85 + 40 assertions, 0 failures) before you merge, and tell me the result.

## Done when (Srijan's gate)
Migrations apply from scratch, the regression runner is green, the app (with `env/dev.json`) signs up, submits an ID (admin approves it in the admin panel), the Renter publishes an item with photos and the Borrower sees it in Explore (that step needs Smaran's zip). Update `docs/evidence/` with the runner log.
