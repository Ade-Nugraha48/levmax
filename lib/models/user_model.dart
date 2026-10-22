// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/models/user_model.dart
// Deskripsi: Model Pengguna/Player dengan UUID (String), Atribut RPG Seimbang
//            (STR, AGI, INT, CHA), Data Fisik (height, weight, bmi_score),
//            serta helper gamifikasi Leveling & Rank Solo Leveling.
// ==============================================================================

class UserModel {
  final String id; // UUID String
  final String username;
  final String email;
  final String passwordHash;
  final bool biometricEnabled;
  final bool isOnboarded;

  // Statistik Fisik (Antropometri & Kalibrasi Awal)
  final int height; // Dalam cm (contoh: 175)
  final double weight; // Dalam kg (contoh: 68.5)
  final double bmiScore; // BMI Index (contoh: 22.37)
  final int maxPushup;
  final int maxSitup;
  final int maxSquat;
  final int maxPullup;
  final double maxRunKm;
  final double pace2kmMenit;

  // Atribut Gamifikasi Solo Leveling (Status Window)
  final int level;
  final String rank; // F, E, D, C, B, A, S
  final int hp; // 0 - 100, jika <= 0 = Game Over
  final int exp; // EXP saat ini menuju Level Up berikutnya
  final int gold; // Mata uang virtual Vault

  // 4 Pilar Atribut RPG Utama
  final int str; // Kekuatan (Strength)
  final int agi; // Kelincahan (Agility)
  final int intStat; // Kepintaran (Intelligence, mapping dari kolom 'int')
  final int cha; // Kharisma (Charisma)

  // Status Penalti & Tracking Waktu
  final bool isPenaltyActive;
  final String lastActiveDate; // Format YYYY-MM-DD
  final String createdAt;

  UserModel({
    dynamic id = '',
    required this.username,
    required this.email,
    this.passwordHash = '',
    this.biometricEnabled = false,
    this.isOnboarded = false,
    int? height,
    double? weight,
    double? bmiScore,
    double? tbCm,
    double? bbKg,
    double? bmi,
    this.maxPushup = 10,
    this.maxSitup = 10,
    this.maxSquat = 10,
    this.maxPullup = 5,
    this.maxRunKm = 2.0,
    this.pace2kmMenit = 15.0,
    this.level = 1,
    this.rank = 'F',
    this.hp = 100,
    this.exp = 0,
    this.gold = 0,
    this.str = 10,
    this.agi = 10,
    this.intStat = 10,
    this.cha = 10,
    this.isPenaltyActive = false,
    this.lastActiveDate = '',
    this.createdAt = '',
  }) : id = id?.toString() ?? '',
       height = height ?? (tbCm != null ? tbCm.toInt() : 170),
       weight = weight ?? (bbKg ?? 65.0),
       bmiScore = bmiScore ?? (bmi ?? 22.49);

  // ============================================================================
  // GETTERS UNTUK KOMPATIBILITAS KODE LAMA (BACKWARD COMPATIBILITY)
  // ============================================================================
  double get tbCm => height.toDouble();
  double get bbKg => weight;
  double get bmi => bmiScore;

  /// Kategori BMI (Underweight, Normal, Overweight, Obese)
  String get bmiCategory {
    if (bmiScore < 18.5) return 'Underweight';
    if (bmiScore < 25.0) return 'Normal';
    if (bmiScore < 30.0) return 'Overweight';
    return 'Obese';
  }

  /// Gelar Kehormatan berdasarkan Rank
  String get rankTitle {
    switch (rank.toUpperCase()) {
      case 'S':
        return 'National Level / Monarch';
      case 'A':
        return 'Elite Hunter';
      case 'B':
        return 'High-Rank Hunter';
      case 'C':
        return 'Mid-Rank Hunter';
      case 'D':
        return 'Novice Hunter';
      case 'E':
        return 'Low-Rank Hunter';
      default:
        return 'The Weakest Hunter';
    }
  }

  /// Nilai rata-rata dari keempat atribut RPG
  double get averageStat => (str + agi + intStat + cha) / 4.0;

  /// Nilai atribut terlemah
  int get minStat => [str, agi, intStat, cha].reduce((a, b) => a < b ? a : b);

  /// Nilai atribut terkuat
  int get maxStat => [str, agi, intStat, cha].reduce((a, b) => a > b ? a : b);

  /// Memeriksa apakah distribusi atribut seimbang (selisih max - min <= 35)
  bool get isBalanced => (maxStat - minStat) <= 35;

  /// Factory untuk membuat UserModel baru dengan nilai default
  factory UserModel.initial({
    dynamic id,
    required String username,
    required String email,
    String passwordHash = '',
    bool biometricEnabled = false,
  }) {
    final now = DateTime.now();
    return UserModel(
      id: id?.toString() ?? '',
      username: username,
      email: email,
      passwordHash: passwordHash,
      biometricEnabled: biometricEnabled,
      isOnboarded: false,
      height: 170,
      weight: 65.0,
      bmiScore: 22.49,
      maxPushup: 10,
      maxSitup: 10,
      maxSquat: 10,
      maxPullup: 5,
      maxRunKm: 2.0,
      pace2kmMenit: 15.0,
      level: 1,
      rank: 'F',
      hp: 100,
      exp: 0,
      gold: 0,
      str: 10,
      agi: 10,
      intStat: 10,
      cha: 10,
      isPenaltyActive: false,
      lastActiveDate: now.toIso8601String().substring(0, 10),
      createdAt: now.toIso8601String(),
    );
  }

  /// Deserialisasi dari JSON Supabase PostgREST
  factory UserModel.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final idString = rawId != null ? rawId.toString() : '';

    int parseHeight() {
      if (json['height'] != null) {
        return (json['height'] is num)
            ? (json['height'] as num).toInt()
            : int.tryParse(json['height'].toString()) ?? 170;
      }
      if (json['tb_cm'] != null) {
        return (json['tb_cm'] is num)
            ? (json['tb_cm'] as num).toInt()
            : (double.tryParse(json['tb_cm'].toString())?.toInt() ?? 170);
      }
      return 170;
    }

    double parseWeight() {
      final raw = json['weight'] ?? json['bb_kg'];
      if (raw is num) return raw.toDouble();
      return double.tryParse(raw?.toString() ?? '65.0') ?? 65.0;
    }

    double parseBmi() {
      final raw = json['bmi_score'] ?? json['bmi'];
      if (raw is num) return raw.toDouble();
      return double.tryParse(raw?.toString() ?? '22.49') ?? 22.49;
    }

    int parseIntStat() {
      final raw = json['int'] ?? json['int_stat'] ?? json['intStat'];
      if (raw is num) return raw.toInt();
      return int.tryParse(raw?.toString() ?? '10') ?? 10;
    }

    int parseNum(dynamic val, int defaultVal) {
      if (val is num) return val.toInt();
      return int.tryParse(val?.toString() ?? '$defaultVal') ?? defaultVal;
    }

    double parseDouble(dynamic val, double defaultVal) {
      if (val is num) return val.toDouble();
      return double.tryParse(val?.toString() ?? '$defaultVal') ?? defaultVal;
    }

    return UserModel(
      id: idString,
      username: json['username']?.toString() ?? 'Hunter',
      email: json['email']?.toString() ?? '',
      passwordHash: json['password_hash']?.toString() ?? '',
      biometricEnabled: json['biometric_enabled'] as bool? ?? false,
      isOnboarded: json['is_onboarded'] as bool? ?? false,
      height: parseHeight(),
      weight: parseWeight(),
      bmiScore: parseBmi(),
      maxPushup: parseNum(json['max_pushup'], 10),
      maxSitup: parseNum(json['max_situp'], 10),
      maxSquat: parseNum(json['max_squat'], 10),
      maxPullup: parseNum(json['max_pullup'], 5),
      maxRunKm: parseDouble(json['max_run_km'], 2.0),
      pace2kmMenit: parseDouble(json['pace_2km_menit'], 15.0),
      level: parseNum(json['level'], 1),
      rank: json['rank']?.toString().toUpperCase() ?? 'F',
      hp: parseNum(json['hp'], 100),
      exp: parseNum(json['exp'], 0),
      gold: parseNum(json['gold'], 0),
      str: parseNum(json['str'], 10),
      agi: parseNum(json['agi'], 10),
      intStat: parseIntStat(),
      cha: parseNum(json['cha'], 10),
      isPenaltyActive: json['is_penalty_active'] as bool? ?? false,
      lastActiveDate: json['last_active_date']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }

  /// Serialisasi ke JSON Map untuk dikirim ke Supabase REST API
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'username': username,
      'email': email,
      'biometric_enabled': biometricEnabled,
      'is_onboarded': isOnboarded,
      'height': height,
      'weight': weight,
      'bmi_score': bmiScore,
      'tb_cm': height.toDouble(),
      'bb_kg': weight,
      'bmi': bmiScore,
      'max_pushup': maxPushup,
      'max_situp': maxSitup,
      'max_squat': maxSquat,
      'max_pullup': maxPullup,
      'max_run_km': maxRunKm,
      'pace_2km_menit': pace2kmMenit,
      'level': level,
      'rank': rank,
      'hp': hp,
      'exp': exp,
      'gold': gold,
      'str': str,
      'agi': agi,
      'int': intStat, // Mapping resmi ke kolom 'int' PostgreSQL
      'int_stat': intStat, // Alias untuk kompatibilitas
      'cha': cha,
      'is_penalty_active': isPenaltyActive,
      'last_active_date': lastActiveDate.isNotEmpty
          ? lastActiveDate
          : DateTime.now().toIso8601String().substring(0, 10),
    };

    if (id.isNotEmpty) {
      map['id'] = id;
    }
    if (passwordHash.isNotEmpty) {
      map['password_hash'] = passwordHash;
    }
    if (createdAt.isNotEmpty) {
      map['created_at'] = createdAt;
    }
    return map;
  }

  /// Serialisasi ke JSON Map khusus tabel 'users' di Supabase Cloud Database.
  /// Hanya menyertakan 17 kolom resmi Supabase PostgreSQL:
  /// id, email, username, password_hash, height, weight, bmi_score, rank,
  /// exp, hp, str, agi, int, cha, gold, is_onboarded, created_at.
  Map<String, dynamic> toSupabaseJson() {
    final map = <String, dynamic>{
      'username': username,
      'email': email,
      'height': height,
      'weight': weight,
      'bmi_score': bmiScore,
      'rank': rank,
      'exp': exp,
      'hp': hp,
      'str': str,
      'agi': agi,
      'int': intStat,
      'cha': cha,
      'gold': gold,
      'is_onboarded': isOnboarded,
    };

    // Sertakan id HANYA jika berupa format valid UUID RFC 4122 (36 karakter)
    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    if (id.isNotEmpty && uuidRegex.hasMatch(id)) {
      map['id'] = id;
    }

    if (passwordHash.isNotEmpty) {
      map['password_hash'] = passwordHash;
    }

    if (createdAt.isNotEmpty) {
      map['created_at'] = createdAt;
    }

    return map;
  }

  Map<String, dynamic> toMap() => toJson();
  factory UserModel.fromMap(Map<String, dynamic> map) =>
      UserModel.fromJson(map);

  UserModel copyWith({
    dynamic id,
    String? username,
    String? email,
    String? passwordHash,
    bool? biometricEnabled,
    bool? isOnboarded,
    int? height,
    double? weight,
    double? bmiScore,
    double? tbCm,
    double? bbKg,
    double? bmi,
    int? maxPushup,
    int? maxSitup,
    int? maxSquat,
    int? maxPullup,
    double? maxRunKm,
    double? pace2kmMenit,
    int? level,
    String? rank,
    int? hp,
    int? exp,
    int? gold,
    int? str,
    int? agi,
    int? intStat,
    int? cha,
    bool? isPenaltyActive,
    String? lastActiveDate,
    String? createdAt,
  }) {
    return UserModel(
      id: id?.toString() ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      isOnboarded: isOnboarded ?? this.isOnboarded,
      height: height ?? (tbCm != null ? tbCm.toInt() : this.height),
      weight: weight ?? (bbKg ?? this.weight),
      bmiScore: bmiScore ?? (bmi ?? this.bmiScore),
      maxPushup: maxPushup ?? this.maxPushup,
      maxSitup: maxSitup ?? this.maxSitup,
      maxSquat: maxSquat ?? this.maxSquat,
      maxPullup: maxPullup ?? this.maxPullup,
      maxRunKm: maxRunKm ?? this.maxRunKm,
      pace2kmMenit: pace2kmMenit ?? this.pace2kmMenit,
      level: level ?? this.level,
      rank: rank ?? this.rank,
      hp: hp ?? this.hp,
      exp: exp ?? this.exp,
      gold: gold ?? this.gold,
      str: str ?? this.str,
      agi: agi ?? this.agi,
      intStat: intStat ?? this.intStat,
      cha: cha ?? this.cha,
      isPenaltyActive: isPenaltyActive ?? this.isPenaltyActive,
      lastActiveDate: lastActiveDate ?? this.lastActiveDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Menghitung Rank otomatis berdasarkan Level dan Keseimbangan Stat (Bab 5 Rules)
  static String calculateRank(int level, {int? minStatValue}) {
    final minS = minStatValue ?? (level * 2);
    if (level >= 91 && minS >= 225) return 'S';
    if (level >= 71 && minS >= 165) return 'A';
    if (level >= 51 && minS >= 115) return 'B';
    if (level >= 31 && minS >= 75) return 'C';
    if (level >= 16 && minS >= 45) return 'D';
    if (level >= 6 && minS >= 20) return 'E';
    return 'F';
  }
}
