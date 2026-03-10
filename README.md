# moodleskenda

Setup Moodle sendiri dengan core resmi Moodle 5.1.3+ pada branch `MOODLE_501_STABLE`.

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
