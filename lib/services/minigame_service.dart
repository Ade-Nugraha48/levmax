// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/services/minigame_service.dart
// Deskripsi: Layanan Mini-Game Arcade, Validasi Daily Reward Limit (1x per Hari),
//            Sinkronisasi Hive NoSQL, Supabase Cloud & Notarisasi Blockchain.
// ==============================================================================

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../helpers/boxes.dart';
import '../models/user_model.dart';
import 'blockchain_service.dart';
import 'supabase_api_service.dart';

class MinigameService {
  static const String keyDailyRewardDate = 'minigame_gyro_reward_date';
  static const String keyDailyRewardClaimed = 'minigame_gyro_reward_claimed';

  /// Mendapatkan string tanggal hari ini dalam format "YYYY-MM-DD"
  static String getTodayKey() {
    return DateTime.now().toIso8601String().substring(0, 10);
  }

  /// Mengecek apakah hadiah Gold mini-game hari ini sudah pernah diklaim (Daily Cap: 1x/Hari)
  static bool isDailyRewardClaimed() {
    try {
      final box = Hive.box(HiveBoxes.playerBox);
      final savedDate = box.get(keyDailyRewardDate) as String?;
      final isClaimed = box.get(keyDailyRewardClaimed) as bool? ?? false;
      return savedDate == getTodayKey() && isClaimed;
    } catch (e) {
      debugPrint('[MinigameService] Error checking daily reward status: $e');
      return false;
    }
  }

  /// Mengklaim hadiah Gold harian (+50 Gold)
  /// Mengembalikan true jika klaim baru berhasil, atau false jika sudah diklaim hari ini.
  static Future<bool> claimDailyReward({
    required UserModel player,
    int rewardGold = 50,
  }) async {
    final today = getTodayKey();

    // 1. Validasi Daily Cap: Hanya boleh 1x per hari
    if (isDailyRewardClaimed()) {
      debugPrint(
        '[MinigameService] Daily reward already claimed today ($today).',
      );
      return false;
    }

    // 2. Simpan status klaim hari ini ke Hive
    try {
      final box = Hive.box(HiveBoxes.playerBox);
      await box.put(keyDailyRewardDate, today);
      await box.put(keyDailyRewardClaimed, true);
    } catch (e) {
      debugPrint('[MinigameService] Failed to save claim state to Hive: $e');
    }

    // 3. Tambahkan Gold ke User Model dan Sinkronkan ke Supabase & Hive
    final updatedPlayer = player.copyWith(gold: player.gold + rewardGold);
    await SupabaseApiService.updateUser(updatedPlayer);

    // 4. Catat ke tabel minigame_logs di Supabase jika tabel tersedia
    try {
      if (SupabaseApiService.isConfigured && player.id.isNotEmpty) {
        await SupabaseApiService.client.from('minigame_logs').insert({
          'user_id': player.id,
          'game_name': 'mana_core_stabilization',
          'play_date': today,
          'is_reward_claimed': true,
          'reward_gold': rewardGold,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('[MinigameService] Supabase minigame_logs notice: $e');
    }

    // 5. Notarisasi Transaksi ke Blockchain Ledger
    await BlockchainService.addBlock(
      'MINI-GAME REWARD: Mana Core Stabilized (+50 Gold Claimed)',
      userId: player.id,
    );

    debugPrint(
      '[MinigameService] Successfully claimed +$rewardGold Gold for today ($today)',
    );
    return true;
  }
}
