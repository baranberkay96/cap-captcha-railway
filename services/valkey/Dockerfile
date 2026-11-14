# Valkey for Cap on Railway: the official image with a start script that
# applies the password, persistence and a memory cap from the service limit.
# Pinned: valkey/valkey 9.1.3-alpine (2026-10-27), multi-arch index digest.
FROM valkey/valkey:9.1.3-alpine@sha256:bf09d58e96d6b4524a15396b65b242bbe18beebbcc15a04d8ee75ddac62fae0b

COPY --chmod=0755 railway-start.sh /usr/local/bin/railway-start

ENTRYPOINT ["/usr/local/bin/railway-start"]
