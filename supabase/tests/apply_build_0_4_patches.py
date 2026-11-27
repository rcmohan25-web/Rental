"""One-off, safe to run twice. Run from the repo root:
    python supabase/tests/apply_build_0_4_patches.py

1. run_local_regression.py: add the phase1 suite (40 assertions) to the fresh run.
2. corrections_regression.test.sql and check_concurrent_overlap.py: set the new required
   setting min_deposit_amount (0, so every expected amount stays the same) right after
   min_declared_value, because create_booking_request now fails closed without it.
3. config.toml: point the seed path at supabase/seed/seed.sql (the plan's layout).
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def patch(path, old, new, marker):
    file = ROOT / path
    text = file.read_text(encoding="utf-8")
    if marker in text:
        print(f"already patched: {path}")
        return
    if old not in text:
        raise SystemExit(f"expected text not found in {path}: {old!r}")
    file.write_text(text.replace(old, new), encoding="utf-8")
    print(f"patched: {path}")


patch(
    "supabase/tests/run_local_regression.py",
    '"legacy_after_corrections.test.sql": 10}',
    '"legacy_after_corrections.test.sql": 10, "phase1_regression.test.sql": 40}',
    "phase1_regression.test.sql",
)
patch(
    "supabase/tests/run_local_regression.py",
    'list(EXPECTED)[:2]',
    '["phase0_regression.test.sql", "corrections_regression.test.sql", "phase1_regression.test.sql"]',
    '"phase0_regression.test.sql", "corrections_regression.test.sql", "phase1',
)
setting = "SELECT public.admin_update_setting('min_declared_value','2000');"
extra = "SELECT public.admin_update_setting('min_deposit_amount','0');"
for target in (
    "supabase/tests/corrections_regression.test.sql",
    "supabase/tests/check_concurrent_overlap.py",
):
    patch(target, setting, setting + "\n" + extra, "'min_deposit_amount'")
patch(
    "supabase/config.toml",
    'sql_paths = ["./seed.sql"]',
    'sql_paths = ["./seed/seed.sql"]',
    './seed/seed.sql',
)
