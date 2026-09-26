#!/bin/bash
# Renders /etc/odoo/odoo.conf.tpl -> $ODOO_RC and waits for Postgres.
# Then executes the given command (default: odoo).
set -euo pipefail

: "${ODOO_RC:=/tmp/odoo.conf}"
: "${DB_HOST:=db}"
: "${DB_PORT:=5432}"
: "${DB_USER:=odoo}"

TEMPLATE=/etc/odoo/odoo.conf.tpl

if [ -f "$TEMPLATE" ]; then
    python3 - "$TEMPLATE" "$ODOO_RC" <<'PY'
import os, string, sys

src, dst = sys.argv[1], sys.argv[2]
with open(src) as fh:
    rendered = string.Template(fh.read()).safe_substitute(os.environ)
with open(dst, "w") as fh:
    fh.write(rendered)
PY
    chmod 640 "$ODOO_RC"
else
    echo "entrypoint: $TEMPLATE missing, using $ODOO_RC as is" >&2
fi

# Wait for Postgres. The db healthcheck covers the normal case; this catches
# restarts and "docker compose run" without dependencies.
for _ in $(seq 1 60); do
    if pg_isready -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -q; then
        break
    fi
    sleep 1
done

if ! pg_isready -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -q; then
    echo "entrypoint: Postgres at $DB_HOST:$DB_PORT not reachable" >&2
    exit 1
fi

exec "$@"
