#!/bin/sh
# Start capd on Railway. No deploy-form value can stop the deploy: invalid
# values fall back to safe defaults with a warning in the deploy log.
set -u

log() { printf '[railway-start] %s\n' "$*" >&2; }

APP_USER=bun
DATA_DIR="${DATA_DIR:-/usr/src/app/data}"
export DATA_DIR

# Port: Railway's healthcheck probes PORT; capd reads SERVER_PORT.
port="${PORT:-3000}"
case "$port" in
  '' | *[!0-9]*) log "PORT='$port' is not a port number, using 3000."; port=3000 ;;
esac
if [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
  log "PORT=$port is out of range, using 3000."
  port=3000
fi
export SERVER_PORT="$port"
# Bun listens dual-stack on "::": Railway's edge and healthcheck use IPv4,
# legacy private networks IPv6.
export SERVER_HOSTNAME="${SERVER_HOSTNAME:-::}"

# Admin key: capd refuses to start without one of at least 12 characters.
# Fail closed instead: lock the dashboard with a random key nobody knows.
if ! bun -e 'process.exit((process.env.ADMIN_KEY ?? "").trim().length >= 12 ? 0 : 1)' 2>/dev/null; then
  ADMIN_KEY="$(od -An -N32 -tx1 /dev/urandom | tr -d ' \n')"
  export ADMIN_KEY
  log "ADMIN_KEY is missing or shorter than 12 characters. The dashboard is LOCKED with a random key"
  log "nobody knows. Widgets and siteverify keep working. To sign in, set ADMIN_KEY on the Cap service"
  log "(32+ characters, e.g. openssl rand -hex 24) and redeploy."
fi

# DuckDB memory limit: an unparsable value would break analytics at startup.
if [ -n "${DUCKDB_MEMORY_LIMIT:-}" ] \
  && ! printf '%s' "$DUCKDB_MEMORY_LIMIT" | grep -Eiq '^[0-9]+(\.[0-9]+)? ?(b|kb|mb|gb|tb|kib|mib|gib|tib)$'; then
  log "DUCKDB_MEMORY_LIMIT='$DUCKDB_MEMORY_LIMIT' is not a size like 256MB, using 256MB."
  export DUCKDB_MEMORY_LIMIT=256MB
fi

# Railway mounts volumes owned by root; capd runs as bun (UID 1000) and keeps
# the IP databases and the DuckDB event store in DATA_DIR.
if [ "$(id -u)" = 0 ]; then
  mkdir -p "$DATA_DIR"
  find "$DATA_DIR" -xdev ! -user "$APP_USER" -exec chown "$APP_USER:$APP_USER" {} + 2>/dev/null \
    || log "Could not change the owner of $DATA_DIR; analytics and IP data may not be saved."
  run_as() { HOME=/home/bun setpriv --reuid="$APP_USER" --regid="$APP_USER" --init-groups -- "$@"; }
else
  run_as() { "$@"; }
fi

# Wait for Valkey (services start in parallel) and seed the client-IP header
# setting once. capd exits when Valkey is unreachable at startup, so waiting
# here avoids a restart loop while Valkey's volume is attached.
run_as bun /usr/local/bin/cap-prepare-valkey.js \
  || log "Continuing without a confirmed Valkey connection; capd retries on its own restarts."

log "Starting capd on [${SERVER_HOSTNAME}]:${SERVER_PORT}"
if [ "$(id -u)" = 0 ]; then
  exec env HOME=/home/bun setpriv --reuid="$APP_USER" --regid="$APP_USER" --init-groups -- bun run ./src/index.js
fi
exec bun run ./src/index.js
