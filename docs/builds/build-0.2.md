# Build 0.2 manifest

Copy the folder contents of the zip over the repo root, then follow `INSTALL.md` (in the zip) or the steps in the hand-off message.

## New files
- `.github/dependabot.yml`, `.github/rulesets/main-protection.json`
- `scripts/setup_github.mjs`
- `docs/business-rules.md`, `docs/builds/build-0.2.md`
- `apps/mobile/assets/payment_qr/README.md`
- `apps/mobile/android/app/src/main/res/values/colors.xml`
- `packages/rental_core/lib/constants/setting_keys.dart`, `payment_channels.dart`
- `packages/rental_core/test/constants_and_widgets_test.dart`

## Replaced files (Mohan's, safe to overwrite)
- `.github/workflows/flutter-ci.yml`
- `README.md`, `apps/mobile/README.md`, `packages/rental_core/README.md`, `scripts/README.md`
- `docs/00-START-HERE.md`, `docs/BUILD_LOG.md`, `docs/honesty-rules.md`
- `docs/setup/machine-setup.md`, `docs/setup/github-setup-mohan.md`, `docs/setup/supabase-setup-srijan.md`
- `apps/admin_web/web/index.html`, `apps/admin_web/web/manifest.json`
- `apps/mobile/android/app/src/main/res/drawable/launch_background.xml` and `drawable-v21/launch_background.xml`
- `packages/rental_core/lib/rental_core.dart`, `packages/rental_core/lib/constants/honesty_texts.dart`

## One manual edit
`apps/mobile/pubspec.yaml`: add `- assets/payment_qr/` under `flutter: assets:`.

## Not in the zip on purpose
`.github/CODEOWNERS` (your real usernames), all `pubspec.yaml` files, `pubspec.lock`, and files owned by Smaran or Srijan.
