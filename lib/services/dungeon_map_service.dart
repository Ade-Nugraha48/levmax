// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/services/dungeon_map_service.dart
// Deskripsi: Layanan Geospatial LBS (Location Based Services) untuk Peta Dungeon:
//            1. Generate 7 Titik Mystery Gate Mingguan (Reset Setiap Senin 00:00)
//            2. Kalkulasi Jarak Real-time (Geolocator Distance Between)
//            3. Algoritma RNG Drop Loot (Zonk, Gold, Consumable, Collectible, Quest)
//            4. Integrasi Blockchain Notarisasi untuk Item Langka
// ==============================================================================

import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';

import '../helpers/boxes.dart';
import '../models/quest_model.dart';
import '../models/user_model.dart';
import 'blockchain_service.dart';
import 'supabase_api_service.dart';

/// Enum Jenis Loot yang Dihasilkan dari Gate
enum LootType {
  zonk,
  gold,
  consumable,
  collectible,
  quest,
}

/// Model Data Hasil Drop Loot RNG
class LootResult {
  final LootType type;
  final String title;
  final String description;
  final int goldAmount;
  final String? itemName;
  final QuestModel? mysteryQuest;

  LootResult({
    required this.type,
    required this.title,
    required this.description,
    this.goldAmount = 0,
    this.itemName,
    this.mysteryQuest,
  });
}

/// Model Mystery Gate Mingguan (7 Titik per Minggu)
class MysteryGateModel {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String rank; // 'E', 'D', 'C', 'B', 'A', 'S'
  final String description;
  bool isClaimed;
  String? claimedAt;
  String? lootReward;

  MysteryGateModel({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.rank,
    required this.description,
    this.isClaimed = false,
    this.claimedAt,
    this.lootReward,
  });

  factory MysteryGateModel.fromJson(Map<String, dynamic> json) {
    return MysteryGateModel(
      id: json['id'] as String? ?? 'gate_${DateTime.now().millisecondsSinceEpoch}',
      name: json['name'] as String? ?? 'MYSTERY GATE',
      latitude: (json['latitude'] as num?)?.toDouble() ?? -6.2088,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 106.8456,
      rank: json['rank'] as String? ?? 'E',
      description: json['description'] as String? ?? 'Dungeon gate rift terdeteksi radar LBS',
      isClaimed: json['is_claimed'] as bool? ?? false,
      claimedAt: json['claimed_at'] as String?,
      lootReward: json['loot_reward'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'rank': rank,
      'description': description,
      'is_claimed': isClaimed,
      if (claimedAt != null) 'claimed_at': claimedAt,
      if (lootReward != null) 'loot_reward': lootReward,
    };
  }

  MysteryGateModel copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
    String? rank,
    String? description,
    bool? isClaimed,
    String? claimedAt,
    String? lootReward,
  }) {
    return MysteryGateModel(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      rank: rank ?? this.rank,
      description: description ?? this.description,
      isClaimed: isClaimed ?? this.isClaimed,
      claimedAt: claimedAt ?? this.claimedAt,
      lootReward: lootReward ?? this.lootReward,
    );
  }
}

class DungeonMapService {
  static const String keyMysteryGatesWeek = 'mystery_gates_week';
  static const String keyMysteryGatesData = 'mystery_gates_data';

  /// Mendapatkan ID Minggu Kalender Berdasarkan Hari Senin Terakhir
  /// Format: "YYYY-WXX" (Contoh: "2026-W43")
  static String getCurrentWeekId() {
    final now = DateTime.now();
    // Cari hari Senin di minggu ini
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final year = monday.year;
    final dayOfYear = monday.difference(DateTime(year, 1, 1)).inDays;
    final weekNumber = (dayOfYear / 7).floor() + 1;
    return '$year-W${weekNumber.toString().padLeft(2, '0')}';
  }

  /// Mengambil 7 Titik Mystery Gate dari Hive Cache, atau Men-generate Baru
  /// Jika Belum Ada Data Minggu Ini dalam Radius 1km - 3km dari GPS Pengguna.
  static Future<List<MysteryGateModel>> getOrGenerateWeeklyGates({
    required double userLat,
    required double userLng,
  }) async {
    final box = Hive.box(HiveBoxes.questCacheBox);
    final currentWeekId = getCurrentWeekId();
    final savedWeekId = box.get(keyMysteryGatesWeek) as String?;
    final rawData = box.get(keyMysteryGatesData);

    // 1. Jika data minggu ini sudah ada, gunakan cache lokal
    if (savedWeekId == currentWeekId && rawData != null) {
      try {
        final List decoded = (rawData is String) ? jsonDecode(rawData) : rawData;
        final list = decoded
            .map((item) => MysteryGateModel.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
        if (list.isNotEmpty) {
          return list;
        }
      } catch (e) {
        debugPrint('[DungeonMapService] Gagal membaca cache mystery gates: $e');
      }
    }

    // 2. Jika berganti minggu atau data kosong: Generate 7 titik koordinat acak baru
    final newGates = _generateSevenRandomGates(centerLat: userLat, centerLng: userLng);

    // Simpan ke Hive questCacheBox
    final jsonString = jsonEncode(newGates.map((g) => g.toJson()).toList());
    await box.put(keyMysteryGatesWeek, currentWeekId);
    await box.put(keyMysteryGatesData, jsonString);

    debugPrint('[DungeonMapService] Generated 7 new Mystery Gates for $currentWeekId');
    return newGates;
  }

  /// Men-generate 7 Titik Koordinat Acak dalam Radius 1000m - 3000m dari Titik Pusat
  static List<MysteryGateModel> _generateSevenRandomGates({
    required double centerLat,
    required double centerLng,
  }) {
    final random = math.Random();
    final List<MysteryGateModel> gates = [];

    final gateTemplates = [
      {'name': 'GATE 01: AZURE CITADEL RIFT', 'rank': 'E', 'desc': 'Portal biru beresonansi rendah terdeteksi sensor'},
      {'name': 'GATE 02: CRIMSON BOSS GATE', 'rank': 'D', 'desc': 'Aura magis merah darah terdeteksi di koordinat ini'},
      {'name': 'GATE 03: SHADOW ABYSS PORTAL', 'rank': 'C', 'desc': 'Kepadatan mana tinggi menyerupai monster bayangan'},
      {'name': 'GATE 04: SANCTUARY OF HEALING', 'rank': 'E', 'desc': 'Mata air penyembuhan energi pelindung barier'},
      {'name': 'GATE 05: TITAN IRON CAVERN', 'rank': 'D', 'desc': 'Kandungan mineral langka dan monster bebatuan'},
      {'name': 'GATE 06: PHANTOM MONARCH LAIR', 'rank': 'B', 'desc': 'Anomali dimensi terdistorsi di perimeter kota'},
      {'name': 'GATE 07: CELESTIAL VAULT RIFT', 'rank': 'A', 'desc': 'Portal kuno bermuatan energi kosmik tak terduga'},
    ];

    const double earthRadius = 6371000.0; // Radius bumi dalam meter

    for (int i = 0; i < 7; i++) {
      final template = gateTemplates[i];

      // Jarak acak antara 1000 meter (1 km) hingga 3000 meter (3 km)
      final double distance = 1000.0 + random.nextDouble() * 2000.0;
      // Sudut bantalan (bearing) acak 0 hingga 2*pi
      final double bearing = random.nextDouble() * 2 * math.pi;

      final double angularDistance = distance / earthRadius;
      final double latRad = centerLat * math.pi / 180.0;
      final double lngRad = centerLng * math.pi / 180.0;

      final double newLatRad = math.asin(
        math.sin(latRad) * math.cos(angularDistance) +
            math.cos(latRad) * math.sin(angularDistance) * math.cos(bearing),
      );

      final double newLngRad = lngRad +
          math.atan2(
            math.sin(bearing) * math.sin(angularDistance) * math.cos(latRad),
            math.cos(angularDistance) - math.sin(latRad) * math.sin(newLatRad),
          );

      final double generatedLat = newLatRad * 180.0 / math.pi;
      final double generatedLng = newLngRad * 180.0 / math.pi;

      gates.add(
        MysteryGateModel(
          id: 'gate_${getCurrentWeekId()}_0${i + 1}',
          name: template['name']!,
          latitude: generatedLat,
          longitude: generatedLng,
          rank: template['rank']!,
          description: template['desc']!,
          isClaimed: false,
        ),
      );
    }

    return gates;
  }

  /// Menghitung Jarak GPS Antara Pengguna dan Gate dalam Satuan Meter (Geolocator)
  static double calculateDistanceInMeters({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  /// Menyimpan Pembaruan Status Gate ke Hive Cache
  static Future<void> saveGatesToCache(List<MysteryGateModel> gates) async {
    final box = Hive.box(HiveBoxes.questCacheBox);
    final jsonString = jsonEncode(gates.map((g) => g.toJson()).toList());
    await box.put(keyMysteryGatesData, jsonString);
  }

  // ============================================================================
  // LOGIKA RNG (RANDOM LOOT DROP) SESUAI SPESIFIKASI PROMPT 10
  // ============================================================================
  // Drop Rate:
  // - ZONK (30%): 0 - 29
  // - GOLD (30%): 30 - 59 (50 - 200 Gold)
  // - ITEM CONSUMABLE (15%): 60 - 74 (HP Potion / Mystery Ticket)
  // - COLLECTIBLE PRIDE ITEM (15%): 75 - 89 (Item Langka + Blockchain Ledger Notarization)
  // - MYSTERY QUEST (10%): 90 - 99 (Secret Daily Quest + EXP Besar)
  static Future<LootResult> exploreGate({
    required MysteryGateModel gate,
    required UserModel player,
    required double currentLat,
    required double currentLng,
  }) async {
    // 1. Validasi Jarak: Harus < 50 Meter
    final double distance = calculateDistanceInMeters(
      startLat: currentLat,
      startLng: currentLng,
      endLat: gate.latitude,
      endLng: gate.longitude,
    );

    if (distance > 50.0) {
      throw Exception('Target terlalu jauh: ${distance.toInt()}m. Dekati gate dalam radius 50 meter!');
    }

    if (gate.isClaimed) {
      throw Exception('Mystery Gate ini telah di-clear sebelumnya!');
    }

    final random = math.Random();
    final int roll = random.nextInt(100); // 0 sampai 99
    LootResult result;

    if (roll < 30) {
      // 1. ZONK (30%)
      result = LootResult(
        type: LootType.zonk,
        title: 'GATE KOSONG',
        description: 'Gate telah di-clear oleh Hunter lain sebelum kedatangan Anda. Tidak ada energi atau artefak yang tersisa.',
      );
    } else if (roll < 60) {
      // 2. GOLD (30%): 50 - 200 Gold
      final int droppedGold = 50 + random.nextInt(151); // 50 hingga 200
      final updatedPlayer = player.copyWith(gold: player.gold + droppedGold);
      await SupabaseApiService.updateUser(updatedPlayer);

      result = LootResult(
        type: LootType.gold,
        title: 'DROPPED VAULT GOLD',
        description: 'Menemukan pundi-pundi koin emas dungeon tersembunyi!',
        goldAmount: droppedGold,
      );
    } else if (roll < 75) {
      // 3. ITEM CONSUMABLE (15%): HP Potion (+40 HP) atau Ticket Mystery Quest
      final isPotion = random.nextBool();
      if (isPotion) {
        final newHp = (player.hp + 40).clamp(0, 100);
        final updatedPlayer = player.copyWith(hp: newHp);
        await SupabaseApiService.updateUser(updatedPlayer);

        result = LootResult(
          type: LootType.consumable,
          title: 'ELIXIR OF LIFE (HP POTION)',
          description: 'Cairan esensial pemulih sel tubuh. HP pulih +40 poin secara instan!',
          itemName: 'Elixir of Life (+40 HP)',
        );
      } else {
        result = LootResult(
          type: LootType.consumable,
          title: 'MYSTERY GATEWAY TICKET',
          description: 'Tiket akses instan membuka Red Gate Dungeon tanpa batasan kuota harian.',
          itemName: 'Gateway Pass Ticket',
        );
      }
    } else if (roll < 90) {
      // 4. COLLECTIBLE PRIDE ITEM (15%): Rare Artifact + Blockchain Notarization
      final rareItems = [
        {'name': "Kasaka's Venom Fang", 'desc': 'Belati taring berbisa dari bos dungeon rawa beracun.'},
        {'name': "Demon Monarch's Dagger", 'desc': 'Senjata legendaris berdaya serang tinggi milik Raja Iblis.'},
        {'name': 'Orb of Avarice', 'desc': 'Artefak permata api yang menggandakan kekuatan sihir seratus persen.'},
        {'name': "Knight Commander's Helm", 'desc': 'Pelindung kepala prajurit bayangan berkehormatan tinggi.'},
      ];
      final pickedItem = rareItems[random.nextInt(rareItems.length)];
      final itemName = pickedItem['name']!;

      // PENTING: Catat ke Blockchain Ledger (SHA-256) agar tampil di Profil & Audit Log
      await BlockchainService.addBlock(
        'RARE ARTIFACT DISCOVERED: Hunter acquired collectible artifact [$itemName] from ${gate.name}.',
        userId: player.id,
      );

      // Tingkatkan stat CHA & EXP sebagai wujud kebanggaan
      final updatedPlayer = player.copyWith(
        cha: player.cha + 5,
        exp: player.exp + 50,
      );
      await SupabaseApiService.updateUser(updatedPlayer);

      result = LootResult(
        type: LootType.collectible,
        title: 'COLLECTIBLE PRIDE ARTIFACT',
        description: '${pickedItem['desc']} Tercatat resmi pada Blockchain Ledger!',
        itemName: itemName,
      );
    } else {
      // 5. MYSTERY QUEST (10%): Secret Quest dengan EXP Besar
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final questBox = Hive.box<QuestModel>(HiveBoxes.questBox);

      final mysteryQuest = QuestModel(
        id: 'mystery_quest_${DateTime.now().millisecondsSinceEpoch}',
        title: 'SECRET GATE: MONARCH TRIUMPH',
        description: 'Tantangan rahasia dari kedalaman dimensi: Selesaikan 50 Push-up atau 3KM Sprint!',
        category: 'Workout',
        targetValue: 50,
        currentValue: 0,
        unit: 'Reps',
        expReward: 150,
        goldReward: 200,
        isCompleted: false,
        scheduledDate: today,
      );

      await questBox.add(mysteryQuest);
      await SupabaseApiService.syncQuest(quest: mysteryQuest, userId: player.id);

      result = LootResult(
        type: LootType.quest,
        title: 'SECRET MYSTERY QUEST UNLOCKED',
        description: 'Membuka quest rahasia dengan reward +150 EXP dan +200 Gold! Silakan cek Daily Quest Feed Anda.',
        mysteryQuest: mysteryQuest,
      );
    }

    // Tandai gate sebagai telah di-klaim
    gate.isClaimed = true;
    gate.claimedAt = DateTime.now().toIso8601String();
    gate.lootReward = result.title;

    return result;
  }
}
