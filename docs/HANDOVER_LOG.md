# LEVMAX - SYSTEM HANDOVER & DEVELOPMENT LOG
**Proyek:** LevMax (Asisten Manajemen Gaya Hidup Cerdas & Gamifikasi Solo Leveling)  
**Pengembang:** Ade Nugraha  
**Peran:** Principal DevOps, Tech Lead & Mobile Architect  
**Tanggal Save Point:** 23 Oktober 2026  
**Status Build:** STABLE & PASSING (`flutter analyze`: 0 Errors, 0 Warnings, 0 Lint Issues)  
**Branch:** `Develop-04`

---

## BAGIAN 1: CHANGELOG HARI INI (TECHNICAL MILESTONES COMPLETED)

Hari ini telah dilakukan perombakan arsitektur, refaktorisasi penuh, dan penyelesaian fitur end-to-end yang mengintegrasikan aspek sensor native, computer vision, ekonomi game, desentralisasi blockchain lokal, serta utilitas pengujian presentasi UAS:

### 1. UX Autentikasi & Biometric Gate (Prompt 8 & Fixes)
- **Navigasi Auth Sempurna:** Alur mulus `SplashScreen -> BiometricGate -> LoginPage -> RegisterPage -> Onboarding -> MainNavigationPage`.
- **Face & Fingerprint Scanning:** Pengecekan sensor biometrik lokal (`local_auth`) dan kamera native (`camera`) untuk validasi biometrik wajah.
- **Auto-Logout Sesi 1 Jam:** Pengecekan session timeout 60 menit di `UserInfo.checkSessionTimeout()` untuk menjaga integritas keamanan akun.
- **Supabase User Sync:** Data registrasi dan login tersimpan sinkron antara Cloud Supabase (`users` table) dan local NoSQL (`player_cache_box`).

### 2. "The Awakening Trial" ML-Kit Camera Onboarding (Prompt 8)
- **Zero Manual Stepper:** Menghapus seluruh input stepper (+/-) manual pada penentuan rank awal.
- **Computer Vision Pose Detection:** Mengintegrasikan `google_mlkit_pose_detection` secara real-time dari stream kamera depan (`nv21`/`bgra8888`).
- **Mathematical Joint Angle Engine:** Perhitungan sudut sendi matematis menggunakan `math.atan2` (shoulder-elbow-wrist, hip-knee-ankle, shoulder-hip-knee) untuk 4 latihan fisik wajib: *Push-up*, *Sit-up*, *Squat*, dan *Pull-up*.
- **State Machine Repetisi:** Validasi inflection point naik/turun dengan ambang batas (lower & upper threshold) 60 FPS menggunakan `ValueNotifier` tanpa lag/drop frame.
- **Dynamic Rank Matrix:** Algoritma penentuan Rank awal (F hingga S) berbasis indeks massa tubuh (BMI) dan repetisi fisik aktual.

### 3. Main Dashboard HUD & Penalty Guard System (Prompt 9 & 14)
- **Solo Leveling Window HUD:** Dashboard RPG bergradasi *Cyan/Mint/Dark Indigo* dengan status bar HP, EXP, Level, dan Rank.
- **Enforced Penalty Guard:** Pemeriksaan mutlak `isPenaltyActive`. Jika pemain mengabaikan quest atau dalam masa penalti, sistem seketika melempar pengguna ke `PenaltyGamePage` (`/penalty`) via `rootNavigator`.
- **Time-Locked Appearance Quest:** Form Skincare harian terkunci secara otomatis jika jam sistem belum mencapai pukul 21:00 Server Time.
- **Multi-Timezone & Server Reset Strip:** Hitung mundur menuju 00:00 WIB (UTC+7) beserta penampil waktu dinamis (WIB, WITA, WIT, LND) secara reactive via `ValueNotifier`.

### 4. Interactive LBS Map & Weekly Mystery Gate (Prompt 10)
- **Real-Time GPS Tracking:** Menggunakan `geolocator` dan `flutter_map` dengan tema CartoDB Dark Matter untuk pelacakan koordinat pemain di dunia nyata.
- **Geofencing Mystery Gate (< 50m):** Logika validasi jarak ketat `Geolocator.distanceBetween` yang hanya membuka gerbang misteri jika pemain berada dalam radius < 50 meter.
- **Dynamic Loot Table:** Probabilitas drop EXP, Gold (50-200), dan Extra Secret Quests tersinkronisasi ke Hive & Supabase.

### 5. Tactical Mini-Game Hub & Gyroscope Core Game (Prompt 11)
- **Sensor Native Integration:** Pemanfaatan `sensors_plus` (`gyroscopeEventStream` & `accelerometerEventStream`) untuk mendeteksi *pitch* dan *roll* perangkat.
- **The Core Stabilization Game:** Mini-game menahan bola energi di tengah reticle target selama 15 detik dengan haptic feedback dinamis.
- **Enforced Daily Cap (1x/Hari):** Mekanisme pembatasan reward harian (+50 Gold) melalui pengecekan `keyDailyRewardDate` di Hive box `playerBox`.

### 6. Monarch's Treasury: Shop, Top-Up, & Blockchain SHA-256 Ledger (Prompt 12)
- **Validasi Saldo Transaksi:** Pembelian consumable (Potion HP, Mana Catalyst) memotong Gold pengguna secara langsung dan terbukti anti-cheat.
- **Blockchain Inventory Ledger:** Setiap minting *Collectible Pride Item* (Demon Monarch's Ring, Orb of Avarice, dll.) menghasilkan blok hash SHA-256 yang merantai `previous_hash`, `user_id`, `item_id`, dan `timestamp`.
- **Dual-Storage Persistency:** Tercatat di database cloud Supabase (`blockchain_inventory_logs`) dan NoSQL offline (`blockchainBox`).

### 7. Hunter Profile, Complete RPG Stats, & Course Evaluation (Prompt 13)
- **System Window Profil:** Menampilkan 4 pilar atribut (STR, AGI, INT, CHA), status Vessel Metrics (TB/BB/BMI), dan status Biometrik.
- **Academic Course Evaluation:** Form Kesan & Saran Mata Kuliah Mobile yang langsung mengirim payload ke Supabase tabel `saran_kesan` serta ter-backup di Hive `feedbackBox`.
- **Danger Zone Logout:** Penghapusan token sesi dan navigasi bersih kembali ke Login Page.

### 8. "Monarch's God Mode" - QA Presentation Override Panel (Prompt 14)
- **Hidden Entry Point:** Akses tersembunyi via **Long Press pada Avatar Profil** dengan haptic feedback berat.
- **Hazard Terminal Interface:** Antarmuka hitam, merah, dan kuning neon beraksen peringatan sistem militer.
- **5 Tombol Override Presentasi UAS:**
  1. `[ INJECT 10,000 GOLD ]`: Suntik instan 10.000 Gold untuk demonstrasi belanja di Blockchain Shop.
  2. `[ TRIGGER PENALTY MODE ]`: Paksa `isPenaltyActive = true` dan luncurkan mini-game hukuman kelabang beracun.
  3. `[ BYPASS TIME: FORCE 21:00 ]`: Toggle instan untuk membuka form Skincare siang hari di hadapan dosen penguji.
  4. `[ RESET DAILY LIMITS ]`: Reset limit harian mini-game dan reset pool status quest hari ini.
  5. `[ FORCE LEVEL UP ]`: Manipulasi EXP penuh dan picu dialog promosi Rank Hunter.
- **Live Console Terminal Stream:** Jendela log real-time di bawah panel yang mencatat setiap eksekusi override.

---

## BAGIAN 2: NEXT ACTION ITEMS (ACADEMIC & NON-CODING TO-DO LIST)

Seluruh logika teknis aplikasi telah tuntas dan lulus uji. Fokus tugas berikutnya (besok) dialihkan sepenuhnya ke persiapan berkas administratif, akademis, dan materi presentasi UAS:

- [ ] **1. Penyusunan Dokumen Laporan Perancangan Sistem (RBPL / Laporan UAS):**
  - Mengompilasi latar belakang masalah, deskripsi produk, dan kebaruan konsep gamifikasi *Solo Leveling Lifestyle*.
  - Menyertakan arsitektur database Supabase (ERD, relasi tabel `users`, `quests`, `blockchain_inventory_logs`, `saran_kesan`).
  - Menjelaskan implementasi modul sensor native (GPS/LBS, Gyroscope/Accelerometer, Camera Pose ML-Kit, Biometrik).
  - Melampirkan dokumentasi arsitektur penyimpanan hibrida (Supabase Cloud + Hive Local Caching).

- [ ] **2. Pembuatan Dokumen Skenario Black-Box Testing:**
  - Menyusun tabel kasus uji (Test Case ID, Deskripsi Pengujian, Langkah-Langkah, Ekspektasi Hasil, dan Hasil Aktual).
  - Mencakup pengujian batas:
    - Autentikasi biometrik & session timeout 60 menit.
    - Akurasi pengenalan pose tubuh ML-Kit tanpa sentuhan layar.
    - Batas geofencing < 50 meter Mystery Gate.
    - Pembelian item tanpa gold yang cukup (Insufficient Gold handling).
    - Mekanisme rujukan penalti otomatis saat quest diabaikan.
    - Pengujian seluruh 5 fungsi bypass pada QA Debug Panel.

- [ ] **3. Penyusunan Pitch Deck Presentasi UAS:**
  - Desain slide bertema modern gelap (*Solo Leveling aesthetic*) dengan tipografi tajam.
  - Alur slide:
    1. *Title & Team Intro* (Ade Nugraha).
    2. *Problem Statement*: Tingginya tingkat *sedentary lifestyle* dan kejenuhan aplikasi *habit-tracker* konvensional.
    3. *The Solution*: LevMax - Asisten cerdas berbasis gamifikasi RPG dengan validasi sensor nyata.
    4. *System Architecture*: Diagram alur Flutter, Hive, Supabase, dan SHA-256 Blockchain.
    5. *Live Demo Walkthrough*: Panduan mendemokan aplikasi menggunakan "Monarch's God Mode".
    6. *Conclusion & Q&A*.

- [ ] **4. Perekaman Video Demo Cadangan (Offline Backup Video):**
  - Merekam layar demonstrasi flow lengkap (Registrasi -> Onboarding Pose -> Daily Quest -> LBS Gate -> Gyroscope Game -> Shop Blockchain -> God Mode Panel) sebagai antisipasi kendala teknis/jaringan saat presentasi di hadapan Dosen Penguji.

---

## RINGKASAN VERIFIKASI AKHIR

| Pengecekan | Status |
|---|---|
| `dart format .` | Selesai (52 file terformat rapi sesuai standar Dart) |
| `flutter analyze` | **No issues found!** (0 error, 0 warning, 0 lint hint) |
| Git Synchronization | **Up-to-date di origin/Develop-04** |

```text
[SYSTEM NOTIFICATION]
All Hunter Protocols compiled, secured, and synchronized with Central Database.
Codebase formatting completed. Handover artifact persisted to docs/HANDOVER_LOG.md.
System entering sleep mode. Good work, Hunter.
```
