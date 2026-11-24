# Supabase setup (Srijan): Phase 0

Commands are for **Windows PowerShell**, run from the repo root (`rental/`) on your branch `srijan/backend`.
Never paste a password, the service-role key or a database password into a file in this repo.

## 0. What the Phase 0 zip contains

```
supabase/migrations/   4 migration files (schema, RLS, storage, blocked-dates RPC)
supabase/seed/         seed.sql (local only), demo_seed.sql (cloud)
supabase/tests/        3 pgTAP files (131 tests)
docs/                  api-contract, data-model, security, BUILD_LOG, evidence, this guide
shared/fixtures/       status_transitions.json
```

Unzip it **over** the repo root so the paths line up. It replaces `docs/api-contract.md`, `docs/data-model.md`, `docs/security.md`,
`docs/BUILD_LOG.md`, `supabase/README.md` and `shared/fixtures/status_transitions.json`, and adds the rest.
Check `git status` and `git diff` before committing.

## 1. Create `supabase/config.toml` (once)

The zip does not include `config.toml`, because `supabase init` writes the version that matches your CLI.

```powershell
supabase init
```

If it asks about VS Code or IntelliJ settings, answer **N** (the repo already has `.vscode/`).
Then open `supabase/config.toml`, find the `[db.seed]` section and point it at our seed folder:

```toml
[db.seed]
enabled = true
sql_paths = ["./seed/seed.sql"]
```

`demo_seed.sql` is **not** listed, so it never runs on a local reset.
Commit `config.toml` (it holds no secrets). `supabase/.env`, `.temp/` and `.branches/` are already git-ignored.

## 2. Run everything locally first

Docker Desktop must be running.

```powershell
supabase start
supabase db reset        # applies the 4 migrations, then seed.sql
supabase test db         # runs supabase/tests/*.sql, expect 131 passing
supabase db lint --level warning
```

Expected: no errors from `db reset`, `test db` ends with `Result: PASS`. If `db lint` prints warnings, read them; they are not automatically wrong, but do not ignore them.
Save the `supabase test db` output into `docs/evidence/` (it replaces the pgTAP file in the zip, which was produced on a plain PostgreSQL, not the Supabase stack).

Quick look inside: Studio is at the URL `supabase start` prints (usually http://127.0.0.1:54323). Check **Table Editor** (5 tables, 10 items), **Storage** (4 buckets) and **Authentication** (5 fake users).
Local test logins are in the header of `seed.sql`.

## 3. Push the migrations to the cloud projects

You created `rental-dev` and `rental-demo`. Do `rental-dev` first.

```powershell
supabase login
supabase link --project-ref <rental-dev project ref>
supabase db push
```

The project ref is the part of the project URL before `.supabase.co`. `db push` asks for the database password you chose when creating the project; type it at the prompt and do not save it in a file.
`db push` applies **migrations only**; it does not run any seed.

Then repeat for `rental-demo` (`supabase link --project-ref <rental-demo project ref>`, then `supabase db push`).
`supabase link` points at one project at a time: always re-check which one you linked before pushing.

## 4. Create the demo accounts and load demo data (cloud)

Do **not** run `seed.sql` on a cloud project (it contains a known password and the repository is public).

1. Dashboard > **Authentication > Users > Add user > Create new user**. Tick **Auto Confirm User**. Create four accounts with strong passwords you keep in a password manager: one admin, two Renters, one Borrower.
2. Dashboard > **SQL Editor**. Paste `supabase/seed/demo_seed.sql`, change the four emails at the top, and run it.
   It makes one user admin, marks the four as ID-verified, sets fake display names, and adds 10 items and 2 open requests.
   It is safe to run twice. If you forgot to create the users it stops with a clear message.
3. Repeat on the other project if you want the same data in both.

## 5. Checks on the cloud project (Phase 0 "done")

- **Table Editor:** `profiles`, `items`, `bookings`, `app_settings` (4 rows), `terms_documents` (3 rows) exist.
- **Authentication > Policies / Table Editor:** RLS shows as enabled on all five tables.
- **Storage:** `item-photos` (public), `kyc-documents`, `handover-evidence`, `payment-proofs` (private).
- **Advisors > Security Advisor:** run it and read every item. Write down anything it reports in `docs/security.md`.
- **Sign-up trigger:** create one more user (or sign up from the app) and confirm a row appears in `profiles` automatically.
- **Double booking:** in the SQL Editor, run the two inserts from `supabase/tests/01_schema.test.sql` (the "overlapping accepted booking is rejected" case) and confirm Postgres answers `23P01`. (The pgTAP file does this for you locally.)

## 5b. Realtime

The migration adds `bookings` to the `supabase_realtime` publication. If Dashboard > Database > Replication does not show it on a cloud project, tick it there once.

## 6. Keys for the apps

Dashboard > Project Settings > API: copy the **Project URL** and the **anon / publishable** key into `env/dev.json` (and `env/demo.json`), copied from the `*.example.json` files.
`env/*.json` is git-ignored. **Never** copy the `service_role` / secret key anywhere in the repo or the Flutter app.
Give Mohan and Smaran the URL and anon key through your private team chat, not through GitHub.

## 7. Commit and open the PR

```powershell
git status
git diff --stat
git add supabase docs shared
git commit -m "feat(db): phase 0 schema, RLS, storage, seed, tests and contract draft"
git push -u origin srijan/backend
```

Open a pull request into `main` (never push to `main`). Ask Smaran to review `docs/api-contract.md`, specifically the "PROPOSED" rows and the open questions in section 7.
Merged migrations are never edited afterwards; fixes become a new migration file.

## 8. Troubleshooting

| Symptom | Likely cause and fix |
| --- | --- |
| `supabase db reset` says it cannot find the seed | `sql_paths` in `config.toml` is not `["./seed/seed.sql"]`. |
| `extension "btree_gist" ... does not exist` | Old local image. `supabase stop`, update the CLI, `supabase start` again. |
| `supabase test db` cannot find `plan()` | pgTAP is not enabled. Run `create extension if not exists pgtap with schema extensions;` in Studio's SQL editor on the local DB, then retry. |
| `db push` fails with a permission error on `storage.objects` | Tell Mohan the exact message; do not work around it by editing the migration after it is merged. |
| Sign-up works but `profiles` is empty | The `on_auth_user_created` trigger is missing; check `supabase db reset` finished without errors. |
