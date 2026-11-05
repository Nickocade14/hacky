# Deploy

Every push to `main` that passes CI is deployed to the droplet by `.github/workflows/deploy.yml`.

```
push to main → CI passes → Deploy workflow (skips if main already moved past that commit) → SSH to droplet
  → deploy/ssh-deploy.sh   (git fetch + reset to origin/main)
  → deploy/deploy.sh       (build API + web app, pm2 reload, health check, switch web app)
```

Nothing live changes until both builds succeed, and the web app only switches after the API health check passes, so a failed deploy leaves the previous version online.

You can also run it by hand: GitHub → Actions → Deploy → Run workflow.

## Droplet layout

- Repo: `/var/www/hacky`, API process: `pm2` app `hacky-api` (`npm start` in `server/`, runs `server/dist`)
- Secrets: `/var/www/hacky/server/.env` (never in git; `git reset` doesn't touch it)
- Web app: each deploy builds `web/` and copies the result to `/var/www/hacky-web/releases/<time>-<commit>/` (the newest 3 are kept). `/var/www/hacky-web/current` is a symlink to the live one.
- Nginx site: `/etc/nginx/sites-available/hacky`, made from [`nginx/hacky.conf`](nginx/hacky.conf) by `setup-domain.sh` (certbot adds the HTTPS part). It serves `/var/www/hacky-web/current` and proxies `/api/` and `/socket.io/` to `127.0.0.1:8787`. To change it, edit the template and run `setup-domain.sh` again.
- HTTPS: Let's Encrypt certificate from certbot, renewed automatically by `certbot.timer`.
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

## Domain and HTTPS (one time)

The demo must run on a real domain with HTTPS, never on the IP. Do these steps in order.

1. **Make sure the web app has been built once**, so `/var/www/hacky-web/current` exists. That happens on the first deploy after the web build was added to `deploy.sh`. To do it by hand: `cd /var/www/hacky && git pull && bash deploy/deploy.sh`.

2. **Check the droplet has enough swap** (the builds need it on 1 GB of RAM): run `free -h`. If the `Swap:` line shows less than 1G total, add a 2 GB swap file:

   ```bash
   fallocate -l 2G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
   echo '/swapfile none swap sw 0 0' >> /etc/fstab
   ```

   If `/swapfile` already exists, run `swapon --show` to see what you have instead.

3. **Get a domain.** The [GitHub Student Developer Pack](https://education.github.com/pack) has included free first-year domains, for example a `.me` from Namecheap or a free domain from name.com. Offers change, so check the pack for what's there now. Check the renewal price after year one too.

4. **Point the domain at the droplet.** In the registrar's DNS settings (Namecheap: Domain List → Manage → Advanced DNS), create two records:

   | Type | Host | Value |
   |---|---|---|
   | A | `@` | `64.23.249.112` |
   | A | `www` | `64.23.249.112` |

   Delete any other records for `@` and `www` that the registrar added (parking page CNAME, URL redirect, AAAA). They make the certificate fail.

5. **Wait for DNS.** Usually a few minutes, sometimes up to an hour. Check from your laptop: `nslookup <domain>` and `nslookup www.<domain>` should both answer `64.23.249.112`.

6. **Check the DigitalOcean firewall.** If the droplet has a Cloud Firewall (DigitalOcean → Networking → Firewalls), it must allow inbound HTTP (80) and HTTPS (443). The script opens them in `ufw` on the droplet itself.

7. **Run the setup script on the droplet** as root:

   ```bash
   cd /var/www/hacky && git pull
   bash deploy/setup-domain.sh <domain> <your-email>
   ```

   It checks DNS first and stops with a message if the domain doesn't point at the droplet yet (wait and run it again). Then it installs Nginx and certbot if needed, writes the Nginx site, gets the HTTPS certificate, redirects `http://` and `www.` to `https://<domain>`, and checks that renewal works. Running it again is safe. The email only gets certificate expiry notices.

8. **Point the API at the domain.** Edit `/var/www/hacky/server/.env` (the script prints these lines with your domain filled in):

   ```
   CORS_ORIGIN=https://<domain>,https://www.<domain>
   APP_URL=https://<domain>
   ```

   `APP_URL` is the start of the links in verification and password-reset emails. Then restart the API so it reads the file again: `pm2 reload hacky-api --update-env`.

9. **Test.** Open `https://<domain>/api/health` (it should show `{"ok":true}`) and `https://<domain>` (the login screen), on your laptop and on your phone over mobile data. Also open `https://<domain>/verify` directly: it should load the app, not a 404.

10. **Test on UCF campus Wi-Fi before demo day.** Campus networks sometimes block newly registered domains for a while. Find out early so there's time to ask UCF IT, or plan to use a phone hotspot.

## If a deploy fails

- The workflow log shows the last 30 lines of `pm2 logs`.
- On the droplet: `pm2 status`, `pm2 logs hacky-api`, `curl localhost:8787/api/health`.
- A failed build or health check doesn't switch the web app, so the site keeps showing the previous version.
- Roll back the API by hand: `cd /var/www/hacky/server && mv dist dist.bad && mv dist.prev dist && pm2 reload hacky-api`.
- Roll back the web app: `ls /var/www/hacky-web/releases`, then `cd /var/www/hacky-web && ln -sfn releases/<older> current.next && mv -T current.next current`.
- Site problems: `nginx -t`, `systemctl status nginx`, `tail /var/log/nginx/error.log`, `certbot certificates`.
- The repo is public, so the droplet pulls without credentials. If it goes private, the droplet needs a read-only GitHub deploy key.
