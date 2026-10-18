// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/models/user_model.dart
// Deskripsi: Model Player/User sesuai Tabel 'users' Supabase & Cache Hive
//            Mencakup Atribut RPG, Data Fisik BMI, & Helper Game Balancing
// ==============================================================================

import 'package:flutter/material.dart';

class UserModel {
  final int id;
  final String username;
  final String email;
  final String passwordHash;
  final bool biometricEnabled;
  final bool isOnboarded;

  // Statistik Fisik Awal (Onboarding)
  final double tbCm;
  final double bbKg;
  final double bmi;
  final int maxPushup;
  final int maxSitup;
  final int maxSquat;
  final int maxPullup;
  final double maxRunKm;
  final double pace2kmMenit;

  // Atribut Gamifikasi Solo Leveling (Status Window)
  final int level;
  final String rank; // F, E, D, C, B, A, S
  final int hp; // Maks 100, jika <= 0 = Game Over
  final int exp; // Setiap 100 EXP = Level Up
  final int gold; // Diuangkan di Guild Exchange (1 Gold = Rp 1.000)
  final bool isPenaltyActive;
  final String lastActiveDate; // Format YYYY-MM-DD
  final String createdAt;

  UserModel({
    this.id = 0,
    required this.username,
    required this.email,
    this.passwordHash = '',
    this.biometricEnabled = false,
    this.isOnboarded = false,
    this.tbCm = 0.0,
    this.bbKg = 0.0,
    this.bmi = 0.0,
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
    this.isPenaltyActive = false,
    this.lastActiveDate = '',
    this.createdAt = '',
  });

  /// Factory untuk membuat UserModel baru dengan nilai default awal
  factory UserModel.initial({
    required int id,
    required String username,
    required String email,
    String passwordHash = '',
    bool biometricEnabled = false,
  }) {
    return UserModel(
      id: id,
      username: username,
      email: email,
      passwordHash: passwordHash,
      biometricEnabled: biometricEnabled,
      isOnboarded: false,
      tbCm: 170.0,
      bbKg: 65.0,
      bmi: 22.49,
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
      isPenaltyActive: false,
      lastActiveDate: DateTime.now().toIso8601String().substring(0, 10),
      createdAt: DateTime.now().toIso8601String(),
    );
  }

  /// Kalkulasi Rank otomatis berdasarkan Level (Bab 5 Rules)
  static String calculateRank(int lvl) {
    if (lvl >= 30) return 'S';
    if (lvl >= 21) return 'A';
    if (lvl >= 15) return 'B';
    if (lvl >= 10) return 'C';
    if (lvl >= 6) return 'D';
    if (lvl >= 3) return 'E';
    return 'F';
  }

  /// Gelar / Title Hunter berdasarkan Rank
  String get rankTitle {
    switch (rank.toUpperCase()) {
      case 'S':
        return 'Shadow Monarch';
      case 'A':
        return 'National Level Hunter';
      case 'B':
        return 'Elite Hunter';
      case 'C':
        return 'High Achiever';
      case 'D':
        return 'Iron Disciplined';
      case 'E':
        return 'Awakened Novice';
      default:
        return 'Unawakened Trainee';
    }
  }

  /// Warna bingkai avatar sesuai Rank (Bab 5 Rules)
  Color get rankColor {
    switch (rank.toUpperCase()) {
      case 'S':
        return const Color(0xFF7B1FA2); // Deep Purple dengan glow
      case 'A':
        return const Color(0xFFD500F9); // Purple Accent
      case 'B':
        return const Color(0xFF00E5FF); // Cyan Accent
      case 'C':
        return const Color(0xFFFFB300); // Amber / Gold
      case 'D':
        return const Color(0xFF607D8B); // Blue Grey
      case 'E':
        return const Color(0xFF795548); // Brown
      default:
        return const Color(0xFF9E9E9E); // Grey
    }
  }

  /// Warna sekunder untuk efek gradien border frame
  Color get rankColorSecondary {
    switch (rank.toUpperCase()) {
      case 'S':
        return const Color(0xFFFFD700); // Emas berkilau Solo Leveling
      case 'A':
        return const Color(0xFF651FFF);
      case 'B':
        return const Color(0xFF2979FF);
      case 'C':
        return const Color(0xFFFF6D00);
      case 'D':
        return const Color(0xFF455A64);
      case 'E':
        return const Color(0xFF4E342E);
      default:
        return const Color(0xFF616161);
    }
  }

  /// Kategori BMI (Underweight, Normal, Overweight)
  String get bmiCategory {
    if (bmi < 18.5) return 'Underweight (Kurang BB)';
    if (bmi <= 24.9) return 'Normal (Ideal)';
    if (bmi <= 29.9) return 'Overweight (Kelebihan BB)';
    return 'Obese (Obesitas)';
  }

  /// Rekomendasi latihan sesuai kategori BMI
  String get bmiRecommendation {
    if (bmi < 18.5) {
      return 'Fokus: Strength Workout (Massa Otot) & Asupan Kalori Tinggi Protein.';
    } else if (bmi <= 24.9) {
      return 'Fokus: Seimbang (Workout, Cardio, Skincare Looksmaxxing, & Disiplin Belajar).';
    } else {
      return 'Fokus: Cardio (Run/Jogging) Defisit Kalori & Latihan Endurance.';
    }
  }

  /// Rumus Target Adaptif Harian (Bab 5 Rules):
  /// targetHariIni = (kapasitasMaks * (0.60 + ((level - 1) * 0.05))).round()
  int calculateAdaptiveTarget(int kapasitasMaks) {
    if (kapasitasMaks <= 0) kapasitasMaks = 10;
    final factor = 0.60 + ((level - 1) * 0.05);
    final target = (kapasitasMaks * factor).round();
    return target < 1 ? 1 : target;
  }

  /// Rumus Target Adaptif Lari (Km)
  double calculateAdaptiveRunKm(double maxKm) {
    if (maxKm <= 0) maxKm = 2.0;
    final factor = 0.60 + ((level - 1) * 0.05);
    final target = maxKm * factor;
    return double.parse(target.toStringAsFixed(1));
  }

  /// Mengonversi objek ke Map persis sesuai nama kolom Supabase SQL
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'password_hash': passwordHash,
      'biometric_enabled': biometricEnabled,
      'is_onboarded': isOnboarded,
      'tb_cm': tbCm,
      'bb_kg': bbKg,
      'bmi': bmi,
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
      'is_penalty_active': isPenaltyActive,
      'last_active_date': lastActiveDate,
      'created_at': createdAt,
    };
  }

  /// Mengonversi Map (dari Supabase / Hive JSON) ke objek UserModel
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] is int ? map['id'] : int.tryParse(map['id']?.toString() ?? '0') ?? 0,
      username: map['username']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      passwordHash: map['password_hash']?.toString() ?? '',
      biometricEnabled: map['biometric_enabled'] == true,
      isOnboarded: map['is_onboarded'] == true,
      tbCm: (map['tb_cm'] is num) ? (map['tb_cm'] as num).toDouble() : double.tryParse(map['tb_cm']?.toString() ?? '0') ?? 0.0,
      bbKg: (map['bb_kg'] is num) ? (map['bb_kg'] as num).toDouble() : double.tryParse(map['bb_kg']?.toString() ?? '0') ?? 0.0,
      bmi: (map['bmi'] is num) ? (map['bmi'] as num).toDouble() : double.tryParse(map['bmi']?.toString() ?? '0') ?? 0.0,
      maxPushup: map['max_pushup'] is int ? map['max_pushup'] : int.tryParse(map['max_pushup']?.toString() ?? '10') ?? 10,
      maxSitup: map['max_situp'] is int ? map['max_situp'] : int.tryParse(map['max_situp']?.toString() ?? '10') ?? 10,
      maxSquat: map['max_squat'] is int ? map['max_squat'] : int.tryParse(map['max_squat']?.toString() ?? '10') ?? 10,
      maxPullup: map['max_pullup'] is int ? map['max_pullup'] : int.tryParse(map['max_pullup']?.toString() ?? '5') ?? 5,
      maxRunKm: (map['max_run_km'] is num) ? (map['max_run_km'] as num).toDouble() : double.tryParse(map['max_run_km']?.toString() ?? '2.0') ?? 2.0,
      pace2kmMenit: (map['pace_2km_menit'] is num) ? (map['pace_2km_menit'] as num).toDouble() : double.tryParse(map['pace_2km_menit']?.toString() ?? '15.0') ?? 15.0,
      level: map['level'] is int ? map['level'] : int.tryParse(map['level']?.toString() ?? '1') ?? 1,
      rank: map['rank']?.toString() ?? 'F',
      hp: map['hp'] is int ? map['hp'] : int.tryParse(map['hp']?.toString() ?? '100') ?? 100,
      exp: map['exp'] is int ? map['exp'] : int.tryParse(map['exp']?.toString() ?? '0') ?? 0,
      gold: map['gold'] is int ? map['gold'] : int.tryParse(map['gold']?.toString() ?? '0') ?? 0,
      isPenaltyActive: map['is_penalty_active'] == true,
      lastActiveDate: map['last_active_date']?.toString() ?? '',
      createdAt: map['created_at']?.toString() ?? '',
    );
  }

  /// Membuat salinan objek dengan modifikasi nilai tertentu
  UserModel copyWith({
    int? id,
    String? username,
    String? email,
    String? passwordHash,
    bool? biometricEnabled,
    bool? isOnboarded,
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
    bool? isPenaltyActive,
    String? lastActiveDate,
    String? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      isOnboarded: isOnboarded ?? this.isOnboarded,
      tbCm: tbCm ?? this.tbCm,
      bbKg: bbKg ?? this.bbKg,
      bmi: bmi ?? this.bmi,
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
      isPenaltyActive: isPenaltyActive ?? this.isPenaltyActive,
      lastActiveDate: lastActiveDate ?? this.lastActiveDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
