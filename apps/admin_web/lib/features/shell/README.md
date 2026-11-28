# shell

**Owner: Mohan.** Side navigation, layout, sign-in and the admin role guard.

- `presentation/admin_shell.dart`: AppBar titled "Rental Admin" with a sign-out button, side nav (drawer on narrow screens).
- `presentation/admin_side_nav.dart`: navigation entries. Add a new admin screen here and in its feature's `routes.dart`.
- `presentation/admin_login_screen.dart`: `/login`. Shows "This account is not a Sapati admin." when a normal user signs in.
- `application/admin_guard.dart`: `AdminGate.redirect`. Not signed in goes to `/login`. A signed-in account whose profile is not an active admin is signed out and sent to `/login?denied=1`. The result is cached per user id. The database enforces the same rule on every admin read and RPC.
- `application/admin_providers.dart`: the repositories the panel uses and the auth refresh listenable.

Without SUPABASE_URL and SUPABASE_ANON_KEY the panel runs on fakes: admin@sapati.test / admin12345.
