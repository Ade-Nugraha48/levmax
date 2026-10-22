# DOKUMENTASI HIVE LOCAL STORAGE (ARSITEKTUR BARU)
## LEVMAX: Solo Leveling Lifestyle RPG Mobile Application

---

## 1. Definisi 4 Box Utama (Lapisan 2 Cache & Sesi Lokal)

Arsitektur penyimpanan lokal Hive dioptimalkan murni untuk **caching**, **performa I/O ultra cepat (< 10 ms)**, dan **efisiensi panggilan REST API Supabase**. Seluruh sesi `SharedPreferences` lama telah dimigrasikan ke Hive.

```dart
class HiveBoxes {
  // ============================================================================
  // 1. EMPAT BOX INTI ARSITEKTUR BARU
  // ============================================================================
  static const String authBox = 'auth_box';           // Sesi, Token, UUID & Kredensial Biometrik
  static const String questCacheBox = 'quest_cache_box'; // Cache JSON Quests Hari Ini & Last Sync Date
  static const String alarmBox = 'alarm_box';         // Entitas Alarm Harian (TypeAdapter manual)
  static const String aiChatBox = 'ai_chat_box';       // Riwayat Chat AI System (Gemini Pro)

  // ============================================================================
  // 2. BOX PENDUKUNG (KOMPATIBILITAS MUNDUR)
  // ============================================================================
  static const String questBox = questCacheBox;
  static const String blockchainBox = 'blockchain_box';
  static const String playerBox = 'player_cache_box';
  static const String feedbackBox = 'feedback_box';
}
```

---

## 2. Struktur Key-Value & Tipe Data per Box

### 2.1 `authBox` (Sesi & Kredensial Pengguna)
Menggantikan `SharedPreferences` lama secara menyeluruh.

| Key | Tipe Data | Deskripsi | Contoh Nilai |
|:---|:---|:---|:---|
| `access_token` | `String` | Token kriptografis sesi login aktif | `"a9f1c4e7...levmax_auth_token"` |
| `user_id` | `String` | UUID String pengguna di tabel `users` | `"f47ac10b-58cc-4372-a567-0e02b2c3d479"` |
| `username` | `String` | Username Hunter | `"SungJinWoo"` |
| `email` | `String` | Email terdaftar | `"jinwoo@hunter.net"` |
| `is_logged_in` | `bool` | Status autentikasi aktif | `true` |
| `is_onboarded` | `bool` | Status penyelesaian kalibrasi awal | `true` |
| `is_biometric_enabled` | `bool` | Status aktivasi umum biometrik | `true` |
| `biometric_credential` | `String` | Token pengenal biometrik perangkat | `"bio_cred_device_uuid_9981"` |
| `face_id_enabled` | `bool` | Status aktivasi Face ID Kamera | `true` |
| `fingerprint_enabled` | `bool` | Status aktivasi Sensor Sidik Jari | `true` |
| `last_active` | `String` | ISO-8601 Timestamp terakhir aktif | `"2026-10-22T21:30:00Z"` |

---

### 2.2 `questCacheBox` (Cache Offline Quests)
Menyimpan snapshot JSON quest hasil JOIN Supabase untuk mengurangi request berulang.

| Key | Tipe Data | Deskripsi | Format / Contoh |
|:---|:---|:---|:---|
| `last_sync_date` | `String` | Tanggal sinkronisasi terakhir (YYYY-MM-DD) | `"2026-10-22"` |
| `today_quests` | `String` | JSON Array dari `DailyUserQuestModel` yang di-JOIN dengan `MasterQuestModel` | `"[{\"id\":\"uuid-1\",\"title\":\"Push-up\",\"status\":\"pending\"...}]"` |

---

### 2.3 `alarmBox` (Pengingat & Alarm Hunter)
Menyimpan daftar entitas `AlarmModel` menggunakan TypeAdapter manual (`typeId: 3`).

| Properti | Tipe Data | Field Index | Keterangan |
|:---|:---|:---:|:---|
| `id` | `int` | `@HiveField(0)` | ID unik alarm lokal (untuk notifikasi) |
| `time` | `String` | `@HiveField(1)` | Format jam 24h `"HH:mm"` (misal: `"06:30"`) |
| `label` | `String` | `@HiveField(2)` | Deskripsi/Label pengingat quest |
| `isActive` | `bool` | `@HiveField(3)` | Status aktif atau jeda |

---

### 2.4 `aiChatBox` (Riwayat Asisten AI "The System")
Menyimpan histori percakapan interaktif dengan model Gemini Pro.

| Key | Tipe Data | Deskripsi | Format / Contoh |
|:---|:---|:---|:---|
| `history` | `List<Map<String, String>>` | Percakapan multi-turn AI | `[{"role": "user", "text": "Halo System"}, {"role": "model", "text": "Katakan kebutuhanmu, Hunter."}]` |

---

## 3. Inisialisasi & Cara Penggunaan di Flutter

### Inisialisasi di `main.dart`:
```dart
import 'package:hive_flutter/hive_flutter.dart';
import 'helpers/hive_boxes.dart';
import 'models/alarm_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  // Registrasi TypeAdapter Manual (typeId: 3)
  if (!Hive.isAdapterRegistered(3)) {
    Hive.registerAdapter(AlarmModelAdapter());
  }

  // Membuka 4 Box Utama
  await HiveBoxes.openAllBoxes();

  runApp(const LevMaxApp());
}
```

### Akses Cepat via Helper:
```dart
// 1. Simpan Sesi Login di AuthBox
final authBox = HiveBoxes.getAuthBox();
await authBox.put(HiveBoxes.keyAccessToken, 'token_xyz');
await authBox.put(HiveBoxes.keyUserId, 'f47ac10b-58cc-4372-a567-0e02b2c3d479');

// 2. Simpan Cache Quests di QuestCacheBox
final questBox = HiveBoxes.getQuestCacheBox();
await questBox.put(HiveBoxes.keyTodayQuests, jsonEncode(questsJson));
await questBox.put(HiveBoxes.keyLastSyncDate, '2026-10-22');

// 3. Simpan Alarm Baru di AlarmBox
final alarmBox = HiveBoxes.getAlarmBox();
await alarmBox.add(AlarmModel(
  id: 1,
  time: '06:00',
  label: 'Morning Workout Push-up Protocol',
  isActive: true,
));

// 4. Simpan Riwayat Chat AI di AiChatBox
final chatBox = HiveBoxes.getAiChatBox();
final currentHistory = (chatBox.get(HiveBoxes.keyHistory) as List?) ?? [];
currentHistory.add({'role': 'user', 'text': 'Evaluasi kebugaranku hari ini'});
await chatBox.put(HiveBoxes.keyHistory, currentHistory);
```