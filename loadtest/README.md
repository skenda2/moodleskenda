# Load Test Quick Start

Folder ini berisi artefak load test awal berbasis `k6` yang dijalankan lewat Docker Compose profile `loadtest`.

## File penting

- `k6/moodle_phase.js`: skenario login, dashboard, course listing, dan health endpoint
- `users.example.csv`: contoh format user untuk multi-user load test

## Menyiapkan user test

1. Salin file contoh:

```bash
cp loadtest/users.example.csv loadtest/users.csv
```

2. Isi username dan password user Moodle yang valid.

Jika `loadtest/users.csv` tidak ada, wrapper script akan fallback ke `MOODLE_ADMIN_USER` dan `MOODLE_ADMIN_PASS` dari `.env`.

Alternatif cepat untuk membuat user test lokal:

```bash
chmod +x scripts/provision_loadtest_user.sh
./scripts/provision_loadtest_user.sh loadtest1 LoadTest123! loadtest1@example.local
```

Script ini akan:

- membuat atau update user Moodle `loadtest1`
- set password yang diberikan
- menulis `loadtest/users.csv` lokal untuk dipakai runner `k6`

Alternatif batch berdasarkan jumlah user:

```bash
chmod +x scripts/provision_loadtest_users.sh
./scripts/provision_loadtest_users.sh 50
```

Format parameter:

```bash
./scripts/provision_loadtest_users.sh <count> [prefix] [password_prefix] [email_domain] [start_index]
```

Contoh:

```bash
./scripts/provision_loadtest_users.sh 20 loadtest LoadTest demo.local 1
```

Perintah di atas akan membuat user:

- `loadtest001` sampai `loadtest020`
- password mengikuti pola `LoadTest001!` sampai `LoadTest020!`

## Smoke test cepat

```bash
./scripts/run_k6_phase.sh smoke 30s
```

## Menjalankan fase bertahap

```bash
./scripts/run_k6_phase.sh 300 10m
./scripts/run_k6_phase.sh 700 10m
./scripts/run_k6_phase.sh 1200 10m
```

Output ringkasan akan ditulis ke `tmp/loadtest-results/`.
