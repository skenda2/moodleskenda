#!/usr/bin/env bash
set -euo pipefail

# Host-level kernel hardening required by Redis/MariaDB when running in containers.
# Run this script on the Docker host (or LXC host), not inside application containers.

if [[ "${EUID}" -ne 0 ]]; then
  echo "[ERROR] Jalankan sebagai root: sudo $0"
  exit 1
fi

CONF_FILE="/etc/sysctl.d/99-moodleskenda.conf"

echo "[INFO] Menulis ${CONF_FILE} ..."
cat > "${CONF_FILE}" <<'EOF'
# Redis persistence reliability under memory pressure.
vm.overcommit_memory=1

# Improve connection backlog handling for high concurrency workloads.
net.core.somaxconn=1024

# Inotify limits useful for modern toolchains and containerized workloads.
fs.inotify.max_user_watches=524288
fs.inotify.max_user_instances=1024
EOF

echo "[INFO] Menerapkan sysctl ..."
sysctl --system >/dev/null

echo "[OK] Applied. Nilai aktif saat ini:"
sysctl vm.overcommit_memory net.core.somaxconn fs.inotify.max_user_watches fs.inotify.max_user_instances
