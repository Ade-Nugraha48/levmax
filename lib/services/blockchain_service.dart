// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/services/blockchain_service.dart
// Deskripsi: Layanan Rantai Blok Lokal (FR-6.3) Berbasis SHA-256 (Anti-Cheat)
//            Mencatat Level Up, Rank Up, Re-Awakening, & Sinkronisasi Cloud Supabase.
// ==============================================================================

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:hive/hive.dart';
import '../helpers/boxes.dart';
import '../helpers/user_info.dart';
import '../models/block_model.dart';
import 'supabase_api_service.dart';

class BlockchainService {
  static const String genesisPrevHash =
      '0000000000000000000000000000000000000000000000000000000000000000';

  /// Kalkulasi Hash SHA-256 untuk sebuah blok data
  static String calculateHash({
    required int index,
    required String timestamp,
    required String action,
    required String prevHash,
  }) {
    final rawData = '$index|$timestamp|$action|$prevHash';
    final bytes = utf8.encode(rawData);
    return sha256.convert(bytes).toString();
  }

  /// Memastikan Genesis Block tersedia saat pertama kali Hunter terbangun
  static Future<void> ensureGenesisBlock({int? userId}) async {
    final box = Hive.box<BlockModel>(HiveBoxes.blockchainBox);
    if (box.isEmpty) {
      final now = DateTime.now().toIso8601String();
      const action = 'GENESIS BLOCK: Hunter Awakened (Level 1, Rank F)';
      final hash = calculateHash(
        index: 0,
        timestamp: now,
        action: action,
        prevHash: genesisPrevHash,
      );

      final genesisBlock = BlockModel(
        index: 0,
        timestamp: now,
        action: action,
        prevHash: genesisPrevHash,
        currentHash: hash,
      );

      await box.add(genesisBlock);

      // Sinkronisasi ke Supabase jika userId tersedia
      final uid = userId ?? await UserInfo.getUserID();
      if (uid != null && uid > 0) {
        await SupabaseApiService.syncBlock(block: genesisBlock, userId: uid);
      }
    }
  }

  /// Menambahkan blok baru ke rantai blockchain lokal & cadangkan ke Supabase
  static Future<BlockModel> addBlock(String action, {int? userId}) async {
    final box = Hive.box<BlockModel>(HiveBoxes.blockchainBox);

    // Pastikan ada blok awal jika masih kosong
    if (box.isEmpty) {
      await ensureGenesisBlock(userId: userId);
    }

    final lastBlock = box.getAt(box.length - 1)!;
    final newIndex = lastBlock.index + 1;
    final now = DateTime.now().toIso8601String();
    final prevHash = lastBlock.currentHash;

    final currentHash = calculateHash(
      index: newIndex,
      timestamp: now,
      action: action,
      prevHash: prevHash,
    );

    final newBlock = BlockModel(
      index: newIndex,
      timestamp: now,
      action: action,
      prevHash: prevHash,
      currentHash: currentHash,
    );

    // Simpan ke Hive (Lapisan 2)
    await box.add(newBlock);

    // Sinkronisasi ke Supabase (Lapisan 3)
    final uid = userId ?? await UserInfo.getUserID();
    if (uid != null && uid > 0) {
      await SupabaseApiService.syncBlock(block: newBlock, userId: uid);
    }

    return newBlock;
  }

  /// Memvalidasi seluruh integritas Rantai Blok (Anti-Cheat Validator)
  /// Mengembalikan true jika seluruh hash blok valid dan tidak pernah dimanipulasi
  static bool isChainValid() {
    final box = Hive.box<BlockModel>(HiveBoxes.blockchainBox);
    if (box.isEmpty) return true;

    for (int i = 0; i < box.length; i++) {
      final current = box.getAt(i);
      if (current == null) return false;

      // Verifikasi integritas hash blok saat ini
      final recalculatedHash = calculateHash(
        index: current.index,
        timestamp: current.timestamp,
        action: current.action,
        prevHash: current.prevHash,
      );

      if (current.currentHash != recalculatedHash) {
        return false; // Hash blok terkorupsi / diubah secara ilegal!
      }

      // Verifikasi rantai sambungan ke blok sebelumnya
      if (i > 0) {
        final previous = box.getAt(i - 1);
        if (previous == null || current.prevHash != previous.currentHash) {
          return false; // Rantai hash terputus!
        }
      } else {
        // Blok Genesis wajib memiliki prevHash nol
        if (current.prevHash != genesisPrevHash) {
          return false;
        }
      }
    }
    return true;
  }

  /// Mengambil seluruh blok yang tersimpan di Hive
  static List<BlockModel> getBlocks() {
    final box = Hive.box<BlockModel>(HiveBoxes.blockchainBox);
    return box.values.toList();
  }

  /// Sinkronisasi seluruh blok lokal ke Supabase jika belum tersinkron
  static Future<int> syncAllToSupabase() async {
    final uid = await UserInfo.getUserID();
    if (uid == null || uid <= 0) return 0;

    final box = Hive.box<BlockModel>(HiveBoxes.blockchainBox);
    int syncedCount = 0;

    for (final block in box.values) {
      final ok = await SupabaseApiService.syncBlock(block: block, userId: uid);
      if (ok) syncedCount++;
    }

    return syncedCount;
  }
}
