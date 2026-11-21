# shell

**Owner: Mohan.** Side navigation, layout and the admin role guard.

- `presentation/admin_shell.dart`: AppBar titled "Rental Admin", side nav (drawer on narrow screens).
- `presentation/admin_side_nav.dart`: navigation entries. Add a new admin screen here and in its feature's `routes.dart`.
- `application/admin_guard.dart`: redirect that only lets signed-in accounts with role = admin through (Phase 1).
