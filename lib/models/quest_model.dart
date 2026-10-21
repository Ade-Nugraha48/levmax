// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/models/quest_model.dart
// Deskripsi: Model HiveObject untuk Daily Quest, Plan Esok Hari, & Penalti Quest.
//            Dilengkapi TypeAdapter manual (typeId: 0) tanpa perlu build_runner.
// ==============================================================================

import 'package:hive/hive.dart';

@HiveType(typeId: 0)
class QuestModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String description;

  @HiveField(3)
  String category; // Workout, Cardio, Skincare, Study, Work

  @HiveField(4)
  int targetValue;

  @HiveField(5)
  int currentValue;

  @HiveField(6)
  String unit; // Reps, Km, Jam, Checklist

  @HiveField(7)
  int expReward;

  @HiveField(8)
  int goldReward;

  @HiveField(9)
  bool isCompleted;

  @HiveField(10)
  bool isPenaltyQuest;

  @HiveField(11)
  String scheduledDate; // Format: YYYY-MM-DD

  @HiveField(12)
  bool isAccepted; // Apakah quest sudah diambil ke slot harian

  @HiveField(13)
  String statType; // STR, AGI, INT, CHA

  @HiveField(14)
  int statReward; // Tambahan poin stat atribut RPG saat selesai

  QuestModel({
    required this.id,
    required this.title,
    this.description = '',
    required this.category,
    required this.targetValue,
    this.currentValue = 0,
    required this.unit,
    this.expReward = 20,
    this.goldReward = 10,
    this.isCompleted = false,
    this.isPenaltyQuest = false,
    required this.scheduledDate,
    this.isAccepted = true,
    this.statType = 'STR',
    this.statReward = 3,
  });

  /// Stat efektif berdasarkan konfigurasi atau pemetaan kategori otomatis
  String get effectiveStatType {
    if (statType.isNotEmpty && statType != 'STR') return statType;
    switch (category.toLowerCase()) {
      case 'workout':
        return 'STR';
      case 'cardio':
        return 'AGI';
      case 'study':
      case 'work':
      case 'productivity':
        return 'INT';
      case 'skincare':
      case 'postur':
      case 'posture':
        return 'CHA';
      default:
        return 'STR';
    }
  }

  /// Persentase progres penyelesaian quest (0.0 s.d. 1.0)
  double get progressPercentage {
    if (targetValue <= 0) return isCompleted ? 1.0 : 0.0;
    final progress = currentValue / targetValue;
    return progress > 1.0 ? 1.0 : (progress < 0.0 ? 0.0 : progress);
  }

  /// Konversi ke Map sesuai skema tabel Supabase 'quest_history'
  Map<String, dynamic> toMap({int? userId}) {
    final map = <String, dynamic>{
      'local_quest_id': id,
      'title': title,
      'category': category,
      'target_value': targetValue,
      'current_value': currentValue,
      'unit': unit,
      'exp_reward': expReward,
      'gold_reward': goldReward,
      'is_completed': isCompleted,
      'is_penalty_quest': isPenaltyQuest,
      'quest_date': scheduledDate,
      'is_accepted': isAccepted,
      'stat_type': statType,
      'stat_reward': statReward,
    };
    if (userId != null) {
      map['user_id'] = userId;
    }
    return map;
  }

  /// Buat instance QuestModel dari Map data (Supabase / JSON)
  factory QuestModel.fromMap(Map<String, dynamic> map) {
    return QuestModel(
      id: map['local_quest_id']?.toString() ?? map['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      category: map['category']?.toString() ?? 'Workout',
      targetValue: map['target_value'] is int ? map['target_value'] : int.tryParse(map['target_value']?.toString() ?? '10') ?? 10,
      currentValue: map['current_value'] is int ? map['current_value'] : int.tryParse(map['current_value']?.toString() ?? '0') ?? 0,
      unit: map['unit']?.toString() ?? 'Reps',
      expReward: map['exp_reward'] is int ? map['exp_reward'] : int.tryParse(map['exp_reward']?.toString() ?? '20') ?? 20,
      goldReward: map['gold_reward'] is int ? map['gold_reward'] : int.tryParse(map['gold_reward']?.toString() ?? '10') ?? 10,
      isCompleted: map['is_completed'] == true,
      isPenaltyQuest: map['is_penalty_quest'] == true,
      scheduledDate: map['quest_date']?.toString() ?? DateTime.now().toIso8601String().substring(0, 10),
      isAccepted: map['is_accepted'] == null ? true : map['is_accepted'] == true,
      statType: map['stat_type']?.toString() ?? 'STR',
      statReward: map['stat_reward'] is int ? map['stat_reward'] : int.tryParse(map['stat_reward']?.toString() ?? '3') ?? 3,
    );
  }

  /// Membuat duplikat objek dengan perubahan field
  QuestModel copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    int? targetValue,
    int? currentValue,
    String? unit,
    int? expReward,
    int? goldReward,
    bool? isCompleted,
    bool? isPenaltyQuest,
    String? scheduledDate,
    bool? isAccepted,
    String? statType,
    int? statReward,
  }) {
    return QuestModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      targetValue: targetValue ?? this.targetValue,
      currentValue: currentValue ?? this.currentValue,
      unit: unit ?? this.unit,
      expReward: expReward ?? this.expReward,
      goldReward: goldReward ?? this.goldReward,
      isCompleted: isCompleted ?? this.isCompleted,
      isPenaltyQuest: isPenaltyQuest ?? this.isPenaltyQuest,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      isAccepted: isAccepted ?? this.isAccepted,
      statType: statType ?? this.statType,
      statReward: statReward ?? this.statReward,
    );
  }
}

/// ==============================================================================
/// MANUAL HIVE TYPE ADAPTER: QuestAdapter (typeId: 0)
/// Berjalan langsung tanpa perlu menjalankan flutter packages pub run build_runner!
/// ==============================================================================
class QuestAdapter extends TypeAdapter<QuestModel> {
  @override
  final int typeId = 0;

  @override
  QuestModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      final key = reader.readByte();
      final value = reader.read();
      fields[key] = value;
    }
    return QuestModel(
      id: fields[0] as String? ?? '',
      title: fields[1] as String? ?? '',
      description: fields[2] as String? ?? '',
      category: fields[3] as String? ?? 'Workout',
      targetValue: fields[4] as int? ?? 10,
      currentValue: fields[5] as int? ?? 0,
      unit: fields[6] as String? ?? 'Reps',
      expReward: fields[7] as int? ?? 20,
      goldReward: fields[8] as int? ?? 10,
      isCompleted: fields[9] as bool? ?? false,
      isPenaltyQuest: fields[10] as bool? ?? false,
      scheduledDate: fields[11] as String? ?? '',
      isAccepted: fields[12] as bool? ?? true,
      statType: fields[13] as String? ?? 'STR',
      statReward: fields[14] as int? ?? 3,
    );
  }

  @override
  void write(BinaryWriter writer, QuestModel obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.category)
      ..writeByte(4)
      ..write(obj.targetValue)
      ..writeByte(5)
      ..write(obj.currentValue)
      ..writeByte(6)
      ..write(obj.unit)
      ..writeByte(7)
      ..write(obj.expReward)
      ..writeByte(8)
      ..write(obj.goldReward)
      ..writeByte(9)
      ..write(obj.isCompleted)
      ..writeByte(10)
      ..write(obj.isPenaltyQuest)
      ..writeByte(11)
      ..write(obj.scheduledDate)
      ..writeByte(12)
      ..write(obj.isAccepted)
      ..writeByte(13)
      ..write(obj.statType)
      ..writeByte(14)
      ..write(obj.statReward);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuestAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
