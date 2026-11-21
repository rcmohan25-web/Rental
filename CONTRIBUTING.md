# Contributing

1. **One owner per folder.** `.github/CODEOWNERS` maps paths to owners. Do not edit another person's folder; open an issue or comment on their PR.
2. **Branches:** `feature/<area>-<name>`. `main` is protected and always runnable.
3. **PRs:** squash merge, one required review (a code owner), CI green, under about 400 lines. Rebase on `main` daily. Review others' PRs within 24 hours.
4. **Contract first:** `docs/api-contract.md` and the models in `rental_data/lib/models` are frozen after Phase 0. Changes need all three approvals.
5. **Fakes first:** build UI against the `fake/` repositories until the RPCs land.
6. **Migrations only by Srijan**, one file per change `YYYYMMDDHHMMSS_area_description.sql`, never edited after merge. Ask via an issue labelled `backend-request`.
7. **Thin central files:** routers only aggregate each feature's `routes.dart`. Add a dependency in your own package or app pubspec, one line, in the same PR that uses it.
8. **No generated code in git:** hand-written models, no freezed or build_runner outputs.
9. **Secrets:** only the anon key in apps (`--dart-define-from-file`). Never commit `env/*.json`, keystores or the service-role key.
10. **Honesty rules** (`docs/honesty-rules.md`) apply to every screen and to the report.
11. **Definition of done:** works on a physical device, loading/empty/error states handled, no analyzer warnings, tests pass, reviewed, merged, listed in the demo script or test log.

Two fixed weekly integration sessions: merge all open PRs, then run `main` on a real phone and in Chrome. Daily 10-minute check-in.
