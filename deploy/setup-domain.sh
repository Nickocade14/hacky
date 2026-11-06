#!/usr/bin/env bash
# One-time HTTPS setup for Hacky's domain. Run on the droplet as root:
#
#   bash /var/www/hacky/deploy/setup-domain.sh <domain> <email>
#   e.g. bash /var/www/hacky/deploy/setup-domain.sh hackyteam.me you@ucf.edu
#
# Safe to run again (after changing deploy/nginx/hacky.conf, for example): it
# re-renders the site and certbot reinstalls the certificate it already has.
# The email is only for Let's Encrypt expiry notices.
# Set SKIP_DNS_CHECK=1 to continue when the DNS check fails (not recommended:
# Let's Encrypt blocks a domain for an hour after 5 failed attempts).
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TEMPLATE="$SCRIPT_DIR/nginx/hacky.conf"
SITE_AVAILABLE=/etc/nginx/sites-available/hacky
SITE_ENABLED=/etc/nginx/sites-enabled/hacky
BACKUP_DIR=/etc/nginx/hacky-backups
WEB_CURRENT=/var/www/hacky-web/current

die() { echo "ERROR: $*" >&2; exit 1; }
warn() { echo "WARNING: $*" >&2; }
step() { echo; echo "==> $*"; }

usage() {
  echo "Usage: bash $0 <domain> <email>" >&2
  echo "  domain: the bare domain, without www or https:// (e.g. hackyteam.me)" >&2
  exit 1
}

[ $# -eq 2 ] || usage
DOMAIN=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
EMAIL=$2

case "$DOMAIN" in
  http://* | https://* | */*) die "Give only the domain, e.g. hackyteam.me (no https://, no path)." ;;
  www.*) die "Give the bare domain, ${DOMAIN#www.} (www. is added automatically)." ;;
esac
[[ "$DOMAIN" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$ ]] \
  || die "'$DOMAIN' doesn't look like a domain name."
[[ "$EMAIL" =~ ^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$ ]] || die "'$EMAIL' doesn't look like an email address."
[ "$(id -u)" -eq 0 ] || die "Run as root (the droplet's root user, or with sudo)."
[ -f "$TEMPLATE" ] || die "Template not found: $TEMPLATE. Pull the repo first (cd /var/www/hacky && git pull)."

# --- 1. DNS must point at this droplet, or Let's Encrypt can't verify the domain.
step "Checking DNS for $DOMAIN and www.$DOMAIN"

# The droplet's public IPs, from DigitalOcean's metadata service.
METADATA=http://169.254.169.254/metadata/v1/interfaces/public/0
DROPLET_IPV4=${DROPLET_IP:-$(curl -fsS --max-time 5 "$METADATA/ipv4/address" 2>/dev/null || true)}
DROPLET_IPV6=$(curl -fsS --max-time 5 "$METADATA/ipv6/address" 2>/dev/null || true)
[ -n "$DROPLET_IPV4" ] || die "Couldn't read this droplet's public IP. Re-run with DROPLET_IP=64.23.249.112 in front of the command."
echo "This droplet: $DROPLET_IPV4${DROPLET_IPV6:+ and $DROPLET_IPV6}"

# Ask a public resolver directly (dig), so a stale local cache can't fool the check.
lookup() { # lookup <A|AAAA> <name>: one address per line
  if command -v dig >/dev/null 2>&1; then
    dig +short "$1" "$2" @1.1.1.1 | grep -E '^[0-9a-fA-F.:]+$' || true
  elif [ "$1" = A ]; then
    getent ahostsv4 "$2" | awk '{print $1}' | sort -u || true
  else
    getent ahostsv6 "$2" | awk '{print $1}' | sort -u || true
  fi
}

dns_ok=true
for name in "$DOMAIN" "www.$DOMAIN"; do
  a=$(lookup A "$name" | tr '\n' ' ')
  aaaa=$(lookup AAAA "$name" | tr '\n' ' ')
  echo "$name: A = ${a:-none}, AAAA = ${aaaa:-none}"
  if [ "$(echo "$a" | xargs)" != "$DROPLET_IPV4" ]; then
    warn "$name must have exactly one A record, $DROPLET_IPV4 (found: ${a:-none})."
    dns_ok=false
  fi
  # Let's Encrypt prefers IPv6, so a leftover AAAA (registrar parking page) breaks it.
  for ip in $aaaa; do
    if [ "$ip" != "$DROPLET_IPV6" ]; then
      warn "$name has an AAAA record $ip that isn't this droplet. Delete it at the registrar."
      dns_ok=false
    fi
  done
done

if [ "$dns_ok" != true ]; then
  echo >&2
  warn "DNS doesn't point at this droplet yet."
  echo "  At the registrar, set two A records: '@' and 'www' -> $DROPLET_IPV4," >&2
  echo "  delete any other A, AAAA, CNAME or URL-redirect records for @ and www," >&2
  echo "  wait a few minutes (up to an hour), then run this script again." >&2
  if [ "${SKIP_DNS_CHECK:-0}" != 1 ]; then
    exit 1
  fi
  warn "SKIP_DNS_CHECK=1 is set, continuing anyway."
fi

# --- 2. Packages
step "Installing nginx and certbot (skipped if already installed)"
export DEBIAN_FRONTEND=noninteractive
missing=()
for pkg in nginx certbot python3-certbot-nginx; do
  dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed" || missing+=("$pkg")
done
if [ ${#missing[@]} -gt 0 ]; then
  apt-get update -q
  apt-get install -y -q "${missing[@]}"
else
  echo "Already installed."
fi

# --- 3. Firewall: HTTPS needs port 443 open, not only 80.
if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
  step "Opening ports 80 and 443 in ufw"
  ufw allow 'Nginx Full'
fi

# --- 4. Nginx site
step "Writing $SITE_AVAILABLE"
rendered=$(mktemp)
trap 'rm -f "$rendered"' EXIT
sed "s/__DOMAIN__/$DOMAIN/g" "$TEMPLATE" > "$rendered"
if [ -f "$SITE_AVAILABLE" ]; then
  mkdir -p "$BACKUP_DIR"
  backup="$BACKUP_DIR/hacky.$(date +%Y%m%d-%H%M%S)"
  cp "$SITE_AVAILABLE" "$backup"
  echo "Previous version saved to $backup"
fi
install -m 644 "$rendered" "$SITE_AVAILABLE"
ln -sfn "$SITE_AVAILABLE" "$SITE_ENABLED"

if [ -e /etc/nginx/sites-enabled/default ]; then
  rm /etc/nginx/sites-enabled/default
  echo "Disabled the default site (the file stays in sites-available/default)."
fi

others=$(find /etc/nginx/sites-enabled -mindepth 1 ! -name hacky -printf '%f ' 2>/dev/null || true)
if [ -n "$others" ]; then
  warn "Other enabled sites: $others"
  echo "  If one of them is the old IP-only /api/ proxy, it's no longer needed:" >&2
  echo "  rm /etc/nginx/sites-enabled/<name> && nginx -t && systemctl reload nginx" >&2
fi

nginx -t
systemctl enable --now nginx
systemctl reload nginx

if [ ! -f "$WEB_CURRENT/index.html" ]; then
  warn "No web build at $WEB_CURRENT yet, so the site shows 404 until one exists."
  echo "  It appears after the next deploy, or run: bash /var/www/hacky/deploy/deploy.sh" >&2
fi

# --- 5. Certificate. certbot edits $SITE_AVAILABLE: adds the 443 server and the
# HTTP -> HTTPS redirect. On a re-run it keeps the existing certificate and
# reinstalls it into the freshly rendered file.
step "Getting the HTTPS certificate from Let's Encrypt"
certbot --nginx \
  -d "$DOMAIN" -d "www.$DOMAIN" \
  --cert-name "$DOMAIN" \
  --redirect --keep-until-expiring \
  --non-interactive --agree-tos -m "$EMAIL"

# --- 6. Renewal. The apt package renews twice a day through a systemd timer.
step "Checking automatic renewal"
certbot renew --dry-run
if systemctl is-enabled --quiet certbot.timer 2>/dev/null; then
  echo "Auto-renew is on (systemd timer certbot.timer):"
  systemctl list-timers certbot.timer --no-pager | sed -n '1,2p'
else
  warn "certbot.timer isn't enabled. Turn it on with: systemctl enable --now certbot.timer"
fi

# --- 7. Smoke test through the public name.
step "Testing https://$DOMAIN/api/health"
if curl -fsS --max-time 10 "https://$DOMAIN/api/health"; then
  echo
else
  warn "https://$DOMAIN/api/health didn't answer from here. Check: pm2 status, curl localhost:8787/api/health"
fi

cat <<EOF

==> Done. https://$DOMAIN is live (www.$DOMAIN and http:// redirect to it).

Next, point the API at the domain. Edit /var/www/hacky/server/.env and set:

  CORS_ORIGIN=https://$DOMAIN,https://www.$DOMAIN
  APP_URL=https://$DOMAIN

(APP_URL is the base of the links in verification and password-reset emails.)
Then restart the API so it reads the new .env:

  pm2 reload hacky-api --update-env && pm2 status

Check in a browser: https://$DOMAIN (web app) and https://$DOMAIN/api/health
EOF
