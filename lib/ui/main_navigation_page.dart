// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/ui/main_navigation_page.dart
// Deskripsi: Navigasi Utama 4 Tab (BottomNavigationBar), Pengecekan Pergantian
//            Hari & Penalti Otomatis (Bab 5 Rules), & Manajemen State Player.
// ==============================================================================

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../helpers/boxes.dart';
import '../helpers/user_info.dart';
import '../models/quest_model.dart';
import '../models/user_model.dart';
import '../services/notification_service.dart';
import '../services/supabase_api_service.dart';
import 'penalty/game_over_page.dart';
import 'penalty/penalty_minigame_page.dart';
import '../helpers/levmax_theme.dart';
import 'tabs/status_quest_tab.dart';
import 'tabs/dungeon_guild_tab.dart';
import 'tabs/saran_kesan_tab.dart';
import 'tabs/profile_tab.dart';

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _currentIndex = 0;
  UserModel? _currentPlayer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlayerAndCheckPenalty();
  }

  /// Memuat profil player dan menjalankan pemeriksaan pergantian hari & penalti (Bab 5)
  Future<void> _loadPlayerAndCheckPenalty() async {
    final uid = await UserInfo.getUserID();
    UserModel? player;

    if (uid != null && uid > 0) {
      player = await SupabaseApiService.getUserById(uid);
    }
    player ??= SupabaseApiService.getPlayerCache();

    if (player == null) {
      final username = await UserInfo.getUsername() ?? 'Hunter';
      final email = await UserInfo.getEmail() ?? '';
      player = UserModel.initial(id: uid ?? 1, username: username, email: email);
      await SupabaseApiService.savePlayerCache(player);
    }

    // Periksa apakah HP <= 0 (Game Over)
    if (player.hp <= 0) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const GameOverPage()),
      );
      return;
    }

    // ========================================================================
    // ATURAN PERGANTIAN HARI & SISTEM PENALTI (BAB 5 RULES)
    // ========================================================================
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (player.lastActiveDate.isNotEmpty && player.lastActiveDate != today) {
      // Terjadi pergantian hari (melewati pukul 23:59)
      final questBox = Hive.box<QuestModel>(HiveBoxes.questBox);
      final hasIncompleteQuests = questBox.values.any((q) => !q.isCompleted);

      if (hasIncompleteQuests) {
        int hpDeduction = 20;
        if (player.isPenaltyActive) {
          hpDeduction = 40; // Double penalty jika penalti sebelumnya diabaikan
        }

        final newHp = max(0, player.hp - hpDeduction);
        const isPenaltyActive = true;

        // Tambahkan Extra Penalty Quest
        final penaltyQuest = QuestModel(
          id: 'penalty_quest_${DateTime.now().millisecondsSinceEpoch}',
          title: 'EXTRA QUEST: HUKUMAN SISTEM',
          description: 'Lakukan 50x Push-up penalti untuk memulihkan kehormatan Hunter!',
          category: 'Workout',
          targetValue: 50,
          currentValue: 0,
          unit: 'Reps',
          expReward: 10,
          goldReward: 5,
          isCompleted: false,
          isPenaltyQuest: true,
          scheduledDate: today,
        );
        await questBox.add(penaltyQuest);

        player = player.copyWith(
          hp: newHp,
          isPenaltyActive: isPenaltyActive,
          lastActiveDate: today,
        );

        await SupabaseApiService.updateUser(player);
        await NotificationService.showPenaltyNotification(hpDeduction: hpDeduction);

        if (newHp <= 0) {
          await NotificationService.showGameOverNotification();
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const GameOverPage()),
          );
          return;
        }

        // Tampilkan prompt navigasi ke Penalty Mini-Game
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showPenaltyWarningDialog();
          });
        }
      } else {
        // Hari berganti dan semua quest kemarin selesai
        player = player.copyWith(lastActiveDate: today);
        await SupabaseApiService.updateUser(player);
      }
    }

    if (mounted) {
      setState(() {
        _currentPlayer = player;
        _isLoading = false;
      });
    }
  }

  void _showPenaltyWarningDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: LevMaxTheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: LevMaxTheme.hpRed, width: 2),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning, color: LevMaxTheme.hpRed),
            const SizedBox(width: 8),
            Text(
              'PENALTY ZONE AKTIF',
              style: LevMaxTheme.headline(fontSize: 14, color: LevMaxTheme.hpRed),
            ),
          ],
        ),
        content: Text(
          'Daily Quest kemarin tidak selesai sebelum 23:59!\nHP Anda telah dikurangi oleh Sistem.\n\nMasuki Penalty Zone sekarang dan selesaikan Mini-Game Survival untuk memulihkan +10 HP!',
          style: LevMaxTheme.mono(fontSize: 11, color: LevMaxTheme.onSurfaceVariant),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PenaltyMiniGamePage()),
              ).then((_) => _loadPlayerAndCheckPenalty());
            },
            style: ElevatedButton.styleFrom(backgroundColor: LevMaxTheme.hpRed),
            child: Text(
              'MASUKI PENALTY ZONE',
              style: LevMaxTheme.mono(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  String _getTabTitle(int index) {
    switch (index) {
      case 1:
        return 'DUNGEON & GUILD EXCHANGE';
      case 2:
        return 'REVIEWS & FEEDBACK';
      case 3:
        return 'HUNTER PROFILE & STATS';
      default:
        return 'DAILY QUESTS HUD';
    }
  }

  Widget _buildTacticalBottomNavBar() {
    final items = [
      {'label': 'QUESTS', 'icon': Icons.shield_moon},
      {'label': 'DUNGEON', 'icon': Icons.shield_outlined},
      {'label': 'REVIEWS', 'icon': Icons.analytics_outlined},
      {'label': 'PROFILE', 'icon': Icons.person_outline},
    ];

    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: LevMaxTheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 24,
            offset: Offset(0, -4),
          ),
        ],
        border: Border(
          top: BorderSide(color: LevMaxTheme.surfaceContainerHighest, width: 1.0),
        ),
      ),
      child: Row(
        children: List.generate(items.length, (index) {
          final item = items[index];
          final isSelected = _currentIndex == index;
          final color = isSelected ? LevMaxTheme.primaryContainer : LevMaxTheme.outline;

          return Expanded(
            child: InkWell(
              onTap: () {
                setState(() {
                  _currentIndex = index;
                });
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    item['icon'] as IconData,
                    size: 22,
                    color: color,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item['label'] as String,
                    style: LevMaxTheme.mono(
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: color,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _currentPlayer == null) {
      return const Scaffold(
        backgroundColor: LevMaxTheme.background,
        body: Center(
          child: CircularProgressIndicator(color: LevMaxTheme.primaryContainer),
        ),
      );
    }

    final pages = [
      StatusQuestTab(
        player: _currentPlayer!,
        onPlayerUpdated: _loadPlayerAndCheckPenalty,
      ),
      DungeonGuildTab(
        player: _currentPlayer!,
        onPlayerUpdated: _loadPlayerAndCheckPenalty,
      ),
      SaranKesanTab(
        player: _currentPlayer!,
      ),
      ProfileTab(
        player: _currentPlayer!,
        onPlayerUpdated: _loadPlayerAndCheckPenalty,
      ),
    ];

    return Scaffold(
      backgroundColor: LevMaxTheme.background,
      appBar: _currentIndex == 0
          ? null // Tab 1: Status & Daily Quests menampilkan Sticky Tactical Header Bar kustom sendiri
          : PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: Container(
                color: LevMaxTheme.surface,
                child: SafeArea(
                  bottom: false,
                  child: Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: LevMaxTheme.surfaceContainerHighest, width: 1.0),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.bolt, color: LevMaxTheme.primaryContainer, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          _getTabTitle(_currentIndex),
                          style: LevMaxTheme.headline(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: LevMaxTheme.onSurface,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.refresh, color: LevMaxTheme.primaryContainer, size: 20),
                          onPressed: _loadPlayerAndCheckPenalty,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      body: pages[_currentIndex],
      bottomNavigationBar: _buildTacticalBottomNavBar(),
    );
  }
}
