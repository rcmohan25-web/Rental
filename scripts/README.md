# scripts/

- `bootstrap.sh` (macOS, Linux, Git Bash) and `bootstrap.ps1` (Windows PowerShell): run **once** by Mohan. They create the Android and web platform folders with `flutter create`, restore the skeleton files Flutter would overwrite, set the app label to "Rental" and the web title to "Rental Admin", run `flutter pub get` and `dart format`.
  Safe to re-run: it only restores our files after `flutter create`.
- `setup_github.mjs`: run **once** by Mohan with Node and the GitHub CLI (`gh auth login`). Creates the labels and the Phase 0 and Phase 1 issues and assigns them.
  ```bash
  node scripts/setup_github.mjs --dry-run        # preview
  node scripts/setup_github.mjs --mohan <user> --smaran <user> --srijan <user>
  ```
  Safe to re-run: labels are updated, issues with the same title are skipped.
