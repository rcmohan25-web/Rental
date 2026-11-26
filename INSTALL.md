# Build 0.2 install (not part of the repo)

1. Unzip this folder next to your repo.
2. Copy the CONTENTS of `rental-build-0.2/` into your repo root and overwrite when asked. It does not contain CODEOWNERS or any pubspec, so nothing of yours is lost.
3. Edit `apps/mobile/pubspec.yaml`: under `flutter:` > `assets:` add the line `- assets/payment_qr/`.
4. From the repo root:
   ```bash
   flutter pub get
   dart format .
   flutter analyze
   (cd packages/rental_core && flutter test)
   ```
5. Commit and push on a branch, open a PR, and merge when CI is green:
   ```bash
   git checkout -b chore/build-0.2
   git add -A
   git commit -m "chore: phase 0 completion (build 0.2)"
   git push -u origin chore/build-0.2
   ```
6. Then follow `docs/setup/github-setup-mohan.md` (ruleset import, labels and issues script).
Full file list: `docs/builds/build-0.2.md`.
