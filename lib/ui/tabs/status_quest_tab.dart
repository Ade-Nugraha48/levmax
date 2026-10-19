// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/ui/tabs/status_quest_tab.dart
// Deskripsi: Tab 1 Daily Quests & Hunter Status Window - Redesain Google Stitch
//            Mengusung estetika Solo Leveling System Blue Window, Telemetri HUD,
//            dan Integrasi Sensor Realtime dengan Hive Reactive Box.
// ==============================================================================

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../../helpers/boxes.dart';
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
    {'label': 'PENALTI', 'icon': Icons.warning_amber_rounded},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _titleController.dispose();
    _descController.dispose();
    _targetValueController.dispose();
    super.dispose();
  }

  // ==========================================================================
  // LOGIKA GAME BALANCING: SELESAIKAN QUEST & LEVEL UP
  // ==========================================================================
  Future<void> _toggleQuestCompletion(QuestModel quest, int index) async {
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
            content: Row(
              children: [
                const Icon(Icons.verified, color: Colors.black),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'QUEST SELESAI! +${quest.expReward} EXP, +${quest.goldReward} GOLD DITAMBAHKAN.',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 12),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF00F0FF),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      await SupabaseApiService.syncQuest(quest: quest, userId: widget.player.id);
      widget.onPlayerUpdated();
    }
  }

  // ==========================================================================
  // FORM TAMBAH PLAN QUEST ESOK HARI (MODAL BOTTOM SHEET)
  // ==========================================================================
  void _openTomorrowPlanSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: Color(0xFF00F0FF), width: 1.5),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Form(
                key: _planFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade700,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        Icon(Icons.calendar_today, color: Color(0xFF00F0FF), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'RENCANA QUEST ESOK HARI',
                          style: TextStyle(
                            color: Color(0xFF00F0FF),
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Rancang quest produktivitas esok hari agar Anda terhindar dari Zona Penalti.',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _titleController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Judul Quest',
                        labelStyle: const TextStyle(color: Color(0xFF00F0FF), fontSize: 12),
                        filled: true,
                        fillColor: const Color(0xFF0B0F19),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF1E293B)),
                        ),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Judul wajib diisi' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Deskripsi / Catatan Tambahan',
                        labelStyle: const TextStyle(color: Color(0xFF00F0FF), fontSize: 12),
                        filled: true,
                        fillColor: const Color(0xFF0B0F19),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF1E293B)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _newQuestCategory,
                            dropdownColor: const Color(0xFF111827),
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              labelText: 'Kategori',
                              labelStyle: const TextStyle(color: Color(0xFF00F0FF), fontSize: 12),
                              filled: true,
                              fillColor: const Color(0xFF0B0F19),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            items: ['Workout', 'Cardio', 'Skincare', 'Study', 'Work']
                                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setSheetState(() {
                                  _newQuestCategory = val;
                                  if (val == 'Workout') _newQuestUnit = 'Reps';
                                  if (val == 'Cardio') _newQuestUnit = 'KM';
                                  if (val == 'Study' || val == 'Work') _newQuestUnit = 'Mins';
                                  if (val == 'Skincare') _newQuestUnit = 'Sesi';
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
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              labelText: 'Target ($_newQuestUnit)',
                              labelStyle: const TextStyle(color: Color(0xFF00F0FF), fontSize: 12),
                              filled: true,
                              fillColor: const Color(0xFF0B0F19),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            validator: (v) => (int.tryParse(v ?? '') == null) ? 'Angka valid' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () async {
                        if (_planFormKey.currentState?.validate() != true) return;

                        final targetVal = int.tryParse(_targetValueController.text) ?? 10;
                        int expReward = 20;
                        int goldReward = 10;
                        if (_newQuestCategory == 'Workout') {
                          expReward = 25;
                          goldReward = 50;
                        } else if (_newQuestCategory == 'Cardio') {
                          expReward = 40;
                          goldReward = 80;
                        } else if (_newQuestCategory == 'Study') {
                          expReward = 30;
                          goldReward = 60;
                        }

                        final tomorrow = DateTime.now().add(const Duration(days: 1)).toIso8601String().substring(0, 10);
                        final newQuest = QuestModel(
                          id: 'custom_plan_${DateTime.now().millisecondsSinceEpoch}',
                          title: _titleController.text.trim(),
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

                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        final navigator = Navigator.of(ctx);

                        final box = Hive.box<QuestModel>(HiveBoxes.questBox);
                        await box.add(newQuest);
                        await SupabaseApiService.syncQuest(quest: newQuest, userId: widget.player.id);

                        _titleController.clear();
                        _descController.clear();
                        _targetValueController.text = '10';

                        navigator.pop();
                        scaffoldMessenger.showSnackBar(
                          const SnackBar(
                            content: Text('Rencana Quest Berhasil Ditambahkan ke Sistem!'),
                            backgroundColor: Color(0xFF00F0FF),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add_task, color: Colors.black),
                      label: const Text('SIMPAN RENCANA KE SISTEM', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00F0FF),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ==========================================================================
  // MODAL AI CHAT ASSISTANT "THE SYSTEM" (GEMINI AI)
  // ==========================================================================
  void _openSystemChatSheet() {
    final chatMsgController = TextEditingController();
    final List<Map<String, String>> messages = [
      {
        'sender': 'system',
        'text':
            '[THE SYSTEM ONLINE]\nHunter ${widget.player.username}. Status Anda: Level ${widget.player.level}, Rank ${widget.player.rank}. Laporkan kebutuhan konsultasi Anda seputar Workout, Looksmaxxing, atau Disiplin Belajar.'
      }
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0B0F19),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: Color(0xFF00F0FF), width: 1.5),
      ),
      builder: (ctx) {
        bool isTyping = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 18,
                right: 18,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.72,
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.visibility, color: Color(0xFF00F0FF), size: 24),
                        const SizedBox(width: 8),
                        const Text(
                          '[THE SYSTEM: CONDUIT OF MONARCH]',
                          style: TextStyle(
                            color: Color(0xFF00F0FF),
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(color: Color(0xFF1E293B)),
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
                                maxWidth: MediaQuery.of(context).size.width * 0.8,
                              ),
                              decoration: BoxDecoration(
                                color: isSystem
                                    ? const Color(0xFF111827)
                                    : const Color(0xFF00F0FF).withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSystem ? const Color(0xFF1E293B) : const Color(0xFF00F0FF),
                                ),
                              ),
                              child: Text(
                                msg['text'] ?? '',
                                style: TextStyle(
                                  color: isSystem ? const Color(0xFFDFE2F1) : const Color(0xFF00F0FF),
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
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          '[The System sedang memproses telemetri...]',
                          style: TextStyle(
                            color: Color(0xFF00F0FF),
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: chatMsgController,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'Inquire with The System...',
                                hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                                filled: true,
                                fillColor: const Color(0xFF111827),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFF1E293B)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.send, color: Color(0xFF00F0FF)),
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

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'workout':
        return const Color(0xFF00F0FF); // Primary Cyan
      case 'cardio':
        return const Color(0xFF65F2B5); // Mint Emerald
      case 'skincare':
        return const Color(0xFFD2BBFF); // Violet
      case 'study':
        return const Color(0xFF7C3AED); // Royal Purple
      case 'work':
        return const Color(0xFFF59E0B); // Amber
      case 'penalti':
        return const Color(0xFFFF2A54); // Crimson
      default:
        return const Color(0xFF00F0FF);
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'workout':
        return Icons.fitness_center;
      case 'cardio':
        return Icons.directions_run;
      case 'skincare':
        return Icons.spa;
      case 'study':
        return Icons.timer;
      case 'work':
        return Icons.terminal;
      case 'penalti':
        return Icons.warning_amber_rounded;
      default:
        return Icons.assignment;
    }
  }

  String _getCategoryTag(String category) {
    switch (category.toLowerCase()) {
      case 'workout':
        return 'PHYSICAL SENSOR (ACCELEROMETER)';
      case 'cardio':
        return 'GPS DUNGEON TRACKING';
      case 'skincare':
        return 'HABIT RESTORATION PROTOCOL';
      case 'study':
        return 'GYROSCOPE POSTURE GUARDIAN';
      case 'work':
        return 'DEEP WORK FOCUS SESSION';
      case 'penalti':
        return 'CRITICAL SYSTEM PUNISHMENT';
      default:
        return 'DAILY SYSTEM PROTOCOL';
    }
  }

  @override
  Widget build(BuildContext context) {
    final hpPercentage = (widget.player.hp / 100.0).clamp(0.0, 1.0);
    final expPercentage = (widget.player.exp / 100.0).clamp(0.0, 1.0);
    final formattedDate = DateFormat('MMM dd').format(DateTime.now()).toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFF0F131D),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
          // MAIN SCROLLABLE CONTENT
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 12.0, bottom: 120.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ============================================================
                // TOP SYSTEM BAR
                // ============================================================
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF00F0FF),
                            boxShadow: [
                              BoxShadow(color: Color(0xFF00F0FF), blurRadius: 8, spreadRadius: 1),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '[SYSTEM ALERT]',
                              style: TextStyle(
                                color: Color(0xFF00F0FF),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            Text(
                              'DAILY QUESTS',
                              style: TextStyle(
                                color: Color(0xFFDFE2F1),
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              formattedDate,
                              style: const TextStyle(
                                color: Color(0xFFDFE2F1),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Row(
                              children: [
                                CircleAvatar(radius: 2.5, backgroundColor: Color(0xFF4EDEA3)),
                                SizedBox(width: 4),
                                Text(
                                  'ONLINE • 24ms',
                                  style: TextStyle(color: Color(0xFFB9CACB), fontSize: 9),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(width: 10),
                        // Mini Profile Thumbnail
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF00F0FF), width: 1.5),
                            color: const Color(0xFF1C1F2A),
                          ),
                          child: const Icon(Icons.person, color: Color(0xFF00F0FF), size: 20),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ============================================================
                // HERO CARD: PLAYER STATUS WINDOW (STITCH DESIGN)
                // ============================================================
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1F2A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1E293B)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Top Strip
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF00F0FF),
                                  boxShadow: [
                                    BoxShadow(color: Color(0xFF00F0FF), blurRadius: 6, spreadRadius: 1),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'HUNTER HUD // ID: #${widget.player.id.toString().padLeft(6, '0')}',
                                style: const TextStyle(
                                  color: Color(0xFF00F0FF),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                          // Gold Badge Pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0A0E18),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.toll, color: Color(0xFFF59E0B), size: 13),
                                const SizedBox(width: 4),
                                Text(
                                  '${widget.player.gold} G',
                                  style: const TextStyle(
                                    color: Color(0xFFFBBF24),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Avatar & Identity Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 64x64 Avatar with Rank Badge
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: const Color(0xFF0A0E18),
                                  border: Border.all(color: const Color(0xFF00F0FF).withValues(alpha: 0.4)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF00F0FF).withValues(alpha: 0.2),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.shield, color: Color(0xFF00F0FF), size: 36),
                              ),
                              Positioned(
                                bottom: -4,
                                right: -4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00F0FF),
                                    borderRadius: BorderRadius.circular(4),
                                    boxShadow: const [
                                      BoxShadow(color: Color(0xFF00F0FF), blurRadius: 4),
                                    ],
                                  ),
                                  child: Text(
                                    'RANK ${widget.player.rank}',
                                    style: const TextStyle(
                                      color: Color(0xFF002022),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 14),

                          // Player Name, Level & Class
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        widget.player.username.toUpperCase(),
                                        style: const TextStyle(
                                          color: Color(0xFFDFE2F1),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.8,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00F0FF).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'LV. ${widget.player.level}',
                                        style: const TextStyle(
                                          color: Color(0xFF00F0FF),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.shield_outlined, color: Color(0xFFD2BBFF), size: 12),
                                    const SizedBox(width: 4),
                                    Text(
                                      widget.player.rankTitle.toUpperCase(),
                                      style: const TextStyle(
                                        color: Color(0xFFD2BBFF),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Text('•', style: TextStyle(color: Color(0xFF849495), fontSize: 10)),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'AWAKENED',
                                      style: TextStyle(
                                        color: Color(0xFF4EDEA3),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // HP Gauge
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.favorite, color: Color(0xFFFF2A54), size: 11),
                                        SizedBox(width: 3),
                                        Text(
                                          'HP',
                                          style: TextStyle(color: Color(0xFFFF2A54), fontSize: 9, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '${widget.player.hp} / 100',
                                      style: const TextStyle(color: Color(0xFFB9CACB), fontSize: 9, fontFamily: 'monospace'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(3),
                                    color: const Color(0xFF0A0E18),
                                  ),
                                  child: FractionallySizedBox(
                                    widthFactor: hpPercentage,
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(3),
                                        color: const Color(0xFFFF2A54),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFFFF2A54).withValues(alpha: 0.6),
                                            blurRadius: 6,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // EXP Gauge
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.bolt, color: Color(0xFF65F2B5), size: 12),
                                        SizedBox(width: 3),
                                        Text(
                                          'EXP',
                                          style: TextStyle(color: Color(0xFF65F2B5), fontSize: 9, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '${widget.player.exp} / 100 (${(expPercentage * 100).toInt()}%)',
                                      style: const TextStyle(color: Color(0xFFB9CACB), fontSize: 9, fontFamily: 'monospace'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(3),
                                    color: const Color(0xFF0A0E18),
                                  ),
                                  child: FractionallySizedBox(
                                    widthFactor: expPercentage,
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(3),
                                        color: const Color(0xFF65F2B5),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF65F2B5).withValues(alpha: 0.6),
                                            blurRadius: 6,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ============================================================
                // SEARCH & CATEGORY FILTER CAROUSEL
                // ============================================================
                Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1F2A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      const Icon(Icons.search, color: Color(0xFF849495), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: 'Search habits & dungeon quests...',
                            hintStyle: TextStyle(color: Color(0xFF849495), fontSize: 12),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF313540),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'CTRL+K',
                          style: TextStyle(color: Color(0xFF849495), fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Horizontal Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: _filterChips.map((chip) {
                      final label = chip['label'] as String;
                      final icon = chip['icon'] as IconData?;
                      final isSelected = _selectedCategory == label;

                      return Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedCategory = label;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: 32,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF00F0FF) : const Color(0xFF1C1F2A),
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF00F0FF).withValues(alpha: 0.35),
                                        blurRadius: 8,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              children: [
                                if (isSelected) ...[
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0xFF0A0E18),
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                ] else if (icon != null) ...[
                                  Icon(icon, size: 14, color: const Color(0xFFB9CACB)),
                                  const SizedBox(width: 4),
                                ],
                                Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                                    letterSpacing: 0.5,
                                    color: isSelected ? const Color(0xFF002022) : const Color(0xFFB9CACB),
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
                const SizedBox(height: 20),

                // ============================================================
                // ACTIVE QUEST LOG SECTION HEADER
                // ============================================================
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.assignment_turned_in_outlined, color: Color(0xFF00F0FF), size: 18),
                            SizedBox(width: 6),
                            Text(
                              '[ACTIVE QUEST LOG]',
                              style: TextStyle(
                                color: Color(0xFFDFE2F1),
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Complete daily assignments to avoid the Penalty Zone',
                          style: TextStyle(color: Color(0xFF849495), fontSize: 11),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (widget.player.isPenaltyActive)
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
                            child: const Text(
                              'PENALTI AKTIF!',
                              style: TextStyle(
                                color: Color(0xFFFF2A54),
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          )
                        else
                          const Text(
                            'PENALTY: 14H 12M',
                            style: TextStyle(
                              color: Color(0xFFFF2A54),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        const Text(
                          'RESET AT 00:00',
                          style: TextStyle(color: Color(0xFF849495), fontSize: 9),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ============================================================
                // DAILY QUEST CARDS LIST (HIVE REACTIVE STREAM)
                // ============================================================
                ValueListenableBuilder<Box<QuestModel>>(
                  valueListenable: Hive.box<QuestModel>(HiveBoxes.questBox).listenable(),
                  builder: (context, box, _) {
                    if (box.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1F2A),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF1E293B)),
                        ),
                        child: const Center(
                          child: Column(
                            children: [
                              Icon(Icons.inbox_outlined, color: Color(0xFF849495), size: 36),
                              SizedBox(height: 10),
                              Text(
                                'Tidak ada Daily Quest aktif.',
                                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Tekan "+ Tomorrow Plan" di bawah untuk merancang quest baru.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Color(0xFF849495), fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final query = _searchController.text.toLowerCase().trim();
                    final allQuests = box.values.toList();
                    final filtered = allQuests.where((q) {
                      final matchQuery = query.isEmpty ||
                          q.title.toLowerCase().contains(query) ||
                          q.description.toLowerCase().contains(query);

                      final matchCategory = _selectedCategory == 'ALL' ||
                          (_selectedCategory == 'PENALTI'
                              ? q.isPenaltyQuest
                              : q.category.toUpperCase() == _selectedCategory);

                      return matchQuery && matchCategory;
                    }).toList();

                    if (filtered.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1F2A),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Text(
                            'Tidak ada quest yang sesuai dengan filter.',
                            style: TextStyle(color: Color(0xFF849495), fontSize: 12),
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final quest = filtered[index];
                        final originalIndex = allQuests.indexOf(quest);
                        final accentColor = _getCategoryColor(quest.category);
                        final categoryIcon = _getCategoryIcon(quest.category);
                        final categoryTag = _getCategoryTag(quest.category);

                        final progressFraction = quest.targetValue > 0
                            ? (quest.currentValue / quest.targetValue).clamp(0.0, 1.0)
                            : (quest.isCompleted ? 1.0 : 0.0);
                        final progressPercent = (progressFraction * 100).toInt();

                        return Dismissible(
                          key: Key(quest.id.isNotEmpty ? quest.id : index.toString()),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF2A54),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Icon(Icons.delete_outline, color: Colors.white),
                                SizedBox(width: 6),
                                Text('HAPUS QUEST', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                          ),
                          onDismissed: (_) {
                            box.deleteAt(originalIndex);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Quest "${quest.title}" dihapus.'),
                                backgroundColor: const Color(0xFFFF2A54),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1C1F2A),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: quest.isCompleted
                                    ? const Color(0xFF10B981).withValues(alpha: 0.5)
                                    : const Color(0xFF1E293B),
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Cybernetic Accent Strip on Left
                                  Container(
                                    width: 4,
                                    decoration: BoxDecoration(
                                      color: quest.isCompleted ? const Color(0xFF10B981) : accentColor,
                                      boxShadow: [
                                        BoxShadow(
                                          color: (quest.isCompleted ? const Color(0xFF10B981) : accentColor).withValues(alpha: 0.8),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Card Content Body
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(14.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          // Row 1: Icon + Subtitle + Badge
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                width: 38,
                                                height: 38,
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF0A0E18),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Icon(categoryIcon, color: accentColor, size: 20),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      categoryTag,
                                                      style: TextStyle(
                                                        color: accentColor,
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.bold,
                                                        letterSpacing: 0.8,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      '[${quest.title.toUpperCase()}]',
                                                      style: TextStyle(
                                                        color: quest.isCompleted ? const Color(0xFF849495) : const Color(0xFFDFE2F1),
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w900,
                                                        decoration: quest.isCompleted ? TextDecoration.lineThrough : null,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: quest.isCompleted
                                                      ? const Color(0xFF10B981).withValues(alpha: 0.2)
                                                      : const Color(0xFF262A35),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  quest.isCompleted
                                                      ? 'COMPLETED'
                                                      : (progressPercent > 0 ? 'IN PROGRESS' : 'DAILY'),
                                                  style: TextStyle(
                                                    color: quest.isCompleted ? const Color(0xFF10B981) : const Color(0xFFB9CACB),
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),

                                          // Row 2: Metric Telemetry Track
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text(
                                                'PROGRESS',
                                                style: TextStyle(
                                                  color: Color(0xFF849495),
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                              Text(
                                                '${quest.currentValue} / ${quest.targetValue} ${quest.unit} ($progressPercent%)',
                                                style: TextStyle(
                                                  color: quest.isCompleted ? const Color(0xFF10B981) : const Color(0xFFDFE2F1),
                                                  fontSize: 11,
                                                  fontFamily: 'monospace',
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Container(
                                            height: 6,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(3),
                                              color: const Color(0xFF0A0E18),
                                            ),
                                            child: FractionallySizedBox(
                                              widthFactor: progressFraction,
                                              alignment: Alignment.centerLeft,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(3),
                                                  color: quest.isCompleted ? const Color(0xFF10B981) : accentColor,
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: (quest.isCompleted ? const Color(0xFF10B981) : accentColor)
                                                          .withValues(alpha: 0.6),
                                                      blurRadius: 6,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 12),

                                          // Row 3: Footer Rewards & Tactile Action Button
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  const Icon(Icons.bolt, color: Color(0xFF65F2B5), size: 13),
                                                  const SizedBox(width: 2),
                                                  Text(
                                                    '+${quest.expReward} EXP',
                                                    style: const TextStyle(
                                                      color: Color(0xFF65F2B5),
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  const Text('•', style: TextStyle(color: Color(0xFF849495), fontSize: 10)),
                                                  const SizedBox(width: 6),
                                                  const Icon(Icons.toll, color: Color(0xFFFBBF24), size: 13),
                                                  const SizedBox(width: 2),
                                                  Text(
                                                    '+${quest.goldReward} G',
                                                    style: const TextStyle(
                                                      color: Color(0xFFFBBF24),
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),

                                              // Primary Action Button
                                              ElevatedButton.icon(
                                                onPressed: () => _toggleQuestCompletion(quest, originalIndex),
                                                icon: Icon(
                                                  quest.isCompleted ? Icons.check_circle : Icons.play_arrow,
                                                  size: 15,
                                                  color: quest.isCompleted ? Colors.white : Colors.black,
                                                ),
                                                label: Text(
                                                  quest.isCompleted
                                                      ? 'DONE'
                                                      : (quest.category.toLowerCase() == 'workout'
                                                          ? 'START QUEST'
                                                          : quest.category.toLowerCase() == 'cardio'
                                                              ? 'CONTINUE'
                                                              : quest.category.toLowerCase() == 'study'
                                                                  ? 'FOCUS'
                                                                  : 'EXECUTE'),
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w900,
                                                    letterSpacing: 0.8,
                                                    color: quest.isCompleted ? Colors.white : Colors.black,
                                                  ),
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: quest.isCompleted
                                                      ? const Color(0xFF10B981)
                                                      : const Color(0xFF00F0FF),
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                                  elevation: 4,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),

                // ============================================================
                // STREAK SAFEGUARD BANNER
                // ============================================================
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF171B26),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF00F0FF).withValues(alpha: 0.15),
                        ),
                        child: const Icon(Icons.verified_outlined, color: Color(0xFF00F0FF), size: 18),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'STREAK SAFEGUARD ACTIVE',
                              style: TextStyle(
                                color: Color(0xFFDFE2F1),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Day 12 Consecutive Protocol Maintained',
                              style: TextStyle(color: Color(0xFF849495), fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF65F2B5),
                              boxShadow: [
                                BoxShadow(color: Color(0xFF65F2B5), blurRadius: 4),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            '+15% EXP BUFF',
                            style: TextStyle(
                              color: Color(0xFF65F2B5),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ============================================================
          // FLOATING BUTTONS OVERLAY (BOTTOM DOCKED)
          // ============================================================
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left Pill Button: + Tomorrow Plan
                GestureDetector(
                  onTap: _openTomorrowPlanSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1F2A).withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF00F0FF).withValues(alpha: 0.4)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today_outlined, color: Color(0xFF00F0FF), size: 15),
                        SizedBox(width: 8),
                        Text(
                          '+ TOMORROW PLAN',
                          style: TextStyle(
                            color: Color(0xFF00F0FF),
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Right Circular FAB: The System AI Conduit (Eye Icon)
                GestureDetector(
                  onTap: _openSystemChatSheet,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF00F0FF),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00F0FF).withValues(alpha: 0.5),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.visibility, color: Color(0xFF002022), size: 24),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  }
}
