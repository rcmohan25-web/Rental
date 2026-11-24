# Phase 0 database test results (pgTAP)

**Owner: Srijan.** Output of the three pgTAP files in `supabase/tests/`, run against the migrations **and** the dev seed.

> **Where this was run:** a plain PostgreSQL 16.15 with pgTAP 1.3, plus a small emulation of the Supabase pieces the migrations need
> (the `anon` / `authenticated` / `service_role` roles, `auth.users`, `auth.uid()`, `storage.buckets` / `storage.objects` / `storage.foldername`).
> It is **not** the real Supabase stack. Before the demo, run `supabase test db` on your local stack and replace this file with that output.

Result: **131 tests, 0 failures** (46 schema + 54 security + 31 storage).

## supabase/tests/01_schema.test.sql

```
1..46
ok 1 - profiles table exists
ok 2 - items table exists
ok 3 - bookings table exists
ok 4 - app_settings table exists
ok 5 - terms_documents table exists
ok 6 - sign-up trigger is installed on auth.users
ok 7 - a profile is created for every new auth user
ok 8 - name, phone and area are copied from sign-up metadata (name is trimmed)
ok 9 - role, status and kyc_status in metadata are ignored
ok 10 - a user with no metadata still gets a profile
ok 11 - an unknown area and a too-short phone are dropped instead of blocking sign-up
ok 12 - first accepted booking is stored
ok 13 - days are inclusive: 6 to 8 March is 3 days
ok 14 - overlapping accepted booking is rejected
ok 15 - sharing only the last day is still an overlap (end date is inclusive)
ok 16 - sharing only the first day is also an overlap
ok 17 - the day after the last booked day is free
ok 18 - a plain request does not block dates (many people can ask for the same days)
ok 19 - declined bookings do not block dates
ok 20 - the same dates on a different item are fine
ok 21 - cancelling a booking frees its dates
ok 22 - accepting a request whose dates are now taken is rejected by the database
ok 23 - end date before start date is rejected
ok 24 - a Renter cannot book their own item
ok 25 - rental fee must equal days x daily price
ok 26 - an unknown status is rejected
ok 27 - commission rate must be a fraction between 0 and 1
ok 28 - a listing needs at least one photo
ok 29 - a listing allows at most five photos
ok 30 - daily price must be above zero
ok 31 - area must be Kathmandu, Lalitpur or Bhaktapur
ok 32 - category must be one of the allowed values
ok 33 - an item must belong to an existing profile
ok 34 - the four baseline settings are seeded
ok 35 - commission rate above 1 is rejected
ok 36 - auto_approve_orders must be true or false
ok 37 - request expiry must be above zero
ok 38 - a valid commission rate is accepted
ok 39 - one active version 1 exists for each of the three term sets
ok 40 - every seeded term set is marked as a prototype, not legal advice
ok 41 - two active versions of the same kind are not allowed
ok 42 - publishing is: deactivate the old version, insert the new one as active
ok 43 - a published version cannot be edited
ok 44 - a published version cannot be deleted
ok 45 - updated_at is refreshed by the trigger on every update
ok 46 - today_kathmandu() uses Nepal time
```

## supabase/tests/02_security_rls.test.sql

```
1..54
ok 1 - profiles: a user sees only their own profile
ok 2 - profiles: a user cannot make themselves admin
ok 3 - profiles: a user cannot mark their own ID as verified
ok 4 - profiles: a user cannot change their own account status
ok 5 - profiles: a user can edit their own name and area
ok 6 - profiles: updating someone else matches no rows (no error, no change; checked below)
ok 7 - profiles: clients cannot insert profiles (the sign-up trigger does that)
ok 8 - profiles: clients cannot delete profiles
ok 9 - items: a user can create their own listing
ok 10 - items: a user cannot create a listing for someone else
ok 11 - items: a new listing must start active or paused
ok 12 - items: an owner can edit their listing
ok 13 - items: an owner cannot hand a listing to someone else
ok 14 - items: updating someone else's listing matches no rows (checked below)
ok 15 - items: an owner still sees their own paused listing
ok 16 - items: a soft-deleted listing is hidden from its owner
ok 17 - items: listings are never hard-deleted by clients
ok 18 - blocked dates: the owner sees dates of their own paused listing
ok 19 - bookings: the lender sees every booking on their items
ok 20 - bookings: clients cannot create bookings directly (only the RPC can)
ok 21 - bookings: a lender cannot move a booking to another status directly
ok 22 - bookings: clients cannot delete bookings
ok 23 - app_settings: signed-in users can read settings
ok 24 - app_settings: clients cannot change settings (admin RPC only)
ok 25 - terms: clients cannot publish terms
ok 26 - is_admin() is false for a normal user
ok 27 - bookings: the borrower sees their own bookings
ok 28 - profiles: a borrower cannot read the Renter's private profile
ok 29 - get_public_profiles: other users can see a name
ok 30 - get_public_profiles: the phone number is not exposed
ok 31 - bookings: a stranger sees none
ok 32 - items: everyone signed in sees an active listing
ok 33 - items: paused and deleted listings are hidden from strangers
ok 34 - blocked dates: a stranger sees accepted dates only (a plain request does not block)
ok 35 - blocked dates: nothing is revealed for a paused listing the caller cannot see
ok 36 - items: a stranger's update matches no rows (checked below)
ok 37 - items: a suspended user cannot create listings
ok 38 - profiles: a suspended user's edit matches no rows (checked below)
ok 39 - is_active_user() is false for a suspended user
ok 40 - anon: cannot read profiles
ok 41 - anon: cannot read items
ok 42 - anon: cannot read settings
ok 43 - anon: cannot call get_item_blocked_dates
ok 44 - anon: can read terms (the sign-up screen shows them)
ok 45 - is_admin() is true for an active admin
ok 46 - profiles: an admin can read every profile
ok 47 - items: an admin sees paused and deleted listings
ok 48 - bookings: an admin can read every booking (test rows only; the seed adds others)
ok 49 - profiles: even an admin changes roles only through an RPC, not a direct update
ok 50 - unchanged: A could not rename B
ok 51 - unchanged: A could not edit B's listing
ok 52 - unchanged: the stranger could not edit A's listing
ok 53 - unchanged: the suspended user could not edit their profile
ok 54 - unchanged: A is still a normal user
```

## supabase/tests/03_storage.test.sql

```
1..31
ok 1 - four buckets exist: only item-photos is public, all are limited to 5 MB
ok 2 - kyc-documents accepts images only
ok 3 - item-photos: a user can upload into their own folder
ok 4 - item-photos: a user cannot upload into someone else's folder
ok 5 - item-photos: a second upload works
ok 6 - item-photos: a user can delete their own photo
ok 7 - item-photos: the deleted photo is gone
ok 8 - item-photos: deleting someone else's photo matches no rows (checked below)
ok 9 - item-photos: the stranger could not delete A's photo
ok 10 - item-photos: anyone, even not signed in, can see listing photos
ok 11 - item-photos: not signed in means no upload
ok 12 - kyc: a user can upload their own ID photo
ok 13 - kyc: a user cannot upload into another user's folder
ok 14 - kyc: even the owner cannot read ID photos back (admins only)
ok 15 - kyc: a user's delete matches no rows (checked below)
ok 16 - kyc: a suspended user cannot upload
ok 17 - kyc: an admin can read ID photos (and the owner's delete changed nothing)
ok 18 - handover: the booking's Renter can upload evidence once payment is verified
ok 19 - handover: no evidence upload while the booking is only requested
ok 20 - handover: a folder that is not a booking id is rejected cleanly
ok 21 - handover: the Borrower cannot upload handover evidence
ok 22 - handover: the Borrower can read the evidence of their booking
ok 23 - handover: a stranger cannot read it
ok 24 - handover: a stranger cannot upload to it
ok 25 - payment: the Borrower can upload proof while payment is due
ok 26 - payment: no proof upload once payment is already verified
ok 27 - payment: the Borrower can read their own proof
ok 28 - payment: the Renter cannot upload payment proof
ok 29 - payment: the Renter cannot see payment proof
ok 30 - payment: an admin can read payment proof
ok 31 - handover: an admin can read handover evidence
```

