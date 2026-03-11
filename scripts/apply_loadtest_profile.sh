#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
ENV_FILE="$ROOT_DIR/.env"
PROFILE_NAME=${1:-}
PROFILE_FILE="$ROOT_DIR/config/loadtest-profiles/${PROFILE_NAME}.env"
MODE=${2:-apply}

if [[ -z "$PROFILE_NAME" ]]; then
  echo "Usage: $0 <300|700|1200> [apply|dry-run]"
  exit 1
fi

if [[ ! -f "$ENV_FILE" ]]; then
  echo "File .env belum ada. Jalankan: cp .env.example .env"
  exit 1
fi

if [[ ! -f "$PROFILE_FILE" ]]; then
  echo "Profile tidak ditemukan: $PROFILE_FILE"
  exit 1
fi

merge_key() {
  local key="$1"
  local value="$2"

  if grep -q "^${key}=" "$ENV_FILE"; then
    sed -i "s|^${key}=.*|${key}=${value}|" "$ENV_FILE"
  else
    printf '\n%s=%s\n' "$key" "$value" >> "$ENV_FILE"
  fi
}

echo "Profile: $PROFILE_NAME"
echo "Source : $PROFILE_FILE"

while IFS='=' read -r key value; do
  [[ -z "$key" ]] && continue
  [[ "$key" =~ ^# ]] && continue

  if [[ "$MODE" == "dry-run" ]]; then
    echo "would set ${key}=${value}"
  else
    merge_key "$key" "$value"
    echo "set ${key}=${value}"
  fi
done < "$PROFILE_FILE"

if [[ "$MODE" == "dry-run" ]]; then
  exit 0
fi

echo
if docker compose version >/dev/null 2>&1; then
  echo "Profile diterapkan ke .env. Jalankan: docker compose up -d --build --force-recreate php web"
else
  echo "Profile diterapkan ke .env."
fi
