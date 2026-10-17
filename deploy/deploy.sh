#!/usr/bin/env bash
# Build and ship Pairnest to the Oracle VM prepared by setup.sh.
# Run from the repo root in Git Bash / macOS / Linux:
#
#   SERVER=pairnest.example.com bash deploy/deploy.sh
#
# Optional: SSH_USER (default deploy), SSH_KEY (path to private key),
# SCHEME (https for domains, http for raw IPs), SKIP_WEB=1 to ship API only.
set -euo pipefail

SERVER="${SERVER:?Set SERVER to your domain or public IP}"
SSH_USER="${SSH_USER:-deploy}"
if [[ "$SERVER" =~ ^[0-9.]+$ ]]; then SCHEME="${SCHEME:-http}"; else SCHEME="${SCHEME:-https}"; fi
API_URL="$SCHEME://$SERVER/api/v1"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RELEASE=$(date +%Y%m%d%H%M%S)
SSH_OPTS=(-o StrictHostKeyChecking=accept-new)
[[ -n "${SSH_KEY:-}" ]] && SSH_OPTS+=(-i "$SSH_KEY")
BUNDLE="$(mktemp -d)"
trap 'rm -rf "$BUNDLE"' EXIT

if [[ -z "${SKIP_WEB:-}" ]]; then
  echo "==> Building Flutter web for $API_URL"
  (cd "$ROOT/app" && flutter build web --release --dart-define=API_URL="$API_URL")
fi

echo "==> Packing release $RELEASE"
mkdir -p "$BUNDLE/pkg"
tar -C "$ROOT" \
  --exclude='backend/vendor' --exclude='backend/node_modules' --exclude='backend/.env' \
  --exclude='backend/storage' --exclude='backend/database/*.sqlite' --exclude='backend/tests' \
  --exclude='backend/bootstrap/cache/*.php' --exclude='backend/.phpunit.result.cache' \
  -cf - backend | tar -C "$BUNDLE/pkg" -xf -
if [[ -z "${SKIP_WEB:-}" ]]; then
  cp -r "$ROOT/app/build/web" "$BUNDLE/pkg/web"
fi
tar -C "$BUNDLE/pkg" -czf "$BUNDLE/release.tgz" .

echo "==> Uploading"
scp "${SSH_OPTS[@]}" "$BUNDLE/release.tgz" "$SSH_USER@$SERVER:/tmp/pairnest-$RELEASE.tgz"

echo "==> Activating on server"
ssh "${SSH_OPTS[@]}" "$SSH_USER@$SERVER" RELEASE="$RELEASE" bash -s <<'REMOTE'
set -euo pipefail
APP=/var/www/pairnest
DIR=$APP/releases/$RELEASE
mkdir -p "$DIR"
tar -xzf /tmp/pairnest-$RELEASE.tgz -C "$DIR"
rm /tmp/pairnest-$RELEASE.tgz

# Keep the previous web build when shipping API only.
if [[ ! -d "$DIR/web" && -d "$APP/current/web" ]]; then cp -r "$(readlink -f $APP/current)/web" "$DIR/web"; fi

cd "$DIR/backend"
ln -sfn $APP/shared/.env .env
rm -rf storage && ln -sfn $APP/shared/storage storage
composer install --no-dev --optimize-autoloader --no-interaction --quiet
php artisan migrate --force
php artisan db:seed --class=ConversationPromptSeeder --force
php artisan config:cache
php artisan route:cache
php artisan view:cache
chmod -R g+rX "$DIR"

ln -sfn "$DIR" $APP/current.new && mv -T $APP/current.new $APP/current
sudo /usr/bin/systemctl reload php8.3-fpm

# Keep the five most recent releases.
ls -1dt $APP/releases/* | tail -n +6 | xargs -r rm -rf
echo "Release $RELEASE is live."
REMOTE

echo "==> Health check"
curl -fsS "$API_URL/health" && echo
echo "Done: $SCHEME://$SERVER"
