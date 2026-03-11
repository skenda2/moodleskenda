#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
ENV_FILE="$ROOT_DIR/.env"
PHASE=${1:-smoke}
DURATION=${2:-}
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
RESULT_DIR="$ROOT_DIR/tmp/loadtest-results"
USERS_CSV="$ROOT_DIR/loadtest/users.csv"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "File .env belum ada. Jalankan: cp .env.example .env"
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

case "$PHASE" in
  smoke)
    VUS=1
    DURATION=${DURATION:-30s}
    ;;
  300|700|1200)
    VUS=$PHASE
    DURATION=${DURATION:-10m}
    ;;
  *)
    echo "Phase harus salah satu dari: smoke, 300, 700, 1200"
    exit 1
    ;;
esac

mkdir -p "$RESULT_DIR"

cd "$ROOT_DIR"

if [[ "$PHASE" != "smoke" ]]; then
  ./scripts/prepare_loadtest_phase.sh "$PHASE"
fi

K6_ENV_ARGS=(
  -e K6_VUS="$VUS"
  -e K6_DURATION="$DURATION"
  -e K6_BASE_URL="${MOODLE_URL:-http://localhost:8080}"
  -e K6_COURSE_PATH="/my/courses.php"
  -e K6_THINK_TIME="1"
)

if [[ -f "$USERS_CSV" ]]; then
  K6_ENV_ARGS+=( -e K6_USERS_CSV="../users.csv" )
else
  if [[ -n "${MOODLE_ADMIN_USER:-}" && -n "${MOODLE_ADMIN_PASS:-}" ]]; then
    K6_ENV_ARGS+=( -e K6_USERNAME="${MOODLE_ADMIN_USER}" -e K6_PASSWORD="${MOODLE_ADMIN_PASS}" )
  else
    echo "Tidak menemukan loadtest/users.csv dan kredensial admin di .env."
    echo "Buat loadtest/users.csv dari loadtest/users.example.csv atau isi MOODLE_ADMIN_USER/MOODLE_ADMIN_PASS."
    exit 1
  fi
fi

SUMMARY_FILE="results/${TIMESTAMP}-${PHASE}-summary.json"

echo "Menjalankan k6 phase=$PHASE vus=$VUS duration=$DURATION"
docker compose --profile loadtest run --rm -T \
  "${K6_ENV_ARGS[@]}" \
  k6 run /loadtest/k6/moodle_phase.js \
  --summary-export "$SUMMARY_FILE"

echo "Summary tersimpan di $RESULT_DIR/$(basename "$SUMMARY_FILE")"