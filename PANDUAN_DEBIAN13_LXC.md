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
