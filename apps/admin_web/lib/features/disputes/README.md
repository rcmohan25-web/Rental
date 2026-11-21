# disputes

**Owner: Mohan**

Damage and non-return cases, decisions, legal action status.

Layout
- `routes.dart`: exposes `disputesRoutes`, aggregated by the app router. Keep all paths of this feature here.
- `presentation/`: screens and widgets.
- `application/`: Riverpod providers and controllers.

Rules: use repository interfaces from `rental_data` (fakes first), no direct Supabase calls from screens,
handle loading, empty and error states, edit only this folder (open an issue for anything else).
