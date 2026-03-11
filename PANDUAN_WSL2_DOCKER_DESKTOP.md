# Panduan WSL2 (Ubuntu) + Docker Desktop

Panduan ini khusus untuk menjalankan proyek ini di Windows menggunakan:

- WSL2 (Ubuntu)
- Docker Desktop (Linux containers)

Tujuan utama:

- instalasi stabil
- performa file I/O lebih baik
- menghindari problem umum path/permission/line ending

## 1. Prasyarat di Windows

1. Install Docker Desktop terbaru.
2. Aktifkan mode Linux containers.
3. Install WSL2 dan distro Ubuntu.
4. Di Docker Desktop:
   - Settings -> General: centang `Use the WSL 2 based engine`
   - Settings -> Resources -> WSL Integration: aktifkan distro Ubuntu Anda.

Verifikasi di Ubuntu (WSL):

```bash
docker version
docker compose version
```

Jika dua perintah di atas sukses, integrasi sudah benar.

## 2. Lokasi Repo yang Direkomendasikan

Gunakan filesystem Linux WSL (`/home/...`), jangan jalankan dari mount Windows (`/mnt/c/...`) untuk workload Docker yang berat.

Contoh:

```bash
mkdir -p ~/projects
cd ~/projects
git clone https://github.com/skenda2/moodleskenda.git
cd moodleskenda
```

## 3. Atur Line Ending agar Script Bash Aman

Set git agar file shell tidak jadi CRLF:

```bash
git config core.autocrlf input
```

Jika sudah terlanjur CRLF dan script gagal, konversi:

```bash
sudo apt-get update && sudo apt-get install -y dos2unix
find scripts -type f -name "*.sh" -print0 | xargs -0 dos2unix
```

## 4. Setup Proyek

```bash
cp .env.example .env
```

Edit `.env` minimal:

- `MOODLE_PORT=8080`
- `MOODLE_URL=http://localhost:8080`
- `MOODLE_REVERSEPROXY=true`
- `MOODLE_SSLPROXY=false`
- ganti password placeholder (`DB_ROOT_PASSWORD`, `DB_PASSWORD`, `MOODLE_ADMIN_PASS`)

Lanjut install:

```bash
chmod +x scripts/*.sh
./scripts/bootstrap_moodle.sh moodle MOODLE_501_STABLE
mkdir -p moodledata
docker compose up -d --build
./scripts/install_moodle_cli.sh
```

Verifikasi:

```bash
docker compose ps
curl -I -sS http://localhost:8080/login/index.php
```

## 5. Akses dari Browser Windows

Karena Docker publish ke host Windows, biasanya Anda bisa langsung buka:

```text
http://localhost:8080
```

Jika mau akses dari device lain di LAN, gunakan IP Windows host dan buka firewall port 8080.

## 6. Troubleshooting Khas WSL2

### A. Docker command tidak dikenali di WSL

- Pastikan Docker Desktop berjalan.
- Pastikan WSL Integration untuk distro Ubuntu aktif.

### B. Build lambat sekali

- Pastikan repo ada di `/home/<user>/...`, bukan `/mnt/c/...`.

### C. Script `.sh` error aneh (`^M`, bad interpreter)

- Problem line ending CRLF.
- Jalankan `dos2unix` seperti di bagian line ending.

### D. Container `web` unhealthy

Jalankan:

```bash
docker compose logs --tail=120 web php
curl -I -sS http://localhost:8080/login/index.php
```

Jika login page `200 OK`, umumnya service sudah hidup.

### E. Browser timeout dari device lain

- Dari host sendiri tes:

```bash
curl -I -sS http://127.0.0.1:8080/login/index.php
```

- Jika host OK tapi device lain timeout, problem di firewall/routing Windows.

## 7. Menjalankan Load Test di WSL2

Setelah instalasi stabil:

```bash
./scripts/provision_loadtest_users.sh 20
./scripts/run_k6_phase.sh smoke 30s
```

Fase bertahap:

```bash
./scripts/run_k6_phase.sh 300 10m
./scripts/run_k6_phase.sh 700 10m
./scripts/run_k6_phase.sh 1200 10m
```

Monitoring paralel:

```bash
INTERVAL=15 DURATION=1800 ./scripts/monitor_loadtest.sh phase-300
```

## 8. Rekomendasi Resource Docker Desktop

Untuk uji awal:

- CPU: minimal 4 vCPU
- RAM: minimal 8 GB (lebih baik 12-16 GB untuk fase tinggi)
- Disk image Docker: cukup longgar

Semakin kecil resource Docker Desktop, semakin cepat jenuh pada fase 700/1200.
