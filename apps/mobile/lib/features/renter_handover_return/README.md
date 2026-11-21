# renter_handover_return

**Owner: Srijan**

Evidence photos, checklist, handover code entry, borrower ID and face photo, return and damage report.

Layout
- `routes.dart`: exposes `renterHandoverReturnRoutes`, aggregated by the app router. Keep all paths of this feature here.
- `presentation/`: screens and widgets.
- `application/`: Riverpod providers and controllers.

Rules: use repository interfaces from `rental_data` (fakes first), no direct Supabase calls from screens,
handle loading, empty and error states, edit only this folder (open an issue for anything else).
