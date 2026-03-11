# Review Readiness Load Test 2000 User

## Ringkasan

Kesimpulan saat ini: stack lokal ini belum siap untuk target 2000 pengguna aktif pada host yang sekarang.

Profil host saat review ini dibuat:

- CPU: 2 vCPU
- RAM: 7.8 GiB
- Disk tersedia: sekitar 18 GiB
- Topologi: single-node Docker Compose (nginx + php-fpm + mariadb + redis)

Dengan profil tersebut, bottleneck utama hampir pasti ada di CPU PHP-FPM dan kontensi database sebelum mencapai 2000 user aktif stabil.

## Temuan Utama

1. Target 2000 active users di single-node 2 vCPU tidak realistis untuk Moodle dengan pola trafik campuran login, dashboard, course view, dan write ringan.
2. Konfigurasi awal PHP-FPM terlalu agresif untuk host kecil jika dibiarkan tinggi, karena bisa memicu context switching dan tekanan RAM tanpa menaikkan throughput nyata.
3. MariaDB saat ini sudah lebih aman untuk container, tetapi masih berbagi resource dengan PHP dan Nginx pada host yang sama.
4. Redis sudah cukup sehat untuk session backend, tetapi bukan bottleneck utama pada profil host ini.

## Perubahan yang Sudah Diterapkan

- Web health endpoint end-to-end ringan tersedia di `/healthz.php`.
- Healthcheck container `web` sekarang mengecek endpoint aplikasi, bukan hanya halaman biasa.
- PHP-FPM sekarang bisa dituning lewat environment variables di `.env`.
- Default PHP-FPM diubah ke baseline yang lebih aman untuk host kecil:
  - `PHP_FPM_MAX_CHILDREN=24`
  - `PHP_FPM_START_SERVERS=4`
  - `PHP_FPM_MIN_SPARE_SERVERS=4`
  - `PHP_FPM_MAX_SPARE_SERVERS=12`
  - `PHP_FPM_MAX_REQUESTS=700`

## Estimasi Risiko terhadap Target 2000 User

Risiko tertinggi:

1. Saturasi CPU pada PHP-FPM.
2. Peningkatan latency login/dashboard saat worker pool penuh.
3. Lock/wait di MariaDB saat beban write ringan ikut masuk.
4. Error rate meningkat sebelum steady-state 2000 user tercapai.

## Rekomendasi Operasional

Untuk host saat ini:

- Anggap target realistis awal ada di kisaran 300 sampai 700 user aktif, tergantung komposisi trafik.
- Jalankan fase bertahap sesuai `SCENARIO_LOADTEST_2000_USERS.md`, jangan lompat ke 2000 user.
- Monitor `docker stats`, slow query log, dan p95 per endpoint kritikal.

Untuk benar-benar mengejar target 2000 user:

1. Pisahkan MariaDB dari node aplikasi.
2. Naikkan kapasitas aplikasi minimal ke 4 sampai 8 vCPU dengan RAM 12 sampai 16 GiB.
3. Pertimbangkan memisahkan Redis dari node aplikasi jika session/cache sudah berat.
4. Tuning ulang PHP-FPM berdasarkan hasil baseline 300, 700, dan 1200 user.
5. Audit slow query dan plugin berat sebelum menyimpulkan perlu scaling lebih lanjut.

## Parameter yang Layak Disesuaikan Saat Iterasi Load Test

- `PHP_FPM_MAX_CHILDREN`
- `PHP_FPM_MAX_REQUESTS`
- `innodb_buffer_pool_size`
- `max_connections`
- mode persistence Redis sesuai kebutuhan uji

## Verdict Saat Ini

- Readiness endpoint: siap
- Container health visibility: siap
- Hardening dasar container: siap
- Single-node 2000 active users: belum siap
