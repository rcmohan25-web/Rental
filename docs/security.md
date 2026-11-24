# Security notes

**Owner: Srijan.** What is in place after Phase 0. Test evidence: `docs/evidence/phase0-pgtap-results.md`.

## 1. Approach: three layers

1. **Column grants.** Supabase gives signed-in users broad table access by default. The Phase 0 migration revokes everything, then grants back only what the apps need. This is what stops a user editing their own `role` or `kyc_status`, even though they may update their own profile row.
2. **Row Level Security (RLS).** Policies decide which rows a user can read or write. A table with RLS on and no matching policy rejects the action (default deny).
3. **RPCs and constraints.** Everything that changes a booking, an ID status, a setting or terms goes through a `SECURITY DEFINER` function that checks the caller and the current status. The database itself refuses overlapping bookings, wrong fees and invalid values.

All functions use `set search_path = ''` and fully qualified names, so a caller cannot hijack them with a look-alike object.
The service-role key is never used by the apps; it exists only in Edge Function secrets and Mohan's password manager.

## 2. Table access (apps use the `authenticated` role; `anon` = not signed in)

| Table | anon | Signed-in user | Admin |
| --- | --- | --- | --- |
| `profiles` | nothing | read **own** row; update own `full_name`, `phone`, `area` (only while `active`) | read all; role/status/kyc only via RPC |
| `items` | nothing | read `active` items and own `paused` ones; insert own (status `active` or `paused`, not suspended); update own non-deleted; **no delete** | read all, incl. deleted |
| `bookings` | nothing | read where they are Renter or Borrower; **no insert, update or delete** | read all |
| `app_settings` | nothing | read | read; change via `admin_update_setting` |
| `terms_documents` | read | read | read; publish via `admin_publish_terms` |

Contact details: other people's phone numbers are not readable from any table. `get_public_profiles` returns only name, area and the verified badge.

## 3. Storage

| Bucket | Visibility | Write | Read |
| --- | --- | --- | --- |
| `item-photos` | public | own folder `<user_id>/` | everyone |
| `kyc-documents` | private | own folder, insert only | admins only (even the owner cannot read it back) |
| `handover-evidence` | private | the booking's Renter, from `payment_verified` onwards | the booking's Renter and Borrower, admins |
| `payment-proofs` | private | the booking's Borrower, while `awaiting_payment` or `payment_submitted` | the Borrower and admins; **never the Renter** |

Every bucket allows 5 MB and images only (`payment-proofs` also PDF). Users cannot overwrite or delete private files, which keeps the evidence trail intact.
A suspended user cannot upload.

## 4. Other protections

- **Sign-up trigger** ignores `role`, `status`, `kyc_status` in user metadata.
- **Suspended users** fail `is_active_user()`: no new listings, no uploads, no profile edits.
- **Terms immutability:** a trigger rejects editing or deleting a published version.
- **Realtime** on `bookings` respects the same RLS, so a user only receives their own bookings.
- **Dates** are date-only and interpreted in `Asia/Kathmandu` (`today_kathmandu()`).
- **Logs:** nothing sensitive is written by the migrations. Apps must not log ID photo paths, phone numbers or handover codes.

## 5. Planned for later phases (not built yet)

- **Handover code:** 6 digits, generated when payment is verified, stored hashed, single use, locks after 5 wrong tries (`wrong_code`, `code_locked`). How the Borrower reads the code is an open question in `docs/api-contract.md`.
- **Contact and address hiding** until `payment_verified` (`get_booking_contact`, `item_pickup_details`).
- **Audit log** written by every admin RPC.
- **Edge Function `delete-user`** for account deletion.

## 6. Known limits and honest notes

- Commission (10%) and deposit (25%) are **placeholder** values.
- The seeded terms are **templates** ("prototype, not legal advice") and need review before real use.
- "Verified" means an admin looked at the ID. Nothing is automatic.
- The test results in the evidence file were produced on a plain PostgreSQL 16 with a small emulation of the Supabase pieces (`auth`, `storage`, the roles). Run `supabase test db` on the real local stack and keep that output as the final evidence.
- Not yet checked: `supabase db lint`, and the Supabase dashboard's Security Advisor on `rental-dev`. Check both after the first `db push`.
