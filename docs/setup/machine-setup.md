# Machine setup (everyone)

Install:
1. **Flutter SDK (stable channel)**. Check with `flutter doctor`.
2. **Android Studio** (SDK and emulator) or a physical Android phone with USB debugging.
3. **VS Code** with the Flutter and Dart extensions (the repo recommends them).
4. **Git**, **Node.js** (LTS), **Chrome**.
5. **Docker Desktop** (for the local Supabase stack).
6. **Supabase CLI** (`npm i -g supabase` or the official installer).

Dart workspaces need Dart 3.6 or newer, which every recent Flutter stable includes.

## Clone and run
```bash
git clone https://github.com/<org-or-user>/rental.git
cd rental
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

Never commit `env/*.json`, keystores or the Supabase service-role key.
