# auth

**Owner: Mohan**

Splash, landing, sign-up (with optional ID step and a "Do it later" link), login.

Layout
- `routes.dart`: exposes `authRoutes`, aggregated by the app router. Keep all paths of this feature here.
- `presentation/`: screens and widgets.
- `application/`: Riverpod providers and controllers.

Rules: use repository interfaces from `rental_data` (fakes first), no direct Supabase calls from screens,
handle loading, empty and error states, edit only this folder (open an issue for anything else).
