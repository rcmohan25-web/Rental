"""Run SQL tests without resetting or deleting any database.

upgrade: apply pending source migrations and tests in one rolled-back transaction.
fresh: create a uniquely named local test database, bootstrap schema-only local
Supabase service schemas, and apply the full project chain. Never drops the DB.
Only the fixed local Docker container is addressed; no cloud credentials used.
"""
import argparse
import json
from datetime import datetime, timezone
from pathlib import Path
import re
import subprocess
import uuid

ROOT = Path(__file__).resolve().parents[2]
CONTAINER = "supabase_db_Rental"
RESULTS = ROOT / "supabase" / "tests" / "results"
EXPECTED = {"phase0_regression.test.sql": 101, "corrections_regression.test.sql": 85,
            "legacy_after_corrections.test.sql": 10}


def command(args, sql=None):
    result = subprocess.run(args, input=sql, text=True, capture_output=True)
    if result.returncode:
        raise RuntimeError(result.stderr + "\n" + result.stdout)
    return result.stdout


def psql(database, sql):
    return command(["docker", "exec", "-i", CONTAINER, "psql", "-U", "postgres",
                    "-d", database, "-X", "-A", "-t", "-v", "ON_ERROR_STOP=1"], sql)


def check_tap(output, expected):
    assertions = re.findall(r"^(not )?ok (\d+)(?:\s|$)", output, re.M)
    plans = re.findall(r"^1\.\.(\d+)$", output, re.M)
    if (any(failed for failed, _ in assertions) or plans != [str(expected)]
            or [int(number) for _, number in assertions] != list(range(1, expected + 1))
            or re.search(r"^Bail out!", output, re.M)):
        raise RuntimeError("Incomplete or failing TAP output; see saved log")
    return len(assertions)


def run(mode):
    migrations = sorted((ROOT / "supabase" / "migrations").glob("*.sql"))
    suites = ["legacy_after_corrections.test.sql"] if mode == "legacy" else list(EXPECTED)[:2]
    run_id = datetime.now(timezone.utc).strftime("%Y%m%d%H%M%S") + "_" + uuid.uuid4().hex[:6]
    RESULTS.mkdir(exist_ok=True)
    database = "postgres"
    # Database health is checked without stopping, starting or resetting services.
    command(["docker", "exec", CONTAINER, "pg_isready", "-U", "postgres"])
    if mode in ("fresh", "legacy"):
        database = "rental_test_" + run_id
        service_schema = command(["docker", "exec", CONTAINER, "pg_dump", "-U", "postgres",
                                  "-d", "postgres", "--schema-only", "--schema=auth",
                                  "--schema=storage", "--schema=extensions", "--no-owner"])
        # These project objects will instead be installed by the original migration.
        service_schema = re.sub(r"^CREATE TRIGGER on_auth_user_created .*?;\n", "", service_schema, flags=re.M | re.S)
        service_schema = re.sub(r"^CREATE POLICY .*?;\n", "", service_schema, flags=re.M | re.S)
        # Service-role defaults belong to the service owners, not postgres.
        # Existing service-object grants above are retained for RLS tests.
        service_schema = re.sub(r"^ALTER DEFAULT PRIVILEGES .*?;\n", "", service_schema, flags=re.M | re.S)
        command(["docker", "exec", CONTAINER, "createdb", "-U", "postgres", database])
        psql(database, 'CREATE SCHEMA extensions; CREATE EXTENSION pgcrypto WITH SCHEMA extensions; '
                       'CREATE EXTENSION "uuid-ossp" WITH SCHEMA extensions;')
        service_schema = service_schema.replace("CREATE SCHEMA extensions;", "")
        psql(database, service_schema)
        psql(database, "CREATE PUBLICATION supabase_realtime;")
        print(f"isolated database={database}", flush=True)
        # Commit each file separately, matching migration transaction boundaries.
        for migration in migrations:
            if mode == "legacy" and migration.name.startswith("20261124011500"):
                psql(database, (Path(__file__).parent / "legacy_before_corrections.sql").read_text())
            psql(database, "BEGIN;\n" + migration.read_text() + "\nCOMMIT;")
    else:
        applied = set(psql(database, "SELECT version FROM supabase_migrations.schema_migrations;").splitlines())
        pending = [p for p in migrations if p.name.split("_")[0] not in applied]
    for name in suites:
        test = (Path(__file__).parent / name).read_text()
        if name == "corrections_regression.test.sql":
            cases = json.loads((Path(__file__).parent / "approved_money_cases.json").read_text())["cases"]
            checks = []
            for case in cases:
                values = [case[k] for k in ("days", "daily_npr", "declared_npr", "commission_bps", "deposit_bps")]
                if any(type(v) is not int for v in values):
                    raise ValueError("Money fixture inputs must be integers")
                days, daily, declared, commission, deposit = values
                expected = json.dumps(case["expected"]).replace("'", "''")
                label = ("shared money fixture: " + case["id"]).replace("'", "''")
                checks.append(f"SELECT is(rental_private.calculate_money({days},{daily},{declared},{commission}/10000.0,{deposit}/10000.0),'{expected}'::jsonb,'{label}');")
            test = test.replace("SELECT * FROM finish();", "\n".join(checks) + "\nSELECT * FROM finish();")
        if mode == "upgrade":
            # Reapply and roll back pending migrations independently for each suite.
            test = "BEGIN;\n" + "\n".join(p.read_text() for p in pending) + "\n" + test.replace("BEGIN;", "", 1)
        log = RESULTS / f"{run_id}_{mode}_{name}.log"
        try:
            output = psql(database, test)
        except RuntimeError as error:
            log.write_text(str(error), encoding="utf-8")
            raise
        log.write_text(f"database={database}\n" + output, encoding="utf-8")
        count = check_tap(output, EXPECTED[name])
        print(f"mode={mode} database={database} suite={name} assertions={count} failures=0 log={log}")
    if mode in ("fresh", "legacy"):
        print("Isolated test database retained; no database was reset or deleted.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=["upgrade", "fresh", "legacy"])
    run(parser.parse_args().mode)
