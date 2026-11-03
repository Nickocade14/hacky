#!/usr/bin/env bash
# Builds and restarts the API on the droplet. Called by ssh-deploy.sh after the
# checkout is on origin/main. server/.env is untracked, so git reset keeps it.
set -euo pipefail

APP_DIR=/var/www/hacky
HEALTH_URL=http://localhost:8787/api/health

cd "$APP_DIR/server"
npm ci --no-audit --no-fund
npm run build
pm2 reload hacky-api --update-env

# The API connects to Atlas before it listens, so give it a few seconds.
for _ in $(seq 1 15); do
  if curl -fsS "$HEALTH_URL"; then
    echo
    echo "Deploy OK"
    exit 0
  fi
  sleep 2
done

echo "Health check failed: $HEALTH_URL" >&2
pm2 logs hacky-api --lines 30 --nostream >&2 || true
exit 1
