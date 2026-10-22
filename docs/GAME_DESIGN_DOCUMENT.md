# Buku Aturan & Mekanik Aplikasi (Game Design Document)
Dokumen ini berisi rangkuman aturan main, sistem progression, dan mekanik aplikasi gamifikasi produktivitas/kebugaran berbasis RPG.

## 1. Sistem Onboarding & Kalibrasi Awal
### A. Registrasi & Login
- **Keamanan:** Mendukung login standar serta biometrik (Face ID & Fingerprint) untuk kesan premium dan aman.
### B. Initial Assessment (Penentuan Rank Awal)
- **Input Data:** Pengguna baru diwajibkan memasukkan Tinggi Badan (TB) dan Berat Badan (BB) untuk menghitung BMI.
- **Tes Fisik Awal:** Pengguna wajib melakukan tes Push-up, Sit-up, Pull-up, dan Squat. Tidak ada batasan waktu; sistem akan terus mendeteksi postur tubuh hingga pengguna merasa maksimal atau lelah.
- **Validasi:** Menggunakan kamera (AI Pose Detection) agar repetisi terhitung secara nyata (anti-cheat).
- **Hasil:** Berdasarkan metrik BMI yang ideal dan hasil tes fisik, pengguna akan ditempatkan di Rank awal. Pangkat maksimal untuk pengguna baru dengan performa sangat baik adalah **Rank E** (tidak bisa langsung D atau ke atas).

## 2. Sistem Quest (Misi Utama & Sampingan)
Sistem quest dibagi menjadi beberapa kategori dengan syarat penyelesaian harian yang ketat.
### A. Kategori Quest & Validasi
1. **Workout (Fisik Berat):** Push Up, Sit Up, Pull Up, Squat. (Validasi: AI Camera Pose Detection).
2. **Cardio:** Jalan dan Lari. (Validasi: Sensor Accelerometer/Pedometer. Kecepatan > 15 km/jam tidak akan dihitung).
3. **Appearance (Perawatan Diri):** Rutinitas pagi & malam. (Validasi: Checklist Bottom Sheet setelah pukul 21.00 waktu lokal).
4. **Study (Kognitif):** Pembelajaran dan kuis trivia. (Validasi: Sistem skoring kuis menentukan jumlah EXP).
### B. Syarat Wajib (Daily Quota)
Jika syarat ini tidak terpenuhi sebelum *reset* harian (Pukul 00.00), pengguna akan menerima Penalti:
- **Workout:** Minimal 2 jenis per hari.
- **Cardio:** Minimal 1 jenis setiap 3 hari.
- **Appearance:** Wajib diisi setiap hari.
- **Study:** Wajib dikerjakan setiap hari.
### C. Mystery Quest (Misi Kejutan)
- Quest acak dengan hadiah EXP besar. Maksimal diambil 1x sehari, butuh "Item Entry" khusus (jatah maksimal 3x seminggu dari minigames). Hanya dibuka jika Quest Wajib hari itu selesai.

## 3. The Penalty Zone (Sistem Hukuman)
1. **Pencegatan Login:** Saat login keesokan harinya, langsung dilempar ke halaman **Pinalti Quest**. Tidak ada akses menu lain.
2. **Beban Berlipat:** Misi yang ditinggalkan akan **dikali 2 (x2)** repetisinya.
3. **Sistem HP & Game Over:** Jika penalti diabaikan lagi, beban dikali 2 lagi dan HP berkurang. Jika HP habis = **GAME OVER**.
4. **Konsekuensi Game Over:** Rank pengguna di-reset kembali ke titik terendah (Rank F).

## 4. Sistem Peringkat (Rank) & EXP
| Rank Saat Ini | Target Rank | EXP Dibutuhkan | Syarat Tambahan (Contoh) | Base EXP Per Quest |
| :--- | :--- | :--- | :--- | :--- |
| **Rank F** | Rank E | 1.000 | Semua stat min. level 2 | 50 |
| **Rank E** | Rank D | 2.500 | Semua stat min. level 5 | 50 |
| **Rank D** | Rank C | 6.000 | Semua stat min. level 12 | 120 |
| **Rank C** | Rank B | 14.500 | Semua stat min. level 25 | 120 |
| **Rank B** | Rank A | 32.000 | Semua stat min. level 40 | 250 |
| **Rank A** | Rank S | 65.000 | Semua stat min. level 60 | 250 |
| **Rank S** | *Uncapped* | Terus Bertambah | Mode Leaderboard. | 450 |

**Multiplier Kesulitan:**
- WO & Cardio (Fisik): 1.5x
- Study (Kognitif): 1.2x (Turun 0.5x jika banyak salah)
- Appearance: 1.0x
- Mystery Quest: 2.5x

## 5. Scaling Beban Workout (WO) & Cardio Berdasarkan Rank
* **Rank F:** Push Up (10), Sit Up (15), Pull Up (2), Squat (15), Jalan (1 km), Lari (500 meter)
* **Rank E:** Push Up (15), Sit Up (20), Pull Up (5), Squat (25), Jalan (1.5 km), Lari (1 km)
* **Rank D:** Push Up (25), Sit Up (35), Pull Up (8), Squat (40), Jalan (2.5 km), Lari (1.5 km)
* **Rank C:** Push Up (40), Sit Up (50), Pull Up (12), Squat (60), Jalan (3.5 km), Lari (2.5 km)
* **Rank B:** Push Up (60), Sit Up (70), Pull Up (20), Squat (80), Jalan (5 km), Lari (4 km)
* **Rank A:** Push Up (80), Sit Up (90), Pull Up (30), Squat (100), Jalan (7 km), Lari (6 km)
* **Rank S:** Push Up (100), Sit Up (120), Pull Up (40), Squat (150), Jalan (10 km), Lari (8 km)

## 6. Eksplorasi LBS, Minigames, Shop & Blockchain
- **LBS:** 7 titik *Mystery Gift* per minggu.
- **Minigames:** Max 1x kemenangan berhadiah *Gold* per hari.
- **Shop & Blockchain:** Pembelian "Pride Items" dicatat dengan *hash SHA-256* secara lokal.
- **Utilitas:** AI Asisten, Alarm, Konversi Zona Waktu & Mata Uang.
