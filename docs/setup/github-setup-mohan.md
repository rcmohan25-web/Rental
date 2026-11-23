# GitHub setup (Mohan, repository admin)

## 1. Push the skeleton
```bash
cd rental                      # your local clone of the empty repo
# copy the contents of the zip into this folder, then:
bash scripts/bootstrap.sh      # Windows: powershell -ExecutionPolicy Bypass -File scripts/bootstrap.ps1
git add .
git commit -m "chore: phase 0 skeleton"
git push origin main
```
(If branch protection is already on, push to `feature/phase0-skeleton` and merge by PR with your admin bypass.)

## 2. Invite collaborators
Settings > Collaborators > add Smaran and Srijan (Write access).

## 3. CODEOWNERS usernames
Replace `@MOHAN_USERNAME`, `@SMARAN_USERNAME`, `@SRIJAN_USERNAME` in `.github/CODEOWNERS` with the real usernames.
Why two owners per folder: GitHub ignores the author's own approval, so each folder lists its owner plus one peer (Mohan > Smaran > Srijan > Mohan).

## 4. Protect `main` (Settings > Rules > Rulesets > New branch ruleset)
- Target: default branch. Enforcement: Active.
- Require a pull request before merging: **1 approval**, **Require review from Code Owners**, dismiss stale approvals.
- Require status checks: `Analyze and test` (from Flutter CI). Add `Migrations, lint and pgTAP` once Srijan's migration is merged.
- Require branches to be up to date. Block force pushes. Require linear history (squash merge).
- Bypass list: yourself only, for emergencies.
Settings > General > Pull Requests: allow **squash merging** only, delete branch on merge.

## 5. Labels and board
Create labels: `task`, `bug`, `backend-request`, `phase-0` to `phase-5`. Create a GitHub Project board (Todo, In progress, Review, Done).

## 6. Secrets (Settings > Secrets and variables > Actions)
| Secret | Used by |
| --- | --- |
| `SUPABASE_DEV_URL`, `SUPABASE_DEV_ANON_KEY` | keepalive, builds |
| `SUPABASE_DEMO_URL`, `SUPABASE_DEMO_ANON_KEY` | keepalive |
| `SUPABASE_URL`, `SUPABASE_ANON_KEY` | deploy-admin (the project the admin panel should talk to) |
| `SUPABASE_DB_URL` | backup-db (Session pooler string) |
| `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID` | deploy-admin |

The service-role key is **never** stored in GitHub secrets for the apps. Keep it in your password manager and in Edge Function secrets only.

## 7. After the first green CI
- Open `.github/workflows/flutter-ci.yml` and confirm the format check passes (bootstrap runs `dart format`).
- Run **Backup database** manually once and test a restore into a scratch project.
- Create a Cloudflare Pages project named `rental-admin`, then run **Deploy admin web** (later map `admin.sapati.com`).

## 8. Announce
Tell Smaran and Srijan: "main is ready, pull and work only in your folders."
