# Runbook Load Test Bertahap

Runbook ini dipakai untuk menjalankan fase `300 -> 700 -> 1200` user secara konsisten pada stack saat ini.

Catatan:

- Host saat ini hanya `2 vCPU / 7.8 GiB RAM`.
- Fase `1200` diperlakukan sebagai fase eksplorasi bottleneck, bukan target stabil yang diasumsikan lulus.
- Dokumen ini tidak menjalankan generator beban tertentu. Anda tetap perlu tool eksternal seperti k6, JMeter, Locust, atau sejenisnya.

## Prasyarat Sebelum Semua Fase

1. Pastikan stack sehat:

```bash
docker compose ps
curl -I -sS http://localhost:8080/login/index.php
```

2. Pastikan data uji siap sesuai [SCENARIO_LOADTEST_2000_USERS.md](/workspaces/moodleskenda/SCENARIO_LOADTEST_2000_USERS.md).
3. Pastikan `.env` sudah berisi password non-placeholder.

## Fase 300 User

1. Siapkan stack untuk fase 300:

```bash
./scripts/prepare_loadtest_phase.sh 300
```

2. Mulai monitoring snapshot:

```bash
INTERVAL=15 DURATION=1800 ./scripts/monitor_loadtest.sh phase-300
```

3. Jalankan generator beban dengan target `300 active users`.

Pilihan cepat dari repo ini:

```bash
./scripts/run_k6_phase.sh 300 10m
```

4. Setelah fase selesai, cek:

```bash
docker compose ps
curl -I -sS http://localhost:8080/login/index.php
docker compose logs --tail=100 php db redis web
```

5. Evaluasi cepat:

- apakah ada error rate naik
- apakah worker PHP habis
- apakah response time melonjak tajam

## Fase 700 User

1. Naikkan tuning ke profil 700:

```bash
./scripts/prepare_loadtest_phase.sh 700
```

2. Mulai monitoring snapshot:

```bash
INTERVAL=15 DURATION=1800 ./scripts/monitor_loadtest.sh phase-700
```

3. Jalankan generator beban dengan target `700 active users`.

Pilihan cepat dari repo ini:

```bash
./scripts/run_k6_phase.sh 700 10m
```

4. Setelah fase selesai, review snapshot di `tmp/loadtest-monitor/`.

Checkpoint utama fase ini:

- CPU PHP dan DB mulai mendekati jenuh atau belum
- health endpoint tetap `ok: true`
- tidak ada restart container

## Fase 1200 User

1. Naikkan tuning ke profil 1200:

```bash
./scripts/prepare_loadtest_phase.sh 1200
```

2. Mulai monitoring snapshot:

```bash
INTERVAL=15 DURATION=1800 ./scripts/monitor_loadtest.sh phase-1200
```

3. Jalankan generator beban dengan target `1200 active users`.

Pilihan cepat dari repo ini:

```bash
./scripts/run_k6_phase.sh 1200 10m
```

4. Anggap fase ini sebagai pencarian batas host.

Jika salah satu kondisi berikut muncul, hentikan eskalasi:

- error rate naik tajam
- health endpoint gagal
- container restart
- response time tidak lagi usable
- MariaDB menunjukkan wait/lock berkepanjangan

## Checklist Setelah Tiap Fase

1. Simpan folder snapshot monitoring terbaru di `tmp/loadtest-monitor/`.
2. Catat keputusan: lanjut, tuning ulang, atau rollback.
3. Catat profil yang dipakai (`300`, `700`, atau `1200`).
4. Catat anomali log dari `php`, `db`, `redis`, dan `web`.

## Rollback ke Baseline Aman

Jika host mulai tidak stabil, kembali ke baseline konservatif:

```bash
./scripts/prepare_loadtest_phase.sh 300
```

## Artefak yang Dipakai

- Profil tuning: [config/loadtest-profiles/300.env](/workspaces/moodleskenda/config/loadtest-profiles/300.env)
- Profil tuning: [config/loadtest-profiles/700.env](/workspaces/moodleskenda/config/loadtest-profiles/700.env)
- Profil tuning: [config/loadtest-profiles/1200.env](/workspaces/moodleskenda/config/loadtest-profiles/1200.env)
- Monitoring: [scripts/monitor_loadtest.sh](/workspaces/moodleskenda/scripts/monitor_loadtest.sh)
- Persiapan fase: [scripts/prepare_loadtest_phase.sh](/workspaces/moodleskenda/scripts/prepare_loadtest_phase.sh)
- Runner k6: [scripts/run_k6_phase.sh](/workspaces/moodleskenda/scripts/run_k6_phase.sh)
- Skenario k6: [loadtest/k6/moodle_phase.js](/workspaces/moodleskenda/loadtest/k6/moodle_phase.js)
- Review readiness: [LOADTEST_READINESS_REVIEW.md](/workspaces/moodleskenda/LOADTEST_READINESS_REVIEW.md)
