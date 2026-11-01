#!/usr/bin/env bash
# Runs on the droplet as the forced command of the GitHub Actions deploy key.
# Updates the checkout to origin/main, then runs the freshly pulled deploy.sh.
# Kept separate from deploy.sh: bash reads a script while running it, so a script
# must not overwrite itself with git reset.
set -euo pipefail

APP_DIR=/var/www/hacky

cd "$APP_DIR"
git fetch --quiet origin main
git reset --hard --quiet origin/main
echo "Checked out $(git log -1 --format='%h %s')"

exec bash "$APP_DIR/deploy/deploy.sh"
