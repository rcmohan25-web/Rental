# Machine setup (everyone)

Install:
1. **Flutter SDK, version 3.47.3** (the version CI uses, set in `.github/workflows/flutter-ci.yml`). Check with `flutter --version` and `flutter doctor`.
2. **Android Studio** (SDK and emulator) or a physical Android phone with USB debugging.
3. **VS Code** with the Flutter and Dart extensions (the repo recommends them).
4. **Git**, **Node.js** (LTS), **Chrome**, and the **GitHub CLI** (`gh`) if you are Mohan.
5. **Docker Desktop** (for the local Supabase stack).
6. **Supabase CLI** (`npm i -g supabase` or the official installer).

If your Flutter differs from CI, builds can fail on one side only (this already happened with the Android Gradle plugin). Upgrade or pin to match.

## Clone and run
```bash
git clone https://github.com/<owner>/Rental.git
cd Rental
flutter pub get                    # resolves the whole workspace from the root
cp env/dev.example.json env/dev.json   # then fill in the anon key (ask Srijan)
cd apps/mobile && flutter run --dart-define-from-file=../../env/dev.json
```

Admin web: `cd apps/admin_web && flutter run -d chrome --dart-define-from-file=../../env/dev.json`

## Before every push
```bash
dart format .
flutter analyze
cd packages/rental_core && flutter test      # and the package/app you changed
```
CI rejects unformatted code, so run `dart format .` every time.

Never commit `env/*.json`, keystores or the Supabase service-role key.
