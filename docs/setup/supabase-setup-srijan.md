# Supabase setup (Srijan)

1. Create two projects at supabase.com: `rental-dev` and `rental-demo` (free tier). Save the anon keys in `env/dev.json` and `env/demo.json` (git-ignored) and send them to the team privately.
2. Install Docker Desktop and the Supabase CLI.
3. Inside the repo: `cd supabase && supabase init` (creates `config.toml`), then `supabase start`.
4. First migration `migrations/YYYYMMDDHHMMSS_core_tables.sql`: `profiles` (with the sign-up trigger), `items`, `bookings` (with the `btree_gist` exclusion constraint against double booking), `app_settings`, `terms_documents`.
5. Seed `app_settings` with the keys in `docs/business-rules.md`: `commission_rate`, `deposit_rate`, **`min_deposit_amount`**, `late_fee_multiplier`, `return_grace_hours`, `legal_action_period_days`, `request_expiry_hours`, `min_declared_value`, `auto_approve_orders`. The values are placeholders the admin changes later.
6. `bookings` snapshot columns: `commission_rate`, `deposit_rate`, **`min_deposit_amount`**, `terms_version_ids`.
7. Deposit in SQL must match Dart: `greatest(round(declared_value * deposit_rate), min_deposit_amount)`.
8. Add storage buckets (public item photos; private kyc, handover, payment-proof; images only, under 5 MB) and the first RLS policies. Payment QR codes are app assets, no bucket.
9. Agree RPC names with Smaran in `docs/api-contract.md` (names are listed in plan Section 10).
10. Link the dev project: `supabase link --project-ref <ref>` and `supabase db push`.

Rules: one migration file per change, never edited after merge; service-role key only in Edge Function secrets.
