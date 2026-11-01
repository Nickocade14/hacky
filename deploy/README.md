# Deploy

Every push to `main` that passes CI is deployed to the droplet by `.github/workflows/deploy.yml`.

```
push to main → CI passes → Deploy workflow → SSH to droplet
  → deploy/ssh-deploy.sh   (git fetch + reset to origin/main)
  → deploy/deploy.sh       (npm ci, build, pm2 reload, health check)
```

You can also run it by hand: GitHub → Actions → Deploy → Run workflow.

## Droplet layout

- Repo: `/var/www/hacky`, API process: `pm2` app `hacky-api` (`npm start` in `server/`)
- Secrets: `/var/www/hacky/server/.env` (never in git; `git reset` doesn't touch it)
- Nginx proxies `/api/` to `127.0.0.1:8787`
- Owner: Deploy (Nicolas). Ask before changing anything on the droplet.

## One-time setup

Needs the CI workflow on `main` (the Deploy workflow runs after it).

1. On the droplet, pull once so the deploy scripts exist:

   ```bash
   cd /var/www/hacky && git pull
   ```

2. Create a key only for GitHub Actions and allow it to run the deploy script and nothing else:

   ```bash
   ssh-keygen -t ed25519 -N "" -C github-actions-deploy -f ~/.ssh/github_deploy
   echo "command=\"bash /var/www/hacky/deploy/ssh-deploy.sh\",no-port-forwarding,no-agent-forwarding,no-X11-forwarding,no-pty $(cat ~/.ssh/github_deploy.pub)" >> ~/.ssh/authorized_keys
   ```

3. Print the two values for GitHub:

   ```bash
   cat ~/.ssh/github_deploy                                                   # DEPLOY_SSH_KEY
   echo "64.23.249.112 $(cut -d' ' -f1,2 /etc/ssh/ssh_host_ed25519_key.pub)"  # DEPLOY_KNOWN_HOSTS
   ```

4. GitHub → repo Settings → Secrets and variables → Actions → New repository secret:

   | Name | Value |
   |---|---|
   | `DEPLOY_HOST` | `64.23.249.112` |
   | `DEPLOY_SSH_KEY` | the whole private key, `-----BEGIN` to `END-----` lines included |
   | `DEPLOY_KNOWN_HOSTS` | the `64.23.249.112 ssh-ed25519 ...` line |

5. Delete the private key from the droplet (GitHub has the only copy now):

   ```bash
   rm ~/.ssh/github_deploy
   ```

6. Test: Actions → Deploy → Run workflow. The log ends with `Deploy OK`.

## If a deploy fails

- The workflow log shows the last 30 lines of `pm2 logs`.
- On the droplet: `pm2 status`, `pm2 logs hacky-api`, `curl localhost:8787/api/health`.
- The repo is public, so the droplet pulls without credentials. If it goes private, the droplet needs a read-only GitHub deploy key.
