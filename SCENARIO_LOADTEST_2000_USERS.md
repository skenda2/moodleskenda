# Skenario Load Test Moodle untuk Target 2000 Pengguna

Dokumen ini menyusun skenario uji beban untuk memvalidasi apakah stack saat ini mampu melayani 2000 pengguna aktif.

## 1) Tujuan Uji

- Memvalidasi kestabilan layanan pada 2000 pengguna aktif.
- Mengukur batas bottleneck utama: PHP-FPM, MariaDB, Redis, dan Nginx.
- Menentukan angka aman operasional (kapasitas harian + headroom).

## 2) Definisi Sukses (Acceptance Criteria)

Skenario dianggap lulus jika semua kriteria berikut terpenuhi pada fase 2000 user:

- Error rate total request < 1%.
- p95 response time:
  - Halaman login/dashboard <= 2500 ms.
  - Halaman course/listing <= 3000 ms.
- Tidak ada restart container karena OOM.
- CPU host rata-rata <= 85% selama steady state 30 menit.
- RAM host tidak swap-thrashing (swap in/out tidak agresif).
- DB tidak mengalami lonjakan lock/wait berkepanjangan.

## 3) Prasyarat Data Uji

- Minimal 2000 akun user uji.
- Minimal 20 course aktif.
- Setiap course punya konten realistis (resource/file/quiz/forum) agar query mencerminkan produksi.
- Gunakan media file secukupnya agar beban static dan dynamic seimbang.
- Pastikan cron Moodle berjalan normal sebelum test dimulai.

## 4) Profil Trafik yang Diuji

Komposisi traffic yang disarankan:

- 50%: buka dashboard dan navigasi course.
- 20%: buka aktivitas (assignment/quiz/forum) mode read.
- 15%: login/logout cycle.
- 10%: request static assets (css/js/image/theme).
- 5%: aksi write ringan (post forum singkat atau update preferensi) jika environment test mengizinkan.

Catatan:

- Untuk fase awal, boleh fokus read-heavy dulu.
- Fase lanjutan wajib menambahkan write traffic agar lebih realistis.

## 5) Tahapan Uji Beban

Lakukan bertahap, jangan langsung 2000.

1. Warm-up
- 100 user aktif, 10 menit.
- Tujuan: validasi script dan monitoring.

2. Baseline
- 300 user aktif, 20 menit.
- Tujuan: dapat metrik acuan p95, CPU, RAM.

3. Step-up 1
- 700 user aktif, 30 menit.

4. Step-up 2
- 1200 user aktif, 30 menit.

5. Step-up 3
- 1600 user aktif, 30 menit.

6. Target steady-state
- 2000 user aktif, 60 menit.
- Ini fase utama kelulusan.

7. Spike test (opsional tapi disarankan)
- Naik cepat ke 2400 user selama 10 menit, lalu turun ke 2000.
- Tujuan: cek ketahanan saat lonjakan mendadak.

## 6) Metrik yang Wajib Dicatat

Aplikasi:

- Request per second (RPS).
- Error rate per endpoint.
- p50, p90, p95, p99 response time.
- Throughput endpoint kritikal: login, dashboard, course view.

Infrastruktur:

- CPU, RAM, load average host.
- docker stats untuk web, php, db, redis.
- I/O disk (terutama database volume).
- Network throughput.

Database:

- Jumlah koneksi aktif.
- Slow query count.
- Lock wait / deadlock.

## 7) Perintah Monitoring yang Disarankan

Jalankan terpisah selama test:

```bash
docker compose ps
watch -n 2 'docker stats --no-stream moodle_web moodle_php moodle_db moodle_redis'
docker compose logs -f --tail=200 web
docker compose logs -f --tail=200 php
docker compose logs -f --tail=200 db
docker compose logs -f --tail=200 redis
```

Untuk cek DB cepat:

```bash
docker compose exec -T db mariadb -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "SHOW FULL PROCESSLIST;"
```

Untuk snapshot monitoring otomatis selama test:

```bash
INTERVAL=15 DURATION=1800 ./scripts/monitor_loadtest.sh baseline-300
```

Untuk persiapan per fase secara konsisten:

```bash
./scripts/prepare_loadtest_phase.sh 300
./scripts/prepare_loadtest_phase.sh 700
./scripts/prepare_loadtest_phase.sh 1200
```

## 8) Template Eksekusi Uji (Checklist)

Sebelum test:

- Pastikan branch dan konfigurasi final sudah terdeploy.
- Jalankan:

```bash
docker compose down
docker compose up -d --build
./scripts/install_moodle_cli.sh
```

- Purge cache Moodle:

```bash
docker compose exec -T php php /var/www/html/admin/cli/purge_caches.php
```

Saat test:

- Jalankan fase sesuai urutan.
- Catat metrik tiap 5 menit.
- Simpan timestamp saat error rate naik atau p95 melonjak.

Setelah test:

- Ambil ringkasan hasil per fase.
- Tandai endpoint terburuk.
- Bandingkan dengan acceptance criteria.

## 9) Tindakan Jika Belum Lulus 2000 User

Prioritas tuning berikutnya:

1. PHP-FPM pool tuning:
- Sesuaikan pm.max_children dengan RAM aktual host.
- Pantau apakah worker sering habis.

Gunakan profil siap pakai untuk iterasi awal:

```bash
./scripts/apply_loadtest_profile.sh 300
./scripts/apply_loadtest_profile.sh 700
./scripts/apply_loadtest_profile.sh 1200
```

2. MariaDB tuning:
- Naikkan innodb_buffer_pool_size jika RAM cukup.
- Audit slow query, tambahkan index jika perlu.

3. Moodle application tuning:
- Aktifkan dan validasi cron stabil.
- Review plugin berat yang menambah query/page load.

4. Infrastruktur:
- Pisahkan DB ke node/VM terdedikasi jika bottleneck utama di database.
- Gunakan Redis persistence sesuai kebutuhan.

## 10) Output Akhir yang Harus Dihasilkan Tim

- Tabel hasil per fase (user, RPS, p95, error rate, CPU, RAM).
- Keputusan: Lulus atau Tidak Lulus target 2000 user.
- Daftar bottleneck utama (urut prioritas dampak).
- Rencana tuning iterasi berikutnya dengan owner dan estimasi waktu.
