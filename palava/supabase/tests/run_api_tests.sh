#!/usr/bin/env bash
# Runs the app's Supabase code (test/supabase_backend_test.dart) against a
# fresh local copy of the database served by PostgREST, the same server
# Supabase uses. Needs: psql + a local PostgreSQL, python3, flutter, and the
# PostgREST binary (https://github.com/PostgREST/postgrest/releases).
#
#   PSQL_ARGS="-h /tmp/pg -p 5433 -U postgres" \
#   PG_URI="postgres://authenticator@localhost:5433/palava_api?host=/tmp/pg" \
#   POSTGREST=/opt/postgrest/postgrest supabase/tests/run_api_tests.sh
set -euo pipefail
cd "$(dirname "$0")/.."

PSQL_ARGS=${PSQL_ARGS:-"-U postgres"}
PG_URI=${PG_URI:-"postgres://authenticator@localhost/palava_api"}
POSTGREST=${POSTGREST:-postgrest}
SECRET="palava-local-test-secret-at-least-32-chars"
USER_ID="00000000-0000-0000-0000-0000000000c1"
ADMIN_ID="00000000-0000-0000-0000-0000000000c2"
WORK=$(mktemp -d)
trap 'kill $(jobs -p) 2>/dev/null || true; rm -rf "$WORK"' EXIT

psql $PSQL_ARGS -q -c "drop database if exists palava_api;" \
  -c "create database palava_api;"
run() { psql $PSQL_ARGS -q -v ON_ERROR_STOP=1 -d palava_api "$@" >/dev/null; }
run -f tests/supabase_shim.sql
for migration in migrations/*.sql; do run -f "$migration"; done
run -f seed.sql
run -c "insert into auth.users (id, phone) values ('$USER_ID', '231770000009');"
run -c "insert into auth.users (id, email) values ('$ADMIN_ID', 'admin@example.com');"
run -c "insert into public.admins (user_id) values ('$ADMIN_ID');"

sign() {
  python3 - "$SECRET" "$1" <<'PY'
import base64, hashlib, hmac, json, sys, time
secret, claims = sys.argv[1], json.loads(sys.argv[2])
claims["exp"] = int(time.time()) + 3600
enc = lambda d: base64.urlsafe_b64encode(json.dumps(d).encode()).rstrip(b"=")
body = enc({"alg": "HS256", "typ": "JWT"}) + b"." + enc(claims)
sig = base64.urlsafe_b64encode(
    hmac.new(secret.encode(), body, hashlib.sha256).digest()).rstrip(b"=")
print((body + b"." + sig).decode())
PY
}
ANON_KEY=$(sign '{"role": "anon"}')
USER_JWT=$(sign "{\"role\": \"authenticated\", \"aud\": \"authenticated\", \"sub\": \"$USER_ID\"}")
ADMIN_JWT=$(sign "{\"role\": \"authenticated\", \"aud\": \"authenticated\", \"sub\": \"$ADMIN_ID\"}")

cat > "$WORK/postgrest.conf" <<EOF
db-uri = "$PG_URI"
db-schemas = "public"
db-anon-role = "anon"
jwt-secret = "$SECRET"
jwt-aud = "authenticated"
server-port = 3101
EOF
"$POSTGREST" "$WORK/postgrest.conf" >"$WORK/postgrest.log" 2>&1 &
python3 tests/api_proxy.py 3100 3101 &
for _ in $(seq 50); do
  curl -sf http://127.0.0.1:3100/rest/v1/app_settings >/dev/null && break
  sleep 0.2
done

export PALAVA_TEST_API_URL=http://127.0.0.1:3100
export PALAVA_TEST_ANON_KEY=$ANON_KEY
export PALAVA_TEST_USER_JWT=$USER_JWT PALAVA_TEST_USER_ID=$USER_ID
export PALAVA_TEST_ADMIN_JWT=$ADMIN_JWT PALAVA_TEST_ADMIN_ID=$ADMIN_ID
cd ..
flutter test test/supabase_backend_test.dart
# The viewer's unlocks above changed the data; the admin checks expect the
# original sample settings, which the viewer cannot change.
(cd admin && flutter test test/admin_api_test.dart)
