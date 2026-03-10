#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR=${1:-moodle}
BRANCH=${2:-MOODLE_501_STABLE}

if [[ -d "$TARGET_DIR/.git" ]]; then
  echo "Moodle repo sudah ada di '$TARGET_DIR'. Menarik update branch $BRANCH..."
  git -C "$TARGET_DIR" fetch origin "$BRANCH"
  git -C "$TARGET_DIR" checkout "$BRANCH"
  git -C "$TARGET_DIR" pull --ff-only origin "$BRANCH"
else
  echo "Clone Moodle branch $BRANCH ke '$TARGET_DIR'..."
  git clone --branch "$BRANCH" --single-branch https://github.com/moodle/moodle.git "$TARGET_DIR"
fi

echo "Selesai. Versi saat ini:"
git -C "$TARGET_DIR" describe --tags --always || true
