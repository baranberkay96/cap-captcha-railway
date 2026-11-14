# NOTICE: Cap v4 Self-Hosted CAPTCHA (Proof-of-Work) template

## Software deployed

| Component | Version | Source | Licence | How it is used |
|---|---|---|---|---|
| Cap (capd) | 4.0.13 | Docker Hub `tiago2/cap:4.0.13@sha256:9eb46e42…` built from https://github.com/tiagozip/cap (`capd/Dockerfile`, tag `capd@4.0.13`) | Apache-2.0, Copyright 2025 Tiago | Unmodified image; this template adds a start script and a Valkey wait/seed script on top |
| Valkey | 9.1.3 | Docker Hub `valkey/valkey:9.1.3-alpine@sha256:bf09d58e…` | BSD-3-Clause | Unmodified image with a start script |
| util-linux (`setpriv`) | Debian archive | already in the Cap image (the Dockerfile installs it only if missing) | GPL-2.0+ | Drops from root to Cap's `bun` user |

## Written for this template

`services/cap/Dockerfile`, `services/cap/railway-start.sh`, `services/cap/prepare-valkey.js`, `services/valkey/Dockerfile`, `services/valkey/railway-start.sh`, `template.json`, `TEMPLATE.md`, `README.md` and this file were written for this template. No code or text was copied from Cap's repository or from other Railway templates. The README's widget and `siteverify` examples follow Cap's documented API.

The icon is Cap's own logo (`docs/public/logo.png` at the `capd@4.0.13` commit), referenced by URL on jsDelivr to identify the software.

## Upstream files checked (2026-11-14, tag `capd@4.0.13`)

`LICENSE`, `capd/Dockerfile`, `capd/docker-compose.yml`, `capd/docker-compose.duckdb.yml`, `capd/.env.example`, `capd/package.json`, `capd/src/{index,config,db,auth,health,app,siteverify,cap,settings-cache,ipdb}.js`, `capd/src/events/{open-store,context}.js`, `core/src/{index,prng}.js`, `docs/guide/capd/{index,options}.md`, `docs/guide/{index,widget}.md`. Docker Hub tag lists for `tiago2/cap` and `valkey/valkey`.

## Market templates reviewed

`cap-1`, `cap-captcha-or-self-hosted-proof-of-work` and `cap` (configuration and README read for comparison; nothing copied).

## Names and affiliation

Cap is a project by Tiago (GitHub tiagozip) and contributors. This is a community template, not affiliated with, sponsored or endorsed by the Cap authors or Railway. reCAPTCHA, hCaptcha and Turnstile are trademarks of their owners and are named only to describe compatibility.
