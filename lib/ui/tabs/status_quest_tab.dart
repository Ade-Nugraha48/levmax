// Tab Status Window dan Manajemen Daily Quest
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../helpers/boxes.dart';
import '../../models/quest_model.dart';
import '../../models/user_model.dart';
import '../../services/blockchain_service.dart';
import '../../services/notification_service.dart';
import '../../services/supabase_api_service.dart';
import '../penalty_minigame_page.dart';
import '../sensor_workout_page.dart';
import '../widgets/ai_system_chat_sheet.dart';

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
  // Controller pencarian dan form rencana baru
  final _searchController = TextEditingController();
  final _planFormKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _targetValueController = TextEditingController(text: '10');

  // Filter kategori dan form
  String _selectedCategory = 'Semua';
  String _newQuestCategory = 'Workout';
  String _newQuestUnit = 'Reps';
  bool _isFormExpanded = false;

  final List<String> _categories = [
    'Semua',
    'Workout',
    'Cardio',
    'Skincare',
    'Study',
    'Work',
    'Penalti',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _titleController.dispose();
    _descController.dispose();
    _targetValueController.dispose();
    super.dispose();
  }

  // Toggle status penyelesaian quest dan kalkulasi reward EXP/Gold/Level
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

      // Pengecekan Level Up jika EXP >= 100
      if (currentExp >= 100) {
        currentLevel += 1;
        currentExp -= 100;
        currentHp = min(100, currentHp + 10);
        final newRank = UserModel.calculateRank(currentLevel);

        // Catat peristiwa kenaikan level ke rantai blok
        await BlockchainService.addBlock(
          'LEVEL UP: Player reached Level $currentLevel (Rank $newRank). Restored +10 HP.',
          userId: widget.player.id,
        );

        // Kirim notifikasi lokal kenaikan level
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

      // Simpan perubahan data ke database dan cache
      await SupabaseApiService.updateUser(updatedPlayer);
      await SupabaseApiService.syncQuest(quest: quest, userId: widget.player.id);
      widget.onPlayerUpdated();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Quest Selesai! +$expGain EXP, +$goldGain Gold diperoleh.'),
            backgroundColor: const Color(0xFF00E5FF),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      await SupabaseApiService.syncQuest(quest: quest, userId: widget.player.id);
      widget.onPlayerUpdated();
    }
  }

  // Validasi dan penyimpanan rencana quest esok hari
  Future<void> _onFormSubmit() async {
    if (_planFormKey.currentState == null || !_planFormKey.currentState!.validate()) {
      return;
    }

    final targetVal = int.tryParse(_targetValueController.text) ?? 10;
    int expReward = 20;
    int goldReward = 10;

    switch (_newQuestCategory) {
      case 'Workout':
        expReward = 25;
        goldReward = 10;
        break;
      case 'Cardio':
        expReward = 30;
        goldReward = 15;
        break;
      case 'Skincare':
        expReward = 15;
        goldReward = 5;
        break;
      case 'Study':
      case 'Work':
        expReward = 20;
        goldReward = 10;
        break;
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

    // Simpan ke Hive box dan sinkronisasi
    final box = Hive.box<QuestModel>(HiveBoxes.questBox);
    await box.add(newQuest);
    await SupabaseApiService.syncQuest(quest: newQuest, userId: widget.player.id);

    _titleController.clear();
    _descController.clear();
    _targetValueController.text = '10';

    setState(() {
      _isFormExpanded = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rencana quest berhasil ditambahkan ke jadwal esok hari.'),
          backgroundColor: Color(0xFF00E5FF),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Tampilan modal dialog konsultasi asisten The System
  void _openSystemChatSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: Color(0xFF00E5FF), width: 1.5),
      ),
      builder: (ctx) => AiSystemChatSheet(player: widget.player),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hpPercentage = (widget.player.hp / 100.0).clamp(0.0, 1.0);
    final expPercentage = (widget.player.exp / 100.0).clamp(0.0, 1.0);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Kartu Status Window Utama
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF131B2E),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: widget.player.rankColor,
                width: 2.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.player.rankColor.withValues(alpha: 0.35),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: widget.player.rankColor, width: 2.5),
                            color: const Color(0xFF0A0E1A),
                          ),
                          child: Center(
                            child: Text(
                              widget.player.rank,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: widget.player.rankColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.player.username.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 1.5,
                              ),
                            ),
                            Text(
                              widget.player.rankTitle,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: widget.player.rankColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF00E5FF)),
                      ),
                      child: Text(
                        'LVL ${widget.player.level}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF00E5FF),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Health Points Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'HP (HEALTH POINTS)',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                    Text(
                      '${widget.player.hp} / 100',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: widget.player.hp <= 30 ? const Color(0xFFFF1744) : Colors.greenAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: hpPercentage,
                    minHeight: 10,
                    backgroundColor: const Color(0xFF1E293B),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      widget.player.hp <= 30 ? const Color(0xFFFF1744) : Colors.greenAccent,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Experience Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'EXP (NEXT LEVEL)',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                    Text(
                      '${widget.player.exp} / 100',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF00E5FF)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: expPercentage,
                    minHeight: 8,
                    backgroundColor: const Color(0xFF1E293B),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
                  ),
                ),
                const SizedBox(height: 12),

                // Indikator Gold dan Penalti
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.monetization_on, color: Colors.amber, size: 20),
                        const SizedBox(width: 6),
                        Text(
                          '${widget.player.gold} Gold',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Colors.amber,
                          ),
                        ),
                      ],
                    ),
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
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF1744).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFF1744)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.warning, color: Color(0xFFFF1744), size: 14),
                              SizedBox(width: 4),
                              Text(
                                'PENALTI AKTIF (BUKA)',
                                style: TextStyle(
                                  color: Color(0xFFFF1744),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
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
          const SizedBox(height: 16),

          // Tombol Navigasi Cepat Sensor Workout dan Asisten
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => SensorWorkoutPage(player: widget.player)),
                    );
                  },
                  icon: const Icon(Icons.sensors, size: 18, color: Colors.black),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'SENSOR WORKOUT',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5FF),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openSystemChatSheet,
                  icon: const Icon(Icons.psychology, size: 18, color: Color(0xFF00E5FF)),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'THE SYSTEM CHAT',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF00E5FF)),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF00E5FF)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Field Pencarian Quest
          TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Cari Daily Quest Hunter...',
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF00E5FF), size: 20),
              filled: true,
              fillColor: const Color(0xFF131B2E),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF1E293B)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF1E293B)),
              ),
            ),
            onChanged: (val) {
              setState(() {});
            },
          ),
          const SizedBox(height: 10),

          // ChoiceChips Filter Kategori
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(
                      cat,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.black : Colors.white70,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: const Color(0xFF00E5FF),
                    backgroundColor: const Color(0xFF131B2E),
                    side: BorderSide(
                      color: isSelected ? const Color(0xFF00E5FF) : const Color(0xFF1E293B),
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedCategory = cat;
                        });
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          const Text(
            'DAILY QUEST HARI INI',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: Color(0xFF00E5FF),
            ),
          ),
          const SizedBox(height: 10),

          // Hive listenable builder untuk render daftar quest harian
          ValueListenableBuilder<Box<QuestModel>>(
            valueListenable: Hive.box<QuestModel>(HiveBoxes.questBox).listenable(),
            builder: (context, box, _) {
              if (box.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131B2E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text(
                      'Tidak ada Daily Quest aktif.\nBuat rencana quest esok hari di bawah!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),
                );
              }

              // Filter pencarian dan kategori
              final query = _searchController.text.toLowerCase().trim();
              final allQuests = box.values.toList();
              final filtered = allQuests.where((q) {
                final matchQuery = query.isEmpty ||
                    q.title.toLowerCase().contains(query) ||
                    q.description.toLowerCase().contains(query);

                final matchCategory = _selectedCategory == 'Semua' ||
                    (_selectedCategory == 'Penalti' ? q.isPenaltyQuest : q.category == _selectedCategory);

                return matchQuery && matchCategory;
              }).toList();

              if (filtered.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  child: const Center(
                    child: Text(
                      'Tidak ada quest yang cocok dengan filter.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
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
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF1744),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Icon(Icons.delete, color: Colors.white),
                          SizedBox(width: 8),
                          Text('HAPUS QUEST', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    onDismissed: (_) {
                      box.deleteAt(originalIndex);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Quest "${quest.title}" dihapus.'),
                          backgroundColor: const Color(0xFFFF1744),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131B2E),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: quest.isCompleted
                              ? Colors.green.withValues(alpha: 0.6)
                              : (quest.isPenaltyQuest ? const Color(0xFFFF1744) : const Color(0xFF1E293B)),
                          width: 1.2,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        leading: Checkbox(
                          value: quest.isCompleted,
                          activeColor: const Color(0xFF00E5FF),
                          checkColor: Colors.black,
                          onChanged: (_) => _toggleQuestCompletion(quest, originalIndex),
                        ),
                        title: Text(
                          quest.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            decoration: quest.isCompleted ? TextDecoration.lineThrough : null,
                            color: quest.isCompleted ? Colors.grey : Colors.white,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (quest.description.isNotEmpty) ...[
                              Text(
                                quest.description,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withValues(alpha: 0.6),
                                ),
                              ),
                              const SizedBox(height: 4),
                            ],
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00E5FF).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${quest.targetValue} ${quest.unit}',
                                    style: const TextStyle(
                                      color: Color(0xFF00E5FF),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '+${quest.expReward} EXP | +${quest.goldReward} G',
                                  style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
                          onPressed: () {
                            _toggleQuestCompletion(quest, originalIndex);
                          },
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 24),

          // Form Tambah Rencana Quest Esok Hari
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF131B2E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'RENCANA QUEST ESOK HARI',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                        color: Color(0xFF00E5FF),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _isFormExpanded ? Icons.keyboard_arrow_up : Icons.add_circle_outline,
                        color: const Color(0xFF00E5FF),
                      ),
                      onPressed: () {
                        setState(() {
                          _isFormExpanded = !_isFormExpanded;
                        });
                      },
                    ),
                  ],
                ),
                if (_isFormExpanded) ...[
                  const Divider(color: Color(0xFF1E293B)),
                  const SizedBox(height: 8),
                  Form(
                    key: _planFormKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _titleController,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            labelText: 'Judul Rencana / Kegiatan',
                            labelStyle: const TextStyle(color: Color(0xFF00E5FF), fontSize: 12),
                            filled: true,
                            fillColor: const Color(0xFF0A0E1A),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Judul wajib diisi' : null,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _descController,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            labelText: 'Deskripsi / Target Fokus',
                            labelStyle: const TextStyle(color: Color(0xFF00E5FF), fontSize: 12),
                            filled: true,
                            fillColor: const Color(0xFF0A0E1A),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _newQuestCategory,
                                dropdownColor: const Color(0xFF131B2E),
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                                decoration: InputDecoration(
                                  labelText: 'Kategori',
                                  labelStyle: const TextStyle(color: Color(0xFF00E5FF), fontSize: 11),
                                  filled: true,
                                  fillColor: const Color(0xFF0A0E1A),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                items: ['Workout', 'Cardio', 'Skincare', 'Study', 'Work']
                                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _newQuestCategory = val;
                                      if (val == 'Workout') _newQuestUnit = 'Reps';
                                      if (val == 'Cardio') _newQuestUnit = 'Km';
                                      if (val == 'Skincare') _newQuestUnit = 'Checklist';
                                      if (val == 'Study' || val == 'Work') _newQuestUnit = 'Jam';
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
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                                decoration: InputDecoration(
                                  labelText: 'Target ($_newQuestUnit)',
                                  labelStyle: const TextStyle(color: Color(0xFF00E5FF), fontSize: 11),
                                  filled: true,
                                  fillColor: const Color(0xFF0A0E1A),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                validator: (v) => v == null || v.isEmpty ? 'Target angka' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _onFormSubmit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00E5FF),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'TERBITKAN RENCANA QUEST',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
