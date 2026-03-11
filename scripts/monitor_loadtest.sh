#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
ENV_FILE="$ROOT_DIR/.env"
OUTPUT_ROOT="$ROOT_DIR/tmp/loadtest-monitor"
INTERVAL=${INTERVAL:-15}
DURATION=${DURATION:-1800}
LABEL=${1:-manual}
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
RUN_DIR="$OUTPUT_ROOT/${TIMESTAMP}-${LABEL}"
SAMPLES=$(( DURATION / INTERVAL ))

mkdir -p "$RUN_DIR"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

DB_NAME=${DB_NAME:-moodle}
DB_USER=${DB_USER:-moodle}
DB_PASSWORD=${DB_PASSWORD:-}
MOODLE_PORT=${MOODLE_PORT:-8080}
HEALTH_URL=${HEALTH_URL:-http://127.0.0.1:${MOODLE_PORT}/healthz.php}

meta_file="$RUN_DIR/meta.txt"
{
  echo "timestamp=$TIMESTAMP"
  echo "label=$LABEL"
  echo "interval=$INTERVAL"
  echo "duration=$DURATION"
  echo "health_url=$HEALTH_URL"
} > "$meta_file"

capture_once() {
  local sample="$1"
  local prefix="$RUN_DIR/$(printf '%04d' "$sample")"
  local now
  now=$(date --iso-8601=seconds)

  printf 'sample=%s\ntimestamp=%s\n' "$sample" "$now" > "${prefix}.meta"
  docker compose ps > "${prefix}.compose-ps.txt"
  docker stats --no-stream moodle_web moodle_php moodle_db moodle_redis > "${prefix}.docker-stats.txt"
  curl -sS "$HEALTH_URL" > "${prefix}.healthz.json" || true

  if [[ -n "$DB_PASSWORD" ]]; then
    docker compose exec -T db mariadb -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "SHOW GLOBAL STATUS LIKE 'Threads_connected'; SHOW GLOBAL STATUS LIKE 'Threads_running'; SHOW FULL PROCESSLIST;" > "${prefix}.db.txt" 2>&1 || true
  fi
}

echo "Menyimpan snapshot ke: $RUN_DIR"
echo "Jumlah sample: $SAMPLES"

sample=1
while [[ "$sample" -le "$SAMPLES" ]]; do
  capture_once "$sample"
  if [[ "$sample" -lt "$SAMPLES" ]]; then
    sleep "$INTERVAL"
  fi
  sample=$((sample + 1))
done

echo "Selesai. Hasil ada di: $RUN_DIR"
