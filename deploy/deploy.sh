#!/usr/bin/env bash
# Builds the API and the web app on the droplet, then switches both to the new
# build. Called by ssh-deploy.sh after the checkout is on origin/main.
# server/.env is untracked, so git reset keeps it.
#
# Nothing live changes until both builds succeed:
#   1. API -> server/dist.next, web app -> a new folder in /var/www/hacky-web/releases/
#   2. only then: server/dist.next replaces server/dist and PM2 reloads the API
#   3. only after the API health check passes: the site's "current" symlink
#      flips to the new web release (one atomic rename, so Nginx never serves a
#      half-copied build). A failed deploy leaves the previous web app live.
set -euo pipefail

APP_DIR=/var/www/hacky
WEB_ROOT=/var/www/hacky-web   # Nginx serves $WEB_ROOT/current (deploy/nginx/hacky.conf)
KEEP_RELEASES=3               # older web releases are deleted
HEALTH_URL=http://localhost:8787/api/health

# 1 vCPU / 1 GB RAM: builds run one at a time, and each Node build gets a
# fixed heap cap so it collects garbage instead of growing into the memory the
# running API needs (the droplet's swap absorbs short peaks). Only the build
# commands get NODE_OPTIONS; pm2 --update-env would otherwise pass it to the API.
build() { NODE_OPTIONS=--max-old-space-size=512 "$@"; }

echo "Memory before build:"
free -m | sed -n '1,3p' || true

# --- 1. Build the API into dist.next (the running API keeps using dist).
# npm appends the flags after "--" to server's build script, which is "tsc".
cd "$APP_DIR/server"
build npm ci --no-audit --no-fund
rm -rf dist.next
# TypeScript 7's compiler is native and checks in parallel by default, which
# measured ~1.1 GB on an 8-core machine; --singleThreaded measured ~450 MB and
# costs nothing on 1 vCPU. TypeScript 5 doesn't know the flag, so only add it on 7+.
tsc_flags=(--outDir dist.next)
if node_modules/.bin/tsc --version | grep -qE '^Version ([7-9]|[1-9][0-9])\.'; then
  tsc_flags+=(--singleThreaded)
fi
build npm run build -- "${tsc_flags[@]}"
[ -f dist.next/index.js ] || { echo "Server build didn't produce dist.next/index.js" >&2; exit 1; }

# --- 2. Build the web app. VITE_API_URL=/api makes it call the API on the same
# origin (Nginx proxies /api/), so no domain is baked into the build.
cd "$APP_DIR/web"
build npm ci --no-audit --no-fund
VITE_API_URL=/api build npm run build
[ -f dist/index.html ] || { echo "Web build didn't produce dist/index.html" >&2; exit 1; }

release="$(date +%Y%m%d-%H%M%S)-$(git -C "$APP_DIR" rev-parse --short HEAD)"
mkdir -p "$WEB_ROOT/releases"
rm -rf "$WEB_ROOT/releases/"*.partial
cp -a dist "$WEB_ROOT/releases/$release.partial"
chmod -R a+rX "$WEB_ROOT/releases/$release.partial"
mv "$WEB_ROOT/releases/$release.partial" "$WEB_ROOT/releases/$release"

# --- 3. Both builds succeeded: switch the API. dist.prev is kept for a manual
# rollback (mv dist dist.bad && mv dist.prev dist && pm2 reload hacky-api).
cd "$APP_DIR/server"
rm -rf dist.prev
if [ -d dist ]; then mv dist dist.prev; fi
mv dist.next dist
pm2 reload hacky-api --update-env

# The API connects to Atlas before it listens, so give it a few seconds.
healthy=false
for _ in $(seq 1 15); do
  if curl -fsS "$HEALTH_URL"; then
    echo
    healthy=true
    break
  fi
  sleep 2
done

if [ "$healthy" != true ]; then
  echo "Health check failed: $HEALTH_URL (web app not switched; previous one stays live)" >&2
  pm2 logs hacky-api --lines 30 --nostream >&2 || true
  exit 1
fi

# --- 4. Switch the web app: make a new symlink, then rename it over "current".
ln -sfn "releases/$release" "$WEB_ROOT/current.next"
mv -T "$WEB_ROOT/current.next" "$WEB_ROOT/current"
echo "Web app: $WEB_ROOT/current -> releases/$release"

# Keep the newest releases (names start with a timestamp, so they sort by age).
find "$WEB_ROOT/releases" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' \
  | sort | head -n -"$KEEP_RELEASES" \
  | while read -r old; do rm -rf "${WEB_ROOT:?}/releases/$old"; done

echo "Deploy OK"
