# scripts/

- `bootstrap.sh` (macOS, Linux, Git Bash) and `bootstrap.ps1` (Windows PowerShell): run **once** by Mohan. They create the Android and web platform folders with `flutter create`, restore the skeleton files Flutter would overwrite, set the app label to "Rental" and the web title to "Rental Admin", run `flutter pub get` and `dart format`.

Safe to re-run: it only restores our files after `flutter create`.
