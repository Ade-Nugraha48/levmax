// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/models/alarm_model.dart
// Deskripsi: Model Alarm pengingat harian terintegrasi TypeAdapter Hive manual (typeId: 3)
// ==============================================================================

import 'package:hive/hive.dart';

@HiveType(typeId: 3)
class AlarmModel extends HiveObject {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final String time; // Format "HH:mm" misal "06:30"

  @HiveField(2)
  final String label;

  @HiveField(3)
  final bool isActive;

  AlarmModel({
    required this.id,
    required this.time,
    required this.label,
    this.isActive = true,
  });

  AlarmModel copyWith({int? id, String? time, String? label, bool? isActive}) {
    return AlarmModel(
      id: id ?? this.id,
      time: time ?? this.time,
      label: label ?? this.label,
      isActive: isActive ?? this.isActive,
    );
  }

  factory AlarmModel.fromJson(Map<String, dynamic> json) {
    return AlarmModel(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      time: json['time'] as String? ?? '07:00',
      label: json['label'] as String? ?? 'Hunter Alarm',
      isActive: json['is_active'] is bool
          ? json['is_active'] as bool
          : (json['isActive'] as bool? ?? true),
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'time': time, 'label': label, 'is_active': isActive};
  }
}

/// TypeAdapter manual untuk AlarmModel tanpa perlu code generation build_runner
class AlarmModelAdapter extends TypeAdapter<AlarmModel> {
  @override
  final int typeId = 3;

  @override
  AlarmModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AlarmModel(
      id: fields[0] as int? ?? 0,
      time: fields[1] as String? ?? '07:00',
      label: fields[2] as String? ?? '',
      isActive: fields[3] as bool? ?? true,
    );
  }

  @override
  void write(BinaryWriter writer, AlarmModel obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.time)
      ..writeByte(2)
      ..write(obj.label)
      ..writeByte(3)
      ..write(obj.isActive);
  }
}
