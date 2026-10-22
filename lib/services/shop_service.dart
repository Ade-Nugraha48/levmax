// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/services/shop_service.dart
// Deskripsi: Layanan Ekonomi Sistem, Pembelian Consumables, Minting Blockchain SHA-256
//            (blockchain_inventory_logs), Mockup Top-Up Fiat & Kalkulator Konversi Kurs.
// ==============================================================================

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../helpers/boxes.dart';
import '../models/block_model.dart';
import '../models/quest_models.dart';
import '../models/user_model.dart';
import 'blockchain_service.dart';
import 'supabase_api_service.dart';

class ShopService {
  static const String genesisBlockHash = 'GENESIS_BLOCK';

  // ============================================================================
  // 1. KATALOG ITEM SHOP (DEFAULT PRESETS SESUAI DOKUMEN GDD & PROMPT 12)
  // ============================================================================
  static List<ItemShopModel> getDefaultShopItems() {
    return [
      // Consumables
      ItemShopModel(
        id: 'item_hp_potion_01',
        name: 'Elixir of Life (+25 HP)',
        description: 'Memulihkan 25 nyawa yang hilang akibat penalti kegagalan misi harian.',
        priceGold: 500,
        prideScore: 0,
        category: 'Consumable',
      ),
      ItemShopModel(
        id: 'item_mystery_key_01',
        name: 'Mystery Gate Key',
        description: 'Membuka 1 Mystery Quest tersembunyi hari ini dengan reward EXP besar.',
        priceGold: 800,
        prideScore: 0,
        category: 'Consumable',
      ),
      ItemShopModel(
        id: 'item_mana_catalyst_01',
        name: 'Mana Surge Catalyst (+50 EXP)',
        description: 'Katalis mana murni yang memberikan lonjakan +50 EXP instan kepada Hunter.',
        priceGold: 650,
        prideScore: 0,
        category: 'Consumable',
      ),
      ItemShopModel(
        id: 'item_aegis_shield_01',
        name: 'Penalty Aegis Shield',
        description: 'Pelindung magis yang menganulir pengurangan HP untuk 1 kali penalti.',
        priceGold: 1200,
        prideScore: 0,
        category: 'Consumable',
      ),

      // Collectibles (Pride Items / Leaderboard)
      ItemShopModel(
        id: 'item_pride_crown_01',
        name: 'Crown of Shadows',
        description: 'Simbol status abadi di Leaderboard. Mustahil diduplikasi berkat Rantai Blok SHA-256.',
        priceGold: 15000,
        prideScore: 1000,
        category: 'PrideItem',
      ),
      ItemShopModel(
        id: 'item_pride_kasaka_01',
        name: "Kasaka's Poison Fang Dagger",
        description: 'Belati taring beracun legendaris dari bos rawa biru. Menambah +5 Stat CHA.',
        priceGold: 12000,
        prideScore: 750,
        category: 'PrideItem',
      ),
      ItemShopModel(
        id: 'item_pride_monarch_ring_01',
        name: "Demon Monarch's Ring",
        description: 'Cincin kekuasaan kuno berukir runik kegelapan. Lambang martabat Hunter elite.',
        priceGold: 20000,
        prideScore: 1500,
        category: 'PrideItem',
      ),
      ItemShopModel(
        id: 'item_pride_orb_avarice_01',
        name: 'Orb of Avarice (Celestial)',
        description: 'Permata api kosmik yang memancarkan aura prestise tak terbatas.',
        priceGold: 18000,
        prideScore: 1200,
        category: 'PrideItem',
      ),
    ];
  }

  // ============================================================================
  // 2. PEMBELIAN ITEM CONSUMABLE (PENGURANGAN GOLD & RESTORE HP)
  // ============================================================================
  static Future<UserModel> purchaseConsumable({
    required UserModel player,
    required ItemShopModel item,
  }) async {
    if (player.gold < item.priceGold) {
      throw Exception('Insufficient Gold! Saldo Anda tidak mencukupi untuk item ini.');
    }

    int newGold = player.gold - item.priceGold;
    int newHp = player.hp;
    int newExp = player.exp;

    if (item.id.contains('hp_potion') || item.name.contains('+25 HP')) {
      newHp = (newHp + 25).clamp(0, 100);
    } else if (item.id.contains('mana_catalyst') || item.name.contains('+50 EXP')) {
      newExp += 50;
    }

    final updatedPlayer = player.copyWith(
      gold: newGold,
      hp: newHp,
      exp: newExp,
    );

    // Update user di Supabase & Hive
    await SupabaseApiService.updateUser(updatedPlayer);

    // Notarisasi ke Blockchain lokal
    await BlockchainService.addBlock(
      'CONSUMABLE PURCHASE: ${item.name} (-${item.priceGold} Gold, HP: $newHp)',
      userId: player.id,
    );

    return updatedPlayer;
  }

  // ============================================================================
  // 3. MINTING ITEM COLLECTIBLE (PRIDE ITEM) KE BLOCKCHAIN SHA-256 LEDGER
  // ============================================================================
  // Sesuai aturan Prompt 12:
  // 1. Cek gold >= price. Jika gagal, exception Insufficient Gold!
  // 2. Kurangi gold pengguna.
  // 3. Ambil baris terakhir blockchain_inventory_logs (atau Hive blockchainBox).
  //    Jika kosong, gunakan 'GENESIS_BLOCK'.
  // 4. timestamp = DateTime.now().toIso8601String()
  // 5. dataPayload = "USER:${user.id}_MINTED_ITEM:${itemId}_AT_${timestamp}"
  // 6. current_hash = sha256(utf8.encode(previous_hash + dataPayload + timestamp)).toString()
  // 7. Simpan ke Supabase dan Hive.
  // ============================================================================
  static Future<BlockchainInventoryLogModel> mintCollectibleItem({
    required UserModel player,
    required ItemShopModel item,
  }) async {
    // 1. Validasi Saldo Gold
    if (player.gold < item.priceGold) {
      throw Exception('Insufficient Gold! Anda membutuhkan ${item.priceGold} Gold untuk mem-mint item ini.');
    }

    // 2. Ambil previous_hash dari tabel blockchain_inventory_logs atau Hive
    String previousHash = genesisBlockHash;
    if (SupabaseApiService.isConfigured && player.id.isNotEmpty) {
      try {
        final List<dynamic> response = await SupabaseApiService.client
            .from('blockchain_inventory_logs')
            .select('current_hash')
            .eq('user_id', player.id)
            .order('timestamp', ascending: false)
            .limit(1)
            .timeout(const Duration(seconds: 7));
        if (response.isNotEmpty) {
          final Map first = response.first as Map;
          final prev = first['current_hash']?.toString();
          if (prev != null && prev.isNotEmpty) {
            previousHash = prev;
          }
        }
      } catch (e) {
        debugPrint('[ShopService] Fetch previous_hash online error: $e');
      }
    }

    // Fallback ke Hive blockchainBox jika previousHash masih genesis
    if (previousHash == genesisBlockHash) {
      try {
        final box = Hive.box<BlockModel>(HiveBoxes.blockchainBox);
        if (box.isNotEmpty) {
          previousHash = box.values.last.currentHash;
        }
      } catch (_) {}
    }

    // 4. Generate timestamp ISO-8601
    final timestamp = DateTime.now().toIso8601String();

    // 5. Buat string dataPayload eksak sesuai Prompt 12
    final dataPayload = 'USER:${player.id}_MINTED_ITEM:${item.id}_AT_$timestamp';

    // 6. Generate current_hash menggunakan SHA-256
    final rawHashInput = '$previousHash$dataPayload$timestamp';
    final currentHash = sha256.convert(utf8.encode(rawHashInput)).toString();

    // 7. Buat Model Log Rantai Blok
    final logModel = BlockchainInventoryLogModel(
      id: generateUuidV4(),
      userId: player.id,
      itemId: item.id,
      previousHash: previousHash,
      currentHash: currentHash,
      timestamp: timestamp,
      status: 'verified',
    );

    // Simpan ke Supabase tabel blockchain_inventory_logs
    if (SupabaseApiService.isConfigured) {
      try {
        await SupabaseApiService.client
            .from('blockchain_inventory_logs')
            .insert(logModel.toJson())
            .timeout(const Duration(seconds: 8));
      } catch (e) {
        debugPrint('[ShopService] Post blockchain_inventory_logs error: $e');
      }
    }

    // Simpan juga ke Hive blockchainBox lokal sebagai cadangan
    try {
      final box = Hive.box<BlockModel>(HiveBoxes.blockchainBox);
      final newIndex = box.isEmpty ? 0 : box.values.last.index + 1;
      await box.add(
        BlockModel(
          index: newIndex,
          timestamp: timestamp,
          action: 'MINT PRIDE ITEM: ${item.name} ($currentHash)',
          prevHash: previousHash,
          currentHash: currentHash,
        ),
      );
    } catch (e) {
      debugPrint('[ShopService] Save to Hive blockchainBox error: $e');
    }

    // Kurangi Gold pengguna dan tambahkan stat CHA / EXP
    final updatedPlayer = player.copyWith(
      gold: player.gold - item.priceGold,
      cha: player.cha + 5,
      exp: player.exp + 100,
    );
    await SupabaseApiService.updateUser(updatedPlayer);

    return logModel;
  }

  // ============================================================================
  // 4. TOP-UP MOCKUP (PEMBELIAN UANG ASLI VIA PLAY STORE / APP STORE)
  // ============================================================================
  static Future<UserModel> processTopUp({
    required UserModel player,
    required int goldAmount,
    required String idrPriceFormatted,
  }) async {
    final newGold = player.gold + goldAmount;
    final updatedPlayer = player.copyWith(gold: newGold);

    // Update profil pengguna di Supabase & Hive
    await SupabaseApiService.updateUser(updatedPlayer);

    // Catat notarisasi top-up ke Blockchain Ledger
    await BlockchainService.addBlock(
      'TOP-UP FIAT: Hunter purchased $goldAmount Gold ($idrPriceFormatted) via Store',
      userId: player.id,
    );

    return updatedPlayer;
  }

  // ============================================================================
  // 5. KALKULATOR KONVERSI KURS MATA UANG
  // ============================================================================
  // 1 Gold = Rp 10
  // Kurs acuan: 1 USD = Rp 15.920, 1 EUR = Rp 17.360
  static Map<String, String> calculateCurrencyExchange(int gold) {
    final double idr = gold * 10.0;
    final double usd = idr / 15920.0;
    final double eur = idr / 17360.0;

    return {
      'idr': 'Rp ${idr.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
      'usd': '\$ ${usd.toStringAsFixed(2)}',
      'eur': '€ ${eur.toStringAsFixed(2)}',
    };
  }
}
