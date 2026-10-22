// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/helpers/hive_boxes.dart
// Deskripsi: Arsitektur Hive NoSQL Baru (Lapisan 2 Cache & Sesi Lokal)
//            4 Box Inti: authBox, questCacheBox, alarmBox, aiChatBox
// ==============================================================================

import 'package:hive/hive.dart';
import '../models/quest_model.dart';
import '../models/block_model.dart';
import '../models/feedback_model.dart';

class HiveBoxes {
  // ============================================================================
  // 1. EMPAT KONSTANTA NAMA BOX INTI (ARSITEKTUR BARU)
  // ============================================================================

  /// Menyimpan status autentikasi, token sesi, UUID pengguna, dan kredensial biometrik
  static const String authBox = 'auth_box';

  /// Menyimpan cache JSON kuota quest hari ini dan stempel tanggal sinkronisasi terakhir
  static const String questCacheBox = 'quest_cache_box';

  /// Menyimpan entitas Alarm dan pengingat harian Hunter (TypeAdapter AlarmModel)
  static const String alarmBox = 'alarm_box';

  /// Menyimpan riwayat percakapan interaktif dengan AI System (Gemini Pro)
  static const String aiChatBox = 'ai_chat_box';

  // ============================================================================
  // 2. NAMA BOX LEGACY / PENDUKUNG (UNTUK KOMPATIBILITAS MUNDUR)
  // ============================================================================
  static const String questBox = 'quest_box';
  static const String blockchainBox = 'blockchain_box';
  static const String playerBox = 'player_cache_box';
  static const String feedbackBox = 'feedback_box';

  // ============================================================================
  // 3. DAFTAR KUNCI STANDAR PENYIMPANAN KEY-VALUE HIVE
  // ============================================================================

  // AuthBox Keys
  static const String keyAccessToken = 'access_token';
  static const String keyUserId = 'user_id';
  static const String keyIsBiometricEnabled = 'is_biometric_enabled';
  static const String keyBiometricCredential = 'biometric_credential';
  static const String keyUsername = 'username';
  static const String keyEmail = 'email';
  static const String keyIsLoggedIn = 'is_logged_in';
  static const String keyIsOnboarded = 'is_onboarded';
  static const String keyLastActive = 'last_active';
  static const String keyFaceIdEnabled = 'face_id_enabled';
  static const String keyFingerprintEnabled = 'fingerprint_enabled';

  // QuestCacheBox Keys
  static const String keyLastSyncDate = 'last_sync_date';
  static const String keyTodayQuests = 'today_quests';

  // AiChatBox Keys
  static const String keyHistory = 'history';

  // ============================================================================
  // 4. METODE INISIALISASI & MEMBUKA SELURUH BOX HIVE
  // ============================================================================

  /// Membuka seluruh box dan mendaftarkan Adapter yang diperlukan
  static Future<void> openAllBoxes() async {
    // Buka 4 Box Utama Arsitektur Baru
    if (!Hive.isBoxOpen(authBox)) await Hive.openBox(authBox);
    if (!Hive.isBoxOpen(questCacheBox)) await Hive.openBox(questCacheBox);
    if (!Hive.isBoxOpen(alarmBox)) await Hive.openBox<AlarmModel>(alarmBox);
    if (!Hive.isBoxOpen(aiChatBox)) await Hive.openBox(aiChatBox);

    // Buka Box Pendukung untuk menjamin backward compatibility
    if (!Hive.isBoxOpen(questBox)) await Hive.openBox<QuestModel>(questBox);
    if (!Hive.isBoxOpen(blockchainBox)) await Hive.openBox<BlockModel>(blockchainBox);
    if (!Hive.isBoxOpen(feedbackBox)) await Hive.openBox<FeedbackModel>(feedbackBox);
    if (!Hive.isBoxOpen(playerBox)) await Hive.openBox(playerBox);
  }

  /// Helper untuk mengambil AuthBox
  static Box getAuthBox() => Hive.box(authBox);

  /// Helper untuk mengambil QuestCacheBox
  static Box getQuestCacheBox() => Hive.box(questCacheBox);

  /// Helper untuk mengambil AlarmBox
  static Box<AlarmModel> getAlarmBox() => Hive.box<AlarmModel>(alarmBox);

  /// Helper untuk mengambil AiChatBox
  static Box getAiChatBox() => Hive.box(aiChatBox);
}
