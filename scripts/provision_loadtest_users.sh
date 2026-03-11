#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
COUNT=${1:-10}
PREFIX=${2:-loadtest}
PASSWORD_PREFIX=${3:-LoadTest}
EMAIL_DOMAIN=${4:-example.local}
START_INDEX=${5:-1}
USERS_CSV="$ROOT_DIR/loadtest/users.csv"

if ! [[ "$COUNT" =~ ^[0-9]+$ ]] || [[ "$COUNT" -lt 1 ]]; then
  echo "COUNT harus bilangan bulat >= 1"
  echo "Usage: $0 <count> [prefix] [password_prefix] [email_domain] [start_index]"
  exit 1
fi

if ! [[ "$START_INDEX" =~ ^[0-9]+$ ]] || [[ "$START_INDEX" -lt 1 ]]; then
  echo "START_INDEX harus bilangan bulat >= 1"
  exit 1
fi

cd "$ROOT_DIR"

docker compose exec -T \
  -e LOADTEST_COUNT="$COUNT" \
  -e LOADTEST_PREFIX="$PREFIX" \
  -e LOADTEST_PASSWORD_PREFIX="$PASSWORD_PREFIX" \
  -e LOADTEST_EMAIL_DOMAIN="$EMAIL_DOMAIN" \
  -e LOADTEST_START_INDEX="$START_INDEX" \
  php php <<'PHP'
<?php
define('CLI_SCRIPT', true);
require '/var/www/html/config.php';
require_once($CFG->dirroot . '/lib/moodlelib.php');
require_once($CFG->dirroot . '/user/lib.php');

global $DB, $CFG;

$count = (int)getenv('LOADTEST_COUNT');
$prefix = strtolower(trim((string)getenv('LOADTEST_PREFIX')));
$passwordprefix = trim((string)getenv('LOADTEST_PASSWORD_PREFIX'));
$emaildomain = trim((string)getenv('LOADTEST_EMAIL_DOMAIN'));
$startindex = (int)getenv('LOADTEST_START_INDEX');

if ($count < 1 || $prefix === '' || $passwordprefix === '' || $emaildomain === '' || $startindex < 1) {
    fwrite(STDERR, "Invalid provisioning parameters.\n");
    exit(1);
}

for ($i = $startindex; $i < $startindex + $count; $i++) {
    $index = str_pad((string)$i, 3, '0', STR_PAD_LEFT);
    $username = $prefix . $index;
    $password = $passwordprefix . $index . '!';
    $email = $username . '@' . $emaildomain;

    $existing = $DB->get_record('user', [
        'username' => $username,
        'mnethostid' => $CFG->mnet_localhost_id,
        'deleted' => 0,
    ], '*', IGNORE_MISSING);

    if ($existing) {
        update_internal_user_password($existing, $password);
        $existing->firstname = 'Load';
        $existing->lastname = 'Test ' . $index;
        $existing->email = $email;
        $existing->auth = 'manual';
        $existing->confirmed = 1;
        $existing->suspended = 0;
        $existing->timemodified = time();
        $DB->update_record('user', $existing);
        echo "Updated {$username}\n";
        continue;
    }

    $user = create_user_record($username, $password, 'manual');
    $record = new stdClass();
    $record->id = $user->id;
    $record->firstname = 'Load';
    $record->lastname = 'Test ' . $index;
    $record->email = $email;
    $record->confirmed = 1;
    $record->suspended = 0;
    $record->timemodified = time();
    $DB->update_record('user', $record);
    echo "Created {$username}\n";
}
PHP

{
  echo "username,password"
  for ((i=START_INDEX; i<START_INDEX+COUNT; i++)); do
    index=$(printf '%03d' "$i")
    username="${PREFIX}${index}"
    password="${PASSWORD_PREFIX}${index}!"
    echo "${username},${password}"
  done
} > "$USERS_CSV"

echo "Wrote $USERS_CSV with $COUNT users"
