// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/models/block_model.dart
// Deskripsi: Model HiveObject untuk Blok Rantai Data Blockchain Lokal (Anti-Cheat).
//            Dilengkapi TypeAdapter manual (typeId: 1) tanpa perlu build_runner.
// ==============================================================================

import 'package:hive/hive.dart';

@HiveType(typeId: 1)
class BlockModel extends HiveObject {
  @HiveField(0)
  int index;

  @HiveField(1)
  String timestamp;

  @HiveField(2)
  String action; // Contoh: "GENESIS BLOCK", "LEVEL UP: Level 2 (Rank F)", "RE-AWAKENING"

  @HiveField(3)
  String prevHash;

  @HiveField(4)
  String currentHash;

  BlockModel({
    required this.index,
    required this.timestamp,
    required this.action,
    required this.prevHash,
    required this.currentHash,
  });

  /// Konversi ke Map sesuai skema tabel Supabase 'blockchain_ledger'
  Map<String, dynamic> toMap({int? userId}) {
    final map = <String, dynamic>{
      'block_index': index,
      'timestamp': timestamp,
      'action_data': action,
      'prev_hash': prevHash,
      'current_hash': currentHash,
    };
    if (userId != null) {
      map['user_id'] = userId;
    }
    return map;
  }

  /// Buat instance BlockModel dari Map data (Supabase / JSON)
  factory BlockModel.fromMap(Map<String, dynamic> map) {
    return BlockModel(
      index: map['block_index'] is int
          ? map['block_index']
          : int.tryParse(map['block_index']?.toString() ?? '0') ?? 0,
      timestamp:
          map['timestamp']?.toString() ?? DateTime.now().toIso8601String(),
      action: map['action_data']?.toString() ?? map['action']?.toString() ?? '',
      prevHash: map['prev_hash']?.toString() ?? '',
      currentHash: map['current_hash']?.toString() ?? '',
    );
  }
}

/// ==============================================================================
/// MANUAL HIVE TYPE ADAPTER: BlockAdapter (typeId: 1)
/// Berjalan langsung tanpa perlu menjalankan flutter packages pub run build_runner!
/// ==============================================================================
class BlockAdapter extends TypeAdapter<BlockModel> {
  @override
  final int typeId = 1;

  @override
  BlockModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      final key = reader.readByte();
      final value = reader.read();
      fields[key] = value;
    }
    return BlockModel(
      index: fields[0] as int? ?? 0,
      timestamp: fields[1] as String? ?? '',
      action: fields[2] as String? ?? '',
      prevHash: fields[3] as String? ?? '',
      currentHash: fields[4] as String? ?? '',
    );
  }

  @override
  void write(BinaryWriter writer, BlockModel obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.index)
      ..writeByte(1)
      ..write(obj.timestamp)
      ..writeByte(2)
      ..write(obj.action)
      ..writeByte(3)
      ..write(obj.prevHash)
      ..writeByte(4)
      ..write(obj.currentHash);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BlockAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
