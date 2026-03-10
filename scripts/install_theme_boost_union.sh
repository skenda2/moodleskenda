#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
ENV_FILE="$ROOT_DIR/.env"
PLUGIN_DIR="$ROOT_DIR/moodle/public/theme/boost_union"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "File .env belum ada. Jalankan: cp .env.example .env"
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

cd "$ROOT_DIR"

if [[ ! -d "$ROOT_DIR/moodle/.git" ]]; then
  echo "Folder core Moodle belum ada. Jalankan bootstrap dulu."
  exit 1
fi

if [[ -d "$PLUGIN_DIR/.git" ]]; then
  echo "Boost Union sudah ada, update branch MOODLE_501_STABLE..."
  git -C "$PLUGIN_DIR" fetch origin MOODLE_501_STABLE
  git -C "$PLUGIN_DIR" checkout MOODLE_501_STABLE
  git -C "$PLUGIN_DIR" pull --ff-only origin MOODLE_501_STABLE
else
  rm -rf "$PLUGIN_DIR"
  git clone --branch MOODLE_501_STABLE --single-branch \
    https://github.com/moodle-an-hochschulen/moodle-theme_boost_union.git \
    "$PLUGIN_DIR"
fi

docker compose up -d

docker compose exec -T php php /var/www/html/admin/cli/upgrade.php --non-interactive

docker compose exec -T db mariadb -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" \
  -e "UPDATE mdl_config SET value='boost_union' WHERE name='theme';"

docker compose exec -T php php /var/www/html/admin/cli/purge_caches.php

echo "Theme Boost Union aktif."
