# orders

**Owner: Mohan**

Order queue and approval when auto_approve_orders is off.

Layout
- `routes.dart`: exposes `ordersRoutes`, aggregated by the app router. Keep all paths of this feature here.
- `presentation/`: screens and widgets.
- `application/`: Riverpod providers and controllers.

Rules: use repository interfaces from `rental_data` (fakes first), no direct Supabase calls from screens,
handle loading, empty and error states, edit only this folder (open an issue for anything else).
