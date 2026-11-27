# renter_listings

**Owner: Srijan**

Add, edit, pause and delete listings (1 to 5 photos, declared value, rules, pickup area).

Layout
- `routes.dart`: `/listings` (Listings tab), `/listings/new`, `/listings/:id/edit`.
- `application/listing_providers.dart`: `listingRepositoryProvider`, `myItemsProvider`.
- `application/listing_error_messages.dart`: friendly text for contract error codes, `parseNpr`.
- `presentation/renter_listings_screen.dart`: the Renter's items with status chips, Pause, Publish, Edit, Delete, and the Add listing button.
- `presentation/listing_form_screen.dart`: the form. "Publish" saves as active, "Save as draft" as draft. The exact address is private.

ID gate: Add listing and Publish call `ensureIdSubmitted` (Mohan, `shared/id_gate.dart`). The database also enforces it (`KYC_REQUIRED`).
Saving order (in `SupabaseListingRepository`): upload photos, save a draft, save the private address, then publish. A failure in the middle leaves a draft, never a public listing without an address.

Rules: use repository interfaces from `rental_data` (fakes first), no direct Supabase calls from screens,
handle loading, empty and error states, edit only this folder (open an issue for anything else).
