// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/services/supabase_api_service.dart
// Deskripsi: Lapisan 3 Arsitektur DB - Komunikasi JSON REST API ke 5 Tabel Supabase
//            menggunakan package:http dengan mekanisme Offline-First Fallback ke Hive.
// ==============================================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../helpers/boxes.dart';
import '../models/user_model.dart';
import '../models/quest_model.dart';
import '../models/block_model.dart';
import '../models/feedback_model.dart';

class SupabaseApiService {
  // URL dan Publishable Anon Key project Supabase
  static String supabaseUrl = 'https://eoujrrvbrqotbnhsgjni.supabase.co';
  static String supabaseAnonKey = 'sb_publishable_BCwFIi7ZpuBONB-rLMg4Jw_sB0NFxCb';

  /// Instance SupabaseClient resmi dari package supabase_flutter
  static SupabaseClient get client => Supabase.instance.client;

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      !supabaseUrl.contains('YOUR_SUPABASE_PROJECT_ID') &&
      !supabaseAnonKey.contains('YOUR_SUPABASE_ANON_KEY');

  static Map<String, String> get _headers => {
        'apikey': supabaseAnonKey,
        'Authorization': 'Bearer $supabaseAnonKey',
        'Content-Type': 'application/json',
        'Prefer': 'return=representation',
      };

  // ==========================================================================
  // OFFLINE-FIRST CACHE HELPER (HIVE PLAYER BOX)
  // ==========================================================================

  /// Menyimpan cache Player ke Hive untuk mode offline
  static Future<void> savePlayerCache(UserModel user) async {
    try {
      final box = Hive.box(HiveBoxes.playerBox);
      await box.put('current_player', user.toMap());
    } catch (e) {
      // Abaikan jika box belum terbuka
    }
  }

  /// Mengambil cache Player dari Hive saat offline
  static UserModel? getPlayerCache() {
    try {
      final box = Hive.box(HiveBoxes.playerBox);
      final raw = box.get('current_player');
      if (raw != null && raw is Map) {
        return UserModel.fromMap(Map<String, dynamic>.from(raw));
      }
    } catch (_) {}
    return null;
  }

  // ==========================================================================
  // 1. TABEL: users
  // ==========================================================================

  /// Mendapatkan data user berdasarkan username
  static Future<UserModel?> getUserByUsername(String username) async {
    if (!isConfigured) {
      final cached = getPlayerCache();
      if (cached != null && cached.username.toLowerCase() == username.toLowerCase()) {
        return cached;
      }
      return null;
    }

    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/users?username=eq.$username&select=*');
      final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        if (list.isNotEmpty) {
          final user = UserModel.fromMap(list.first as Map<String, dynamic>);
          await savePlayerCache(user);
          return user;
        }
      }
    } catch (_) {
      // Fallback offline
      final cached = getPlayerCache();
      if (cached != null && cached.username.toLowerCase() == username.toLowerCase()) {
        return cached;
      }
    }
    return null;
  }

  /// Mendapatkan data user berdasarkan email
  static Future<UserModel?> getUserByEmail(String email) async {
    if (!isConfigured) {
      final cached = getPlayerCache();
      if (cached != null && cached.email.toLowerCase() == email.toLowerCase()) {
        return cached;
      }
      return null;
    }

    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/users?email=eq.$email&select=*');
      final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        if (list.isNotEmpty) {
          return UserModel.fromMap(list.first as Map<String, dynamic>);
        }
      }
    } catch (_) {}
    return null;
  }

  /// Mendapatkan user berdasarkan ID
  static Future<UserModel?> getUserById(int id) async {
    if (!isConfigured) return getPlayerCache();

    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/users?id=eq.$id&select=*');
      final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        if (list.isNotEmpty) {
          final user = UserModel.fromMap(list.first as Map<String, dynamic>);
          await savePlayerCache(user);
          return user;
        }
      }
    } catch (_) {
      return getPlayerCache();
    }
    return getPlayerCache();
  }

  /// Registrasi User Baru ke Supabase
  static Future<UserModel> createUser(UserModel user) async {
    // Selalu simpan ke cache lokal terlebih dahulu (Offline-First)
    await savePlayerCache(user);

    if (!isConfigured) {
      return user;
    }

    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/users');
      final payload = user.toMap()..remove('id'); // ID dibuat otomatis SERIAL oleh PostgreSQL
      
      // Sanitasi tanggal agar sesuai tipe PostgreSQL
      if (payload['last_active_date'] == null || (payload['last_active_date'] as String).isEmpty) {
        payload['last_active_date'] = DateTime.now().toIso8601String().substring(0, 10);
      }
      if (payload['created_at'] == null || (payload['created_at'] as String).isEmpty) {
        payload.remove('created_at');
      }

      final res = await http
          .post(uri, headers: _headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 201 || res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        if (list.isNotEmpty) {
          final createdUser = UserModel.fromMap(list.first as Map<String, dynamic>);
          await savePlayerCache(createdUser);
          return createdUser;
        }
      } else {
        debugPrint('Supabase createUser error: ${res.statusCode} - ${res.body}');
      }
    } catch (e) {
      debugPrint('Supabase createUser exception: $e');
    }
    return user;
  }

  /// Memperbarui Statistik Fisik / RPG User
  static Future<bool> updateUser(UserModel user) async {
    // Simpan ke cache lokal
    await savePlayerCache(user);

    if (!isConfigured || user.id <= 0) {
      return true;
    }

    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/users?id=eq.${user.id}');
      final payload = user.toMap()..remove('id');
      if (payload['last_active_date'] == null || (payload['last_active_date'] as String).isEmpty) {
        payload['last_active_date'] = DateTime.now().toIso8601String().substring(0, 10);
      }
      if (payload['created_at'] == null || (payload['created_at'] as String).isEmpty) {
        payload.remove('created_at');
      }

      final res = await http
          .patch(uri, headers: _headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 8));

      if (res.statusCode != 200 && res.statusCode != 204) {
        debugPrint('Supabase updateUser error: ${res.statusCode} - ${res.body}');
      }
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (e) {
      debugPrint('Supabase updateUser exception: $e');
      return true; // Sukses di cache lokal
    }
  }

  // ==========================================================================
  // 2. TABEL: user_tokens
  // ==========================================================================

  /// Menyimpan token autentikasi sesi ke Supabase
  static Future<bool> saveUserToken({
    required int userId,
    required String authKey,
    required DateTime expiresAt,
  }) async {
    if (!isConfigured || userId <= 0) return true;

    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/user_tokens');
      final payload = {
        'user_id': userId,
        'auth_key': authKey,
        'expires_at': expiresAt.toIso8601String(),
      };
      final res = await http
          .post(uri, headers: _headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 8));
      return res.statusCode == 201 || res.statusCode == 200;
    } catch (_) {
      return true; // Sukses fallback lokal
    }
  }

  /// Menghapus token saat Logout
  static Future<void> deleteUserToken({required int userId, required String authKey}) async {
    if (!isConfigured || userId <= 0) return;

    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/user_tokens?user_id=eq.$userId&auth_key=eq.$authKey');
      await http.delete(uri, headers: _headers).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  // ==========================================================================
  // 3. TABEL: quest_history
  // ==========================================================================

  /// Sinkronisasi Quest yang selesai atau dibuat ke Supabase
  static Future<bool> syncQuest({required QuestModel quest, required int userId}) async {
    if (!isConfigured || userId <= 0) return true;

    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/quest_history');
      final payload = quest.toMap(userId: userId);
      final res = await http
          .post(uri, headers: _headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 8));
      return res.statusCode == 201 || res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Mengambil riwayat quest dari Supabase
  static Future<List<QuestModel>> getQuestHistory(int userId) async {
    if (!isConfigured || userId <= 0) return [];

    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/quest_history?user_id=eq.$userId&order=id.desc');
      final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        return list.map((e) => QuestModel.fromMap(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  // ==========================================================================
  // 4. TABEL: blockchain_ledger
  // ==========================================================================

  /// Sinkronisasi Blok Blockchain Baru ke Supabase
  static Future<bool> syncBlock({required BlockModel block, required int userId}) async {
    if (!isConfigured || userId <= 0) return true;

    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/blockchain_ledger');
      final payload = block.toMap(userId: userId);
      final res = await http
          .post(uri, headers: _headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 8));
      return res.statusCode == 201 || res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Mengambil riwayat Blockchain dari Supabase
  static Future<List<BlockModel>> getBlockchainLedger(int userId) async {
    if (!isConfigured || userId <= 0) return [];

    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/blockchain_ledger?user_id=eq.$userId&order=block_index.asc');
      final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        return list.map((e) => BlockModel.fromMap(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  // ==========================================================================
  // 5. TABEL: saran_kesan
  // ==========================================================================

  /// Mengirim Saran & Kesan ke Supabase
  static Future<bool> createFeedback(FeedbackModel feedback) async {
    if (!isConfigured) return true;

    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/saran_kesan');
      final payload = feedback.toMap()..remove('id');
      final res = await http
          .post(uri, headers: _headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 8));
      return res.statusCode == 201 || res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Mengambil daftar Saran & Kesan dari Supabase
  static Future<List<FeedbackModel>> getFeedbackList() async {
    if (!isConfigured) return [];

    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/saran_kesan?order=id.desc');
      final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        return list.map((e) => FeedbackModel.fromMap(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Menghapus Saran & Kesan berdasarkan ID
  static Future<bool> deleteFeedback(int feedbackId) async {
    if (!isConfigured || feedbackId <= 0) return true;

    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/saran_kesan?id=eq.$feedbackId');
      final res = await http.delete(uri, headers: _headers).timeout(const Duration(seconds: 8));
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (_) {
      return false;
    }
  }
}
