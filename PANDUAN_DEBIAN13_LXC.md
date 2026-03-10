# Panduan Lengkap Menjalankan Repo Ini di Debian 13 LXC

Panduan ini ditujukan untuk menjalankan Moodle berbasis Docker Compose dari repo ini di container Debian 13 (LXC).

## 1) Prasyarat LXC (host Proxmox/LXC)

Jika LXC berjalan di Proxmox, aktifkan fitur agar Docker bisa jalan stabil:

- `nesting=1`
- `keyctl=1`

Contoh (di host):

```bash
pct set <CTID> -features nesting=1,keyctl=1
```

Lalu restart container:

```bash
pct restart <CTID>
```

Catatan:

- Untuk penggunaan termudah, banyak admin memakai LXC `privileged` saat menjalankan Docker.
- Untuk LXC `unprivileged`, Docker tetap bisa jalan, tapi troubleshooting permission/cgroup biasanya lebih sering diperlukan.

## 2) Update sistem Debian 13

Masuk ke LXC, lalu jalankan:

```bash
apt update && apt upgrade -y
apt install -y ca-certificates curl gnupg lsb-release git nano
```

## 3) Instal Docker Engine + Compose Plugin

Tambahkan repo resmi Docker:

```bash
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo \
	"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
	$(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
	| tee /etc/apt/sources.list.d/docker.list > /dev/null

apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

Verifikasi:

```bash
docker --version
docker compose version
```

Opsional (agar user non-root bisa pakai docker):

```bash
usermod -aG docker $USER
newgrp docker
```

## 4) Clone repo

```bash
cd /opt
git clone https://github.com/skenda2/moodleskenda.git
cd moodleskenda
```

## 5) Siapkan environment

```bash
cp .env.example .env
nano .env
```

Catatan penting:

- File `.env` diparsing oleh script Bash (`source .env`), jadi nilai yang berisi spasi harus pakai kutip.
- Contoh benar: `MOODLE_FULLNAME="Moodle Skenda"` dan `MOODLE_SHORTNAME="Skenda LMS"`.

Minimal variabel yang wajib dicek:

- `MOODLE_PORT` (contoh `8080`)
- `MOODLE_URL` (contoh `http://IP_LXC:8080`)
- `DB_ROOT_PASSWORD`
- `DB_NAME`
- `DB_USER`
- `DB_PASSWORD`
- `MOODLE_ADMIN_USER`
- `MOODLE_ADMIN_PASS`
- `MOODLE_ADMIN_EMAIL`
- `REDIS_HOST` (default `redis`)
- `REDIS_PORT` (default `6379`)
- `REDIS_PREFIX` (contoh `moodle_`)

Contoh nilai aman untuk awal (sesuaikan ulang sebelum produksi):

```dotenv
MOODLE_URL=http://IP_LXC:8080
MOODLE_ADMIN_PASS=GantiPasswordKuat123!
DB_ROOT_PASSWORD=ganti_root_password_kuat
DB_PASSWORD=ganti_db_password_kuat
```

Penting:

- Jika akses dari perangkat lain, jangan pakai `localhost` pada `MOODLE_URL`.
- Gunakan IP LXC atau domain yang bisa diakses klien.

## 6) Ambil/Update core Moodle branch stabil

Script ini akan clone jika belum ada, atau pull update jika sudah ada:

```bash
chmod +x scripts/bootstrap_moodle.sh
./scripts/bootstrap_moodle.sh moodle MOODLE_501_STABLE
```

## 7) Jalankan instalasi otomatis Moodle (direkomendasikan)

Script ini akan:

- menyalakan semua service Docker
- install Moodle via CLI
- skip instalasi jika `config.php` sudah ada (idempotent)

Jalankan:

```bash
chmod +x scripts/install_moodle_cli.sh
./scripts/install_moodle_cli.sh
```

Jika sukses, Moodle bisa diakses di URL sesuai `MOODLE_URL`.

## 8) Cek status service

```bash
docker compose ps
docker compose logs -f --tail=100
```

Service utama:

- `db` (MariaDB)
- `redis` (session/cache backend)
- `php` (PHP-FPM 8.2)
- `web` (Nginx)

## 9) Login pertama

Gunakan kredensial admin dari `.env`:

- `MOODLE_ADMIN_USER`
- `MOODLE_ADMIN_PASS`

## 10) Opsional: pasang tema Boost Union

```bash
chmod +x scripts/install_theme_boost_union.sh
./scripts/install_theme_boost_union.sh
```

Script akan clone/update plugin tema, upgrade Moodle, set tema default, lalu purge cache.

## 11) Operasional harian

Start:

```bash
docker compose up -d
```

Stop:

```bash
docker compose down
```

Rebuild saat ubah Dockerfile/dependency:

```bash
docker compose up -d --build
```

Update core Moodle ke commit terbaru branch stabil:

```bash
./scripts/bootstrap_moodle.sh moodle MOODLE_501_STABLE
docker compose exec -T php php /var/www/html/admin/cli/upgrade.php --non-interactive
```

## 11.1) Tuning baseline untuk trafik lebih tinggi

Repo ini sudah menyiapkan tuning dasar di:

- `docker/php/Dockerfile` (OPcache dan PHP-FPM pool)
- `docker/nginx/default.conf` (FastCGI timeout/buffer + cache static)
- `docker/db/my.cnf` (MariaDB)
- `docker-compose.yml` + `scripts/install_moodle_cli.sh` (Redis session backend)

Terapkan ulang setelah update repo:

```bash
docker compose down
docker compose up -d --build
```

Catatan penting kapasitas:

- Nilai `innodb_buffer_pool_size=1G` di `docker/db/my.cnf` cocok untuk host dengan RAM memadai.
- Jika RAM host/LXC kecil, turunkan dulu ke `512M` untuk menghindari OOM.

## 12) Troubleshooting cepat

Jika web tidak bisa diakses:

```bash
ss -tulpn | grep 8080
docker compose ps
docker compose logs web --tail=100
docker compose logs php --tail=100
docker compose logs db --tail=100
```

Jika gagal konek database:

- Pastikan `DB_NAME`, `DB_USER`, `DB_PASSWORD` di `.env` sama dengan yang dipakai saat install.
- Cek container `db` sudah `healthy`.

Jika URL salah (redirect ke localhost atau domain lama):

1. Perbaiki `MOODLE_URL` di `.env`.
2. Ubah juga nilai `wwwroot` Moodle via CLI:

```bash
docker compose exec -T php php /var/www/html/admin/cli/cfg.php --name=wwwroot --set="http://IP_LXC:8080"
docker compose exec -T php php /var/www/html/admin/cli/purge_caches.php
```

Jika muncul error `Permission denied` saat membaca `config.php`:

```bash
docker compose exec -T php sh -lc 'chmod 0644 /var/www/html/config.php && chmod 0755 /var/www /var/www/html /var/www/html/public'
docker compose restart php web
```

## 13) Backup yang disarankan

Minimal backup 3 komponen:

- folder project repo ini
- folder `moodledata`
- volume database `db_data`

Contoh backup SQL cepat:

```bash
docker compose exec -T db mariadb-dump -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" > backup_moodle.sql
```

Selesai. Dengan alur di atas, setup baru di Debian 13 LXC biasanya bisa online dalam beberapa menit.
