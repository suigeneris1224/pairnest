#!/usr/bin/env bash
# One-time provisioning for an Oracle Cloud "Always Free" VM.
# Image: Canonical Ubuntu 24.04 (Ampere A1 / aarch64 or AMD micro).
#
#   scp deploy/setup.sh deploy/nginx.conf.template ubuntu@<VM_IP>:~
#   ssh ubuntu@<VM_IP> 'sudo SERVER_NAME=pairnest.example.com bash setup.sh'
#
# SERVER_NAME may be a domain (HTTPS via Let's Encrypt) or the VM's public IP
# (HTTP only). Safe to re-run.
set -euo pipefail

SERVER_NAME="${SERVER_NAME:?Set SERVER_NAME to your domain or public IP}"
CERT_EMAIL="${CERT_EMAIL:-}"
APP_DIR=/var/www/pairnest
DB_NAME=pairnest
DB_USER=pairnest
HERE="$(cd "$(dirname "$0")" && pwd)"

[[ $EUID -eq 0 ]] || { echo "Run with sudo." >&2; exit 1; }

echo "==> Packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update -q
apt-get install -yq nginx mysql-server unzip git curl \
  php8.3-fpm php8.3-cli php8.3-mysql php8.3-mbstring php8.3-xml php8.3-curl \
  php8.3-zip php8.3-bcmath php8.3-intl php8.3-sqlite3 \
  composer certbot python3-certbot-nginx iptables-persistent

echo "==> Swap (helps small shapes run composer)"
if ! swapon --show | grep -q /swapfile; then
  fallocate -l 2G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
  grep -q /swapfile /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

echo "==> Firewall: Oracle images REJECT everything but SSH in iptables"
for port in 80 443; do
  iptables -C INPUT -p tcp -m state --state NEW --dport "$port" -j ACCEPT 2>/dev/null \
    || iptables -I INPUT 5 -p tcp -m state --state NEW --dport "$port" -j ACCEPT
done
netfilter-persistent save
echo "    Also add Ingress Rules for TCP 80 and 443 (source 0.0.0.0/0) in the VCN Security List."

echo "==> Directories"
mkdir -p "$APP_DIR"/{releases,shared/storage/{app/public,framework/{cache/data,sessions,views},logs}}
id -u deploy >/dev/null 2>&1 || useradd --system --create-home --shell /bin/bash deploy
usermod -aG www-data deploy
SUDO_HOME=$(getent passwd "${SUDO_USER:-ubuntu}" | cut -d: -f6)
if [[ -f "$SUDO_HOME/.ssh/authorized_keys" && ! -f /home/deploy/.ssh/authorized_keys ]]; then
  install -d -m 700 -o deploy -g deploy /home/deploy/.ssh
  install -m 600 -o deploy -g deploy "$SUDO_HOME/.ssh/authorized_keys" /home/deploy/.ssh/authorized_keys
fi
# deploy.sh reloads php-fpm after switching releases.
echo 'deploy ALL=(root) NOPASSWD: /usr/bin/systemctl reload php8.3-fpm' > /etc/sudoers.d/pairnest-deploy
chmod 440 /etc/sudoers.d/pairnest-deploy

echo "==> MySQL"
ENV_FILE="$APP_DIR/shared/.env"
if [[ ! -f "$ENV_FILE" ]]; then
  DB_PASS=$(openssl rand -hex 24)
  mysql <<SQL
CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
ALTER USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
SQL

  SCHEME=http
  [[ "$SERVER_NAME" =~ ^[0-9.]+$ ]] || SCHEME=https
  cat > "$ENV_FILE" <<ENV
APP_NAME=Pairnest
APP_ENV=production
APP_KEY=base64:$(openssl rand -base64 32)
APP_DEBUG=false
APP_URL=$SCHEME://$SERVER_NAME
APP_TIMEZONE=UTC

LOG_CHANNEL=daily
LOG_LEVEL=warning

DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=$DB_NAME
DB_USERNAME=$DB_USER
DB_PASSWORD=$DB_PASS

SESSION_DRIVER=database
CACHE_STORE=database
QUEUE_CONNECTION=database
ENV
  echo "    Wrote $ENV_FILE (database password generated)."
fi
chown -R deploy:www-data "$APP_DIR"
chmod 640 "$ENV_FILE"
chmod -R ug+rwX "$APP_DIR/shared/storage"

echo "==> Nginx"
sed "s/__SERVER_NAME__/$SERVER_NAME/g" "$HERE/nginx.conf.template" > /etc/nginx/sites-available/pairnest
ln -sf /etc/nginx/sites-available/pairnest /etc/nginx/sites-enabled/pairnest
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx

if [[ ! "$SERVER_NAME" =~ ^[0-9.]+$ ]]; then
  echo "==> HTTPS certificate"
  if [[ -n "$CERT_EMAIL" ]]; then
    certbot --nginx -d "$SERVER_NAME" --non-interactive --agree-tos -m "$CERT_EMAIL" --redirect
  else
    certbot --nginx -d "$SERVER_NAME" --non-interactive --agree-tos --register-unsafely-without-email --redirect
  fi
fi

echo "==> Done. Now run deploy/deploy.sh from your machine (it connects as user 'deploy')."
