#!/bin/sh
# Start Valkey for Cap. No deploy-form value can stop the deploy.
set -u

log() { printf '[railway-start] %s\n' "$*" >&2; }

dir="${RAILWAY_VOLUME_MOUNT_PATH:-/data}"
mkdir -p "$dir"
cd "$dir" || exit 1

set -- valkey-server --port 6379 --dir "$dir" \
  --appendonly yes --appendfsync everysec --save 60 1 \
  --maxmemory-policy noeviction --loglevel warning

if [ -n "${VALKEY_PASSWORD:-}" ]; then
  set -- "$@" --requirepass "$VALKEY_PASSWORD"
else
  log "VALKEY_PASSWORD is empty: Valkey runs without a password. It has no public port, so only"
  log "services in this project's private network can reach it. Set VALKEY_PASSWORD and redeploy"
  log "both services to require one."
  set -- "$@" --protected-mode no
fi

# Keep Valkey below the service memory limit: with noeviction, writes fail at
# the cap instead of the container being killed.
limit="$(cat /sys/fs/cgroup/memory.max 2>/dev/null || echo max)"
case "$limit" in
  '' | max | *[!0-9]*) ;;
  *) set -- "$@" --maxmemory "$((limit / 4 * 3))" ;;
esac

exec docker-entrypoint.sh "$@"
