# item_details

**Owner: Smaran**

Photo carousel, condition, daily price, deposit shown separately, date picker with blocked dates, cost breakdown.

Layout
- `routes.dart`: exposes `itemDetailsRoutes`, aggregated by the app router. Keep all paths of this feature here.
- `presentation/`: screens and widgets.
- `application/`: Riverpod providers and controllers.

Rules: use repository interfaces from `rental_data` (fakes first), no direct Supabase calls from screens,
handle loading, empty and error states, edit only this folder (open an issue for anything else).
