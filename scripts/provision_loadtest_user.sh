#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
USERNAME=${1:-loadtest1}
PASSWORD=${2:-LoadTest123!}
EMAIL=${3:-${USERNAME}@example.local}
USERS_CSV="$ROOT_DIR/loadtest/users.csv"

cd "$ROOT_DIR"

docker compose exec -T \
  -e LOADTEST_USERNAME="$USERNAME" \
  -e LOADTEST_PASSWORD="$PASSWORD" \
  -e LOADTEST_EMAIL="$EMAIL" \
  php php <<'PHP'
<?php
define('CLI_SCRIPT', true);
require '/var/www/html/config.php';
require_once($CFG->dirroot . '/lib/moodlelib.php');
require_once($CFG->dirroot . '/user/lib.php');

global $DB, $CFG;

$username = strtolower(trim((string)getenv('LOADTEST_USERNAME')));
$password = (string)getenv('LOADTEST_PASSWORD');
$email = trim((string)getenv('LOADTEST_EMAIL'));

if ($username === '' || $password === '' || $email === '') {
    fwrite(STDERR, "Missing load test user parameters.\n");
    exit(1);
}

$existing = $DB->get_record('user', [
    'username' => $username,
    'mnethostid' => $CFG->mnet_localhost_id,
    'deleted' => 0,
], '*', IGNORE_MISSING);

if ($existing) {
    update_internal_user_password($existing, $password);
    $existing->firstname = 'Load';
    $existing->lastname = 'Test';
    $existing->email = $email;
    $existing->auth = 'manual';
    $existing->confirmed = 1;
    $existing->suspended = 0;
    $existing->timemodified = time();
    $DB->update_record('user', $existing);
    echo "Updated existing user {$username}\n";
    exit(0);
}

$user = create_user_record($username, $password, 'manual');
$record = new stdClass();
$record->id = $user->id;
$record->firstname = 'Load';
$record->lastname = 'Test';
$record->email = $email;
$record->confirmed = 1;
$record->suspended = 0;
$record->timemodified = time();
$DB->update_record('user', $record);

echo "Created new user {$username}\n";
PHP

printf 'username,password\n%s,%s\n' "$USERNAME" "$PASSWORD" > "$USERS_CSV"
echo "Wrote $USERS_CSV"
