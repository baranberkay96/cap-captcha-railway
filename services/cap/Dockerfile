# Cap (capd) for Railway: the published image, plus a start script that
# fixes volume permissions, validates deploy-form values and waits for Valkey.
# Pinned: tiago2/cap 4.0.13 (capd@4.0.13, released 2026-11-13), multi-arch index digest.
FROM tiago2/cap:4.0.13@sha256:9eb46e4282e78dacb15b535204ececa1506650499e498a50831e0377b7ac98d1

USER root

# setpriv drops from root to the image's bun user (UID 1000) after the start
# script has fixed the volume owner. It ships with util-linux in Debian.
RUN command -v setpriv >/dev/null 2>&1 \
  || (apt-get update && apt-get install -y --no-install-recommends util-linux && rm -rf /var/lib/apt/lists/*); \
  setpriv --version && id bun

COPY --chmod=0755 railway-start.sh /usr/local/bin/railway-start
COPY --chmod=0755 prepare-valkey.js /usr/local/bin/cap-prepare-valkey.js

ENTRYPOINT ["/usr/local/bin/railway-start"]
