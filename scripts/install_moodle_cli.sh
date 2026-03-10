#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
ENV_FILE="$ROOT_DIR/.env"

if [[ ! -f "$ENV_FILE" ]]; then
	echo "File .env belum ada. Jalankan: cp .env.example .env"
	exit 1
fi

# Load variabel dari .env untuk parameter instalasi CLI.
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

MOODLE_PORT=${MOODLE_PORT:-8080}
MOODLE_URL=${MOODLE_URL:-http://localhost:${MOODLE_PORT}}
MOODLE_LANG=${MOODLE_LANG:-id}
MOODLE_FULLNAME=${MOODLE_FULLNAME:-Moodle Skenda}
MOODLE_SHORTNAME=${MOODLE_SHORTNAME:-Skenda LMS}
MOODLE_ADMIN_USER=${MOODLE_ADMIN_USER:-admin}
MOODLE_ADMIN_PASS=${MOODLE_ADMIN_PASS:-Admin123!ChangeMe}
MOODLE_ADMIN_EMAIL=${MOODLE_ADMIN_EMAIL:-admin@example.local}

if [[ ! -d "$ROOT_DIR/moodle" ]]; then
	echo "Folder moodle belum ada. Jalankan bootstrap terlebih dulu."
	echo "Contoh: ./scripts/bootstrap_moodle.sh moodle MOODLE_501_STABLE"
	exit 1
fi

mkdir -p "$ROOT_DIR/moodledata"
chmod 0777 "$ROOT_DIR/moodledata"

cd "$ROOT_DIR"
docker compose up -d --build

if docker compose exec -T php test -f /var/www/html/config.php; then
	echo "Moodle sudah terpasang (config.php ditemukan). Install dilewati."
	exit 0
fi

docker compose exec -T php php /var/www/html/admin/cli/install.php \
	--non-interactive \
	--agree-license \
	--wwwroot="${MOODLE_URL}" \
	--dataroot=/var/www/moodledata \
	--dbtype=mariadb \
	--dbhost=db \
	--dbname="${DB_NAME}" \
	--dbuser="${DB_USER}" \
	--dbpass="${DB_PASSWORD}" \
	--prefix=mdl_ \
	--fullname="${MOODLE_FULLNAME}" \
	--shortname="${MOODLE_SHORTNAME}" \
	--lang="${MOODLE_LANG}" \
	--adminuser="${MOODLE_ADMIN_USER}" \
	--adminpass="${MOODLE_ADMIN_PASS}" \
	--adminemail="${MOODLE_ADMIN_EMAIL}"

echo "Instalasi Moodle selesai. Buka: ${MOODLE_URL}"
