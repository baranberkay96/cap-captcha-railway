# Cap v4 Self-Hosted CAPTCHA (Proof-of-Work): Railway template spec

## Listing

| Field | Value |
|---|---|
| Name | **Cap v4 Self-Hosted CAPTCHA (Proof-of-Work)** (major version only: capd ships patch releases almost daily) |
| Description | Private proof-of-work CAPTCHA with dashboard, site keys, analytics, Valkey. (73 chars) |
| Category | Authentication (where Railway's "Cap" CAPTCHA template sits) |
| Tags | cap, captcha, proof-of-work, recaptcha-alternative, hcaptcha-alternative, turnstile-alternative, bot-protection, anti-spam, privacy, valkey |
| Icon | `https://cdn.jsdelivr.net/gh/tiagozip/cap@40f65d72…/docs/public/logo.png` (Cap's logo at the `capd@4.0.13` commit, 200 image/png) |
| Repo | `baranberkay96/cap-captcha-railway`, service roots `/services/cap`, `/services/valkey` |

The name says "CAPTCHA (Proof-of-Work)" on purpose: our template `37-cap` is Cap the screen recorder, a different product with the same name.

## Base market templates (checked 2026-11-14)

- `cap-1` "Cap" (Authentication, 226 active, 121 recent deploys, health 72): `tiago2/cap:4` (moving tag) + `valkey/valkey:9-alpine`, volume with daily backups. It does not set `PORT`, so Railway probes the healthcheck on a port Cap does not listen on; Valkey has no password; the volume is root-owned while Cap runs as UID 1000, so the IP databases and DuckDB events cannot be written.
- `cap-captcha-or-self-hosted-proof-of-work` (0 deploys): Cap 3.1.14 (pre-v4), `PORT=3000`, Valkey with password, `RAILWAY_RUN_UID=0` (runs Cap as root).
- `cap` (2 active): Cap with Postgres (`DB_URL`), which v4 no longer reads.
- `PwpGcf` "Cap" (Other) is the screen recorder, not this app.

Improvements here:

- Cap 4.0.13 pinned by digest; `PORT=3000` matches the healthcheck; `/health` checks Valkey.
- Cap runs as its own unprivileged user; the start script fixes the volume owner first (no `RAILWAY_RUN_UID=0`).
- Deploy-form values cannot fail the deploy (STANDARD rule 29): an empty or short `ADMIN_KEY` locks the dashboard with a random key and logs the fix; invalid `PORT` or `DUCKDB_MEMORY_LIMIT` fall back to defaults; an empty Valkey password runs Valkey without one (private network only) instead of crashing.
- The start script waits for Valkey (up to 240 s) instead of letting capd crash-loop while Valkey's volume attaches.
- The client-IP header is saved once into Cap's settings (`x-forwarded-for`), so rate limits apply per visitor, without the deprecated `RATELIMIT_IP_HEADER` variable (which logs a warning on every start).
- Valkey is password-protected, persists with AOF + snapshots, and caps its memory at 75% of the service limit (`noeviction`).
- Cap listens on `[::]` (Bun is dual-stack), so other services can call `siteverify` over the private network.

## Pinned versions

| Component | Version | Reference | Released | Checked |
|---|---|---|---|---|
| Cap (capd) | 4.0.13 | `tiago2/cap:4.0.13@sha256:9eb46e4282e78dacb15b535204ececa1506650499e498a50831e0377b7ac98d1` | 2026-11-13 | 2026-11-14 |
| Valkey | 9.1.3 | `valkey/valkey:9.1.3-alpine@sha256:bf09d58e96d6b4524a15396b65b242bbe18beebbcc15a04d8ee75ddac62fae0b` | 2026-10-27 | 2026-11-14 |
| Widget (README snippet) | cap-widget 0.1.63 | jsDelivr | 2026-11-12 | 2026-11-14 |

## Services

### Cap

| Setting | Value |
|---|---|
| Source | repo, root `/services/cap` (`FROM tiago2/cap:4.0.13@sha256:…`, start script, Valkey wait/seed script) |
| Healthcheck | `/health` (200 when Valkey answers PING), timeout 300 s |
| Public domain | yes, port 3000 |
| Volume | `/usr/src/app/data` (DuckDB `events.duckdb`, DB-IP/MaxMind files) |
| Restart | ALWAYS |

| Variable | Default | Notes |
|---|---|---|
| `ADMIN_KEY` | `secret(48)` | Dashboard password. < 12 chars or empty: dashboard locked, deploy still succeeds. |
| `PORT` | 3000 | Copied to capd's `SERVER_PORT`. |
| `VALKEY_URL` | `redis://default:${{Valkey.VALKEY_PASSWORD}}@${{Valkey.RAILWAY_PRIVATE_DOMAIN}}:6379` | |
| `CAP_CLIENT_IP_HEADER` | `x-forwarded-for` | Seeded once with `SET NX`; the dashboard setting wins afterwards. |
| `CAP_URL`, `CAP_PRIVATE_URL` | references | For other services: widget endpoint and private `siteverify`. |

Supported but not in the form: `DUCKDB_MEMORY_LIMIT`, `DUCKDB_THREADS`, `CLICKHOUSE_URL`, `WEBHOOK_ALLOW_PRIVATE`, `REDIS_PREFIX`, `VALKEY_TLS_*`, `CAP_VALKEY_WAIT_SECONDS`.

### Valkey

| Setting | Value |
|---|---|
| Source | repo, root `/services/valkey` (`FROM valkey/valkey:9.1.3-alpine@sha256:…`, start script) |
| Network | private only (no domain, no TCP proxy) |
| Volume | `/data` (AOF `appendonly yes`, `everysec`, `save 60 1`) |
| Variable | `VALKEY_PASSWORD` = `secret(32, A-Za-z0-9)` |

## Resource profile (measured on Railway, 2026-11-14)

| Service | Idle RAM | Peak during tests | CPU |
|---|---|---|---|
| Cap | 0.07 GB | 0.14 GB (startup, key creation, challenge/redeem) | ~0 idle |
| Valkey | 0.015 GB | 0.017 GB | ~0 |

About $1–2/month idle at Railway prices (RAM $10/GB-month, volumes $0.15/GB-month). Works on every plan, including Free (0.5 GB per service). DuckDB can use up to 256 MB while the dashboard queries large event histories.

## Test results (Railway, pre-publish, 2026-11-14)

- Build and deploy: both services SUCCESS; `/health` 200 through the public domain (IPv4 healthcheck against the `[::]` listener).
- End to end with the documented API: `/auth/login` wrong key 401, right key 200; `POST /server/keys` without auth 401, with session 200; `/{site}/challenge` 200 (c=80, s=32, d=4); solved in Python from capjs-core's algorithm; `/redeem` 200 `success: true`; `/siteverify` wrong secret 403, right secret 200 `success: true`, reuse 404; bad solutions 403; the seeded IP header reads back as `x-forwarded-for`.
- `ADMIN_KEY=short`: deploy SUCCESS, log explains the lock, login with `short` 401, `/health` 200.
- Valkey redeploy: site keys still there (persistence).

## Verification checklist

1. Both services SUCCESS; `https://{domain}/health` → `{"status":"ok"}`.
2. Sign in with `ADMIN_KEY`; create a site key; the key's settings page shows the widget snippet.
3. Put the widget on a test page, solve it, call `siteverify` → `success: true`.
4. Redeploy Valkey and Cap: keys, settings and the Events history remain.

## Open questions

- Railway's edge sets `X-Forwarded-For`; Cap reads its last entry. Verified that the setting is applied, not that every Railway region appends the visitor IP last.
- Instrumentation/HashWX challenges (the default for new keys) need a real browser; the API test used a SHA-256 key without instrumentation.
