# GitHub setup (Mohan, repository admin)

## 1. Check the basics
- Collaborators: Settings > Collaborators > add Smaran and Srijan (Write). Wait until they accept.
- `.github/CODEOWNERS` has the real usernames (no `_USERNAME` placeholders) and GitHub shows no error banner on the file.

## 2. Can your plan protect branches?
Branch rules on a **private** repository need GitHub Pro or a paid team. If Settings > Rules shows an upgrade message:
- apply for the free **GitHub Student Developer Pack** (Pro for students), or
- make the repository public (only if it contains no secrets or real QR codes), or
- keep the rules as a team agreement until you can enable them (CONTRIBUTING.md still applies).

## 3. Protect `main`
**Import (fast):** Settings > Rules > Rulesets > New ruleset > **Import a ruleset** > choose `.github/rulesets/main-protection.json` > review > Create.
If the import complains about the bypass actor, delete the `bypass_actors` block in the form and add yourself under "Bypass list" by hand.

**By hand (same result):** New branch ruleset, target the default branch, enforcement Active, then:
- Require a pull request: 1 approval, require review from Code Owners, dismiss stale approvals, allow squash merge only.
- Require status checks: `Analyze and test` (it only appears after CI ran once). Require branches to be up to date.
- Block force pushes and deletions. Require linear history.

Later, once Srijan's migration is merged, add `Migrations, lint and pgTAP` as a required check.

## 4. Labels and issues (one command)
```bash
gh auth login                       # once
node scripts/setup_github.mjs --dry-run
node scripts/setup_github.mjs --mohan <your-user> --smaran <user> --srijan <user>
```
This creates the labels (`task`, `bug`, `backend-request`, `phase-0` to `phase-5`) and the Phase 0 and Phase 1 issues, assigned to each person.
Then create a Project board (Todo, In progress, Review, Done) and add the issues.

## 5. Secrets (Settings > Secrets and variables > Actions)
| Secret | Used by |
| --- | --- |
| `SUPABASE_DEV_URL`, `SUPABASE_DEV_ANON_KEY` | keepalive |
| `SUPABASE_DEMO_URL`, `SUPABASE_DEMO_ANON_KEY` | keepalive |
| `SUPABASE_URL`, `SUPABASE_ANON_KEY` | deploy-admin |
| `SUPABASE_DB_URL` | backup-db (Session pooler string) |
| `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID` | deploy-admin |

The service-role key is **never** stored in GitHub secrets for the apps. Keep it in your password manager and in Edge Function secrets only.

## 6. Keep CI and your machine on one Flutter version
The version is set once in `.github/workflows/flutter-ci.yml` (`FLUTTER_VERSION`). When the team upgrades Flutter, change that line in the same PR.

## 7. After the first green CI
- Run **Backup database** manually once and test a restore into a scratch project.
- Create a Cloudflare Pages project named `rental-admin`, then run **Deploy admin web** (later map `admin.sapati.com`).

## 8. Announce
Tell Smaran and Srijan: "main is ready, pull it, read `docs/00-START-HERE.md` and `docs/business-rules.md`, work only in your folders."
