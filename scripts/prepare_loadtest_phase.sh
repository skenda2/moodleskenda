#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
PHASE=${1:-}

if [[ -z "$PHASE" ]]; then
  echo "Usage: $0 <300|700|1200>"
  exit 1
fi

cd "$ROOT_DIR"

echo "[1/5] Terapkan profile load test: $PHASE"
./scripts/apply_loadtest_profile.sh "$PHASE"

echo "[2/5] Recreate php dan web"
docker compose up -d --build --force-recreate php web

echo "[3/5] Tunggu healthcheck"
for _ in $(seq 1 20); do
  if docker compose ps | grep -q 'moodle_web.*healthy' && docker compose ps | grep -q 'moodle_php.*healthy'; then
    break
  fi
  sleep 3
done

echo "[4/5] Purge cache Moodle"
docker compose exec -T php php /var/www/html/admin/cli/purge_caches.php

echo "[5/5] Verifikasi health endpoint"
curl -fsS http://localhost:8080/healthz.php >/tmp/moodleskenda-healthz.json
cat /tmp/moodleskenda-healthz.json
echo

echo "Phase $PHASE siap dijalankan."
echo "Mulai monitoring: INTERVAL=15 DURATION=1800 ./scripts/monitor_loadtest.sh phase-$PHASE"
