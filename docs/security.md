# Security notes

**Owner: Srijan.** State after Build 0.4. Details of each rule are in the migrations and `docs/api-contract.md` sections 5 and 10.

## Who can read and write what

| Data | Anonymous | Signed-in user | Admin |
| --- | --- | --- | --- |
| Public item cards (`public_items`) | read | read | read |
| `items`, `item_pickup_details` | active, not deleted, owner eligible (cards only) | own rows; writes only own items | read all |
| `profiles` | none | own row; may change `display_name` only | read all |
| `profile_private` | none | own row (phone, area, payout) | read all |
| `bookings` and booking records | none | only as Borrower or Renter of the booking, read only | read all |
| `app_settings` | none | `get_public_settings()` (whitelist) | read all, write through `admin_update_setting` |
| `kyc`, `handover` buckets | none | upload into own folder; **cannot read back** | read |
| `payment-proof` bucket | none | uploader reads own | read |
| `item-photos` bucket | read | write into own folder; referenced photos cannot be changed or deleted | |

Role, account status, KYC status and every money column are never client-writable: column grants plus RPC-only changes.

## Rules to keep when adding code

- Every new table: RLS on, explicit grants, no default access (the default privileges are revoked).
- Every new function: `SECURITY DEFINER`, `SET search_path = ''`, `REVOKE ... FROM PUBLIC, anon`, explicit `GRANT ... TO authenticated`, caller and status checks first.
- A view that crosses an RLS boundary (like `public_items`) must filter inside the view and expose no private column. Check it with the "card view has no address, phone or full name" test.
- Error transport: RPC errors are `RAISE EXCEPTION '<CODE>'`; the app maps the PostgREST message to the code. Verify once through a real client (contract section 12, item 13).

## Not implemented yet (do not assume)

- Handover code (hashed, single-use, locks after 5 wrong tries) and `admin_verify_payment`: Phase 2.
- Contact and exact address unlock after `payment_verified` (`get_booking_contact`): Phase 2.
- Account deletion and retention jobs: Phase 4.

## Security test evidence

Run `python -B supabase/tests/run_local_regression.py fresh` (needs the local Supabase Docker stack) and keep the log from `supabase/tests/results/` in `docs/evidence/`. Manual checks to add to the log before Phase 2 ends: open another user's ID photo URL, read a Renter's exact address, delete an item with an accepted booking, call `get_public_settings` as anon.
