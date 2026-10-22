// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/models/quest_models.dart
// Deskripsi: Model Relasional Baru Supabase: MasterQuestModel, DailyUserQuestModel,
//            ItemShopModel, dan BlockchainInventoryLogModel (Mendukung UUID & JOIN).
// ==============================================================================

export 'alarm_model.dart';

// ==============================================================================
// 1. MASTER QUEST MODEL (Tabel: master_quests)
// ==============================================================================
class MasterQuestModel {
  final String id; // UUID String
  final String title;
  final String
  category; // 'Workout', 'Cardio', 'Appearance', 'Study', 'Mystery'
  final int baseExp;
  final String targetStat; // 'STR', 'AGI', 'INT', 'CHA'
  final String minRank; // 'F', 'E', 'D', 'C', 'B', 'A', 'S'
  final String? description;
  final int baseGold;
  final String unit; // 'Reps', 'Km', 'Checklist', 'Menit'

  MasterQuestModel({
    required this.id,
    required this.title,
    required this.category,
    required this.baseExp,
    required this.targetStat,
    required this.minRank,
    this.description,
    this.baseGold = 10,
    this.unit = 'Reps',
  });

  factory MasterQuestModel.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic val, int def) {
      if (val is num) return val.toInt();
      return int.tryParse(val?.toString() ?? '$def') ?? def;
    }

    return MasterQuestModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Quest',
      category: json['category']?.toString() ?? 'Workout',
      baseExp: parseInt(json['base_exp'] ?? json['baseExp'], 25),
      targetStat:
          json['target_stat']?.toString() ??
          json['targetStat']?.toString() ??
          'STR',
      minRank:
          json['min_rank']?.toString() ?? json['minRank']?.toString() ?? 'F',
      description: json['description']?.toString(),
      baseGold: parseInt(json['base_gold'] ?? json['baseGold'], 10),
      unit: json['unit']?.toString() ?? 'Reps',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'base_exp': baseExp,
      'target_stat': targetStat,
      'min_rank': minRank,
      if (description != null) 'description': description,
      'base_gold': baseGold,
      'unit': unit,
    };
  }

  MasterQuestModel copyWith({
    String? id,
    String? title,
    String? category,
    int? baseExp,
    String? targetStat,
    String? minRank,
    String? description,
    int? baseGold,
    String? unit,
  }) {
    return MasterQuestModel(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      baseExp: baseExp ?? this.baseExp,
      targetStat: targetStat ?? this.targetStat,
      minRank: minRank ?? this.minRank,
      description: description ?? this.description,
      baseGold: baseGold ?? this.baseGold,
      unit: unit ?? this.unit,
    );
  }
}

// ==============================================================================
// 2. DAILY USER QUEST MODEL (Tabel: daily_user_quests)
// ==============================================================================
class DailyUserQuestModel {
  final String id; // UUID String
  final String userId; // UUID String
  final String questId; // UUID String
  final String status; // 'pending', 'completed', 'failed', 'penalty'
  final int targetValue;
  final int achievedValue;
  final String date; // YYYY-MM-DD
  final MasterQuestModel?
  questDetail; // Menampung hasil JOIN dengan master_quests

  DailyUserQuestModel({
    required this.id,
    required this.userId,
    required this.questId,
    this.status = 'pending',
    required this.targetValue,
    this.achievedValue = 0,
    required this.date,
    this.questDetail,
  });

  // Getters kenyamanan untuk UI & Logika Game
  bool get isCompleted => status.toLowerCase() == 'completed';
  bool get isPenaltyQuest => status.toLowerCase() == 'penalty';
  bool get isFailed => status.toLowerCase() == 'failed';
  bool get isPending => status.toLowerCase() == 'pending';

  String get title => questDetail?.title ?? 'HUNTER QUEST';
  String get category => questDetail?.category ?? 'Workout';
  int get baseExp => questDetail?.baseExp ?? 25;
  String get targetStat => questDetail?.targetStat ?? 'STR';
  String get unit => questDetail?.unit ?? 'Reps';
  int get goldReward => questDetail?.baseGold ?? 15;

  double get progressPercentage {
    if (targetValue <= 0) return 0.0;
    return (achievedValue / targetValue).clamp(0.0, 1.0);
  }

  factory DailyUserQuestModel.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic val, int def) {
      if (val is num) return val.toInt();
      return int.tryParse(val?.toString() ?? '$def') ?? def;
    }

    // Parsing hasil JOIN master_quests
    MasterQuestModel? detail;
    if (json['master_quests'] != null && json['master_quests'] is Map) {
      detail = MasterQuestModel.fromJson(
        Map<String, dynamic>.from(json['master_quests'] as Map),
      );
    } else if (json['quest_detail'] != null && json['quest_detail'] is Map) {
      detail = MasterQuestModel.fromJson(
        Map<String, dynamic>.from(json['quest_detail'] as Map),
      );
    }

    return DailyUserQuestModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? json['userId']?.toString() ?? '',
      questId:
          json['quest_id']?.toString() ?? json['questId']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      targetValue: parseInt(json['target_value'] ?? json['targetValue'], 10),
      achievedValue: parseInt(
        json['achieved_value'] ?? json['achievedValue'],
        0,
      ),
      date:
          json['date']?.toString() ??
          DateTime.now().toIso8601String().substring(0, 10),
      questDetail: detail,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'quest_id': questId,
      'status': status,
      'target_value': targetValue,
      'achieved_value': achievedValue,
      'date': date,
      if (questDetail != null) 'master_quests': questDetail!.toJson(),
    };
  }

  DailyUserQuestModel copyWith({
    String? id,
    String? userId,
    String? questId,
    String? status,
    int? targetValue,
    int? achievedValue,
    String? date,
    MasterQuestModel? questDetail,
  }) {
    return DailyUserQuestModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      questId: questId ?? this.questId,
      status: status ?? this.status,
      targetValue: targetValue ?? this.targetValue,
      achievedValue: achievedValue ?? this.achievedValue,
      date: date ?? this.date,
      questDetail: questDetail ?? this.questDetail,
    );
  }
}

// ==============================================================================
// 3. ITEM SHOP MODEL (Tabel: item_shop / inventory)
// ==============================================================================
class ItemShopModel {
  final String id; // UUID String
  final String name;
  final String description;
  final int priceGold;
  final int prideScore;
  final String category; // 'Consumable', 'PrideItem', 'Ticket'
  final String? imageUrl;

  ItemShopModel({
    required this.id,
    required this.name,
    required this.description,
    required this.priceGold,
    required this.prideScore,
    required this.category,
    this.imageUrl,
  });

  factory ItemShopModel.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic val, int def) {
      if (val is num) return val.toInt();
      return int.tryParse(val?.toString() ?? '$def') ?? def;
    }

    return ItemShopModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['item_name']?.toString() ?? 'Item',
      description: json['description']?.toString() ?? '',
      priceGold: parseInt(
        json['price_gold'] ?? json['purchase_price_gold'],
        100,
      ),
      prideScore: parseInt(json['pride_score'] ?? json['pride_points'], 0),
      category:
          json['category']?.toString() ??
          json['item_type']?.toString() ??
          'Consumable',
      imageUrl: json['image_url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price_gold': priceGold,
      'pride_score': prideScore,
      'category': category,
      if (imageUrl != null) 'image_url': imageUrl,
    };
  }
}

// ==============================================================================
// 4. BLOCKCHAIN INVENTORY LOG MODEL (Tabel: blockchain_inventory_logs)
// ==============================================================================
class BlockchainInventoryLogModel {
  final String id; // UUID String
  final String userId; // UUID String
  final String itemId; // UUID String
  final String previousHash;
  final String currentHash;
  final String timestamp; // ISO-8601
  final String status; // 'verified', 'pending', 'rejected'

  BlockchainInventoryLogModel({
    required this.id,
    required this.userId,
    required this.itemId,
    required this.previousHash,
    required this.currentHash,
    required this.timestamp,
    this.status = 'verified',
  });

  factory BlockchainInventoryLogModel.fromJson(Map<String, dynamic> json) {
    return BlockchainInventoryLogModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      itemId: json['item_id']?.toString() ?? '',
      previousHash:
          json['previous_hash']?.toString() ??
          json['prev_hash']?.toString() ??
          '',
      currentHash: json['current_hash']?.toString() ?? '',
      timestamp:
          json['timestamp']?.toString() ??
          DateTime.now().toUtc().toIso8601String(),
      status: json['status']?.toString() ?? 'verified',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'item_id': itemId,
      'previous_hash': previousHash,
      'current_hash': currentHash,
      'timestamp': timestamp,
      'status': status,
    };
  }
}
