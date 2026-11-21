# settings

**Owner: Mohan**

Commission rate, deposit rate and other app_settings keys. Shows: Applies to new requests from now on.

Layout
- `routes.dart`: exposes `settingsRoutes`, aggregated by the app router. Keep all paths of this feature here.
- `presentation/`: screens and widgets.
- `application/`: Riverpod providers and controllers.

Rules: use repository interfaces from `rental_data` (fakes first), no direct Supabase calls from screens,
handle loading, empty and error states, edit only this folder (open an issue for anything else).
