#!/usr/bin/env bash
# Applies the schema and sample content to a throwaway PostgreSQL database and
# runs the security checks. Needs psql and a local server; set PSQL_ARGS to
# point at it (default: local socket, user postgres).
set -euo pipefail
cd "$(dirname "$0")/.."

PSQL_ARGS=${PSQL_ARGS:-"-U postgres"}
DB=palava_test

psql $PSQL_ARGS -q -c "drop database if exists $DB;" -c "create database $DB;"
run() { psql $PSQL_ARGS -q -v ON_ERROR_STOP=1 -d $DB "$@"; }

run -f tests/supabase_shim.sql
for migration in migrations/*.sql; do
  run -f "$migration"
done
run -f seed.sql
# The seed must be safe to run twice.
run -f seed.sql
run -f tests/security_test.sql
