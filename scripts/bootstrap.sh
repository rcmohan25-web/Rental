#!/usr/bin/env bash
# One-time setup. Run from the repo root: bash scripts/bootstrap.sh
set -euo pipefail

command -v flutter >/dev/null || { echo "Flutter not found. See docs/setup/machine-setup.md"; exit 1; }

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

create_platform () {
  local dir="$1" platform="$2" project="$3"
  echo "==> flutter create ($platform) in $dir"
  local tmp; tmp="$(mktemp -d)"
  for f in pubspec.yaml analysis_options.yaml README.md lib/main.dart test/widget_test.dart; do
    if [ -f "$dir/$f" ]; then mkdir -p "$tmp/$(dirname "$f")"; cp "$dir/$f" "$tmp/$f"; fi
  done
  (cd "$dir" && flutter create --platforms="$platform" --org com.sapati --project-name "$project" .)
  for f in pubspec.yaml analysis_options.yaml README.md lib/main.dart test/widget_test.dart; do
    if [ -f "$tmp/$f" ]; then cp "$tmp/$f" "$dir/$f"; fi
  done
  rm -rf "$tmp"
}

create_platform apps/mobile android rental
create_platform apps/admin_web web rental_admin

# Launcher label "Rental"
MANIFEST="apps/mobile/android/app/src/main/AndroidManifest.xml"
if [ -f "$MANIFEST" ]; then
  sed -i.bak 's/android:label="[^"]*"/android:label="Rental"/' "$MANIFEST" && rm -f "$MANIFEST.bak"
fi
# Web title
INDEX="apps/admin_web/web/index.html"
if [ -f "$INDEX" ]; then
  sed -i.bak 's#<title>[^<]*</title>#<title>Rental Admin</title>#' "$INDEX" && rm -f "$INDEX.bak"
fi

echo "==> flutter pub get"
flutter pub get
echo "==> dart format"
dart format apps packages
echo
echo "Done. Check: android applicationId should be com.sapati.rental"
grep -rn "applicationId" apps/mobile/android/app/build.gradle* || true
echo "Next: git add . && git commit -m 'chore: platform folders' && git push"
