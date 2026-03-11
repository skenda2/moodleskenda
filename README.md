# moodleskenda

Setup Moodle sendiri dengan core resmi Moodle 5.1.3+ pada branch `MOODLE_501_STABLE`.

Panduan khusus test beban tersedia di [PANDUAN_TEST_BEBAN.md](/workspaces/moodleskenda/PANDUAN_TEST_BEBAN.md).

## Prasyarat

- Docker + Docker Compose
- Git

## Struktur yang disiapkan

- `docker-compose.yml` untuk service web, php-fpm, dan database MariaDB
- `docker/php/Dockerfile` berisi ekstensi PHP yang dibutuhkan Moodle
- `docker/nginx/default.conf` konfigurasi web server
- `scripts/bootstrap_moodle.sh` untuk clone/update source Moodle branch stabil
- `scripts/install_moodle_cli.sh` untuk install Moodle otomatis via CLI
- `.env.example` template environment lokal

## Cara pakai

1. Salin environment file:

	```bash
	cp .env.example .env
	```

	Catatan: file `.env` dibaca oleh script Bash, jadi nilai yang mengandung spasi wajib diberi kutip.
	Contoh: `MOODLE_FULLNAME="Moodle Skenda"`.

2. Clone core Moodle branch stabil yang diminta:

	```bash
	chmod +x scripts/bootstrap_moodle.sh
	./scripts/bootstrap_moodle.sh moodle MOODLE_501_STABLE
	```

3. Siapkan folder data Moodle:

	```bash
	mkdir -p moodledata
	```

4. Jalankan container:

	```bash
	docker compose up -d --build
	```

5. Buka installer Moodle sesuai nilai `MOODLE_URL` di `.env`:

	```text
	http://IP_LXC:8080
	```

## Instalasi otomatis via CLI (disarankan)

1. Pastikan `.env` sudah disalin dari `.env.example`, lalu sesuaikan variabel admin/site/database (terutama password dan URL).
2. Jalankan instalasi otomatis:

	```bash
	chmod +x scripts/install_moodle_cli.sh
	./scripts/install_moodle_cli.sh
	```

3. Login menggunakan akun admin dari variabel berikut di `.env`:

- `MOODLE_ADMIN_USER`
- `MOODLE_ADMIN_PASS`
- `MOODLE_ADMIN_EMAIL`

## Pasang tema modern dan responsive (Boost Union)

```bash
chmod +x scripts/install_theme_boost_union.sh
./scripts/install_theme_boost_union.sh
```

Perintah di atas akan:

- memasang plugin `theme_boost_union` dari branch `MOODLE_501_STABLE`
- menjalankan upgrade Moodle CLI
- mengaktifkan Boost Union sebagai tema default
- purge cache agar perubahan langsung aktif

## Parameter database untuk installer

- DB type: `MariaDB`
- Host: `db`
- DB name: nilai `DB_NAME` di `.env`
- DB user: nilai `DB_USER` di `.env`
- DB password: nilai `DB_PASSWORD` di `.env`
- Prefix: `mdl_` (default)

## Variabel penting `.env`

- `MOODLE_URL` URL akses Moodle (gunakan IP/domain yang bisa diakses klien, bukan `localhost` untuk akses lintas perangkat)
- `MOODLE_PORT` port host untuk Nginx
- `MOODLE_FULLNAME` nama situs Moodle
- `MOODLE_SHORTNAME` nama pendek situs
- `MOODLE_LANG` bahasa default
- `MOODLE_ADMIN_USER` user admin awal
- `MOODLE_ADMIN_PASS` password admin awal
- `MOODLE_ADMIN_EMAIL` email admin awal
- `DB_ROOT_PASSWORD` password root MariaDB
- `DB_NAME` nama database Moodle
- `DB_USER` user database Moodle
- `DB_PASSWORD` password user database Moodle
- `REDIS_HOST` host Redis untuk session/cache (default `redis`)
- `REDIS_PORT` port Redis (default `6379`)
- `REDIS_PREFIX` prefix key Redis (default `moodle_`)

## Healthcheck service

- Service `web` dianggap sehat jika halaman login Moodle merespons sukses dari dalam container.
- Service `php` dianggap sehat jika PHP-FPM mendengarkan di port `9000`.
- Status dapat dilihat dengan:

```bash
docker compose ps
```

## Endpoint observability ringan

- Probe yang selalu tersedia lintas instalasi: `http://HOST:PORT/login/index.php`

Contoh cek cepat:

```bash
curl -I -sS http://localhost:8080/login/index.php
```

## Hardening `.env`

- Jangan jalankan `scripts/install_moodle_cli.sh` dengan password placeholder dari `.env.example`.
- Script install sekarang akan berhenti jika nilai berikut masih default/contoh:
	- `DB_ROOT_PASSWORD`
	- `DB_PASSWORD`
	- `MOODLE_ADMIN_PASS`
- Gunakan `MOODLE_REVERSEPROXY=true` bila akses Moodle lewat reverse proxy atau port mapping yang membuat host/port internal berbeda dari URL publik.
- Gunakan `MOODLE_SSLPROXY=true` hanya jika terminasi HTTPS dilakukan di proxy eksternal dan `MOODLE_URL` memakai `https://`.

## Tuning PHP-FPM untuk load test

- Pool PHP-FPM sekarang bisa diatur dari `.env`.
- Default di `.env.example` disetel aman untuk host kecil sekitar `2 vCPU / 8 GB RAM`.
- Variabel yang tersedia:
	- `PHP_FPM_PM`
	- `PHP_FPM_MAX_CHILDREN`
	- `PHP_FPM_START_SERVERS`
	- `PHP_FPM_MIN_SPARE_SERVERS`
	- `PHP_FPM_MAX_SPARE_SERVERS`
	- `PHP_FPM_MAX_REQUESTS`
	- `PHP_FPM_REQUEST_TERMINATE_TIMEOUT`
	- `PHP_FPM_REQUEST_SLOWLOG_TIMEOUT`

Untuk review kesiapan target 2000 user pada host saat ini, lihat `LOADTEST_READINESS_REVIEW.md`.

## Profil load test bertahap

Profil siap pakai tersedia di folder berikut:

- `config/loadtest-profiles/300.env`
- `config/loadtest-profiles/700.env`
- `config/loadtest-profiles/1200.env`

Untuk melihat perubahan tanpa menulis ke `.env`:

```bash
./scripts/apply_loadtest_profile.sh 300 dry-run
```

Untuk menerapkan profil ke `.env`:

```bash
./scripts/apply_loadtest_profile.sh 300
docker compose up -d --build --force-recreate php web
```

Catatan:

- Profil `300` adalah baseline konservatif.
- Profil `700` untuk step-up menengah.
- Profil `1200` adalah profil eksplorasi agresif pada host kecil, bukan jaminan stabil.

## Monitoring snapshot load test

Script monitoring snapshot tersedia di `scripts/monitor_loadtest.sh`.

Contoh menjalankan monitoring 30 menit dengan interval 15 detik:

```bash
chmod +x scripts/monitor_loadtest.sh
INTERVAL=15 DURATION=1800 ./scripts/monitor_loadtest.sh baseline-300
```

Output akan tersimpan di `tmp/loadtest-monitor/` dan berisi snapshot:

- `docker compose ps`
- `docker stats --no-stream`
- response health probe (default `/login/index.php`)
- status koneksi dan processlist MariaDB

## Runbook fase load test

- Untuk eksekusi bertahap `300 -> 700 -> 1200`, gunakan [LOADTEST_PHASE_RUNBOOK.md](/workspaces/moodleskenda/LOADTEST_PHASE_RUNBOOK.md).
- Untuk menyiapkan satu fase secara otomatis:

```bash
chmod +x scripts/prepare_loadtest_phase.sh
./scripts/prepare_loadtest_phase.sh 300
```

## Menjalankan k6 dari repo

- Repo ini sekarang punya workflow `k6` berbasis Docker Compose profile `loadtest`.
- Panduan ringkas ada di [loadtest/README.md](/workspaces/moodleskenda/loadtest/README.md).

Smoke test cepat:

```bash
chmod +x scripts/run_k6_phase.sh
./scripts/run_k6_phase.sh smoke 30s
```

## Redis session backend

- Service Redis sudah aktif di Docker Compose.
- Script `scripts/install_moodle_cli.sh` akan menambahkan konfigurasi session Redis ke `moodle/config.php` secara idempotent.
- Jika Moodle sudah terpasang sebelum fitur ini, jalankan ulang script install agar konfigurasi Redis diinjeksi:

```bash
./scripts/install_moodle_cli.sh
```

## Lokasi penting

- Source Moodle: `./moodle`
- Moodledata: `./moodledata`

## Update core ke commit terbaru branch stabil

```bash
./scripts/bootstrap_moodle.sh moodle MOODLE_501_STABLE
```

## Hentikan service

```bash
docker compose down
```

## Hardening Warning Redis/MariaDB

Jika Anda melihat warning berikut di log:

- Redis: `Memory overcommit must be enabled`
- MariaDB: fallback `io_uring` / warning parameter lama

Lakukan langkah berikut.

1. Terapkan sysctl host (wajib dijalankan di host Docker/LXC):

```bash
chmod +x scripts/hardening_host_sysctl.sh
sudo ./scripts/hardening_host_sysctl.sh
```

2. Restart service agar konfigurasi DB terbaru terpakai:

```bash
docker compose up -d --force-recreate db redis
```

Catatan:

- Warning Redis `vm.overcommit_memory` adalah kernel-level, jadi tidak bisa diselesaikan hanya dari config container aplikasi.
- Tuning MariaDB di `docker/db/my.cnf` sudah disesuaikan untuk lingkungan container agar warning deprecated/`io_uring` berkurang.
