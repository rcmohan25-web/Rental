# Supabase setup (Srijan)

1. Create two projects at supabase.com: `rental-dev` and `rental-demo` (free tier). Save the anon keys in `env/dev.json` and `env/demo.json` (git-ignored) and send them to the team privately.
2. Install Docker Desktop and the Supabase CLI.
3. Inside the repo: `cd supabase && supabase init` (creates `config.toml`), then `supabase start`.
4. First migration `migrations/YYYYMMDDHHMMSS_core_tables.sql`: `profiles`, `items`, `bookings` (with the `btree_gist` exclusion constraint against double booking), `app_settings`, `terms_documents`, plus a trigger that creates a profile row on sign-up.
5. Add storage buckets (public item photos; private kyc, handover, payment-proof; images only, under 5 MB) and the first RLS policies.
6. Agree RPC names with Smaran in `docs/api-contract.md` (names are listed in plan Section 10).
7. Link the dev project: `supabase link --project-ref <ref>` and `supabase db push`.

Rules: one migration file per change, never edited after merge; service-role key only in Edge Function secrets.
