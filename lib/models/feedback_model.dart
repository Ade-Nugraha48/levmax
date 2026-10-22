// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/models/feedback_model.dart
// Deskripsi: Model HiveObject untuk Saran & Kesan Mata Kuliah (Tab 3 Bottom Nav).
//            Dilengkapi TypeAdapter manual (typeId: 2) tanpa perlu build_runner.
// ==============================================================================

import 'package:hive/hive.dart';

@HiveType(typeId: 2)
class FeedbackModel extends HiveObject {
  @HiveField(0)
  int id;

  @HiveField(1)
  dynamic userId;

  @HiveField(2)
  String namaMahasiswa;

  @HiveField(3)
  String nim;

  @HiveField(4)
  String kesan;

  @HiveField(5)
  String saran;

  @HiveField(6)
  String createdAt;

  FeedbackModel({
    this.id = 0,
    required this.userId,
    required this.namaMahasiswa,
    required this.nim,
    required this.kesan,
    required this.saran,
    required this.createdAt,
  });

  /// Konversi ke Map sesuai skema tabel Supabase 'saran_kesan'
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'user_id': userId,
      'nama_mahasiswa': namaMahasiswa,
      'nim': nim,
      'kesan': kesan,
      'saran': saran,
      'created_at': createdAt,
    };
    if (id > 0) {
      map['id'] = id;
    }
    return map;
  }

  /// Buat instance FeedbackModel dari Map data (Supabase / JSON)
  factory FeedbackModel.fromMap(Map<String, dynamic> map) {
    return FeedbackModel(
      id: map['id'] is int
          ? map['id']
          : int.tryParse(map['id']?.toString() ?? '0') ?? 0,
      userId: map['user_id'] is int
          ? map['user_id']
          : int.tryParse(map['user_id']?.toString() ?? '0') ?? 0,
      namaMahasiswa: map['nama_mahasiswa']?.toString() ?? '',
      nim: map['nim']?.toString() ?? '',
      kesan: map['kesan']?.toString() ?? '',
      saran: map['saran']?.toString() ?? '',
      createdAt:
          map['created_at']?.toString() ?? DateTime.now().toIso8601String(),
    );
  }

  /// Ekstraksi rating bintang/dagger (1-5) dari metadata nim atau default 5
  int get rating {
    if (nim.startsWith('RATING:')) {
      final parts = nim.split('|');
      for (final p in parts) {
        if (p.startsWith('RATING:')) {
          return int.tryParse(p.replaceFirst('RATING:', '')) ?? 5;
        }
      }
    }
    return 5;
  }

  /// Ekstraksi mata kuliah/disiplin
  String get discipline {
    if (namaMahasiswa.isNotEmpty &&
        namaMahasiswa != 'Hunter' &&
        namaMahasiswa != 'Admin') {
      return namaMahasiswa;
    }
    if (nim.contains('SECTOR:')) {
      final parts = nim.split('|');
      for (final p in parts) {
        if (p.startsWith('SECTOR:')) {
          return p.replaceFirst('SECTOR:', '');
        }
      }
    }
    return 'Semester 5 - Mobile Programming Theory';
  }

  /// Ekstraksi rank log
  String get rank {
    if (nim.contains('RANK:')) {
      final parts = nim.split('|');
      for (final p in parts) {
        if (p.startsWith('RANK:')) {
          return p.replaceFirst('RANK:', '');
        }
      }
    }
    return rating >= 5 ? 'S' : (rating >= 4 ? 'A' : 'B');
  }
}

/// ==============================================================================
/// MANUAL HIVE TYPE ADAPTER: FeedbackAdapter (typeId: 2)
/// ==============================================================================
class FeedbackAdapter extends TypeAdapter<FeedbackModel> {
  @override
  final int typeId = 2;

  @override
  FeedbackModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      final key = reader.readByte();
      final value = reader.read();
      fields[key] = value;
    }
    return FeedbackModel(
      id: fields[0] as int? ?? 0,
      userId: fields[1] ?? 0,
      namaMahasiswa: fields[2] as String? ?? '',
      nim: fields[3] as String? ?? '',
      kesan: fields[4] as String? ?? '',
      saran: fields[5] as String? ?? '',
      createdAt: fields[6] as String? ?? '',
    );
  }

  @override
  void write(BinaryWriter writer, FeedbackModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.namaMahasiswa)
      ..writeByte(3)
      ..write(obj.nim)
      ..writeByte(4)
      ..write(obj.kesan)
      ..writeByte(5)
      ..write(obj.saran)
      ..writeByte(6)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FeedbackAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
