// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/ui/quests/quest_catalog_modal.dart
// Deskripsi: Modal & Halaman Ensiklopedia / Katalog Quest Resmi Solo Leveling HUD
//            1. Menampilkan seluruh daftar Normal Quest resmi yang ada di sistem
//            2. Sistem Gembok (Lock/Unlock): isLocked = questRank > playerRank
//            3. Kartu Terkunci: Warna abu-abu gelap, ikon gembok 🔒, tap disabled
//            4. Kartu Terbuka: Warna neon cerah, stat detail, tombol Deploy ke slot
//            5. Quest Penalti secara ketat TIDAK ditampilkan di katalog ini
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../helpers/boxes.dart';
import '../../helpers/levmax_theme.dart';
import '../../models/quest_model.dart';
import '../../models/user_model.dart';
import '../../services/quest_generator_service.dart';

class QuestCatalogModal extends StatefulWidget {
  final UserModel player;
  final VoidCallback? onQuestAccepted;

  const QuestCatalogModal({
    super.key,
    required this.player,
    this.onQuestAccepted,
  });

  /// Method pembantu untuk membuka Katalog sebagai Bottom Sheet Taktikal
  static Future<void> show(
    BuildContext context, {
    required UserModel player,
    VoidCallback? onQuestAccepted,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => QuestCatalogModal(
        player: player,
        onQuestAccepted: onQuestAccepted,
      ),
    );
  }

  @override
  State<QuestCatalogModal> createState() => _QuestCatalogModalState();
}

class _QuestCatalogModalState extends State<QuestCatalogModal> {
  String _selectedCategory = 'ALL';
  String _selectedRank = 'ALL';
  final _searchController = TextEditingController();

  final List<String> _categories = [
    'ALL',
    'Workout',
    'Cardio',
    'Skincare',
    'Productivity',
  ];

  final List<String> _ranks = [
    'ALL',
    'F',
    'E',
    'D',
    'C',
    'B',
    'A',
    'S',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================================
  // LOGIKA DEPLOY QUEST DARI KATALOG KE SLOT AKTIF HARIAN
  // ============================================================================
  Future<void> _deployQuest(QuestTemplate template) async {
    final success = await QuestGeneratorService.acceptQuestFromTemplate(
      template: template,
      player: widget.player,
    );

    if (!mounted) return;

    if (success) {
      widget.onQuestAccepted?.call();
      setState(() {});
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
              const Icon(Icons.check_circle, color: LevMaxTheme.primaryContainer, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'PROTOCOL DEPLOYED! "${template.title}" dimasukkan ke Daily Quest.',
                  style: LevMaxTheme.mono(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: LevMaxTheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
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
                'SLOT QUEST PENUH',
                style: LevMaxTheme.headline(fontSize: 14, color: LevMaxTheme.hpRed),
              ),
            ],
          ),
          content: Text(
            'Batas harian Rank ${widget.player.cleanRank} (${widget.player.maxQuestSlots} quest) telah tercapai!\n\nSelesaikan quest aktif di Status Window atau naikkan Rank Hunter Anda untuk menambah kapasitas slot.',
            style: LevMaxTheme.mono(fontSize: 11, color: LevMaxTheme.onSurfaceVariant),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('MENGERTI', style: LevMaxTheme.mono(fontSize: 11, color: LevMaxTheme.primaryContainer)),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final allTemplates = QuestGeneratorService.getAllCatalogTemplates();
    final today = DateTime.now().toIso8601String().substring(0, 10);

    // Ambil list ID quest yang sudah aktif hari ini di Hive
    final box = Hive.box<QuestModel>(HiveBoxes.questBox);
    final activeTitlesToday = box.values
        .where((q) => q.scheduledDate == today && q.isAccepted)
        .map((q) => q.title.trim().toUpperCase())
        .toSet();

    final acceptedCount = activeTitlesToday.length;
    final maxSlots = widget.player.maxQuestSlots;

    // Filter list berdasarkan Kategori, Rank, dan Search
    final query = _searchController.text.toLowerCase().trim();
    final filtered = allTemplates.where((t) {
      final matchCat = _selectedCategory == 'ALL' || t.category.toUpperCase() == _selectedCategory.toUpperCase();
      final matchRank = _selectedRank == 'ALL' || t.minRank.toUpperCase() == _selectedRank.toUpperCase();
      final matchQuery = query.isEmpty ||
          t.title.toLowerCase().contains(query) ||
          t.description.toLowerCase().contains(query);
      return matchCat && matchRank && matchQuery;
    }).toList();

    // Hitung jumlah unlocked
    final unlockedCount = allTemplates.where((t) {
      return QuestGeneratorService.isTemplateUnlocked(minRank: t.minRank, playerRank: widget.player.cleanRank);
    }).length;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: Color(0xFF0A0E18),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          top: BorderSide(color: Color(0xFF00F0FF), width: 1.5),
          left: BorderSide(color: Color(0x3300F0FF), width: 1),
          right: BorderSide(color: Color(0x3300F0FF), width: 1),
        ),
        boxShadow: [
          BoxShadow(color: Color(0x6600F0FF), blurRadius: 24, spreadRadius: 1),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: LevMaxTheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header Katalog
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF101725),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: widget.player.rankColor.withValues(alpha: 0.5)),
                  ),
                  child: Center(
                    child: Icon(Icons.auto_stories, color: widget.player.rankColor, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SYSTEM QUEST ENCYCLOPEDIA',
                        style: LevMaxTheme.headline(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: LevMaxTheme.onSurface,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'HUNTER RANK ${widget.player.sTierBadge} // $unlockedCount / ${allTemplates.length} UNLOCKED',
                        style: LevMaxTheme.mono(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: widget.player.rankColor,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: LevMaxTheme.outline),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Banner Status Slot Harian
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF101725),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0x1FFFFFFF)),
            ),
            child: Row(
              children: [
                const Icon(Icons.assignment_turned_in_outlined, size: 16, color: LevMaxTheme.primaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'DAILY SLOTS: $acceptedCount / $maxSlots TERISI (RANK ${widget.player.cleanRank})',
                    style: LevMaxTheme.mono(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: LevMaxTheme.onSurface,
                    ),
                  ),
                ),
                Text(
                  '${maxSlots - acceptedCount} Tersedia',
                  style: LevMaxTheme.mono(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: maxSlots > acceptedCount ? LevMaxTheme.primaryContainer : LevMaxTheme.hpRed,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF101725),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0x1FFFFFFF)),
              ),
              child: TextField(
                controller: _searchController,
                style: LevMaxTheme.mono(fontSize: 11, color: LevMaxTheme.onSurface),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'CARI PROTOCOL QUEST...',
                  hintStyle: LevMaxTheme.mono(fontSize: 10, color: LevMaxTheme.outline),
                  prefixIcon: const Icon(Icons.search, size: 16, color: LevMaxTheme.outline),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Filter Kategori Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: _categories.map((cat) {
                final isSelected = _selectedCategory.toUpperCase() == cat.toUpperCase();
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(cat.toUpperCase()),
                    selected: isSelected,
                    selectedColor: LevMaxTheme.primaryContainer,
                    backgroundColor: const Color(0xFF101725),
                    labelStyle: LevMaxTheme.mono(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? const Color(0xFF001F24) : LevMaxTheme.onSurfaceVariant,
                    ),
                    side: BorderSide(
                      color: isSelected ? LevMaxTheme.primaryContainer : const Color(0x1FFFFFFF),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onSelected: (val) {
                      if (val) setState(() => _selectedCategory = cat);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 6),

          // Filter Rank Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: _ranks.map((r) {
                final isSelected = _selectedRank.toUpperCase() == r.toUpperCase();
                final labelText = r == 'ALL' ? 'ALL RANKS' : 'RANK $r';
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(labelText),
                    selected: isSelected,
                    selectedColor: widget.player.rankColor,
                    backgroundColor: const Color(0xFF101725),
                    labelStyle: LevMaxTheme.mono(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? const Color(0xFF001F24) : LevMaxTheme.onSurfaceVariant,
                    ),
                    side: BorderSide(
                      color: isSelected ? widget.player.rankColor : const Color(0x1FFFFFFF),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onSelected: (val) {
                      if (val) setState(() => _selectedRank = r);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),

          // List Kartu Quest Ensiklopedia
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'TIDAK ADA PROTOCOL DITEMUKAN',
                      style: LevMaxTheme.mono(fontSize: 11, color: LevMaxTheme.outline),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final template = filtered[index];
                      final isUnlocked = QuestGeneratorService.isTemplateUnlocked(
                        minRank: template.minRank,
                        playerRank: widget.player.cleanRank,
                      );
                      final isLocked = !isUnlocked;
                      final isAlreadyActive = activeTitlesToday.contains(template.title.trim().toUpperCase());

                      return _buildCatalogCard(
                        template: template,
                        isLocked: isLocked,
                        isAlreadyActive: isAlreadyActive,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // KOMPONEN: KARTU ENSIKLOPEDIA (DENGAN SISTEM GEMBOK)
  // ============================================================================
  Widget _buildCatalogCard({
    required QuestTemplate template,
    required bool isLocked,
    required bool isAlreadyActive,
  }) {
    Color accentColor;
    IconData icon;

    switch (template.category.toLowerCase()) {
      case 'workout':
        accentColor = const Color(0xFF00F0FF);
        icon = Icons.fitness_center;
        break;
      case 'cardio':
        accentColor = const Color(0xFF65F2B5);
        icon = Icons.directions_run;
        break;
      case 'skincare':
        accentColor = const Color(0xFFFF80AB);
        icon = Icons.spa;
        break;
      case 'productivity':
      default:
        accentColor = const Color(0xFFB388FF);
        icon = Icons.psychology;
    }

    final targetStr = template.getDisplayTarget(widget.player);

    if (isLocked) {
      // ------------------------------------------------------------------------
      // KARTU TERKUNCI (LOCKED MODE)
      // Warna abu-abu gelap, ikon gembok, onTap disabled
      // ------------------------------------------------------------------------
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0E131D),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0x1AFFFFFF), width: 1),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF151A24),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0x22FFFFFF)),
                        ),
                        child: const Center(
                          child: Icon(Icons.lock, size: 18, color: Color(0xFF718096)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    template.title,
                                    style: LevMaxTheme.headline(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0x33FFFFFF)),
                                  ),
                                  child: Text(
                                    'RANK ${template.minRank}',
                                    style: LevMaxTheme.mono(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'CATEGORY: ${template.category.toUpperCase()} • ${template.exerciseType.toUpperCase()}',
                              style: LevMaxTheme.mono(fontSize: 9, color: const Color(0xFF475569)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Text(
                    template.description,
                    style: const TextStyle(fontSize: 10, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 10),

                  // Lock Warning Strip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF171B26),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0x22FFFFFF)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_outline, size: 14, color: Color(0xFFE2E8F0)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'TERKUNCI: Membutuhkan Rank ${template.minRank} untuk membuka protocol ini.',
                            style: LevMaxTheme.mono(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFCBD5E1),
                            ),
                          ),
                        ),
                        Text(
                          '+${template.statReward} ${template.statType}',
                          style: LevMaxTheme.mono(fontSize: 9, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // --------------------------------------------------------------------------
    // KARTU TERBUKA (UNLOCKED MODE)
    // Warna neon cerah, stat detail, tombol Deploy ke slot aktif
    // --------------------------------------------------------------------------
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF101725),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isAlreadyActive ? const Color(0x4410B981) : accentColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Strip Aksen Kiri
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                color: isAlreadyActive ? const Color(0xFF10B981) : accentColor,
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
                // Baris Atas: Ikon + Judul + Rank Tag
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF090D14),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: accentColor.withValues(alpha: 0.5)),
                      ),
                      child: Center(
                        child: Icon(icon, size: 18, color: accentColor),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  template.title,
                                  style: LevMaxTheme.headline(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: LevMaxTheme.onSurface,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: accentColor.withValues(alpha: 0.4)),
                                ),
                                child: Text(
                                  'RANK ${template.minRank}',
                                  style: LevMaxTheme.mono(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: accentColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${template.category.toUpperCase()} • ${template.exerciseType.toUpperCase()}',
                            style: LevMaxTheme.mono(fontSize: 9, color: LevMaxTheme.outline),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Deskripsi Quest
                Text(
                  template.description,
                  style: const TextStyle(fontSize: 10, color: LevMaxTheme.onSurfaceVariant),
                ),
                const SizedBox(height: 10),

                // Baris Detail Target & Rewards
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF090D14),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0x14FFFFFF)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Target Beban Adaptif
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('TARGET BEBAN', style: LevMaxTheme.mono(fontSize: 8, color: LevMaxTheme.outline)),
                          const SizedBox(height: 2),
                          Text(
                            targetStr,
                            style: LevMaxTheme.mono(fontSize: 11, fontWeight: FontWeight.bold, color: LevMaxTheme.onSurface),
                          ),
                        ],
                      ),

                      // Stat Gain
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text('ATRIBUT STAT', style: LevMaxTheme.mono(fontSize: 8, color: LevMaxTheme.outline)),
                          const SizedBox(height: 2),
                          Text(
                            '+${template.statReward} ${template.statType}',
                            style: LevMaxTheme.mono(fontSize: 11, fontWeight: FontWeight.bold, color: accentColor),
                          ),
                        ],
                      ),

                      // EXP & Gold
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('REWARDS', style: LevMaxTheme.mono(fontSize: 8, color: LevMaxTheme.outline)),
                          const SizedBox(height: 2),
                          Text(
                            '+${template.baseExp} EXP • +${template.baseGold} G',
                            style: LevMaxTheme.mono(fontSize: 10, fontWeight: FontWeight.bold, color: LevMaxTheme.tertiaryFixedDim),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Tombol Aksi Deploy
                if (isAlreadyActive)
                  Container(
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0x2210B981),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0x4410B981)),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle, size: 14, color: Color(0xFF10B981)),
                        const SizedBox(width: 6),
                        Text(
                          'SUDAH AKTIF DI DAILY QUEST',
                          style: LevMaxTheme.mono(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ElevatedButton(
                    onPressed: () => _deployQuest(template),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: const Color(0xFF001F24),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      minimumSize: const Size(double.infinity, 32),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add, size: 14, color: Color(0xFF001F24)),
                        const SizedBox(width: 4),
                        Text(
                          'DEPLOY TO ACTIVE DAILY QUEST',
                          style: LevMaxTheme.mono(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF001F24),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
