# auth

**Owner: Mohan**

Splash, landing (welcome), sign-up (with the optional ID step and a "Do it later" link), login.

Layout
- `routes.dart`: `/splash`, `/welcome`, `/login`, `/sign-up`, `/sign-up/id`.
- `application/auth_providers.dart`: `authRepositoryProvider`, `AuthRefresh` (re-runs the router redirect on sign-in or sign-out) and `mobileRedirect` (the auth guard).
- `application/auth_error_messages.dart`: friendly text for auth error codes and the form validators.
- `presentation/`: the five screens.

How the guard works: signed-out users can only open splash, welcome, login and sign-up. Signed-in users are moved from splash, welcome and login to `/explore`. `/sign-up` is not redirected so the optional ID step is not skipped.

Rules: use repository interfaces from `rental_data` (fakes first), no direct Supabase calls from screens,
handle loading, empty and error states, edit only this folder (open an issue for anything else).
