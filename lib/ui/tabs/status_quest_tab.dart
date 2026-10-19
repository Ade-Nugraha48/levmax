// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/ui/tabs/status_quest_tab.dart
// Deskripsi: Tab 1: Daily Quests HUD (Solo Leveling Tactical HUD Pixel-Perfect)
//            Komponen 1-7: Header, Status Hero Card, Filter Chips, Quest Log,
//            Tactical Quest Card + Hive, Streak Safeguard, & Dual Floating Overlay.
// ==============================================================================

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../helpers/boxes.dart';
import '../../helpers/levmax_theme.dart';
import '../../models/quest_model.dart';
import '../../models/user_model.dart';
import '../../services/blockchain_service.dart';
import '../../services/gemini_service.dart';
import '../../services/notification_service.dart';
import '../../services/supabase_api_service.dart';
import '../penalty/penalty_minigame_page.dart';

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
  final _planFormKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _targetValueController = TextEditingController(text: '10');

  String _selectedCategory = 'ALL';
  String _newQuestCategory = 'Workout';
  String _newQuestUnit = 'Reps';

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
    _seedDummyQuestsIfEmpty();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _titleController.dispose();
    _descController.dispose();
    _targetValueController.dispose();
    super.dispose();
  }

  // ==========================================================================
  // SEED DUMMY QUESTS OTOMATIS JIKA HIVE MASIH KOSONG
  // ==========================================================================
  Future<void> _seedDummyQuestsIfEmpty() async {
    final box = Hive.box<QuestModel>(HiveBoxes.questBox);
    if (box.isEmpty) {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final seedQuests = [
        QuestModel(
          id: 'seed_quest_01',
          title: 'QUEST 01: PUSH-UPS',
          description: 'Physical sensor accelerometer push-up protocol',
          category: 'Workout',
          targetValue: 100,
          currentValue: 0,
          unit: 'Reps',
          expReward: 25,
          goldReward: 50,
          isCompleted: false,
          scheduledDate: today,
        ),
        QuestModel(
          id: 'seed_quest_02',
          title: 'QUEST 02: 5KM RUNNING',
          description: 'GPS dungeon tracking sprint perimeter',
          category: 'Cardio',
          targetValue: 5,
          currentValue: 2,
          unit: 'KM',
          expReward: 40,
          goldReward: 80,
          isCompleted: false,
          scheduledDate: today,
        ),
        QuestModel(
          id: 'seed_quest_03',
          title: 'QUEST 03: STUDY FOCUS',
          description: 'Gyroscope posture guardian & deep study session',
          category: 'Study',
          targetValue: 45,
          currentValue: 30,
          unit: 'Mins',
          expReward: 30,
          goldReward: 60,
          isCompleted: false,
          scheduledDate: today,
        ),
      ];

      for (final q in seedQuests) {
        await box.add(q);
      }
      if (mounted) setState(() {});
    }
  }

  // ==========================================================================
  // LOGIKA GAME BALANCING: SELESAIKAN QUEST & LEVEL UP
  // ==========================================================================
  Future<void> _toggleQuestCompletion(QuestModel quest) async {
    final newStatus = !quest.isCompleted;
    quest.isCompleted = newStatus;
    quest.currentValue = newStatus ? quest.targetValue : 0;
    await quest.save();

    if (newStatus) {
      final expGain = quest.expReward;
      final goldGain = quest.goldReward;

      int currentExp = widget.player.exp + expGain;
      int currentLevel = widget.player.level;
      int currentHp = widget.player.hp;
      final currentGold = widget.player.gold + goldGain;

      // Cek Level Up: Setiap EXP >= 100
      if (currentExp >= 100) {
        currentLevel += 1;
        currentExp -= 100;
        currentHp = min(100, currentHp + 10);
        final newRank = UserModel.calculateRank(currentLevel);

        await BlockchainService.addBlock(
          'LEVEL UP: Player reached Level $currentLevel (Rank $newRank). Restored +10 HP.',
          userId: widget.player.id,
        );

        await NotificationService.showLevelUpNotification(
          newLevel: currentLevel,
          rank: newRank,
        );
      }

      final updatedPlayer = widget.player.copyWith(
        level: currentLevel,
        rank: UserModel.calculateRank(currentLevel),
        exp: currentExp,
        hp: currentHp,
        gold: currentGold,
      );

      await SupabaseApiService.updateUser(updatedPlayer);
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
                    'QUEST COMPLETED! +$expGain EXP • +$goldGain G',
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
  // FORM MODAL BOTTOM SHEET: TAMBAH PLAN QUEST ESOK HARI (FR-3.1)
  // ==========================================================================
  void _openAddPlanModal() {
    _titleController.clear();
    _descController.clear();
    _targetValueController.text = '10';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: LevMaxTheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: LevMaxTheme.primaryContainer, width: 1.5),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: Form(
                key: _planFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 48,
                        height: 4,
                        decoration: BoxDecoration(
                          color: LevMaxTheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, color: LevMaxTheme.primaryContainer, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'ADD TOMORROW PROTOCOL PLAN',
                          style: LevMaxTheme.headline(
                            fontSize: 14,
                            color: LevMaxTheme.primaryContainer,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, color: LevMaxTheme.outline),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(color: LevMaxTheme.surfaceContainerHighest),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _titleController,
                      style: LevMaxTheme.mono(fontSize: 13, color: LevMaxTheme.onSurface),
                      decoration: InputDecoration(
                        labelText: 'QUEST TITLE',
                        labelStyle: LevMaxTheme.mono(fontSize: 11, color: LevMaxTheme.primaryContainer),
                        filled: true,
                        fillColor: LevMaxTheme.surfaceContainerLowest,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Title is required' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _descController,
                      style: LevMaxTheme.mono(fontSize: 13, color: LevMaxTheme.onSurface),
                      decoration: InputDecoration(
                        labelText: 'PROTOCOL DESCRIPTION / SENSOR FOCUS',
                        labelStyle: LevMaxTheme.mono(fontSize: 11, color: LevMaxTheme.primaryContainer),
                        filled: true,
                        fillColor: LevMaxTheme.surfaceContainerLowest,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _newQuestCategory,
                            dropdownColor: LevMaxTheme.surfaceContainer,
                            style: LevMaxTheme.mono(fontSize: 12, color: LevMaxTheme.onSurface),
                            decoration: InputDecoration(
                              labelText: 'CATEGORY',
                              labelStyle: LevMaxTheme.mono(fontSize: 11, color: LevMaxTheme.primaryContainer),
                              filled: true,
                              fillColor: LevMaxTheme.surfaceContainerLowest,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            items: ['Workout', 'Cardio', 'Skincare', 'Study', 'Work']
                                .map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase())))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setModalState(() {
                                  _newQuestCategory = val;
                                  if (val == 'Workout') _newQuestUnit = 'Reps';
                                  if (val == 'Cardio') _newQuestUnit = 'KM';
                                  if (val == 'Skincare') _newQuestUnit = 'Check';
                                  if (val == 'Study' || val == 'Work') _newQuestUnit = 'Mins';
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _targetValueController,
                            keyboardType: TextInputType.number,
                            style: LevMaxTheme.mono(fontSize: 13, color: LevMaxTheme.onSurface),
                            decoration: InputDecoration(
                              labelText: 'TARGET ($_newQuestUnit)',
                              labelStyle: LevMaxTheme.mono(fontSize: 11, color: LevMaxTheme.primaryContainer),
                              filled: true,
                              fillColor: LevMaxTheme.surfaceContainerLowest,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            validator: (v) => v == null || v.isEmpty ? 'Target number' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        if (_planFormKey.currentState == null || !_planFormKey.currentState!.validate()) {
                          return;
                        }
                        final targetVal = int.tryParse(_targetValueController.text) ?? 10;
                        int expReward = 20;
                        int goldReward = 10;

                        switch (_newQuestCategory) {
                          case 'Workout':
                            expReward = 25;
                            goldReward = 50;
                            break;
                          case 'Cardio':
                            expReward = 40;
                            goldReward = 80;
                            break;
                          case 'Skincare':
                            expReward = 15;
                            goldReward = 30;
                            break;
                          case 'Study':
                          case 'Work':
                            expReward = 30;
                            goldReward = 60;
                            break;
                        }

                        final tomorrow = DateTime.now().add(const Duration(days: 1)).toIso8601String().substring(0, 10);
                        final newQuest = QuestModel(
                          id: 'custom_plan_${DateTime.now().millisecondsSinceEpoch}',
                          title: _titleController.text.trim().toUpperCase(),
                          description: _descController.text.trim(),
                          category: _newQuestCategory,
                          targetValue: targetVal,
                          currentValue: 0,
                          unit: _newQuestUnit,
                          expReward: expReward,
                          goldReward: goldReward,
                          isCompleted: false,
                          scheduledDate: tomorrow,
                        );

                        final box = Hive.box<QuestModel>(HiveBoxes.questBox);
                        await box.add(newQuest);
                        await SupabaseApiService.syncQuest(quest: newQuest, userId: widget.player.id);

                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: LevMaxTheme.surfaceContainer,
                              behavior: SnackBarBehavior.floating,
                              content: Text(
                                'TOMORROW PROTOCOL ACTIVATED IN SYSTEM LOG',
                                style: LevMaxTheme.mono(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: LevMaxTheme.primaryContainer,
                                ),
                              ),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: LevMaxTheme.primaryContainer,
                        foregroundColor: LevMaxTheme.onPrimaryFixed,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                      child: Text(
                        'INITIALIZE QUEST PROTOCOL',
                        style: LevMaxTheme.mono(fontSize: 12, fontWeight: FontWeight.bold, color: LevMaxTheme.onPrimaryFixed),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================================================
  // MODAL AI CHAT ASSISTANT "THE SYSTEM" (GEMINI CONDUIT)
  // ==========================================================================
  void _openSystemChatSheet() {
    final chatMsgController = TextEditingController();
    final List<Map<String, String>> messages = [
      {
        'sender': 'system',
        'text':
            '[THE SYSTEM ONLINE]\nHunter ${widget.player.username} (Level ${widget.player.level}, Rank ${widget.player.rank}). Laporkan kebutuhan konsultasi Anda seputar Workout, Looksmaxxing, atau Disiplin Belajar.'
      }
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: LevMaxTheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: LevMaxTheme.primaryContainer, width: 1.5),
      ),
      builder: (ctx) {
        bool isTyping = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.75,
                child: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 4,
                      decoration: BoxDecoration(
                        color: LevMaxTheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.bolt, color: LevMaxTheme.primaryContainer, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'THE SYSTEM // AI CONDUIT',
                          style: LevMaxTheme.headline(
                            fontSize: 14,
                            color: LevMaxTheme.primaryContainer,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, color: LevMaxTheme.outline),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(color: LevMaxTheme.surfaceContainerHighest),
                    Expanded(
                      child: ListView.builder(
                        itemCount: messages.length,
                        itemBuilder: (context, idx) {
                          final msg = messages[idx];
                          final isSystem = msg['sender'] == 'system';

                          return Align(
                            alignment: isSystem ? Alignment.centerLeft : Alignment.centerRight,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              padding: const EdgeInsets.all(12),
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.80,
                              ),
                              decoration: BoxDecoration(
                                color: isSystem
                                    ? LevMaxTheme.surfaceContainerLowest
                                    : LevMaxTheme.primaryContainer.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSystem ? LevMaxTheme.surfaceContainerHighest : LevMaxTheme.primaryContainer,
                                ),
                              ),
                              child: Text(
                                msg['text'] ?? '',
                                style: TextStyle(
                                  fontFamily: isSystem ? 'monospace' : null,
                                  color: isSystem ? LevMaxTheme.onSurface : LevMaxTheme.primaryContainer,
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (isTyping)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          '[SISTEM SEDANG MEMPROSES TELEMETRI HUNTER...]',
                          style: LevMaxTheme.mono(
                            fontSize: 11,
                            color: LevMaxTheme.primaryContainer,
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: chatMsgController,
                              style: LevMaxTheme.mono(fontSize: 13, color: LevMaxTheme.onSurface),
                              decoration: InputDecoration(
                                hintText: 'Query The System protocol...',
                                hintStyle: LevMaxTheme.mono(fontSize: 12, color: LevMaxTheme.outline),
                                filled: true,
                                fillColor: LevMaxTheme.surfaceContainerLowest,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: LevMaxTheme.surfaceContainerHighest),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: LevMaxTheme.surfaceContainerHighest),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.send, color: LevMaxTheme.primaryContainer),
                            onPressed: () async {
                              final txt = chatMsgController.text.trim();
                              if (txt.isEmpty) return;

                              setModalState(() {
                                messages.add({'sender': 'user', 'text': txt});
                                isTyping = true;
                              });
                              chatMsgController.clear();

                              final reply = await GeminiService.sendMessage(
                                message: txt,
                                player: widget.player,
                              );

                              setModalState(() {
                                messages.add({'sender': 'system', 'text': reply});
                                isTyping = false;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
              border: Border.all(color: LevMaxTheme.primaryContainer.withValues(alpha: 0.4)),
              boxShadow: [
                BoxShadow(
                  color: LevMaxTheme.primaryContainer.withValues(alpha: 0.2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.shield, color: LevMaxTheme.primaryContainer, size: 18),
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
                    decoration: const BoxDecoration(
                      color: LevMaxTheme.primaryContainer,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: LevMaxTheme.primaryContainer,
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '[SYSTEM ALERT]',
                    style: LevMaxTheme.mono(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: LevMaxTheme.primaryContainer,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'DAILY QUESTS',
                style: LevMaxTheme.headline(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: LevMaxTheme.onSurface,
                ),
              ),
            ],
          ),
          const Spacer(),

          // Sisi Kanan: Status Baris & Profil Avatar Mini
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                dateStr,
                style: LevMaxTheme.mono(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: LevMaxTheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: LevMaxTheme.tertiaryFixedDim,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'ONLINE • 24ms',
                    style: LevMaxTheme.mono(
                      fontSize: 10,
                      color: LevMaxTheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 12),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: LevMaxTheme.surfaceContainerLowest,
              border: Border.all(color: LevMaxTheme.primaryContainer.withValues(alpha: 0.6)),
              boxShadow: [
                BoxShadow(
                  color: LevMaxTheme.primaryContainer.withValues(alpha: 0.25),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Center(
              child: Text(
                widget.player.username.isNotEmpty ? widget.player.username[0].toUpperCase() : 'S',
                style: LevMaxTheme.mono(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: LevMaxTheme.primaryContainer,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // KOMPONEN 2: PLAYER STATUS WINDOW (HERO STATUS CARD)
  // ==========================================================================
  Widget _buildPlayerStatusHeroCard() {
    final hpPercentage = (widget.player.hp / 100.0).clamp(0.0, 1.0);
    final expPercentage = (widget.player.exp / 100.0).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LevMaxTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top HUD Strip
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: LevMaxTheme.primaryContainer,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: LevMaxTheme.primaryContainer,
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
                  fontWeight: FontWeight.w600,
                  color: LevMaxTheme.primaryContainer,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: LevMaxTheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(4),
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

          // Baris Identitas Utama (Avatar + Stats)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar & Rank Badge
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: LevMaxTheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: LevMaxTheme.primaryContainer.withValues(alpha: 0.3)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x3300F0FF),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        widget.player.rank,
                        style: LevMaxTheme.headline(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: LevMaxTheme.primaryContainer,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: LevMaxTheme.primaryContainer,
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: const [
                          BoxShadow(
                            color: LevMaxTheme.primaryContainer,
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Text(
                        'RANK ${widget.player.rank}',
                        style: LevMaxTheme.mono(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: LevMaxTheme.onPrimaryFixed,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),

              // Kolom Statistik Player
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Baris Nama & Level
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'PLAYER ${widget.player.username.toUpperCase()}',
                          style: LevMaxTheme.headline(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: LevMaxTheme.onSurface,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: LevMaxTheme.primaryContainer.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: LevMaxTheme.primaryContainer.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            'LV. ${widget.player.level}',
                            style: LevMaxTheme.mono(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: LevMaxTheme.primaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Baris Class & Title
                    Row(
                      children: [
                        const Icon(Icons.shield_outlined, size: 14, color: LevMaxTheme.secondary),
                        const SizedBox(width: 4),
                        Text(
                          'SHADOW INITIATE',
                          style: LevMaxTheme.mono(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: LevMaxTheme.secondary,
                          ),
                        ),
                        Text(
                          ' • ',
                          style: LevMaxTheme.mono(fontSize: 10, color: LevMaxTheme.outline),
                        ),
                        Text(
                          'TITLE: AWAKENED',
                          style: LevMaxTheme.mono(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: LevMaxTheme.tertiaryFixedDim,
                          ),
                        ),
                      ],
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
                    const SizedBox(height: 4),
                    GlowingProgressBar(
                      progress: hpPercentage,
                      color: LevMaxTheme.hpRed,
                      height: 8,
                      trackColor: LevMaxTheme.surfaceContainerLowest,
                      glowBlurRadius: 8,
                    ),
                    const SizedBox(height: 8),

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
                    const SizedBox(height: 4),
                    GlowingProgressBar(
                      progress: expPercentage,
                      color: LevMaxTheme.tertiaryContainer,
                      height: 8,
                      trackColor: LevMaxTheme.surfaceContainerLowest,
                      glowBlurRadius: 8,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // KOMPONEN 3: SEARCH BAR & TACTICAL FILTER CHIPS
  // ==========================================================================
  Widget _buildSearchBarAndFilters() {
    return Column(
      children: [
        // Search Input
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: LevMaxTheme.surfaceContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              const Icon(Icons.search, color: LevMaxTheme.outline, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: LevMaxTheme.mono(fontSize: 12, color: LevMaxTheme.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Search habits & dungeon quests...',
                    hintStyle: LevMaxTheme.mono(fontSize: 12, color: LevMaxTheme.outline),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: LevMaxTheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'CTRL+K',
                  style: LevMaxTheme.mono(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: LevMaxTheme.outline,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Horizontal Category Filter
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: _filterChips.map((chip) {
              final label = chip['label'] as String;
              final icon = chip['icon'] as IconData?;
              final isSelected = _selectedCategory == label;

              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategory = label;
                    });
                  },
                  child: Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? LevMaxTheme.primaryContainer : LevMaxTheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isSelected ? LevMaxTheme.primaryContainer : LevMaxTheme.surfaceContainerHighest,
                        width: 1,
                      ),
                      boxShadow: isSelected
                          ? const [
                              BoxShadow(
                                color: Color(0x5900F0FF),
                                blurRadius: 8,
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSelected && label == 'ALL') ...[
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: LevMaxTheme.onPrimaryFixed,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (icon != null) ...[
                          Icon(
                            icon,
                            size: 14,
                            color: isSelected ? LevMaxTheme.onPrimaryFixed : LevMaxTheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          label,
                          style: LevMaxTheme.mono(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected ? LevMaxTheme.onPrimaryFixed : LevMaxTheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // KOMPONEN 4: HEADER [ACTIVE QUEST LOG]
  // ==========================================================================
  Widget _buildActiveQuestLogHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sisi Kiri
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.assignment_turned_in_outlined, size: 18, color: LevMaxTheme.primaryContainer),
                  const SizedBox(width: 6),
                  Text(
                    '[ACTIVE QUEST LOG]',
                    style: LevMaxTheme.headline(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: LevMaxTheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              const Text(
                'Complete daily assignments to avoid the Penalty Zone',
                style: TextStyle(
                  fontSize: 11,
                  color: LevMaxTheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        // Sisi Kanan: Penalty & Reset Time
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            GestureDetector(
              onTap: () async {
                final won = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PenaltyMiniGamePage()),
                );
                if (won == true) {
                  widget.onPlayerUpdated();
                }
              },
              child: Text(
                'PENALTY: 14H 12M',
                style: LevMaxTheme.mono(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: LevMaxTheme.errorCoral,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'RESET AT 04:00',
              style: LevMaxTheme.mono(
                fontSize: 10,
                color: LevMaxTheme.outline,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================================================
  // KOMPONEN 5: KARTU QUEST TAKTIS (_buildTacticalQuestCard)
  // ==========================================================================
  Widget _buildTacticalQuestCard(QuestModel quest) {
    // Penentuan Tema Dinamis berdasarkan Kategori
    final categoryLower = quest.category.toLowerCase();
    Color accentColor = LevMaxTheme.primaryContainer;
    String subLabel = 'PHYSICAL SENSOR (ACCELEROMETER)';
    String badgeText = 'DAILY';
    Color badgeBg = LevMaxTheme.surfaceContainerHighest;
    Color badgeTextColor = LevMaxTheme.onSurface;
    String actionLabel = 'START QUEST';
    Color actionBg = LevMaxTheme.primaryContainer;
    Color actionTextColor = LevMaxTheme.onPrimaryFixed;
    IconData actionIcon = Icons.play_arrow;
    IconData questIcon = Icons.fitness_center;
    String telemetryLabel = 'PROGRESS';

    if (categoryLower == 'workout') {
      accentColor = LevMaxTheme.primaryContainer; // #00F0FF
      subLabel = 'PHYSICAL SENSOR (ACCELEROMETER)';
      badgeText = quest.isCompleted ? 'COMPLETED' : 'DAILY';
      badgeBg = LevMaxTheme.surfaceContainerHighest;
      badgeTextColor = LevMaxTheme.onSurface;
      actionLabel = quest.isCompleted ? 'COMPLETED' : 'START QUEST';
      actionBg = quest.isCompleted ? LevMaxTheme.surfaceContainerHigh : LevMaxTheme.primaryContainer;
      actionTextColor = quest.isCompleted ? LevMaxTheme.onSurfaceVariant : LevMaxTheme.onPrimaryFixed;
      actionIcon = quest.isCompleted ? Icons.check : Icons.play_arrow;
      questIcon = Icons.fitness_center;
      telemetryLabel = 'PROGRESS';
    } else if (categoryLower == 'cardio') {
      accentColor = LevMaxTheme.tertiaryContainer; // #65F2B5
      subLabel = 'GPS DUNGEON TRACKING';
      badgeText = quest.isCompleted ? 'COMPLETED' : 'IN PROGRESS';
      badgeBg = LevMaxTheme.tertiaryContainer.withValues(alpha: 0.15);
      badgeTextColor = LevMaxTheme.tertiaryContainer;
      actionLabel = quest.isCompleted ? 'COMPLETED' : 'CONTINUE';
      actionBg = quest.isCompleted ? LevMaxTheme.surfaceContainerHigh : LevMaxTheme.surfaceContainerHigh;
      actionTextColor = const Color(0xFFDBFCFF);
      actionIcon = Icons.navigation;
      questIcon = Icons.directions_run;
      telemetryLabel = 'DISTANCE';
    } else if (categoryLower == 'study' || categoryLower == 'work') {
      accentColor = LevMaxTheme.secondary; // #D2BBFF
      subLabel = 'GYROSCOPE POSTURE GUARDIAN';
      badgeText = quest.isCompleted ? 'COMPLETED' : 'ACTIVE SYNC';
      badgeBg = LevMaxTheme.secondaryContainer.withValues(alpha: 0.3);
      badgeTextColor = const Color(0xFFEADDFF);
      actionLabel = quest.isCompleted ? 'COMPLETED' : 'FOCUS';
      actionBg = quest.isCompleted ? LevMaxTheme.surfaceContainerHigh : LevMaxTheme.secondaryContainer;
      actionTextColor = const Color(0xFFC9AEFF);
      actionIcon = Icons.center_focus_strong;
      questIcon = categoryLower == 'study' ? Icons.menu_book : Icons.terminal;
      telemetryLabel = 'DEEP WORK TIMER';
    } else if (categoryLower == 'skincare') {
      accentColor = LevMaxTheme.secondary;
      subLabel = 'DAILY LOOKSMAXXING PROTOCOL';
      badgeText = quest.isCompleted ? 'COMPLETED' : 'ROUTINE';
      badgeBg = LevMaxTheme.surfaceContainerHighest;
      badgeTextColor = LevMaxTheme.onSurface;
      actionLabel = quest.isCompleted ? 'COMPLETED' : 'COMPLETE';
      actionBg = LevMaxTheme.primaryContainer;
      actionTextColor = LevMaxTheme.onPrimaryFixed;
      actionIcon = Icons.check;
      questIcon = Icons.spa;
      telemetryLabel = 'PROGRESS';
    }

    final double progressRatio = quest.targetValue > 0
        ? (quest.currentValue / quest.targetValue).clamp(0.0, 1.0)
        : (quest.isCompleted ? 1.0 : 0.0);
    final int progressPercent = (progressRatio * 100).toInt();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: LevMaxTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          // Garis Aksen Neon Kiri (4px)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 4,
            child: Container(
              decoration: BoxDecoration(
                color: accentColor,
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.8),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),

          // Isi Konten Kartu
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Baris Atas: Ikon Kotak + Sub-label/Judul + Status Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: LevMaxTheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(
                        child: Icon(questIcon, size: 20, color: accentColor),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            subLabel,
                            style: LevMaxTheme.mono(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: accentColor,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            quest.title.startsWith('[') ? quest.title : '[${quest.title.toUpperCase()}]',
                            style: LevMaxTheme.headline(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: LevMaxTheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        badgeText,
                        style: LevMaxTheme.mono(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: badgeTextColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 2. Baris Telemetry & Progress
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      telemetryLabel,
                      style: LevMaxTheme.mono(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: LevMaxTheme.outline,
                      ),
                    ),
                    Text(
                      '${quest.currentValue} / ${quest.targetValue} ${quest.unit} ($progressPercent%)',
                      style: LevMaxTheme.mono(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: LevMaxTheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                GlowingProgressBar(
                  progress: progressRatio,
                  color: accentColor,
                  height: 8,
                  trackColor: LevMaxTheme.surfaceContainerLowest,
                  glowBlurRadius: 8,
                ),
                const SizedBox(height: 14),

                // 3. Baris Footer: Rewards di kiri + Tombol Aksi di kanan
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.bolt, size: 12, color: LevMaxTheme.tertiaryFixedDim),
                        const SizedBox(width: 2),
                        Text(
                          '+${quest.expReward} EXP',
                          style: LevMaxTheme.mono(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: LevMaxTheme.tertiaryFixedDim,
                          ),
                        ),
                        Text(' • ', style: LevMaxTheme.mono(fontSize: 10, color: LevMaxTheme.outline)),
                        const Icon(Icons.toll, size: 12, color: LevMaxTheme.goldCoin),
                        const SizedBox(width: 2),
                        Text(
                          '+${quest.goldReward} G',
                          style: LevMaxTheme.mono(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: LevMaxTheme.goldAmber,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () {
                        if (quest.isCompleted) {
                          _toggleQuestCompletion(quest);
                        } else {
                          _incrementQuestProgress(quest);
                        }
                      },
                      child: Container(
                        width: 130,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: actionBg,
                          borderRadius: BorderRadius.circular(4),
                          border: actionBg == LevMaxTheme.surfaceContainerHigh
                              ? Border.all(color: LevMaxTheme.surfaceContainerHighest, width: 1)
                              : null,
                          boxShadow: actionBg == LevMaxTheme.primaryContainer
                              ? const [
                                  BoxShadow(
                                    color: Color(0x6600F0FF),
                                    blurRadius: 10,
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(actionIcon, size: 16, color: actionTextColor),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                actionLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: LevMaxTheme.mono(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: actionTextColor,
                                ),
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
  // KOMPONEN 6: BANNER STREAK SAFEGUARD ACTIVE
  // ==========================================================================
  Widget _buildStreakSafeguardBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LevMaxTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: LevMaxTheme.primaryContainer.withValues(alpha: 0.1),
            ),
            child: const Center(
              child: Icon(Icons.verified, color: LevMaxTheme.primaryContainer, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STREAK SAFEGUARD ACTIVE',
                  style: LevMaxTheme.mono(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: LevMaxTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Day 12 Consecutive Protocol Maintained',
                  style: TextStyle(
                    fontSize: 12,
                    color: LevMaxTheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: LevMaxTheme.tertiaryContainer,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: LevMaxTheme.tertiaryContainer,
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '+15% EXP BUFF',
                style: LevMaxTheme.mono(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: LevMaxTheme.tertiaryContainer,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // KOMPONEN 7: DUAL FLOATING ACTION OVERLAY
  // ==========================================================================
  Widget _buildDualFloatingOverlay() {
    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Row(
        children: [
          // Tombol Kiri: + TOMORROW PLAN
          Expanded(
            child: GestureDetector(
              onTap: _openAddPlanModal,
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: LevMaxTheme.surfaceContainer.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: LevMaxTheme.primaryContainer.withValues(alpha: 0.25),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x3300F0FF),
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.calendar_today, size: 16, color: LevMaxTheme.primaryContainer),
                    const SizedBox(width: 8),
                    Text(
                      '+ TOMORROW PLAN',
                      style: LevMaxTheme.mono(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFDBFCFF),
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
            onTap: _openSystemChatSheet,
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: LevMaxTheme.primaryContainer,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x6600F0FF),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.visibility, color: LevMaxTheme.onPrimaryFixed, size: 24),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: LevMaxTheme.background,
      child: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Komponen 1: Sticky Tactical Header
                _buildStickyTacticalHeader(),

                // Scrollable Content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 90), // Berikan ruang untuk floating overlay
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Komponen 2: Player Status Window
                        _buildPlayerStatusHeroCard(),
                        const SizedBox(height: 16),

                        // Komponen 3: Search Bar & Tactical Filter Chips
                        _buildSearchBarAndFilters(),
                        const SizedBox(height: 16),

                        // Komponen 4: Header [ACTIVE QUEST LOG]
                        _buildActiveQuestLogHeader(),
                        const SizedBox(height: 12),

                        // Komponen 5: Kartu Quest Taktis dengan Hive ValueListenableBuilder
                        ValueListenableBuilder<Box<QuestModel>>(
                          valueListenable: Hive.box<QuestModel>(HiveBoxes.questBox).listenable(),
                          builder: (context, box, _) {
                            final query = _searchController.text.toLowerCase().trim();
                            final allQuests = box.values.toList();
                            final filtered = allQuests.where((q) {
                              final matchQuery = query.isEmpty ||
                                  q.title.toLowerCase().contains(query) ||
                                  q.description.toLowerCase().contains(query);

                              final matchCategory = _selectedCategory == 'ALL' ||
                                  q.category.toUpperCase() == _selectedCategory.toUpperCase();

                              return matchQuery && matchCategory;
                            }).toList();

                            if (filtered.isEmpty) {
                              return Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: LevMaxTheme.surfaceContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    'NO PROTOCOL QUESTS FOUND IN SYSTEM LOG',
                                    style: LevMaxTheme.mono(
                                      fontSize: 11,
                                      color: LevMaxTheme.outline,
                                    ),
                                  ),
                                ),
                              );
                            }

                            return ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final quest = filtered[index];
                                final originalIndex = allQuests.indexOf(quest);

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
                                        const Icon(Icons.delete, color: Colors.white),
                                        const SizedBox(width: 8),
                                        Text(
                                          'ABANDON PROTOCOL',
                                          style: LevMaxTheme.mono(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  onDismissed: (_) {
                                    box.deleteAt(originalIndex);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: LevMaxTheme.surfaceContainer,
                                        content: Text(
                                          'Quest "${quest.title}" purged from System Log.',
                                          style: LevMaxTheme.mono(fontSize: 11, color: LevMaxTheme.hpRedLabel),
                                        ),
                                      ),
                                    );
                                  },
                                  child: _buildTacticalQuestCard(quest),
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 8),

                        // Komponen 6: Banner Streak Safeguard
                        _buildStreakSafeguardBanner(),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Komponen 7: Dual Floating Action Overlay
            _buildDualFloatingOverlay(),
          ],
        ),
      ),
    );
  }
}
