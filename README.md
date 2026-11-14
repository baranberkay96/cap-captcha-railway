# Deploy and Host Cap with Railway

Cap is an open-source, privacy-friendly CAPTCHA you host yourself. Instead of picking traffic lights, the visitor's browser solves a small proof-of-work puzzle in the background, and your backend checks the token with Cap. This community template runs Cap 4.0.13 (capd) with its dashboard, analytics and a password-protected Valkey.

## About Hosting Cap

Cap's server (capd) answers the widget's challenge requests, verifies tokens for your backend through a reCAPTCHA-style `siteverify` endpoint, and has a dashboard for site keys, live events, rules and settings. It keeps keys, sessions and rate-limit counters in Valkey and analytics events in DuckDB on its own volume. This template generates the dashboard key and the Valkey password at deploy, waits for Valkey before starting Cap, fixes the volume permissions for Cap's unprivileged user, and sets Cap to read the visitor's IP from Railway's edge so rate limits work per visitor. Nothing to fill in.

## Common Use Cases

- Protect sign-up, login and contact forms from bots without Google reCAPTCHA or hCaptcha and their tracking
- One CAPTCHA server for several sites: one site key per site, each with its own difficulty, allowed origins and rules
- Guard expensive or abusable API endpoints that should require a solved challenge
- Watch bot traffic: live events, blocked requests, countries and networks per site key

## Dependencies for Cap Hosting

- Cap 4.0.13 (capd), the official image `tiago2/cap`, pinned by digest (included)
- Valkey 9.1.3 for site keys, settings, sessions and rate limits (included)
- The Cap widget on your pages, loaded from jsDelivr or from this server

### Deployment Dependencies

- Cap documentation: https://trycap.dev
- capd configuration: https://trycap.dev/guide/capd/options.html
- Widget: https://trycap.dev/guide/widget.html
- Source: https://github.com/tiagozip/cap
- Valkey: https://valkey.io

### Implementation Details

| Service | Source | Purpose |
|---|---|---|
| Cap | `tiago2/cap:4.0.13` plus a start script (`services/cap`) | Dashboard, challenge API, `siteverify`; public domain, port 3000, `/health` checks Valkey; volume `/usr/src/app/data` (DuckDB events, IP databases) |
| Valkey | `valkey/valkey:9.1.3-alpine` plus a start script (`services/valkey`) | Keys, settings, sessions, rate limits; private only, password, AOF + snapshots on volume `/data` |

**First login.** Open the Cap service's domain and sign in with `ADMIN_KEY` from the Cap service's Variables tab. Create a site key; the key's **Settings > Add Cap to your site** shows the snippet and the secret.

**Add the widget.** With site key `{site-key}` and your domain `{your-domain}`:

```html
<script src="https://cdn.jsdelivr.net/npm/cap-widget@0.1.63"></script>
<cap-widget data-cap-api-endpoint="https://{your-domain}/{site-key}/"></cap-widget>
```

The widget puts a token into your form (`cap-token`). Check it from your backend, once per token:

```bash
curl -X POST https://{your-domain}/{site-key}/siteverify \
  -H 'Content-Type: application/json' \
  -d '{"secret":"{key-secret}","response":"{token}"}'
```

`{"success":true}` means a solved challenge. From a service in the same Railway project, use `${{Cap.CAP_PRIVATE_URL}}` instead of the public URL: no egress, no edge.

**API.** Everything the dashboard does is available over a REST API (`/swagger`). Create an API key under Instance settings > API keys and send `Authorization: Bot {api-key}`.

**Client IPs.** On first start the template saves `x-forwarded-for` as Cap's proxy header (Instance settings > Visitor location), so each visitor gets their own rate-limit bucket. Railway's edge adds the visitor's address as the last entry, which is the one Cap reads. Change it in the dashboard if you put Cloudflare in front.

**Safe defaults.** `ADMIN_KEY` is generated (48 characters). An empty or too-short key does not stop the deploy: the dashboard is locked with a random key and the log says how to fix it, while widgets and `siteverify` keep working. Changing `ADMIN_KEY` later makes stored secrets impossible to reveal again (verification still works); reset a key's secret to see it again.

**Analytics.** Events go to DuckDB on the Cap volume (at most 256 MB of memory; `DUCKDB_MEMORY_LIMIT`, `DUCKDB_THREADS`). To use your own ClickHouse, set `CLICKHOUSE_URL`.

**Scaling.** One Cap replica per volume. Cap idles at a few dozen MB; give it more CPU for heavy challenge traffic.

**Resources and plans.** Measured on Railway: see `TEMPLATE.md`. Both services fit the Free plan's 0.5 GB per service.

**Upgrading.** The image is pinned by digest in `services/cap/Dockerfile`. Change the tag and digest, read Cap's release notes (v3 → v4 needs a migration), and redeploy.

This is a community template, not affiliated with the Cap authors or Railway. Cap is Apache-2.0.

### Why Deploy Cap on Railway?

Railway runs Cap and Valkey on a private network with TLS on the public domain, volumes for both, and logs in one place. You get a self-hosted CAPTCHA without servers to patch, and your backends in the same project can verify tokens over the private network.
