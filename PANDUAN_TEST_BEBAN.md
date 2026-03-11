# Panduan Terpisah Test Beban Moodle

Panduan ini fokus khusus untuk eksekusi test beban (load test) di proyek ini.

Target panduan:

- Menjalankan load test dari mesin Anda sendiri
- Menyiapkan user test dalam jumlah tertentu
- Menjalankan fase bertahap 300 -> 700 -> 1200 user
- Mengambil hasil metrik dan snapshot monitoring

## 1. Prasyarat

Pastikan tersedia:

- Docker + Docker Compose
- Git
- Resource host memadai (minimal 2 vCPU / 8 GB RAM untuk uji awal)

Catatan:

- Untuk target tinggi (mendekati 2000 active users), host 2 vCPU biasanya cepat jenuh.
- Lakukan bertahap, jangan langsung lompat ke fase tinggi.

## 2. Siapkan Project

Jika belum:

```bash
cp .env.example .env
./scripts/bootstrap_moodle.sh moodle MOODLE_501_STABLE
mkdir -p moodledata
docker compose up -d --build
./scripts/install_moodle_cli.sh
```

Cek kesehatan awal:

```bash
docker compose ps
curl -sS http://localhost:8080/healthz.php
```

Jika output health menunjukkan `"ok":true`, stack siap lanjut.

## 3. Hardening Singkat (Disarankan)

Jalankan di host Docker/LXC:

```bash
sudo ./scripts/hardening_host_sysctl.sh
```

Lalu recreate service backend:

```bash
docker compose up -d --force-recreate db redis
```

## 4. Siapkan User Test Sesuai Jumlah

### Opsi A: User tunggal

```bash
./scripts/provision_loadtest_user.sh loadtest1 LoadTest123! loadtest1@example.local
```

### Opsi B: User batch berdasarkan jumlah

Contoh buat 50 user:

```bash
./scripts/provision_loadtest_users.sh 50
```

Format umum:

```bash
./scripts/provision_loadtest_users.sh <count> [prefix] [password_prefix] [email_domain] [start_index]
```

Contoh:

```bash
./scripts/provision_loadtest_users.sh 20 loadtest LoadTest demo.local 1
```

File kredensial otomatis ditulis ke `loadtest/users.csv`.

## 5. Smoke Test Dulu

Jalankan smoke test singkat untuk validasi alur:

```bash
./scripts/run_k6_phase.sh smoke 30s
```

Hasil ringkasan tersimpan di:

- `tmp/loadtest-results/*.json`

Jika smoke test gagal, lihat bagian troubleshooting di bawah.

## 6. Jalankan Fase Bertahap

### Fase 300

```bash
./scripts/run_k6_phase.sh 300 10m
```

### Fase 700

```bash
./scripts/run_k6_phase.sh 700 10m
```

### Fase 1200

```bash
./scripts/run_k6_phase.sh 1200 10m
```

Catatan:

- Script fase akan menyiapkan tuning profile, recreate service, dan menjalankan skenario k6.
- Fase 1200 pada host kecil adalah fase eksplorasi bottleneck, bukan jaminan stabil.

## 7. Jalankan Monitoring Snapshot Paralel

Saat test berjalan, jalankan monitoring di terminal lain:

```bash
INTERVAL=15 DURATION=1800 ./scripts/monitor_loadtest.sh phase-300
```

Ulangi label sesuai fase (`phase-700`, `phase-1200`).

Output monitoring disimpan di:

- `tmp/loadtest-monitor/<timestamp>-<label>/`

Isi snapshot mencakup:

- `docker compose ps`
- `docker stats --no-stream`
- status `healthz.php`
- status koneksi/processlist MariaDB

## 8. Cara Membaca Hasil Cepat

Setelah tiap fase, cek:

1. Error rate dari summary k6
2. p95 response time
3. Status container tetap healthy
4. Tidak ada restart mendadak
5. Health endpoint tetap `ok: true`

Perintah bantu:

```bash
docker compose ps
docker compose logs --tail=100 php db redis web
curl -sS http://localhost:8080/healthz.php
```

## 9. Troubleshooting Cepat

### A. Login gagal di k6

- Pastikan `loadtest/users.csv` ada dan isinya valid
- Pastikan user memang dibuat di Moodle
- Jalankan ulang provisioning user

```bash
./scripts/provision_loadtest_users.sh 10
```

### B. Health endpoint gagal

- Cek DB/Redis container sehat
- Cek kredensial DB di config Moodle
- Cek izin `moodledata`

### C. Container tidak healthy

- Lihat log service terkait

```bash
docker compose logs --tail=200 web
docker compose logs --tail=200 php
docker compose logs --tail=200 db
docker compose logs --tail=200 redis
```

### D. Host mulai berat

Rollback ke profil aman:

```bash
./scripts/prepare_loadtest_phase.sh 300
```

## 10. Urutan Paling Aman untuk Mesin Sendiri

1. `smoke 30s`
2. `300 user 10m`
3. evaluasi metrik
4. `700 user 10m`
5. evaluasi metrik
6. `1200 user 10m` jika fase sebelumnya masih aman

Jangan langsung loncat ke fase tinggi tanpa baseline.

## 11. File Penting Terkait

- `scripts/run_k6_phase.sh`
- `scripts/provision_loadtest_user.sh`
- `scripts/provision_loadtest_users.sh`
- `scripts/monitor_loadtest.sh`
- `scripts/prepare_loadtest_phase.sh`
- `loadtest/k6/moodle_phase.js`
- `loadtest/users.example.csv`
- `LOADTEST_PHASE_RUNBOOK.md`
- `LOADTEST_READINESS_REVIEW.md`
