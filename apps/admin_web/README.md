# apps/admin_web (Rental Admin, Flutter Web)

Panel for Sapati staff. Title: **Rental Admin**. Hosted on Cloudflare Pages (for example admin.sapati.com).

## Run
```bash
flutter run -d chrome --dart-define-from-file=../../env/dev.json
flutter build web --release --dart-define-from-file=../../env/dev.json
```

## Structure
```
lib/main.dart, app.dart           entry and MaterialApp.router (Mohan)
lib/router/admin_router.dart      ShellRoute plus each feature's routes (Mohan)
lib/features/shell/               side navigation, layout, admin role guard (Mohan)
lib/features/<feature>/           one owner per folder, see each README
```

| Feature | Owner |
| --- | --- |
| shell, users, kyc_queue, orders, payments, settlement, disputes, terms_manager, settings | Mohan |
| analytics, audit_log | Smaran |

The `web/` platform folder is created once by `scripts/bootstrap.sh` (or `.ps1`) at the repo root, then committed.
