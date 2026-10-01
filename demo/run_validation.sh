#!/usr/bin/env bash
# Deterministic end-to-end validation of the transform/ dbt project.
#
# Default: DuckDB — zero credentials, identical green output every run.
# Optional: ./demo/run_validation.sh -t snowflake  (requires env vars from
#           transform/.env.example; never hardcode credentials).
#
# Idempotent: the local DuckDB file is rebuilt from scratch on every run.

set -euo pipefail

TARGET="duckdb"
while getopts "t:" opt; do
    case "$opt" in
        t) TARGET="$OPTARG" ;;
        *) echo "usage: $0 [-t duckdb|snowflake]" >&2; exit 2 ;;
    esac
done

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT/transform"

echo "==> Validating transform/ on target: $TARGET"

if [ "$TARGET" = "duckdb" ]; then
    rm -f albion.duckdb albion.duckdb.wal   # clean slate => deterministic take
fi

echo "==> dbt deps"
dbt deps --profiles-dir .

echo "==> dbt seed (raw sources + immutable GOLDEN baselines)"
dbt seed --profiles-dir . -t "$TARGET" --full-refresh

echo "==> dbt build (models + golden-parity + generic + macro tests)"
dbt build --profiles-dir . -t "$TARGET"

echo "==> sqlfluff lint models/ (dialect=snowflake)"
sqlfluff lint models/

echo ""
echo "ALL VALIDATION GREEN on target '$TARGET'."
