// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/ui/tabs/status_quest_tab.dart
// Deskripsi: Tab 1: Daily Quests HUD (Solo Leveling Tactical HUD Pixel-Perfect)
//            1. Generator Quest Harian Otomatis Berdasarkan Rank & Atribut Stat
//            2. Kuota Quest Slots (Rank F: 3 s.d. Rank S: 10)
//            3. Status Window dengan 4 Atribut RPG (STR, AGI, INT, CHA)
//            4. Peringatan Merah (Red Alert) jika Rank Capped (Stat Gate)
//            5. Evolusi Rank S: S⭐ s.d. S⭐⭐⭐, SS, SSS & Aura Avatar
//            6. Protokol Penalti Keras (-20 HP / -40 HP) & Routing Game Over
// ==============================================================================

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../helpers/boxes.dart';
import '../../helpers/levmax_theme.dart';
import '../../models/quest_model.dart';
import '../../models/user_model.dart';
import '../../services/blockchain_service.dart';
import '../../services/notification_service.dart';
import '../../services/quest_generator_service.dart';
import '../../services/supabase_api_service.dart';
import '../chat/system_ai_chat_modal.dart';
import '../penalty/game_over_page.dart';
import '../penalty/penalty_minigame_page.dart';
import '../quests/quest_catalog_modal.dart';
import '../quests/sensor_study_page.dart';
import '../quests/sensor_workout_page.dart';

class StatusQuestTab extends StatefulWidget {
  final UserModel player;
  final VoidCallback onPlayerUpdated;

  const StatusQuestTab({
    super.key,
    required this.player,
    required this.onPlayerUpdated,
  });

  @override
  State<StatusQuestTab> createState() => _StatusQuestTabState();
}

class _StatusQuestTabState extends State<StatusQuestTab> {
  final _searchController = TextEditingController();

  String _selectedCategory = 'ALL';
  int _activeSegmentIndex = 0; // 0: Active Accepted Quests, 1: Available Pool

  final List<Map<String, dynamic>> _filterChips = [
    {'label': 'ALL', 'icon': null},
    {'label': 'WORKOUT', 'icon': Icons.fitness_center},
    {'label': 'CARDIO', 'icon': Icons.directions_run},
    {'label': 'SKINCARE', 'icon': Icons.spa},
    {'label': 'STUDY', 'icon': Icons.menu_book},
    {'label': 'WORK', 'icon': Icons.terminal},
  ];

  @override
  void initState() {
    super.initState();
    _initializeDailyQuestSystem();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ==========================================================================
  // INISIALISASI GENERATOR QUEST & PENGECEKAN PENALTI HARIAN
  // ==========================================================================
  Future<void> _initializeDailyQuestSystem() async {
    // 1. Periksa penalti harian jika ada pergantian hari
    final penaltyResult = await QuestGeneratorService.checkDailyPenaltyStatus(widget.player);
    if (penaltyResult.hasPenalty) {
      widget.onPlayerUpdated();
      if (penaltyResult.isGameOver && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => GameOverPage(player: widget.player)),
        );
        return;
      }
    }

    // 2. Pastikan daftar quest harian sudah ter-generate di Hive
    await QuestGeneratorService.ensureDailyQuestsGenerated(widget.player);
    if (mounted) setState(() {});
  }

  // ==========================================================================
  // LOGIKA GAME BALANCING: SELESAIKAN QUEST & STAT GAIN + LEVEL UP
  // ==========================================================================
  Future<void> _toggleQuestCompletion(QuestModel quest) async {
    final newStatus = !quest.isCompleted;
    quest.isCompleted = newStatus;
    quest.currentValue = newStatus ? quest.targetValue : 0;
    await quest.save();

    if (newStatus) {
      final expGain = quest.expReward;
      final goldGain = quest.goldReward;
      final statGain = quest.statReward;
      final statType = quest.effectiveStatType;

      int currentExp = widget.player.exp + expGain;
      int currentLevel = widget.player.level;
      int currentHp = widget.player.hp;
      final currentGold = widget.player.gold + goldGain;

      // Tambahkan Atribut Stat Spesifik sesuai Kategori Quest
      int currentStr = widget.player.str;
      int currentAgi = widget.player.agi;
      int currentInt = widget.player.intStat;
      int currentCha = widget.player.cha;

      switch (statType) {
        case 'STR':
          currentStr += statGain;
          break;
        case 'AGI':
          currentAgi += statGain;
          break;
        case 'INT':
          currentInt += statGain;
          break;
        case 'CHA':
          currentCha += statGain;
          break;
        default:
          currentStr += statGain;
      }

      // Cek Level Up: Setiap EXP >= 100 naik 1 Level & Pulihkan +10 HP
      bool didLevelUp = false;
      while (currentExp >= 100) {
        currentLevel += 1;
        currentExp -= 100;
        currentHp = min(100, currentHp + 10);
        didLevelUp = true;
      }

      // Cek Kualifikasi Rank Baru dengan STAT CHECK
      final newQualifiedRank = UserModel.calculateQualifiedRank(
        lvl: currentLevel,
        str: currentStr,
        agi: currentAgi,
        intStat: currentInt,
        cha: currentCha,
      );

      final isRankPromoted = newQualifiedRank != widget.player.cleanRank;

      if (didLevelUp) {
        await BlockchainService.addBlock(
          'LEVEL UP: Player reached Level $currentLevel. Stats: STR:$currentStr, AGI:$currentAgi, INT:$currentInt, CHA:$currentCha. Rank: $newQualifiedRank.',
          userId: widget.player.id,
        );

        await NotificationService.showLevelUpNotification(
          newLevel: currentLevel,
          rank: newQualifiedRank,
        );
      }

      if (isRankPromoted) {
        await BlockchainService.addBlock(
          'RANK ADVANCEMENT: Hunter promoted from Rank ${widget.player.cleanRank} to Rank $newQualifiedRank!',
          userId: widget.player.id,
        );
      }

      final updatedPlayer = widget.player.copyWith(
        level: currentLevel,
        rank: newQualifiedRank,
        exp: currentExp,
        hp: currentHp,
        gold: currentGold,
        str: currentStr,
        agi: currentAgi,
        intStat: currentInt,
        cha: currentCha,
      );

      await SupabaseApiService.savePlayerCache(updatedPlayer);
      try {
        await SupabaseApiService.updateUser(updatedPlayer);
      } catch (e) {
        debugPrint('[StatusQuestTab] Supabase sync error: $e');
      }

      await SupabaseApiService.syncQuest(quest: quest, userId: widget.player.id);
      widget.onPlayerUpdated();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: LevMaxTheme.surfaceContainer,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: LevMaxTheme.primaryContainer, width: 1),
            ),
            content: Row(
              children: [
                const Icon(Icons.bolt, color: LevMaxTheme.primaryContainer, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'QUEST COMPLETED! +$expGain EXP • +$goldGain G • +$statGain $statType',
                    style: LevMaxTheme.mono(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: LevMaxTheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      await SupabaseApiService.syncQuest(quest: quest, userId: widget.player.id);
      widget.onPlayerUpdated();
    }
  }

  // Tambah progres interaktif (misal reps / km)
  Future<void> _incrementQuestProgress(QuestModel quest) async {
    if (quest.isCompleted) return;

    final increment = quest.category.toLowerCase() == 'cardio' ? 1 : 10;
    quest.currentValue = min(quest.targetValue, quest.currentValue + increment);

    if (quest.currentValue >= quest.targetValue) {
      await _toggleQuestCompletion(quest);
    } else {
      await quest.save();
      await SupabaseApiService.syncQuest(quest: quest, userId: widget.player.id);
      setState(() {});
    }
  }

  // ==========================================================================
  // PENGAMBILAN QUEST DARI POOL KE SLOT HARIAN (ATURAN 1)
  // ==========================================================================
  Future<void> _handleAcceptQuest(QuestModel quest) async {
    final success = await QuestGeneratorService.acceptQuest(
      quest: quest,
      player: widget.player,
    );

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: LevMaxTheme.surfaceContainer,
            behavior: SnackBarBehavior.floating,
            content: Text(
              'PROTOCOL ACCEPTED! Added to Active Quest Log.',
              style: LevMaxTheme.mono(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: LevMaxTheme.primaryContainer,
              ),
            ),
          ),
        );
        setState(() {});
      }
    } else {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: LevMaxTheme.surfaceContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: LevMaxTheme.hpRed, width: 1.5),
            ),
            title: Row(
              children: [
                const Icon(Icons.lock, color: LevMaxTheme.hpRed, size: 20),
                const SizedBox(width: 8),
                Text(
                  'QUEST SLOTS FULL',
                  style: LevMaxTheme.headline(fontSize: 14, color: LevMaxTheme.hpRed),
                ),
              ],
            ),
            content: Text(
              'Hunter Rank ${widget.player.cleanRank} dibatasi maksimal ${widget.player.maxQuestSlots} quest per hari!\n\nSelesaikan quest aktif atau tingkatkan Rank Anda untuk membuka slot tambahan.',
              style: LevMaxTheme.mono(fontSize: 11, color: LevMaxTheme.onSurfaceVariant),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('MENGERTI', style: LevMaxTheme.mono(fontSize: 12, color: LevMaxTheme.primaryContainer)),
              ),
            ],
          ),
        );
      }
    }
  }

  // ==========================================================================
  // PENALTI: GAGAL / ABANDON PROTOCOL
  // ==========================================================================
  Future<void> _handleAbandonQuest(QuestModel quest, int boxIndex) async {
    final box = Hive.box<QuestModel>(HiveBoxes.questBox);
    await box.deleteAt(boxIndex);

    // Potong -20 HP (atau -40 HP jika penalti sudah aktif)
    final hpDeduction = widget.player.isPenaltyActive ? 40 : 20;
    final newHp = max(0, widget.player.hp - hpDeduction);

    final updatedPlayer = widget.player.copyWith(
      hp: newHp,
      isPenaltyActive: true,
    );

    await SupabaseApiService.savePlayerCache(updatedPlayer);
    try {
      await SupabaseApiService.updateUser(updatedPlayer);
    } catch (_) {}

    await BlockchainService.addBlock(
      'PENALTY TRIGGERED: Quest "${quest.title}" abandoned. -$hpDeduction HP.',
      userId: widget.player.id,
    );

    widget.onPlayerUpdated();

    if (!mounted) return;

    if (newHp <= 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => GameOverPage(player: updatedPlayer)),
      );
    } else {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: LevMaxTheme.surfaceContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: LevMaxTheme.hpRed, width: 2),
          ),
          title: Row(
            children: [
              const Icon(Icons.warning, color: LevMaxTheme.hpRed),
              const SizedBox(width: 8),
              Text('PENALTY ENFORCED', style: LevMaxTheme.headline(fontSize: 14, color: LevMaxTheme.hpRed)),
            ],
          ),
          content: Text(
            'Anda meninggalkan quest!\nHukuman Sistem: -$hpDeduction HP.\n\nSelesaikan Survival Mini-game di Penalty Zone sekarang untuk memulihkan HP!',
            style: LevMaxTheme.mono(fontSize: 11, color: LevMaxTheme.onSurfaceVariant),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PenaltyGamePage(player: updatedPlayer)),
                ).then((_) => widget.onPlayerUpdated());
              },
              style: ElevatedButton.styleFrom(backgroundColor: LevMaxTheme.hpRed),
              child: Text('MASUK PENALTY ZONE', style: LevMaxTheme.mono(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }
  }

  // ==========================================================================
  // MODAL ENSIKLOPEDIA & KATALOG QUEST RESMI
  // ==========================================================================
  void _openQuestCatalog() {
    QuestCatalogModal.show(
      context,
      player: widget.player,
      onQuestAccepted: () {
        widget.onPlayerUpdated();
        setState(() {});
      },
    );
  }

  // ==========================================================================
  // MODAL AI CHAT ASSISTANT "THE SYSTEM"
  // ==========================================================================
  void _openSystemChatSheet() {
    SystemAiChatModal.show(context, player: widget.player);
  }

  // ==========================================================================
  // KOMPONEN 1: STICKY TACTICAL HEADER BAR (64PX)
  // ==========================================================================
  Widget _buildStickyTacticalHeader() {
    final now = DateTime.now();
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    final dateStr = '${months[now.month - 1]} ${now.day}';

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: LevMaxTheme.surface.withValues(alpha: 0.95),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Sisi Kiri: Kotak Logo Crest + Teks Alert
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: LevMaxTheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: widget.player.rankColor.withValues(alpha: 0.5)),
              boxShadow: [
                BoxShadow(
                  color: widget.player.rankColor.withValues(alpha: 0.3),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Center(
              child: Icon(Icons.shield, color: widget.player.rankColor, size: 18),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: widget.player.rankColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: widget.player.rankColor,
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'SYSTEM DIRECTIVES // ${widget.player.sTierBadge}',
                    style: LevMaxTheme.mono(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: widget.player.rankColor,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'STATUS: ONLINE // CYCLE: $dateStr',
                style: LevMaxTheme.mono(
                  fontSize: 10,
                  color: LevMaxTheme.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const Spacer(),

          // Tombol Buka Katalog / Ensiklopedia
          GestureDetector(
            onTap: _openQuestCatalog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF101725),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF00F0FF).withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_stories, color: Color(0xFF00F0FF), size: 13),
                  const SizedBox(width: 5),
                  Text(
                    'CATALOG',
                    style: LevMaxTheme.mono(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF00F0FF),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Sisi Kanan: AI System Eye Indicator
          GestureDetector(
            onTap: _openSystemChatSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF101725),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: LevMaxTheme.primaryContainer.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.visibility, color: LevMaxTheme.primaryContainer, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'SYSTEM AI',
                    style: LevMaxTheme.mono(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: LevMaxTheme.primaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // KOMPONEN 2: HERO STATUS CARD DENGAN STAT RPG & RANK CAPPED ALERT
  // ==========================================================================
  Widget _buildPlayerStatusHeroCard() {
    final hpPercentage = (widget.player.hp / 100.0).clamp(0.0, 1.0);
    final expPercentage = (widget.player.exp / 100.0).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF101725),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: widget.player.rankColor.withValues(alpha: 0.3), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: widget.player.rankColor.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top HUD Strip: ID & Gold
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: widget.player.rankColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: widget.player.rankColor,
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'HUNTER HUD // ID: #${widget.player.id.toString().padLeft(6, '0')}',
                style: LevMaxTheme.mono(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: widget.player.rankColor,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF090D14),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0x22EAB308), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.toll, size: 14, color: LevMaxTheme.goldCoin),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.player.gold} G',
                      style: LevMaxTheme.mono(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: LevMaxTheme.goldAmber,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Baris Identitas Utama (Avatar + Identitas)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar & Rank Badge dengan Bintang / Aura S-Rank
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: widget.player.rankColor,
                        width: widget.player.cleanRank.startsWith('S') ? 2.0 : 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.player.rankColor.withValues(alpha: 0.5),
                          blurRadius: widget.player.cleanRank.startsWith('S') ? 20 : 12,
                        ),
                      ],
                    ),
                    child: CustomPaint(
                      painter: HunterPortraitPainter(
                        rankColor: widget.player.rankColor,
                        rankColorSecondary: widget.player.rankColorSecondary,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: widget.player.rankColor,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: widget.player.rankColor.withValues(alpha: 0.8),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Text(
                        'RANK ${widget.player.sTierBadge}',
                        style: LevMaxTheme.mono(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF001F24),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),

              // Kolom Info & Gauges
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Baris Nama & Level
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'HUNTER ${widget.player.username.toUpperCase()}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: LevMaxTheme.headline(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: LevMaxTheme.onSurface,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: widget.player.rankColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: widget.player.rankColor.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            'LV. ${widget.player.level}',
                            style: LevMaxTheme.mono(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: widget.player.rankColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),

                    // Title / Gelar Hunter
                    Text(
                      'TITLE: ${widget.player.rankTitle.toUpperCase()}',
                      style: LevMaxTheme.mono(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: LevMaxTheme.tertiaryFixedDim,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // HP Gauge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.favorite, size: 12, color: LevMaxTheme.hpRedLabel),
                            const SizedBox(width: 4),
                            Text(
                              'HP',
                              style: LevMaxTheme.mono(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: LevMaxTheme.hpRedLabel,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${widget.player.hp} / 100',
                          style: LevMaxTheme.mono(
                            fontSize: 10,
                            color: LevMaxTheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    GlowingProgressBar(
                      progress: hpPercentage,
                      color: LevMaxTheme.hpRed,
                      height: 6,
                      trackColor: LevMaxTheme.surfaceContainerLowest,
                      glowBlurRadius: 6,
                    ),
                    const SizedBox(height: 6),

                    // EXP Gauge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.bolt, size: 12, color: LevMaxTheme.tertiaryFixedDim),
                            const SizedBox(width: 4),
                            Text(
                              'EXP',
                              style: LevMaxTheme.mono(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: LevMaxTheme.tertiaryFixedDim,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${widget.player.exp} / 100 (${widget.player.exp}%)',
                          style: LevMaxTheme.mono(
                            fontSize: 10,
                            color: LevMaxTheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    GlowingProgressBar(
                      progress: expPercentage,
                      color: LevMaxTheme.tertiaryContainer,
                      height: 6,
                      trackColor: LevMaxTheme.surfaceContainerLowest,
                      glowBlurRadius: 6,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ====================================================================
          // ATURAN 3: GRID 4 ATRIBUT STAT RPG (STR, AGI, INT, CHA)
          // ====================================================================
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF090D14),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0x1FFFFFFF), width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatBadge('STR', widget.player.str, Icons.fitness_center, const Color(0xFF00F0FF), 'Workout'),
                _buildStatBadge('AGI', widget.player.agi, Icons.directions_run, const Color(0xFF65F2B5), 'Cardio'),
                _buildStatBadge('INT', widget.player.intStat, Icons.psychology, const Color(0xFFB388FF), 'Study'),
                _buildStatBadge('CHA', widget.player.cha, Icons.auto_awesome, const Color(0xFFFF80AB), 'Skincare'),
              ],
            ),
          ),

          // ====================================================================
          // ATURAN 4: PERINGATAN MERAH (RED ALERT) JIKA RANK CAPPED
          // ====================================================================
          if (widget.player.isRankCapped) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: LevMaxTheme.hpRed.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: LevMaxTheme.hpRed, width: 1.5),
                boxShadow: const [
                  BoxShadow(color: Color(0x44FF2A54), blurRadius: 10),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.error_outline, color: LevMaxTheme.hpRed, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '⚠️ RANK CAPPED // STAT BOTTLENECK',
                        style: LevMaxTheme.headline(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: LevMaxTheme.hpRed,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.player.rankCapWarning ?? '',
                    style: LevMaxTheme.mono(
                      fontSize: 10,
                      color: const Color(0xFFFFD5DA),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatBadge(String label, int value, IconData icon, Color color, String categoryHint) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: LevMaxTheme.mono(fontSize: 10, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value.toString(),
          style: LevMaxTheme.mono(fontSize: 13, fontWeight: FontWeight.w900, color: LevMaxTheme.onSurface),
        ),
        Text(
          categoryHint,
          style: LevMaxTheme.mono(fontSize: 8, color: LevMaxTheme.outline),
        ),
      ],
    );
  }

  // ==========================================================================
  // KOMPONEN 3: SEARCH BAR & TACTICAL FILTER CHIPS
  // ==========================================================================
  Widget _buildSearchBarAndFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search Bar
        Container(
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFF101725),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0x1FFFFFFF)),
          ),
          child: TextField(
            controller: _searchController,
            style: LevMaxTheme.mono(fontSize: 12, color: LevMaxTheme.onSurface),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'FILTER PROTOCOL QUESTS...',
              hintStyle: LevMaxTheme.mono(fontSize: 11, color: LevMaxTheme.outline),
              prefixIcon: const Icon(Icons.search, size: 18, color: LevMaxTheme.outline),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 11),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Filter Chips Baris Horizontal
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _filterChips.map((chip) {
              final isSelected = _selectedCategory == chip['label'];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (chip['icon'] != null) ...[
                        Icon(chip['icon'] as IconData, size: 12, color: isSelected ? const Color(0xFF001F24) : LevMaxTheme.outline),
                        const SizedBox(width: 4),
                      ],
                      Text(chip['label'] as String),
                    ],
                  ),
                  selected: isSelected,
                  selectedColor: LevMaxTheme.primaryContainer,
                  backgroundColor: const Color(0xFF101725),
                  labelStyle: LevMaxTheme.mono(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? const Color(0xFF001F24) : LevMaxTheme.onSurfaceVariant,
                  ),
                  side: BorderSide(
                    color: isSelected ? LevMaxTheme.primaryContainer : const Color(0x1FFFFFFF),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  onSelected: (val) {
                    if (val) setState(() => _selectedCategory = chip['label'] as String);
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // KOMPONEN 4: HEADER [ACTIVE QUEST LOG & QUEST SLOTS METER]
  // ==========================================================================
  Widget _buildActiveQuestLogHeader(int acceptedCount, int totalPoolCount) {
    final maxSlots = widget.player.maxQuestSlots;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Baris Header & Slots Meter
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sisi Kiri: Judul & Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.assignment_turned_in_outlined, size: 18, color: LevMaxTheme.primaryContainer),
                      const SizedBox(width: 6),
                      Text(
                        '[QUEST DIRECTIVES]',
                        style: LevMaxTheme.headline(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: LevMaxTheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _openQuestCatalog,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0x3300F0FF)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.menu_book, color: Color(0xFF00F0FF), size: 11),
                              const SizedBox(width: 3),
                              Text(
                                'ARCHIVE',
                                style: LevMaxTheme.mono(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF00F0FF),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Pilih quest sesuai batas Rank ${widget.player.cleanRank} ($acceptedCount/$maxSlots Slots)',
                    style: const TextStyle(
                      fontSize: 10,
                      color: LevMaxTheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            // Sisi Kanan: Penalty Zone CTA
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () async {
                final won = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PenaltyGamePage(player: widget.player)),
                );
                if (won == true) {
                  widget.onPlayerUpdated();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: widget.player.isPenaltyActive
                      ? LevMaxTheme.hpRed.withValues(alpha: 0.25)
                      : LevMaxTheme.errorCoral.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: widget.player.isPenaltyActive ? LevMaxTheme.hpRed : LevMaxTheme.errorCoral.withValues(alpha: 0.3),
                    width: widget.player.isPenaltyActive ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.player.isPenaltyActive) ...[
                      const Icon(Icons.warning, color: LevMaxTheme.hpRed, size: 12),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      widget.player.isPenaltyActive ? 'PENALTY ACTIVE' : 'RESET AT 23:59',
                      style: LevMaxTheme.mono(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: widget.player.isPenaltyActive ? LevMaxTheme.hpRed : LevMaxTheme.errorCoral,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // SEGMENTED TAB SELECTOR: ACTIVE PROTOCOLS vs AVAILABLE SYSTEM POOL
        Container(
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFF090D14),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0x1FFFFFFF)),
          ),
          child: Row(
            children: [
              // Tab 1: Active Accepted Quests
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _activeSegmentIndex = 0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _activeSegmentIndex == 0 ? LevMaxTheme.primaryContainer : Colors.transparent,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'ACTIVE SLOTS ($acceptedCount / $maxSlots)',
                      style: LevMaxTheme.mono(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _activeSegmentIndex == 0 ? const Color(0xFF001F24) : LevMaxTheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),

              // Tab 2: Available Pool Choices
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _activeSegmentIndex = 1),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _activeSegmentIndex == 1 ? LevMaxTheme.primaryContainer : Colors.transparent,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'DIRECTIVE POOL ($totalPoolCount)',
                      style: LevMaxTheme.mono(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _activeSegmentIndex == 1 ? const Color(0xFF001F24) : LevMaxTheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // KOMPONEN 5: KARTU QUEST TAKTIS
  // ==========================================================================
  Widget _buildTacticalQuestCard(QuestModel quest, {required bool isPoolView}) {
    final categoryLower = quest.category.toLowerCase();
    Color accentColor = LevMaxTheme.primaryContainer;
    String subLabel = 'PHYSICAL SENSOR (ACCELEROMETER)';
    IconData questIcon = Icons.fitness_center;

    if (categoryLower == 'workout') {
      accentColor = const Color(0xFF00F0FF);
      subLabel = 'PHYSICAL SENSOR (ACCELEROMETER)';
      questIcon = Icons.fitness_center;
    } else if (categoryLower == 'cardio') {
      accentColor = const Color(0xFF65F2B5);
      subLabel = 'GPS DUNGEON TRACKING';
      questIcon = Icons.directions_run;
    } else if (categoryLower == 'study' || categoryLower == 'work') {
      accentColor = const Color(0xFFB388FF);
      subLabel = 'GYROSCOPE POSTURE GUARDIAN';
      questIcon = Icons.psychology;
    } else {
      accentColor = const Color(0xFFFF80AB);
      subLabel = 'LOOKSMAXXING & POSTURE';
      questIcon = Icons.spa;
    }

    final progressRatio = quest.progressPercentage;
    final progressPercent = (progressRatio * 100).toInt();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF101725),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: quest.isCompleted
              ? const Color(0x3310B981)
              : quest.isAccepted
                  ? accentColor.withValues(alpha: 0.3)
                  : const Color(0x1FFFFFFF),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Strip Warna Kiri
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                color: quest.isCompleted ? const Color(0xFF10B981) : accentColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Baris Atas: Ikon + Judul + Stat Gain Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF090D14),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: accentColor.withValues(alpha: 0.4)),
                      ),
                      child: Center(
                        child: Icon(questIcon, size: 16, color: accentColor),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            quest.title,
                            style: LevMaxTheme.headline(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: quest.isCompleted ? const Color(0xFF94A3B8) : LevMaxTheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subLabel,
                            style: LevMaxTheme.mono(fontSize: 9, color: LevMaxTheme.outline),
                          ),
                        ],
                      ),
                    ),
                    // Stat Gain Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: accentColor.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        '+${quest.statReward} ${quest.effectiveStatType}',
                        style: LevMaxTheme.mono(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Deskripsi Singkat
                if (quest.description.isNotEmpty) ...[
                  Text(
                    quest.description,
                    style: const TextStyle(fontSize: 10, color: LevMaxTheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                ],

                // Progres / Target Telemetry
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isPoolView ? 'TARGET BEBAN' : 'PROGRESS',
                      style: LevMaxTheme.mono(fontSize: 9, color: LevMaxTheme.outline),
                    ),
                    Text(
                      isPoolView
                          ? '${quest.targetValue} ${quest.unit}'
                          : '${quest.currentValue} / ${quest.targetValue} ${quest.unit} ($progressPercent%)',
                      style: LevMaxTheme.mono(fontSize: 9, fontWeight: FontWeight.bold, color: LevMaxTheme.onSurface),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                if (!isPoolView) ...[
                  GlowingProgressBar(
                    progress: progressRatio,
                    color: quest.isCompleted ? const Color(0xFF10B981) : accentColor,
                    height: 6,
                    trackColor: const Color(0xFF090D14),
                    glowBlurRadius: 6,
                  ),
                  const SizedBox(height: 10),
                ],

                // Footer Baris Hadiah & Tombol Aksi
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Rewards
                    Row(
                      children: [
                        const Icon(Icons.bolt, size: 12, color: LevMaxTheme.tertiaryFixedDim),
                        const SizedBox(width: 2),
                        Text(
                          '+${quest.expReward} EXP',
                          style: LevMaxTheme.mono(fontSize: 9, fontWeight: FontWeight.bold, color: LevMaxTheme.tertiaryFixedDim),
                        ),
                        Text(' • ', style: LevMaxTheme.mono(fontSize: 9, color: LevMaxTheme.outline)),
                        const Icon(Icons.toll, size: 12, color: LevMaxTheme.goldCoin),
                        const SizedBox(width: 2),
                        Text(
                          '+${quest.goldReward} G',
                          style: LevMaxTheme.mono(fontSize: 9, fontWeight: FontWeight.bold, color: LevMaxTheme.goldAmber),
                        ),
                      ],
                    ),

                    // Action Button
                    if (isPoolView)
                      ElevatedButton(
                        onPressed: () => _handleAcceptQuest(quest),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: LevMaxTheme.primaryContainer,
                          foregroundColor: const Color(0xFF001F24),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          minimumSize: const Size(90, 30),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                        child: Text(
                          'ACCEPT QUEST',
                          style: LevMaxTheme.mono(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF001F24)),
                        ),
                      )
                    else
                      GestureDetector(
                        onTap: () {
                          if (categoryLower == 'study' || categoryLower == 'work') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SensorStudyPage(
                                  quest: quest,
                                  player: widget.player,
                                  onQuestCompleted: () => _toggleQuestCompletion(quest),
                                ),
                              ),
                            );
                          } else if (categoryLower == 'workout') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SensorWorkoutPage(
                                  quest: quest,
                                  player: widget.player,
                                  onQuestCompleted: () => _toggleQuestCompletion(quest),
                                ),
                              ),
                            );
                          } else if (quest.isCompleted) {
                            _toggleQuestCompletion(quest);
                          } else {
                            _incrementQuestProgress(quest);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: quest.isCompleted ? const Color(0xFF1E293B) : accentColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                quest.isCompleted ? Icons.check : Icons.play_arrow,
                                size: 14,
                                color: quest.isCompleted ? const Color(0xFF94A3B8) : const Color(0xFF001F24),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                quest.isCompleted ? 'COMPLETED' : 'EXECUTE',
                                style: LevMaxTheme.mono(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: quest.isCompleted ? const Color(0xFF94A3B8) : const Color(0xFF001F24),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // KOMPONEN 6: BANNER STREAK SAFEGUARD & EXP BUFF
  // ==========================================================================
  Widget _buildStreakSafeguardBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF101725),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0x14FFFFFF)),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield, color: LevMaxTheme.primaryContainer, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'DISCIPLINE PROTOCOL: Daily quota resets at midnight (23:59). Incomplete active quests trigger -20 HP penalty.',
              style: LevMaxTheme.mono(fontSize: 9, color: LevMaxTheme.outline),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // KOMPONEN 7: BOTTOM ACTION ROW (SYSTEM REROLL & AI EYE)
  // ==========================================================================
  Widget _buildBottomActionRow(int acceptedCount) {
    final maxSlots = widget.player.maxQuestSlots;

    return Row(
      children: [
        // Tombol Kiri: SYSTEM QUEST SLOTS OVERVIEW
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _activeSegmentIndex = _activeSegmentIndex == 0 ? 1 : 0;
              });
            },
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFF101725),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: LevMaxTheme.primaryContainer.withValues(alpha: 0.3)),
                boxShadow: const [
                  BoxShadow(color: Color(0x2200F0FF), blurRadius: 10, offset: Offset(0, 2)),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _activeSegmentIndex == 0 ? Icons.add_task : Icons.assignment_turned_in,
                    size: 16,
                    color: LevMaxTheme.primaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _activeSegmentIndex == 0
                        ? 'BROWSE POOL ($acceptedCount/$maxSlots SLOTS)'
                        : 'VIEW ACTIVE SLOTS ($acceptedCount/$maxSlots)',
                    style: LevMaxTheme.mono(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFDBFCFF),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Tombol Kanan: AI "THE SYSTEM" (Gemini Conduit)
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _openSystemChatSheet,
          child: Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: LevMaxTheme.primaryContainer,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x8800F0FF),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.visibility, color: Color(0xFF001F24), size: 22),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // MAIN BUILD METHOD
  // ==========================================================================
  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().toIso8601String().substring(0, 10);

    return Scaffold(
      backgroundColor: LevMaxTheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Sticky Tactical Header
            _buildStickyTacticalHeader(),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Status Window Hero Card
                    _buildPlayerStatusHeroCard(),
                    const SizedBox(height: 16),

                    // Search Bar & Filter Chips
                    _buildSearchBarAndFilters(),
                    const SizedBox(height: 16),

                    // Hive ValueListenableBuilder untuk Quests
                    ValueListenableBuilder<Box<QuestModel>>(
                      valueListenable: Hive.box<QuestModel>(HiveBoxes.questBox).listenable(),
                      builder: (context, box, _) {
                        final allTodayQuests = box.values.where((q) => q.scheduledDate == today).toList();
                        final acceptedQuests = allTodayQuests.where((q) => q.isAccepted).toList();
                        final availablePoolQuests = allTodayQuests.where((q) => !q.isAccepted).toList();

                        final query = _searchController.text.toLowerCase().trim();
                        final targetList = _activeSegmentIndex == 0 ? acceptedQuests : availablePoolQuests;

                        final filtered = targetList.where((q) {
                          final matchQuery = query.isEmpty ||
                              q.title.toLowerCase().contains(query) ||
                              q.description.toLowerCase().contains(query);

                          final matchCategory = _selectedCategory == 'ALL' ||
                              q.category.toUpperCase() == _selectedCategory.toUpperCase();

                          return matchQuery && matchCategory;
                        }).toList();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Header & Segment Selector
                            _buildActiveQuestLogHeader(acceptedQuests.length, availablePoolQuests.length),
                            const SizedBox(height: 12),

                            if (filtered.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: LevMaxTheme.surfaceContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    _activeSegmentIndex == 0
                                        ? 'TIDAK ADA QUEST AKTIF. AMBIL DARI DIRECTIVE POOL!'
                                        : 'SEMUA DIRECTIVE POOL TELAH DIAMBIL ATAU KOSONG.',
                                    textAlign: TextAlign.center,
                                    style: LevMaxTheme.mono(
                                      fontSize: 11,
                                      color: LevMaxTheme.outline,
                                    ),
                                  ),
                                ),
                              )
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final quest = filtered[index];
                                  final originalIndex = box.values.toList().indexOf(quest);

                                  if (_activeSegmentIndex == 0) {
                                    // Active Quests dapat di-dismiss (Abandon) dengan penalti
                                    return Dismissible(
                                      key: Key(quest.id.isNotEmpty ? quest.id : index.toString()),
                                      direction: DismissDirection.endToStart,
                                      background: Container(
                                        alignment: Alignment.centerRight,
                                        padding: const EdgeInsets.only(right: 20),
                                        margin: const EdgeInsets.only(bottom: 12),
                                        decoration: BoxDecoration(
                                          color: LevMaxTheme.hpRed.withValues(alpha: 0.8),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            const Icon(Icons.warning, color: Colors.white, size: 18),
                                            const SizedBox(width: 6),
                                            Text(
                                              'ABANDON (-20 HP)',
                                              style: LevMaxTheme.mono(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      confirmDismiss: (_) async {
                                        return await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            backgroundColor: LevMaxTheme.surfaceContainer,
                                            title: Text('ABANDON QUEST?', style: LevMaxTheme.headline(fontSize: 13, color: LevMaxTheme.hpRed)),
                                            content: Text(
                                              'Meninggalkan quest aktif akan memicu PENALTI KERAS (-20 HP) & melempar Anda ke Penalty Zone!',
                                              style: LevMaxTheme.mono(fontSize: 11, color: LevMaxTheme.onSurfaceVariant),
                                            ),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('BATAL')),
                                              ElevatedButton(
                                                onPressed: () => Navigator.pop(ctx, true),
                                                style: ElevatedButton.styleFrom(backgroundColor: LevMaxTheme.hpRed),
                                                child: const Text('YA, ABANDON'),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                      onDismissed: (_) => _handleAbandonQuest(quest, originalIndex),
                                      child: _buildTacticalQuestCard(quest, isPoolView: false),
                                    );
                                  } else {
                                    // Available Pool Directives
                                    return _buildTacticalQuestCard(quest, isPoolView: true);
                                  }
                                },
                              ),
                            const SizedBox(height: 12),

                            // Streak Safeguard Banner
                            _buildStreakSafeguardBanner(),
                            const SizedBox(height: 14),

                            // Bottom Action Row
                            _buildBottomActionRow(acceptedQuests.length),
                            const SizedBox(height: 16),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==============================================================================
// CUSTOM PAINTER: HUNTER SUNG JIN-WOO AVATAR (AWAKENED HUD PORTRAIT & AURA)
// ==============================================================================
class HunterPortraitPainter extends CustomPainter {
  final Color rankColor;
  final Color rankColorSecondary;

  HunterPortraitPainter({
    this.rankColor = const Color(0xFF00F0FF),
    this.rankColorSecondary = const Color(0xFFFFD700),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));

    // 1. Dark Gradient Background (Mana Aura)
    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, -0.2),
        radius: 0.9,
        colors: [
          rankColor.withValues(alpha: 0.35),
          const Color(0xFF0F172A),
          const Color(0xFF080D18),
        ],
      ).createShader(rect);
    canvas.drawRRect(rrect, bgPaint);

    canvas.save();
    canvas.clipRRect(rrect);

    // 2. Tactical Background Grid
    final gridPaint = Paint()
      ..color = rankColor.withValues(alpha: 0.15)
      ..strokeWidth = 0.6;
    for (double x = 0; x < size.width; x += 12) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 12) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 3. Shadow Cloak / Hunter Silhouette
    final cloakPaint = Paint()..color = const Color(0xFF060911);
    final cloakPath = Path()
      ..moveTo(size.width * 0.12, size.height)
      ..lineTo(size.width * 0.22, size.height * 0.58)
      ..lineTo(size.width * 0.35, size.height * 0.42)
      ..lineTo(size.width * 0.42, size.height * 0.32)
      ..lineTo(size.width * 0.58, size.height * 0.32)
      ..lineTo(size.width * 0.65, size.height * 0.42)
      ..lineTo(size.width * 0.78, size.height * 0.58)
      ..lineTo(size.width * 0.88, size.height)
      ..close();
    canvas.drawPath(cloakPath, cloakPaint);

    // 4. Anime Hair Spikes (Iconic Jin-Woo bangs)
    final hairPaint = Paint()..color = const Color(0xFF10192E);
    final hairPath = Path()
      ..moveTo(size.width * 0.30, size.height * 0.46)
      ..lineTo(size.width * 0.36, size.height * 0.22)
      ..lineTo(size.width * 0.43, size.height * 0.36)
      ..lineTo(size.width * 0.50, size.height * 0.18)
      ..lineTo(size.width * 0.57, size.height * 0.36)
      ..lineTo(size.width * 0.64, size.height * 0.22)
      ..lineTo(size.width * 0.70, size.height * 0.46)
      ..close();
    canvas.drawPath(hairPath, hairPaint);

    // 5. Glowing Hunter Eyes
    final eyeGlowPaint = Paint()
      ..color = rankColor.withValues(alpha: 0.7)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawCircle(Offset(size.width * 0.42, size.height * 0.46), 4, eyeGlowPaint);
    canvas.drawCircle(Offset(size.width * 0.58, size.height * 0.46), 4, eyeGlowPaint);

    final eyeCorePaint = Paint()..color = rankColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(size.width * 0.42, size.height * 0.46), width: 6, height: 2),
        const Radius.circular(1),
      ),
      eyeCorePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(size.width * 0.58, size.height * 0.46), width: 6, height: 2),
        const Radius.circular(1),
      ),
      eyeCorePaint,
    );

    // Eye flare horizontal beam
    final beamPaint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.transparent, rankColor.withValues(alpha: 0.8), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, size.height * 0.44, size.width, 4));
    canvas.drawRect(Rect.fromLTWH(size.width * 0.20, size.height * 0.45, size.width * 0.60, 2), beamPaint);

    // 6. Cybernetic Collar
    final collarPaint = Paint()
      ..color = rankColor.withValues(alpha: 0.4)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final collarPath = Path()
      ..moveTo(size.width * 0.36, size.height * 0.64)
      ..lineTo(size.width * 0.50, size.height * 0.70)
      ..lineTo(size.width * 0.64, size.height * 0.64);
    canvas.drawPath(collarPath, collarPaint);

    canvas.restore();

    // 7. Outer Border dengan Rank Gradient
    final borderPaint = Paint()
      ..shader = LinearGradient(
        colors: [rankColor, rankColorSecondary],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(rrect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant HunterPortraitPainter oldDelegate) {
    return oldDelegate.rankColor != rankColor || oldDelegate.rankColorSecondary != rankColorSecondary;
  }
}
