// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/services/supabase_service.dart
// Deskripsi: Layanan REST API Supabase Baru yang Diadaptasi ke UUID, Join Relasional
//            (daily_user_quests + master_quests), Logika Kenaikan Level/Rank RPG,
//            dan Notarisasi Pembelian Item Blockchain SHA-256.
// ==============================================================================

import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/hive_boxes.dart';
import '../models/block_model.dart';
import '../models/feedback_model.dart';
import '../models/quest_models.dart';
import '../models/user_model.dart';

/// Helper generator UUID v4 murni Dart (RFC 4122)
String generateUuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // Versi 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // Varian RFC 4122
  return [
    bytes.sublist(0, 4).map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
    bytes.sublist(4, 6).map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
    bytes.sublist(6, 8).map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
    bytes.sublist(8, 10).map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
    bytes.sublist(10, 16).map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
  ].join('-');
}

class SupabaseService {
  // ============================================================================
  // KONFIGURASI SUPABASE EDGE REST API
  // ============================================================================
  static String supabaseUrl = 'https://eoujrrvbrqotbnhsgjni.supabase.co';
  static String supabaseAnonKey =
      'sb_publishable_BCwFIi7ZpuBONB-rLMg4Jw_sB0NFxCb';

  static SupabaseClient get client => Supabase.instance.client;

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      !supabaseUrl.contains('YOUR_SUPABASE_PROJECT_ID');

  static Map<String, String> get _headers => {
        'apikey': supabaseAnonKey,
        'Authorization': 'Bearer $supabaseAnonKey',
        'Content-Type': 'application/json',
        'Prefer': 'return=representation',
      };

  // ============================================================================
  // 1. SINKRONISASI QUEST HARIAN DENGAN JOIN (daily_user_quests + master_quests)
  // ============================================================================

  /// Mengambil data dari daily_user_quests di-JOIN dengan master_quests
  /// berdasarkan user_id (UUID) dan date hari ini.
  /// Jika berhasil: simpan ke QuestBox (today_quests) & update last_sync_date.
  /// Jika gagal/offline: kembalikan data cache dari QuestBox.
  static Future<List<DailyUserQuestModel>> syncDailyQuests(String userId) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final questBox = HiveBoxes.getQuestCacheBox();

    if (!isConfigured || userId.isEmpty) {
      return _getCachedDailyQuests();
    }

    try {
      // PostgREST Resource Embedding: daily_user_quests JOIN master_quests
      final uri = Uri.parse(
        '$supabaseUrl/rest/v1/daily_user_quests'
        '?user_id=eq.$userId'
        '&date=eq.$today'
        '&select=*,master_quests(*)',
      );

      final res = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 9));

      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        final quests = list
            .map((item) =>
                DailyUserQuestModel.fromJson(item as Map<String, dynamic>))
            .toList();

        // Simpan ke Hive questCacheBox dalam format JSON String
        final jsonList = quests.map((q) => q.toJson()).toList();
        await questBox.put(HiveBoxes.keyTodayQuests, jsonEncode(jsonList));
        await questBox.put(HiveBoxes.keyLastSyncDate, today);

        return quests;
      }
    } catch (e) {
      debugPrint('[SupabaseService] syncDailyQuests network error: $e');
    }

    // Fallback offline: Ambil cache lokal dari questCacheBox
    return _getCachedDailyQuests();
  }

  /// Helper internal untuk mengambil cache quest hari ini dari questCacheBox
  static List<DailyUserQuestModel> _getCachedDailyQuests() {
    try {
      final questBox = HiveBoxes.getQuestCacheBox();
      final raw = questBox.get(HiveBoxes.keyTodayQuests);
      if (raw != null) {
        final decoded = (raw is String) ? jsonDecode(raw) : raw;
        if (decoded is List) {
          return decoded
              .map((item) =>
                  DailyUserQuestModel.fromJson(item as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('[SupabaseService] Gagal membaca cache quest lokal: $e');
    }
    return [];
  }

  // ============================================================================
  // 2. LOGIKA LEVEL UP & ATRIBUT SEIMBANG (LEVMAX GAMIFICATION RULES)
  // ============================================================================

  /// Aturan gamifikasi LevMax:
  /// Syarat naik level = EXP >= 100 DAN rata-rata atribut (STR, AGI, INT, CHA) seimbang.
  /// Jika syarat terpenuhi: level bertambah +1, exp dikurangi 100, rank dikalkulasi ulang.
  static Future<UserModel> levelUpCheck(UserModel user) async {
    // 1. Periksa ambang batas EXP
    if (user.exp < 100) {
      return user;
    }

    // 2. Periksa syarat keseimbangan 4 atribut
    final minRequiredStat = user.level * 3;
    final isBalanced = user.minStat >= minRequiredStat && user.isBalanced;

    if (!isBalanced) {
      debugPrint(
        '[LevelUpCheck] Kenaikan Level tertahan: Atribut STR/AGI/INT/CHA belum seimbang '
        '(Min Stat: ${user.minStat}, Minimal Dibutuhkan: $minRequiredStat).',
      );
      return user; // Kenaikan level ditahan oleh Sistem sampai atribut seimbang
    }

    // 3. Eksekusi Level Up
    final newLevel = user.level + 1;
    final newExp = user.exp - 100;
    final newRank = UserModel.calculateRank(newLevel, minStatValue: user.minStat);

    final updatedUser = user.copyWith(
      level: newLevel,
      exp: newExp,
      rank: newRank,
    );

    // 4. Sinkronisasi perubahan ke Supabase & Cache
    await updateUser(updatedUser);
    await savePlayerCache(updatedUser);

    debugPrint(
      '[LevelUpCheck] LEVEL UP BERHASIL! Hunter naik ke Level $newLevel, Rank $newRank.',
    );
    return updatedUser;
  }

  /// Meningkatkan atribut Hunter sesuai dengan target_stat dari quest yang diselesaikan
  static Future<UserModel> applyQuestStatReward({
    required UserModel user,
    required String targetStat,
    int statBonus = 2,
    int expBonus = 25,
    int goldBonus = 15,
  }) async {
    int newStr = user.str;
    int newAgi = user.agi;
    int newInt = user.intStat;
    int newCha = user.cha;

    switch (targetStat.toUpperCase()) {
      case 'STR':
        newStr += statBonus;
        break;
      case 'AGI':
        newAgi += statBonus;
        break;
      case 'INT':
        newInt += statBonus;
        break;
      case 'CHA':
        newCha += statBonus;
        break;
      default:
        newStr += statBonus;
    }

    final updated = user.copyWith(
      str: newStr,
      agi: newAgi,
      intStat: newInt,
      cha: newCha,
      exp: user.exp + expBonus,
      gold: user.gold + goldBonus,
    );

    // Otomatis cek apakah player berhak Level Up setelah EXP dan Stat bertambah
    return await levelUpCheck(updated);
  }

  // ============================================================================
  // 3. LOG NOTARISASI PEMBELIAN ITEM BLOCKCHAIN (SHA-256)
  // ============================================================================

  /// Mengambil current_hash dari transaksi terakhir user, men-generate hash SHA-256 baru
  /// dengan formula: hash(id + previous_hash + user_id + item_id + timestamp),
  /// lalu mengirim POST ke tabel blockchain_inventory_logs.
  static Future<BlockchainInventoryLogModel?> logBlockchainItemPurchase({
    required String userId,
    required String itemId,
  }) async {
    const defaultGenesis =
        '0000000000000000000000000000000000000000000000000000000000000000';
    String previousHash = defaultGenesis;

    // 1. Ambil transaksi terakhir untuk mendapatkan current_hash sebelumnya
    if (isConfigured && userId.isNotEmpty) {
      try {
        final uri = Uri.parse(
          '$supabaseUrl/rest/v1/blockchain_inventory_logs'
          '?user_id=eq.$userId'
          '&order=timestamp.desc'
          '&limit=1',
        );

        final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 7));
        if (res.statusCode == 200) {
          final List list = jsonDecode(res.body);
          if (list.isNotEmpty) {
            final lastLog = list.first as Map<String, dynamic>;
            previousHash = lastLog['current_hash']?.toString() ?? defaultGenesis;
          }
        }
      } catch (e) {
        debugPrint('[Blockchain] Fetch previous hash network error: $e');
      }
    }

    // 2. Buat ID unik (UUID), stempel waktu ISO-8601, dan kalkulasi SHA-256
    final id = generateUuidV4();
    final timestamp = DateTime.now().toUtc().toIso8601String();

    // Format: hash(id + previous_hash + user_id + item_id + timestamp)
    final rawData = '$id$previousHash$userId$itemId$timestamp';
    final currentHash = sha256.convert(utf8.encode(rawData)).toString();

    final logModel = BlockchainInventoryLogModel(
      id: id,
      userId: userId,
      itemId: itemId,
      previousHash: previousHash,
      currentHash: currentHash,
      timestamp: timestamp,
      status: 'verified',
    );

    // 3. Kirim POST ke tabel blockchain_inventory_logs di Supabase
    if (isConfigured) {
      try {
        final uri = Uri.parse('$supabaseUrl/rest/v1/blockchain_inventory_logs');
        await http.post(
          uri,
          headers: _headers,
          body: jsonEncode(logModel.toJson()),
        ).timeout(const Duration(seconds: 8));
      } catch (e) {
        debugPrint('[Blockchain] Post inventory log network error: $e');
      }
    }

    return logModel;
  }

  // ============================================================================
  // 4. CRUD TABEL USERS (Dukungan Penuh UUID & Legacy)
  // ============================================================================

  static Future<UserModel?> getUserById(dynamic id) async {
    final idStr = id?.toString() ?? '';
    if (idStr.isEmpty) return getPlayerCache();

    if (!isConfigured) {
      final cached = getPlayerCache();
      if (cached != null && (cached.id == idStr || idStr == '0' || idStr == '1')) {
        return cached;
      }
      return null;
    }

    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/users?id=eq.$idStr&select=*');
      final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        if (list.isNotEmpty) {
          final user = UserModel.fromJson(list.first as Map<String, dynamic>);
          await savePlayerCache(user);
          return user;
        }
      }
    } catch (_) {
      final cached = getPlayerCache();
      if (cached != null && (cached.id == idStr || idStr == '0' || idStr == '1')) {
        return cached;
      }
    }
    return null;
  }

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
          final user = UserModel.fromJson(list.first as Map<String, dynamic>);
          await savePlayerCache(user);
          return user;
        }
      }
    } catch (_) {
      final cached = getPlayerCache();
      if (cached != null && cached.username.toLowerCase() == username.toLowerCase()) {
        return cached;
      }
    }
    return null;
  }

  static Future<UserModel?> createUser(UserModel user) async {
    final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    final validId = (user.id.isNotEmpty && uuidRegex.hasMatch(user.id))
        ? user.id
        : generateUuidV4();
    final userWithId = user.copyWith(id: validId);

    if (!isConfigured) {
      debugPrint('[SupabaseService] Supabase not configured. Using local fallback.');
      await savePlayerCache(userWithId);
      return userWithId;
    }

    final payload = userWithId.toSupabaseJson();
    debugPrint('[SupabaseService] Sending payload to Supabase: $payload');

    // 1. Coba melalui Supabase Flutter Client SDK
    try {
      final res = await client
          .from('users')
          .insert(payload)
          .select()
          .single()
          .timeout(const Duration(seconds: 10));

      final created = UserModel.fromJson(res);
      await savePlayerCache(created);
      debugPrint('[SupabaseService] User successfully created via SDK with ID: ${created.id}');
      return created;
    } catch (sdkError) {
      debugPrint('[SupabaseService] SDK insert failed ($sdkError), trying REST HTTP POST fallback...');
    }

    // 2. Fallback ke Direct HTTP REST POST
    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/users');
      final res = await http
          .post(uri, headers: _headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 10));

      debugPrint('[SupabaseService] HTTP REST Response: status=${res.statusCode}, body=${res.body}');

      if (res.statusCode == 201 || res.statusCode == 200) {
        final dynamic decoded = jsonDecode(res.body);
        Map<String, dynamic>? data;
        if (decoded is List && decoded.isNotEmpty) {
          data = decoded.first as Map<String, dynamic>;
        } else if (decoded is Map<String, dynamic>) {
          data = decoded;
        }
        if (data != null) {
          final created = UserModel.fromJson(data);
          await savePlayerCache(created);
          return created;
        }
      }
    } catch (httpError) {
      debugPrint('[SupabaseService] HTTP REST error: $httpError');
    }

    debugPrint('[SupabaseService] ERROR: Failed to insert user to Supabase.');
    return null;
  }

  static Future<bool> updateUser(UserModel user) async {
    await savePlayerCache(user);

    if (!isConfigured || user.id.isEmpty) return true;

    final payload = user.toSupabaseJson();
    payload.remove('id'); // Primary key tidak di-update pada PATCH

    // 1. Coba melalui Supabase SDK Client
    try {
      await client
          .from('users')
          .update(payload)
          .eq('id', user.id)
          .timeout(const Duration(seconds: 10));
      return true;
    } catch (sdkError) {
      debugPrint('[SupabaseService] SDK update error ($sdkError), trying REST HTTP...');
    }

    // 2. Fallback ke REST HTTP PATCH
    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/users?id=eq.${user.id}');
      final res = await http
          .patch(uri, headers: _headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 8));

      return res.statusCode == 200 || res.statusCode == 204;
    } catch (e) {
      debugPrint('[SupabaseService] updateUser error: $e');
      return false;
    }
  }

  // ============================================================================
  // 5. CACHE PLAYER OFFLINE (Hive playerBox)
  // ============================================================================

  static Future<void> savePlayerCache(UserModel user) async {
    try {
      final box = Hive.box(HiveBoxes.playerBox);
      await box.put('current_player', user.toJson());
    } catch (_) {}
  }

  static UserModel? getPlayerCache() {
    try {
      final box = Hive.box(HiveBoxes.playerBox);
      final raw = box.get('current_player');
      if (raw != null && raw is Map) {
        return UserModel.fromJson(Map<String, dynamic>.from(raw));
      }
    } catch (_) {}
    return null;
  }

  // ============================================================================
  // 6. MASTER QUESTS & SHOP ITEMS
  // ============================================================================

  static Future<List<MasterQuestModel>> getMasterQuests() async {
    if (!isConfigured) return [];
    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/master_quests?select=*');
      final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        return list.map((e) => MasterQuestModel.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('[SupabaseService] getMasterQuests error: $e');
    }
    return [];
  }

  static Future<List<ItemShopModel>> getItemsShop() async {
    if (!isConfigured) return [];
    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/item_shop?select=*');
      final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        return list.map((e) => ItemShopModel.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('[SupabaseService] getItemsShop error: $e');
    }
    return [];
  }

  // ============================================================================
  // 7. KOMPATIBILITAS TOKEN & BLOCKCHAIN SINKRONISASI
  // ============================================================================

  static Future<bool> saveUserToken({
    required dynamic userId,
    required String authKey,
    required DateTime expiresAt,
  }) async {
    if (!isConfigured) return true;
    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/user_tokens');
      final body = jsonEncode({
        'user_id': userId,
        'auth_key': authKey,
        'expires_at': expiresAt.toUtc().toIso8601String(),
      });
      final res = await http.post(uri, headers: _headers, body: body).timeout(const Duration(seconds: 8));
      return res.statusCode == 201 || res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> syncBlock({
    required BlockModel block,
    required dynamic userId,
  }) async {
    if (!isConfigured) return true;
    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/blockchain_ledger');
      final body = jsonEncode({
        'user_id': userId,
        'block_index': block.index,
        'timestamp': block.timestamp,
        'action_data': block.action,
        'prev_hash': block.prevHash,
        'current_hash': block.currentHash,
      });
      final res = await http.post(uri, headers: _headers, body: body).timeout(const Duration(seconds: 8));
      return res.statusCode == 201 || res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ============================================================================
  // 8. SARAN & KESAN (Feedback Kuliah Mobile)
  // ============================================================================

  static Future<bool> submitFeedback({
    required dynamic userId,
    required String namaMahasiswa,
    required String nim,
    required String kesan,
    required String saran,
  }) async {
    if (!isConfigured) return true;
    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/saran_kesan');
      final body = jsonEncode({
        'user_id': userId,
        'nama_mahasiswa': namaMahasiswa,
        'nim': nim,
        'kesan': kesan,
        'saran': saran,
      });
      final res = await http.post(uri, headers: _headers, body: body).timeout(const Duration(seconds: 8));
      return res.statusCode == 201 || res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<List<FeedbackModel>> getFeedbackList() async {
    if (!isConfigured) return [];
    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/saran_kesan?select=*&order=created_at.desc');
      final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        return list.map((e) => FeedbackModel.fromMap(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<UserModel?> getUserByEmail(String email) async {
    if (!isConfigured) return null;
    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/users?email=eq.$email&select=*');
      final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        if (list.isNotEmpty) {
          return UserModel.fromJson(list.first as Map<String, dynamic>);
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<bool> createFeedback(FeedbackModel feedback) async {
    return await submitFeedback(
      userId: feedback.userId,
      namaMahasiswa: feedback.namaMahasiswa,
      nim: feedback.nim,
      kesan: feedback.kesan,
      saran: feedback.saran,
    );
  }

  static Future<bool> deleteUserToken({
    dynamic userId,
    required String authKey,
  }) async {
    if (!isConfigured) return true;
    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/user_tokens?auth_key=eq.$authKey');
      final res = await http.delete(uri, headers: _headers).timeout(const Duration(seconds: 8));
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> syncQuest({
    required dynamic quest,
    required dynamic userId,
  }) async {
    if (!isConfigured) return true;
    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/daily_user_quests');
      final body = {
        'user_id': userId?.toString() ?? '',
        'quest_id': quest.id?.toString() ?? '',
        'status': (quest.isCompleted ?? false) ? 'completed' : 'pending',
        'target_value': quest.targetValue ?? 10,
        'achieved_value': quest.currentValue ?? 0,
        'date': quest.scheduledDate ?? DateTime.now().toIso8601String().substring(0, 10),
      };
      final res = await http.post(uri, headers: _headers, body: jsonEncode(body)).timeout(const Duration(seconds: 8));
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }
}

/// Alias SupabaseApiService untuk kompatibilitas penuh dengan kode yang sudah ada
typedef SupabaseApiService = SupabaseService;

