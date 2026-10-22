// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/helpers/game_rules.dart
// Deskripsi: Single Source of Truth untuk Game Balancing, Rank Progression,
//            Quest Multiplier, Workout Scaling, dan Aturan Penalti (GDD).
// ==============================================================================

/// ============================================================================
/// 1. RANK PROGRESSION CONFIGURATION
/// ============================================================================
class RankConfig {
  final String currentRank;
  final String targetRank;
  final int requiredExp; // -1 untuk Uncapped (Mode Leaderboard)
  final int
  minAllStat; // Syarat minimal untuk seluruh stat (STR, AGI, INT, CHA)
  final int baseExpPerQuest;
  final String description;

  const RankConfig({
    required this.currentRank,
    required this.targetRank,
    required this.requiredExp,
    required this.minAllStat,
    required this.baseExpPerQuest,
    required this.description,
  });

  /// Master Map konfigurasi Rank sesuai Bab 4 GDD
  static const Map<String, RankConfig> table = {
    'F': RankConfig(
      currentRank: 'F',
      targetRank: 'E',
      requiredExp: 1000,
      minAllStat: 2,
      baseExpPerQuest: 50,
      description: 'The Weakest Hunter (Baseline Awakening)',
    ),
    'E': RankConfig(
      currentRank: 'E',
      targetRank: 'D',
      requiredExp: 2500,
      minAllStat: 5,
      baseExpPerQuest: 50,
      description: 'Low-Rank Hunter (Fisik Dasar Terbentuk)',
    ),
    'D': RankConfig(
      currentRank: 'D',
      targetRank: 'C',
      requiredExp: 6000,
      minAllStat: 12,
      baseExpPerQuest: 120,
      description: 'Novice Hunter (Kedisiplinan Konsisten)',
    ),
    'C': RankConfig(
      currentRank: 'C',
      targetRank: 'B',
      requiredExp: 14500,
      minAllStat: 25,
      baseExpPerQuest: 120,
      description: 'Mid-Rank Hunter (Kapasitas Menengah)',
    ),
    'B': RankConfig(
      currentRank: 'B',
      targetRank: 'A',
      requiredExp: 32000,
      minAllStat: 40,
      baseExpPerQuest: 250,
      description: 'High-Rank Hunter (Penguasaan Atribut Tinggi)',
    ),
    'A': RankConfig(
      currentRank: 'A',
      targetRank: 'S',
      requiredExp: 65000,
      minAllStat: 60,
      baseExpPerQuest: 250,
      description: 'Elite Hunter (Ambang Batas Tertinggi)',
    ),
    'S': RankConfig(
      currentRank: 'S',
      targetRank: 'S (Uncapped)',
      requiredExp: -1, // Uncapped (Mode Leaderboard)
      minAllStat: 80,
      baseExpPerQuest: 450,
      description: 'National Level / Monarch (Puncak Tertinggi)',
    ),
  };

  /// Mengambil konfigurasi lengkap berdasarkan Rank
  static RankConfig getConfig(String rank) {
    return table[rank.toUpperCase()] ?? table['F']!;
  }

  /// Mengambil EXP yang dibutuhkan untuk naik dari rank saat ini ke target berikutnya
  static int getRequiredExp(String rank) => getConfig(rank).requiredExp;

  /// Mengambil syarat batas minimal seluruh atribut (STR, AGI, INT, CHA)
  static int getMinStat(String rank) => getConfig(rank).minAllStat;

  /// Mengambil Base EXP per quest sesuai rank
  static int getBaseExp(String rank) => getConfig(rank).baseExpPerQuest;

  /// Memeriksa apakah seorang player berhak naik Rank
  static bool canRankUp({
    required String currentRank,
    required int currentExp,
    required int minStatValue,
  }) {
    final cfg = getConfig(currentRank);
    if (cfg.requiredExp == -1) return false; // Rank S uncapped
    return currentExp >= cfg.requiredExp && minStatValue >= cfg.minAllStat;
  }
}

/// ============================================================================
/// 2. QUEST MULTIPLIER (PENGGANDA EXP BERDASARKAN KESULITAN)
/// ============================================================================
class QuestMultiplier {
  /// Workout & Cardio (Fisik Berat): 1.5x
  static const double physical = 1.5;

  /// Study (Kognitif Standar): 1.2x
  static const double cognitive = 1.2;

  /// Study jika banyak salah (< 50% akurasi kuis): 0.5x
  static const double cognitivePenalty = 0.5;

  /// Appearance / Perawatan Diri: 1.0x
  static const double appearance = 1.0;

  /// Mystery Quest (Misi Kejutan): 2.5x
  static const double mysteryQuest = 2.5;

  /// Menghitung total EXP yang didapat dengan menerapkan multiplier
  static int calculateExp({
    required String category,
    required int baseExp,
    double quizAccuracy = 1.0,
    bool isMystery = false,
  }) {
    if (isMystery) {
      return (baseExp * mysteryQuest).round();
    }

    final cat = category.toLowerCase();
    if (cat.contains('workout') || cat.contains('cardio')) {
      return (baseExp * physical).round();
    } else if (cat.contains('study') || cat.contains('trivia')) {
      final mult = quizAccuracy >= 0.5 ? cognitive : cognitivePenalty;
      return (baseExp * mult * quizAccuracy.clamp(0.5, 1.0)).round();
    } else if (cat.contains('appearance') || cat.contains('skincare')) {
      return (baseExp * appearance).round();
    }
    return baseExp;
  }
}

/// ============================================================================
/// 3. WORKOUT & CARDIO SCALING BERDASARKAN RANK
/// ============================================================================
class WorkoutTargets {
  final int pushUp;
  final int sitUp;
  final int pullUp;
  final int squat;
  final double walkingKm;
  final double runningKm;

  const WorkoutTargets({
    required this.pushUp,
    required this.sitUp,
    required this.pullUp,
    required this.squat,
    required this.walkingKm,
    required this.runningKm,
  });
}

class WorkoutScaling {
  /// Master Map target repetisi latihan fisik dan cardio sesuai Bab 5 GDD
  static const Map<String, WorkoutTargets> targets = {
    'F': WorkoutTargets(
      pushUp: 10,
      sitUp: 15,
      pullUp: 2,
      squat: 15,
      walkingKm: 1.0,
      runningKm: 0.5,
    ),
    'E': WorkoutTargets(
      pushUp: 15,
      sitUp: 20,
      pullUp: 5,
      squat: 25,
      walkingKm: 1.5,
      runningKm: 1.0,
    ),
    'D': WorkoutTargets(
      pushUp: 25,
      sitUp: 35,
      pullUp: 8,
      squat: 40,
      walkingKm: 2.5,
      runningKm: 1.5,
    ),
    'C': WorkoutTargets(
      pushUp: 40,
      sitUp: 50,
      pullUp: 12,
      squat: 60,
      walkingKm: 3.5,
      runningKm: 2.5,
    ),
    'B': WorkoutTargets(
      pushUp: 60,
      sitUp: 70,
      pullUp: 20,
      squat: 80,
      walkingKm: 5.0,
      runningKm: 4.0,
    ),
    'A': WorkoutTargets(
      pushUp: 80,
      sitUp: 90,
      pullUp: 30,
      squat: 100,
      walkingKm: 7.0,
      runningKm: 6.0,
    ),
    'S': WorkoutTargets(
      pushUp: 100,
      sitUp: 120,
      pullUp: 40,
      squat: 150,
      walkingKm: 10.0,
      runningKm: 8.0,
    ),
  };

  /// Mengambil seluruh paket target latihan untuk Rank tertentu
  static WorkoutTargets getTargets(String rank) {
    return targets[rank.toUpperCase()] ?? targets['F']!;
  }

  /// Mengambil target repetisi Push Up (contoh: 'D' -> 25)
  static int getPushUpTarget(String rank) => getTargets(rank).pushUp;

  /// Mengambil target repetisi Sit Up (contoh: 'D' -> 35)
  static int getSitUpTarget(String rank) => getTargets(rank).sitUp;

  /// Mengambil target repetisi Pull Up (contoh: 'D' -> 8)
  static int getPullUpTarget(String rank) => getTargets(rank).pullUp;

  /// Mengambil target repetisi Squat (contoh: 'D' -> 40)
  static int getSquatTarget(String rank) => getTargets(rank).squat;

  /// Mengambil target jarak jalan kaki dalam Kilometer (contoh: 'D' -> 2.5)
  static double getWalkingTargetKm(String rank) => getTargets(rank).walkingKm;

  /// Mengambil target jarak lari dalam Kilometer (contoh: 'D' -> 1.5)
  static double getRunningTargetKm(String rank) => getTargets(rank).runningKm;

  /// Helper dinamis berdasarkan nama latihan (case-insensitive)
  static int getExerciseTarget(String rank, String exerciseName) {
    final t = getTargets(rank);
    final ex = exerciseName.toLowerCase();
    if (ex.contains('push')) return t.pushUp;
    if (ex.contains('sit')) return t.sitUp;
    if (ex.contains('pull')) return t.pullUp;
    if (ex.contains('squat')) return t.squat;
    return t.pushUp;
  }
}

/// ============================================================================
/// 4. ATURAN PENALTI & KEWAJIBAN HARIAN (DAILY OBLIGATIONS)
/// ============================================================================
class PenaltyRules {
  /// Pelipatgandaan beban quest yang tertinggal (x2)
  static const int penaltyMultiplier = 2;

  /// Pengurangan HP default saat pengguna melalaikan quest harian
  static const int defaultHpDeduction = 20;

  /// Jam reset harian sistem (Pukul 00:00 midnight)
  static const int resetHour = 0;
  static const int resetMinute = 0;

  /// Batas jam buka Checklist Appearance malam (Pukul 21:00)
  static const int appearanceAvailableHour = 21;

  /// Batas kecepatan lari/jalan sensor accelerometer/pedometer (Anti-Cheat Kendaraan)
  static const double maxCardioSpeedKmh = 15.0;

  /// Kuota mingguan Mystery Quest dari minigames
  static const int maxWeeklyMysteryQuests = 3;

  /// Kuota harian Mystery Quest
  static const int maxDailyMysteryQuests = 1;

  /// Minimal jenis Workout yang wajib diselesaikan per hari
  static const int minWorkoutTypesPerDay = 2;

  /// Frekuensi Cardio: Minimal 1 jenis setiap 3 hari
  static const int cardioIntervalDays = 3;

  /// Menghitung beban repetisi penalti yang dikalikan dua
  static int calculatePenaltyTarget(
    int missedTargetValue, {
    int multiplier = penaltyMultiplier,
  }) {
    return missedTargetValue * multiplier;
  }
}

/// Konstanta Aturan Penalti Top-Level (Sesuai Spesifikasi Prompt)
const int penaltyMultiplier = PenaltyRules.penaltyMultiplier;
