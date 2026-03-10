#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
ENV_FILE="$ROOT_DIR/.env"

REDIS_HOST=${REDIS_HOST:-redis}
REDIS_PORT=${REDIS_PORT:-6379}
REDIS_PREFIX=${REDIS_PREFIX:-moodle_}

ensure_config_readable() {
	# On some hosts/LXC bind mounts, config.php can end up unreadable by php-fpm worker.
	docker compose exec -T php sh -lc '
		if [ -f /var/www/html/config.php ]; then
			chmod 0644 /var/www/html/config.php || true
		fi
		chmod 0755 /var/www /var/www/html /var/www/html/public 2>/dev/null || true
	'
}

ensure_redis_session_config() {
	local cfg="$ROOT_DIR/moodle/config.php"
	local marker="moodleskenda redis session config"

	if [[ ! -f "$cfg" ]]; then
		return 0
	fi

	if grep -q "$marker" "$cfg"; then
		return 0
	fi

	local line tmp
	line=$(grep -n "require_once(__DIR__ . '/lib/setup.php');" "$cfg" | head -n1 | cut -d: -f1 || true)
	tmp=$(mktemp)

	if [[ -n "$line" ]]; then
		head -n $((line - 1)) "$cfg" > "$tmp"
		cat >> "$tmp" <<EOF

// moodleskenda redis session config.
\$CFG->session_handler_class = '\\core\\session\\redis';
\$CFG->session_redis_host = '${REDIS_HOST}';
\$CFG->session_redis_port = ${REDIS_PORT};
\$CFG->session_redis_database = 0;
\$CFG->session_redis_prefix = '${REDIS_PREFIX}sess_';
\$CFG->session_redis_acquire_lock_timeout = 120;
\$CFG->session_redis_lock_expire = 7200;
\$CFG->session_redis_lock_retry = 100;
EOF
		tail -n +"$line" "$cfg" >> "$tmp"
		mv -f "$tmp" "$cfg"
	else
		echo "Tidak menemukan baris require_once setup.php di config.php, lewati inject Redis."
		rm -f "$tmp"
	fi
}

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
	ensure_redis_session_config
	ensure_config_readable
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

ensure_redis_session_config
ensure_config_readable

echo "Instalasi Moodle selesai. Buka: ${MOODLE_URL}"
