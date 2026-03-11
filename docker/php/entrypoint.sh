#!/usr/bin/env bash
set -euo pipefail

: "${PHP_FPM_PM:=dynamic}"
: "${PHP_FPM_MAX_CHILDREN:=24}"
: "${PHP_FPM_START_SERVERS:=4}"
: "${PHP_FPM_MIN_SPARE_SERVERS:=4}"
: "${PHP_FPM_MAX_SPARE_SERVERS:=12}"
: "${PHP_FPM_MAX_REQUESTS:=700}"
: "${PHP_FPM_REQUEST_TERMINATE_TIMEOUT:=300s}"
: "${PHP_FPM_REQUEST_SLOWLOG_TIMEOUT:=10s}"

cat > /usr/local/etc/php-fpm.d/zz-moodle-pool.conf <<EOF
[www]
pm=${PHP_FPM_PM}
pm.max_children=${PHP_FPM_MAX_CHILDREN}
pm.start_servers=${PHP_FPM_START_SERVERS}
pm.min_spare_servers=${PHP_FPM_MIN_SPARE_SERVERS}
pm.max_spare_servers=${PHP_FPM_MAX_SPARE_SERVERS}
pm.max_requests=${PHP_FPM_MAX_REQUESTS}
request_terminate_timeout=${PHP_FPM_REQUEST_TERMINATE_TIMEOUT}
request_slowlog_timeout=${PHP_FPM_REQUEST_SLOWLOG_TIMEOUT}
slowlog=/proc/self/fd/2
clear_env=no
catch_workers_output=yes
EOF

exec docker-php-entrypoint "$@"
