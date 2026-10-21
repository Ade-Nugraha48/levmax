// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/services/quest_generator_service.dart
// Deskripsi: Service Penyedia Daily Quest Terstandarisasi & Katalog Ensiklopedia
//            1. Template Tetap (Hardcoded): Workout (Push-up, Sit-up, Squat, Pull-up),
//               Cardio (Run, Walk), Skincare (Cuci muka, Moisturizer, Sunscreen),
//               Productivity (Study, Work).
//            2. Perhitungan Adaptive Load: Target = Kapasitas_Maks * (0.60 + ((Level - 1) * 0.05))
//            3. Ensiklopedia Quest dengan Sistem Gembok (Lock/Unlock) Berdasarkan Rank
//            4. Kuota Quest Slots & Sistem Penalti Harian (-20 HP / -40 HP)
// ==============================================================================

import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../helpers/boxes.dart';
import '../models/quest_model.dart';
import '../models/user_model.dart';
import 'notification_service.dart';
import 'supabase_api_service.dart';

/// Template data statis untuk Ensiklopedia & Generator Quest Resmi LevMax
class QuestTemplate {
  final String id;
  final String title;
  final String category; // 'Workout', 'Cardio', 'Skincare', 'Productivity'
  final String exerciseType; // 'pushup', 'situp', 'squat', 'pullup', 'run', 'walk', 'face_wash', 'moisturizer', 'sunscreen', 'study', 'work'
  final String description;
  final String minRank; // 'F', 'E', 'D', 'C', 'B', 'A', 'S'
  final String unit; // 'Reps', 'KM', 'Mins', 'Check'
  final String statType; // 'STR', 'AGI', 'INT', 'CHA'
  final int statReward;
  final int baseExp;
  final int baseGold;
  final int Function(UserModel player)? calculateTargetReps;
  final double Function(UserModel player)? calculateTargetKm;
  final int Function(UserModel player)? calculateTargetMins;
  final int fixedTarget;

  const QuestTemplate({
    required this.id,
    required this.title,
    required this.category,
    required this.exerciseType,
    required this.description,
    required this.minRank,
    required this.unit,
    required this.statType,
    required this.statReward,
    required this.baseExp,
    required this.baseGold,
    this.calculateTargetReps,
    this.calculateTargetKm,
    this.calculateTargetMins,
    this.fixedTarget = 1,
  });

  /// Menghitung nilai target adaptif berdasarkan profil player
  int getTargetValue(UserModel player) {
    if (calculateTargetReps != null) {
      return calculateTargetReps!(player);
    }
    if (calculateTargetKm != null) {
      return (calculateTargetKm!(player) * 10).round();
    }
    if (calculateTargetMins != null) {
      return calculateTargetMins!(player);
    }
    return fixedTarget;
  }

  /// Teks display target untuk UI (misal: "20 Reps", "3.0 KM", "30 Mins", "2 Check")
  String getDisplayTarget(UserModel player) {
    if (calculateTargetKm != null) {
      final km = calculateTargetKm!(player);
      return '$km KM';
    }
    if (calculateTargetReps != null) {
      return '${calculateTargetReps!(player)} Reps';
    }
    if (calculateTargetMins != null) {
      return '${calculateTargetMins!(player)} Mins';
    }
    return '$fixedTarget $unit';
  }

  /// Membuat QuestModel aktif untuk disimpan ke database lokal Hive
  QuestModel toQuestModel(UserModel player, String scheduledDate) {
    final targetVal = getTargetValue(player);
    final lvl = player.level;
    return QuestModel(
      id: 'template_${id}_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      description: description,
      category: category,
      targetValue: targetVal,
      currentValue: 0,
      unit: unit,
      expReward: baseExp + (lvl * 2),
      goldReward: baseGold + (lvl * 2),
      isCompleted: false,
      isPenaltyQuest: false,
      scheduledDate: scheduledDate,
      isAccepted: false,
      statType: statType,
      statReward: statReward,
    );
  }
}

/// Hasil pengecekan penalti pergantian hari
class DailyPenaltyResult {
  final bool hasPenalty;
  final int hpDeducted;
  final bool isGameOver;
  final bool isDoublePenalty;
  final String message;

  DailyPenaltyResult({
    required this.hasPenalty,
    this.hpDeducted = 0,
    this.isGameOver = false,
    this.isDoublePenalty = false,
    this.message = '',
  });
}

class QuestGeneratorService {
  static final Random _random = Random();

  // ============================================================================
  // ADAPTIVE LOAD HELPERS: Target = Kapasitas_Maks * (0.60 + ((Level - 1) * 0.05))
  // ============================================================================
  static int calculateAdaptiveReps({
    required int maxCapacity,
    required int level,
    int minimum = 5,
  }) {
    final cap = maxCapacity > 0 ? maxCapacity : 15;
    final factor = 0.60 + ((level - 1) * 0.05);
    final target = (cap * factor).round();
    return target < minimum ? minimum : target;
  }

  static double calculateAdaptiveKm({
    required double maxKm,
    required int level,
    double minimum = 1.0,
  }) {
    final km = maxKm > 0 ? maxKm : 2.0;
    final factor = 0.60 + ((level - 1) * 0.05);
    final target = km * factor;
    final rounded = double.parse(target.toStringAsFixed(1));
    return rounded < minimum ? minimum : rounded;
  }

  static int calculateAdaptiveMinutes({
    required int baseMinutes,
    required int level,
    int minimum = 15,
  }) {
    final factor = 0.60 + ((level - 1) * 0.05);
    final target = (baseMinutes * factor).round();
    return target < minimum ? minimum : target;
  }

  // ============================================================================
  // ATURAN 1: DAFTAR TEMPLATE TETAP (HARDCODED) RESMI LEVMAX
  // Dibatasi ketat hanya pada jenis latihan & rutinitas yang diizinkan!
  // ============================================================================
  static final List<QuestTemplate> standardQuestTemplates = [
    // --------------------------------------------------------------------------
    // 1. KATEGORI WORKOUT: HANYA PUSH-UP, SIT-UP, SQUAT, & PULL-UP
    // --------------------------------------------------------------------------
    QuestTemplate(
      id: 'workout_pushup_f',
      title: 'PUSH-UP PROTOCOL',
      category: 'Workout',
      exerciseType: 'pushup',
      description: 'Sensor Accelerometer Push-up Drill untuk melatih dada, bahu, dan trisep.',
      minRank: 'F',
      unit: 'Reps',
      statType: 'STR',
      statReward: 3,
      baseExp: 25,
      baseGold: 20,
      calculateTargetReps: (p) => calculateAdaptiveReps(maxCapacity: p.maxPushup, level: p.level, minimum: 10),
    ),
    QuestTemplate(
      id: 'workout_situp_f',
      title: 'SIT-UP CORE DRILL',
      category: 'Workout',
      exerciseType: 'situp',
      description: 'Latihan penguatan otot inti (core) dan abdomen untuk stabilitas tubuh.',
      minRank: 'F',
      unit: 'Reps',
      statType: 'STR',
      statReward: 3,
      baseExp: 20,
      baseGold: 15,
      calculateTargetReps: (p) => calculateAdaptiveReps(maxCapacity: p.maxSitup, level: p.level, minimum: 10),
    ),
    QuestTemplate(
      id: 'workout_squat_e',
      title: 'SQUAT ENDURANCE PROTOCOL',
      category: 'Workout',
      exerciseType: 'squat',
      description: 'Sensor Accelerometer Squat untuk melatih kekuatan paha depan dan gluteus.',
      minRank: 'E',
      unit: 'Reps',
      statType: 'STR',
      statReward: 4,
      baseExp: 25,
      baseGold: 20,
      calculateTargetReps: (p) => calculateAdaptiveReps(maxCapacity: p.maxSquat, level: p.level, minimum: 12),
    ),
    QuestTemplate(
      id: 'workout_pullup_d',
      title: 'PULL-UP ASCENSION',
      category: 'Workout',
      exerciseType: 'pullup',
      description: 'Latihan pull-up kekuatan upper body tingkat lanjut untuk membangun lats & bicep.',
      minRank: 'D',
      unit: 'Reps',
      statType: 'STR',
      statReward: 5,
      baseExp: 35,
      baseGold: 30,
      calculateTargetReps: (p) => calculateAdaptiveReps(maxCapacity: p.maxPullup, level: p.level, minimum: 3),
    ),
    QuestTemplate(
      id: 'workout_pushup_c',
      title: 'HIGH-INTENSITY PUSH-UP OVERLOAD',
      category: 'Workout',
      exerciseType: 'pushup',
      description: 'Push-up explosif tingkat tinggi untuk memecah batas ketahanan serat otot.',
      minRank: 'C',
      unit: 'Reps',
      statType: 'STR',
      statReward: 5,
      baseExp: 40,
      baseGold: 35,
      calculateTargetReps: (p) => calculateAdaptiveReps(maxCapacity: (p.maxPushup * 1.3).round(), level: p.level, minimum: 20),
    ),
    QuestTemplate(
      id: 'workout_squat_a',
      title: 'COLOSSAL SQUAT POWER',
      category: 'Workout',
      exerciseType: 'squat',
      description: 'Squat intensitas master untuk membangun fondasi kaki kokoh setingkat Elite Hunter.',
      minRank: 'A',
      unit: 'Reps',
      statType: 'STR',
      statReward: 6,
      baseExp: 50,
      baseGold: 45,
      calculateTargetReps: (p) => calculateAdaptiveReps(maxCapacity: (p.maxSquat * 1.4).round(), level: p.level, minimum: 30),
    ),
    QuestTemplate(
      id: 'workout_pullup_s',
      title: 'SHADOW MONARCH PULL-UP OVERDRIVE',
      category: 'Workout',
      exerciseType: 'pullup',
      description: 'Protokol pull-up puncak level S-Rank untuk membuka kekuatan penuh fisik Hunter.',
      minRank: 'S',
      unit: 'Reps',
      statType: 'STR',
      statReward: 8,
      baseExp: 60,
      baseGold: 60,
      calculateTargetReps: (p) => calculateAdaptiveReps(maxCapacity: (p.maxPullup * 1.5).round(), level: p.level, minimum: 8),
    ),

    // --------------------------------------------------------------------------
    // 2. KATEGORI CARDIO: HANYA LARI (RUN) & JALAN (WALK)
    // --------------------------------------------------------------------------
    QuestTemplate(
      id: 'cardio_walk_f',
      title: 'TACTICAL PERIMETER WALK',
      category: 'Cardio',
      exerciseType: 'walk',
      description: 'Jalan santai/cepat untuk membakar kalori harian dan menjaga sirkulasi darah.',
      minRank: 'F',
      unit: 'KM',
      statType: 'AGI',
      statReward: 3,
      baseExp: 20,
      baseGold: 15,
      calculateTargetKm: (p) => calculateAdaptiveKm(maxKm: 2.0, level: p.level, minimum: 1.5),
    ),
    QuestTemplate(
      id: 'cardio_run_e',
      title: 'DUNGEON DISTANCE RUNNING',
      category: 'Cardio',
      exerciseType: 'run',
      description: 'Lari daya tahan dengan pelacakan GPS untuk melatih kapasitas aerobik (VO2Max).',
      minRank: 'E',
      unit: 'KM',
      statType: 'AGI',
      statReward: 5,
      baseExp: 35,
      baseGold: 30,
      calculateTargetKm: (p) => calculateAdaptiveKm(maxKm: p.maxRunKm, level: p.level, minimum: 2.0),
    ),
    QuestTemplate(
      id: 'cardio_walk_d',
      title: 'RECOVERY ENDURANCE WALK',
      category: 'Cardio',
      exerciseType: 'walk',
      description: 'Jalan cepat jarak menengah untuk memulihkan otot tanpa membebani persendian.',
      minRank: 'D',
      unit: 'KM',
      statType: 'AGI',
      statReward: 4,
      baseExp: 25,
      baseGold: 20,
      calculateTargetKm: (p) => calculateAdaptiveKm(maxKm: 3.5, level: p.level, minimum: 2.5),
    ),
    QuestTemplate(
      id: 'cardio_run_c',
      title: '5KM SPRINT RUNNING PROTOCOL',
      category: 'Cardio',
      exerciseType: 'run',
      description: 'Lari tempo tinggi 5 Kilometer untuk melatih akselerasi dan ketahanan fisik.',
      minRank: 'C',
      unit: 'KM',
      statType: 'AGI',
      statReward: 6,
      baseExp: 45,
      baseGold: 40,
      calculateTargetKm: (p) => calculateAdaptiveKm(maxKm: max(5.0, p.maxRunKm * 1.5), level: p.level, minimum: 4.0),
    ),
    QuestTemplate(
      id: 'cardio_run_s',
      title: 'MONARCH 10KM MARATHON SPRINT',
      category: 'Cardio',
      exerciseType: 'run',
      description: 'Lari jarak jauh 10 Kilometer untuk kelincahan dan stamina tak terbatas di medan pertempuran.',
      minRank: 'S',
      unit: 'KM',
      statType: 'AGI',
      statReward: 8,
      baseExp: 70,
      baseGold: 70,
      calculateTargetKm: (p) => calculateAdaptiveKm(maxKm: 10.0, level: p.level, minimum: 7.0),
    ),

    // --------------------------------------------------------------------------
    // 3. KATEGORI SKINCARE: CUCI MUKA, MOISTURIZER, SUNSCREEN
    // --------------------------------------------------------------------------
    const QuestTemplate(
      id: 'skincare_facewash_f',
      title: 'FACIAL CLEANSER WASH',
      category: 'Skincare',
      exerciseType: 'face_wash',
      description: 'Cuci muka dengan facial wash untuk mengangkat minyak berlebih dan debu harian.',
      minRank: 'F',
      unit: 'Check',
      statType: 'CHA',
      statReward: 3,
      baseExp: 15,
      baseGold: 10,
      fixedTarget: 2, // Pagi dan Malam
    ),
    const QuestTemplate(
      id: 'skincare_moisturizer_e',
      title: 'HYDRATING MOISTURIZER BARRIER',
      category: 'Skincare',
      exerciseType: 'moisturizer',
      description: 'Oleskan pelembab wajah secara teratur untuk menjaga hidrasi dan skin barrier.',
      minRank: 'E',
      unit: 'Check',
      statType: 'CHA',
      statReward: 3,
      baseExp: 15,
      baseGold: 10,
      fixedTarget: 2, // Pagi dan Malam
    ),
    const QuestTemplate(
      id: 'skincare_sunscreen_d',
      title: 'UV DEFENSE SUNSCREEN',
      category: 'Skincare',
      exerciseType: 'sunscreen',
      description: 'Aplikasikan sunscreen SPF 30+ sebelum beraktivitas di luar ruangan untuk mencegah penuaan dini.',
      minRank: 'D',
      unit: 'Check',
      statType: 'CHA',
      statReward: 4,
      baseExp: 20,
      baseGold: 15,
      fixedTarget: 1, // Sebelum keluar ruangan
    ),
    const QuestTemplate(
      id: 'skincare_moisturizer_b',
      title: 'ADVANCED NIGHT REPAIR MOISTURIZER',
      category: 'Skincare',
      exerciseType: 'moisturizer',
      description: 'Regenerasi sel kulit wajah dengan pelembab kaya antioksidan sebelum tidur.',
      minRank: 'B',
      unit: 'Check',
      statType: 'CHA',
      statReward: 5,
      baseExp: 25,
      baseGold: 20,
      fixedTarget: 1,
    ),
    const QuestTemplate(
      id: 'skincare_sunscreen_s',
      title: 'AURA SHIELD SUNSCREEN PROTOCOL',
      category: 'Skincare',
      exerciseType: 'sunscreen',
      description: 'Proteksi maksimal spektrum luas SPF 50+ PA++++ menjaga aura wajah Hunter tetap prima.',
      minRank: 'S',
      unit: 'Check',
      statType: 'CHA',
      statReward: 6,
      baseExp: 30,
      baseGold: 30,
      fixedTarget: 2,
    ),

    // --------------------------------------------------------------------------
    // 4. KATEGORI PRODUCTIVITY: STUDY & WORK (DURASI RASIONAL)
    // --------------------------------------------------------------------------
    QuestTemplate(
      id: 'prod_study_f',
      title: 'DEEP FOCUS STUDY',
      category: 'Productivity',
      exerciseType: 'study',
      description: 'Sesi fokus belajar intensif tanpa distraksi layar media sosial dengan sensor postur.',
      minRank: 'F',
      unit: 'Mins',
      statType: 'INT',
      statReward: 4,
      baseExp: 25,
      baseGold: 20,
      calculateTargetMins: (p) => calculateAdaptiveMinutes(baseMinutes: 30, level: p.level, minimum: 20),
    ),
    QuestTemplate(
      id: 'prod_work_e',
      title: 'SYSTEM WORK FLOW',
      category: 'Productivity',
      exerciseType: 'work',
      description: 'Sesi kerja produktif menyelesaikan tugas prioritas dan pengembangan keterampilan.',
      minRank: 'E',
      unit: 'Mins',
      statType: 'INT',
      statReward: 5,
      baseExp: 30,
      baseGold: 25,
      calculateTargetMins: (p) => calculateAdaptiveMinutes(baseMinutes: 45, level: p.level, minimum: 30),
    ),
    QuestTemplate(
      id: 'prod_study_d',
      title: 'INTENSE STUDY MARATHON',
      category: 'Productivity',
      exerciseType: 'study',
      description: 'Sesi studi komprehensif membedah modul pembelajaran dan jurnal sains.',
      minRank: 'D',
      unit: 'Mins',
      statType: 'INT',
      statReward: 5,
      baseExp: 35,
      baseGold: 30,
      calculateTargetMins: (p) => calculateAdaptiveMinutes(baseMinutes: 60, level: p.level, minimum: 45),
    ),
    QuestTemplate(
      id: 'prod_work_b',
      title: 'STRATEGIC WORK SPRINT',
      category: 'Productivity',
      exerciseType: 'work',
      description: 'Sesi kerja intensif 90 menit (1.5 jam) dengan eksekusi fokus dan bebas multitasking.',
      minRank: 'B',
      unit: 'Mins',
      statType: 'INT',
      statReward: 6,
      baseExp: 45,
      baseGold: 40,
      calculateTargetMins: (p) => calculateAdaptiveMinutes(baseMinutes: 90, level: p.level, minimum: 60),
    ),
    QuestTemplate(
      id: 'prod_work_s',
      title: 'MASTER ARCHITECT WORK FLOW',
      category: 'Productivity',
      exerciseType: 'work',
      description: 'Blok kerja 120 menit (2 jam) pemecahan masalah kompleks dengan efisiensi tingkat tinggi.',
      minRank: 'S',
      unit: 'Mins',
      statType: 'INT',
      statReward: 8,
      baseExp: 60,
      baseGold: 60,
      calculateTargetMins: (p) => calculateAdaptiveMinutes(baseMinutes: 120, level: p.level, minimum: 90),
    ),
  ];

  // ============================================================================
  // LOGIKA SISTEM GEMBOK (LOCK / UNLOCK) ENSIKLOPEDIA
  // ============================================================================
  /// Memeriksa apakah sebuah template quest sudah terbuka untuk player saat ini
  static bool isTemplateUnlocked({
    required String minRank,
    required String playerRank,
  }) {
    final playerClean = playerRank.replaceAll('⭐', '').trim().toUpperCase();
    final minRankClean = minRank.replaceAll('⭐', '').trim().toUpperCase();
    final playerIndex = UserModel.rankOrder.indexOf(playerClean);
    final minRankIndex = UserModel.rankOrder.indexOf(minRankClean);

    if (playerIndex == -1 || minRankIndex == -1) return true;
    return playerIndex >= minRankIndex;
  }

  /// Mengambil semua template normal untuk Ensiklopedia Katalog (tanpa quest penalti)
  static List<QuestTemplate> getAllCatalogTemplates() {
    return List.unmodifiable(standardQuestTemplates);
  }

  // ============================================================================
  // GENERATOR POOL QUEST HARIAN BERDASARKAN TEMPLATE RESMI
  // ============================================================================
  static List<QuestModel> generateDailyPoolForPlayer(UserModel player) {
    final today = DateTime.now().toIso8601String().substring(0, 10);

    // Filter template yang sudah terbuka (unlocked) berdasarkan Rank Hunter saat ini
    final unlockedTemplates = standardQuestTemplates.where((t) {
      return isTemplateUnlocked(minRank: t.minRank, playerRank: player.cleanRank);
    }).toList();

    // Kelompokkan per kategori untuk memastikan variasi lengkap 4 pilar
    final workoutList = unlockedTemplates.where((t) => t.category == 'Workout').toList()..shuffle(_random);
    final cardioList = unlockedTemplates.where((t) => t.category == 'Cardio').toList()..shuffle(_random);
    final skincareList = unlockedTemplates.where((t) => t.category == 'Skincare').toList()..shuffle(_random);
    final productivityList = unlockedTemplates.where((t) => t.category == 'Productivity').toList()..shuffle(_random);

    final selectedTemplates = <QuestTemplate>[
      if (workoutList.isNotEmpty) ...workoutList.take(2),
      if (cardioList.isNotEmpty) ...cardioList.take(2),
      if (skincareList.isNotEmpty) ...skincareList.take(2),
      if (productivityList.isNotEmpty) ...productivityList.take(2),
    ]..shuffle(_random);

    return selectedTemplates.map((t) => t.toQuestModel(player, today)).toList();
  }

  // ============================================================================
  // MEMASTIKAN POOL QUEST HARI INI TERSEDIA DI HIVE
  // ============================================================================
  static Future<void> ensureDailyQuestsGenerated(UserModel player) async {
    final box = Hive.box<QuestModel>(HiveBoxes.questBox);
    final today = DateTime.now().toIso8601String().substring(0, 10);

    final todayQuests = box.values.where((q) => q.scheduledDate == today).toList();

    if (todayQuests.isEmpty) {
      debugPrint('[QuestGeneratorService] Men-generate Daily Quest Pool terstandarisasi untuk tanggal: $today');
      final newPool = generateDailyPoolForPlayer(player);

      final initialSlotsToAccept = min(player.maxQuestSlots, 3);
      for (int i = 0; i < newPool.length; i++) {
        if (i < initialSlotsToAccept) {
          newPool[i].isAccepted = true;
        }
        await box.add(newPool[i]);
      }
    }
  }

  // ============================================================================
  // PENGAMBILAN QUEST KE SLOT HARIAN (ATURAN 1: BATAS RANK SLOTS)
  // ============================================================================
  static Future<bool> acceptQuest({
    required QuestModel quest,
    required UserModel player,
  }) async {
    final box = Hive.box<QuestModel>(HiveBoxes.questBox);
    final today = DateTime.now().toIso8601String().substring(0, 10);

    final acceptedCount = box.values.where((q) => q.scheduledDate == today && q.isAccepted).length;

    if (acceptedCount >= player.maxQuestSlots) {
      debugPrint('[QuestGeneratorService] Kuota Quest slots penuh: $acceptedCount / ${player.maxQuestSlots}');
      return false;
    }

    quest.isAccepted = true;
    await quest.save();

    try {
      await SupabaseApiService.syncQuest(quest: quest, userId: player.id);
    } catch (e) {
      debugPrint('[QuestGeneratorService] Sync quest error: $e');
    }

    return true;
  }

  /// Menerima quest langsung dari katalog ke database hari ini
  static Future<bool> acceptQuestFromTemplate({
    required QuestTemplate template,
    required UserModel player,
  }) async {
    final box = Hive.box<QuestModel>(HiveBoxes.questBox);
    final today = DateTime.now().toIso8601String().substring(0, 10);

    final acceptedCount = box.values.where((q) => q.scheduledDate == today && q.isAccepted).length;
    if (acceptedCount >= player.maxQuestSlots) {
      return false;
    }

    final questModel = template.toQuestModel(player, today);
    questModel.isAccepted = true;
    await box.add(questModel);

    try {
      await SupabaseApiService.syncQuest(quest: questModel, userId: player.id);
    } catch (_) {}

    return true;
  }

  // ============================================================================
  // ATURAN 6: PENALTI KERAS & LOGIKA PERGANTIAN HARI
  // ============================================================================
  static Future<DailyPenaltyResult> checkDailyPenaltyStatus(UserModel player) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);

    if (player.lastActiveDate.isEmpty || player.lastActiveDate == today) {
      return DailyPenaltyResult(hasPenalty: false);
    }

    final box = Hive.box<QuestModel>(HiveBoxes.questBox);

    final yesterdayIncompleteQuests = box.values.where((q) {
      return q.scheduledDate != today && q.isAccepted && !q.isCompleted;
    }).toList();

    if (yesterdayIncompleteQuests.isNotEmpty) {
      final bool wasPenaltyAlreadyActive = player.isPenaltyActive;
      final int hpDeduction = wasPenaltyAlreadyActive ? 40 : 20;
      final int newHp = max(0, player.hp - hpDeduction);
      final bool isGameOver = newHp <= 0;

      final penaltyQuest = QuestModel(
        id: 'penalty_drill_${DateTime.now().millisecondsSinceEpoch}',
        title: '⚠️ EMERGENCY DIRECTIVE: PENALTY TRIAL',
        description: 'Selesaikan tap survival mini-game 50x rep atau Push-up 50x untuk memulihkan kehormatan!',
        category: 'Workout',
        targetValue: 50,
        currentValue: 0,
        unit: 'Reps',
        expReward: 10,
        goldReward: 5,
        isCompleted: false,
        isPenaltyQuest: true,
        scheduledDate: today,
        isAccepted: true,
        statType: 'STR',
        statReward: 1,
      );
      await box.add(penaltyQuest);

      final updatedPlayer = player.copyWith(
        hp: newHp,
        isPenaltyActive: true,
        lastActiveDate: today,
      );

      await SupabaseApiService.savePlayerCache(updatedPlayer);
      try {
        await SupabaseApiService.updateUser(updatedPlayer);
      } catch (_) {}

      await NotificationService.showPenaltyNotification(hpDeduction: hpDeduction);

      return DailyPenaltyResult(
        hasPenalty: true,
        hpDeducted: hpDeduction,
        isGameOver: isGameOver,
        isDoublePenalty: wasPenaltyAlreadyActive,
        message: wasPenaltyAlreadyActive
            ? 'PENGURANGAN GANDA! Penalti kemarin diabaikan. -$hpDeduction HP!'
            : 'QUEST MANGKIR! Anda tidak menyelesaikan Daily Quest kemarin. -$hpDeduction HP.',
      );
    } else {
      final updatedPlayer = player.copyWith(
        lastActiveDate: today,
        isPenaltyActive: false,
      );
      await SupabaseApiService.savePlayerCache(updatedPlayer);
      try {
        await SupabaseApiService.updateUser(updatedPlayer);
      } catch (_) {}

      return DailyPenaltyResult(hasPenalty: false);
    }
  }
}
