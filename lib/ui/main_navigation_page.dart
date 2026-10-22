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
import 'tabs/feedback_tab.dart';
import 'tabs/profile_tab.dart';
import 'shop/shop_page.dart';

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
    // Fast Load: Gunakan data cache lokal secara instan jika sudah tersedia
    final cached = SupabaseApiService.getPlayerCache();
    if (cached != null) {
      _currentPlayer = cached;
      _isLoading = false;
    }
    _loadPlayerAndCheckPenalty();
  }

  /// Memuat profil player dan menjalankan pemeriksaan pergantian hari & penalti (Bab 5)
  Future<void> _loadPlayerAndCheckPenalty() async {
    try {
      // 1. Ambil data player dari local cache terlebih dahulu untuk responsivitas instan
      UserModel? player = SupabaseApiService.getPlayerCache();

      // 2. Ambil ID pengguna dari session
      final uid = await UserInfo.getUserID();
      final uidStr = uid?.toString().trim() ?? '';

      // 3. Jika cache lokal belum ada dan uid valid, ambil dari Supabase Cloud
      if (player == null && uidStr.isNotEmpty && uidStr != '0') {
        try {
          player = await SupabaseApiService.getUserById(uidStr);
        } catch (e) {
          debugPrint('[MainNavigation] getUserById error: $e');
        }
      }

      // 4. Jika tetap belum ada, buat initial model berbasis session
      if (player == null) {
        final username = await UserInfo.getUsername() ?? 'Hunter';
        final email = await UserInfo.getEmail() ?? '';
        player = UserModel.initial(
          id: uidStr.isNotEmpty
              ? uidStr
              : 'hunter_${DateTime.now().millisecondsSinceEpoch}',
          username: username,
          email: email,
        );
        await SupabaseApiService.savePlayerCache(player);
      }

      // 5. Periksa apakah HP <= 0 (Game Over)
      if (player.hp <= 0) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const GameOverPage()),
        );
        return;
      }

      // 6. Periksa apakah Penalti Aktif (Penalty Guard)
      if (player.isPenaltyActive) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PenaltyGamePage()),
        );
        return;
      }

      // 7. ATURAN PERGANTIAN HARI & SISTEM PENALTI (BAB 5 RULES)
      try {
        final today = DateTime.now().toIso8601String().substring(0, 10);
        if (player.lastActiveDate.isNotEmpty &&
            player.lastActiveDate != today) {
          // Terjadi pergantian hari (melewati pukul 23:59)
          if (!Hive.isBoxOpen(HiveBoxes.questBox)) {
            await Hive.openBox<QuestModel>(HiveBoxes.questBox);
          }
          final questBox = Hive.box<QuestModel>(HiveBoxes.questBox);
          final hasIncompleteQuests = questBox.values.any(
            (q) => !q.isCompleted,
          );

          if (hasIncompleteQuests) {
            int hpDeduction = 20;
            if (player.isPenaltyActive) {
              hpDeduction =
                  40; // Double penalty jika penalti sebelumnya diabaikan
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

            try {
              await SupabaseApiService.updateUser(player);
            } catch (_) {}
            try {
              await NotificationService.showPenaltyNotification(
                hpDeduction: hpDeduction,
              );
            } catch (_) {}

            if (newHp <= 0) {
              try {
                await NotificationService.showGameOverNotification();
              } catch (_) {}
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
            try {
              await SupabaseApiService.updateUser(player);
            } catch (_) {}
          }
        }
      } catch (dayResetErr) {
        debugPrint(
          '[MainNavigation] Day transition check warning: $dayResetErr',
        );
      }

      if (mounted) {
        setState(() {
          _currentPlayer = player;
          _isLoading = false;
        });
      }
    } catch (e, stack) {
      debugPrint(
        '[MainNavigation] Critical error in _loadPlayerAndCheckPenalty: $e\n$stack',
      );
    } finally {
      // Jaminan mutlak: Spinner loading tidak akan pernah menggantung selamanya
      if (mounted && _isLoading) {
        setState(() {
          _currentPlayer ??=
              SupabaseApiService.getPlayerCache() ??
              UserModel.initial(
                id: 'hunter_emergency',
                username: 'Hunter',
                email: '',
              );
          _isLoading = false;
        });
      }
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
              style: LevMaxTheme.headline(
                fontSize: 14,
                color: LevMaxTheme.hpRed,
              ),
            ),
          ],
        ),
        content: Text(
          'Daily Quest kemarin tidak selesai sebelum 23:59!\nHP Anda telah dikurangi oleh Sistem.\n\nMasuki Penalty Zone sekarang dan selesaikan Mini-Game Survival untuk memulihkan +10 HP!',
          style: LevMaxTheme.mono(
            fontSize: 11,
            color: LevMaxTheme.onSurfaceVariant,
          ),
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
              style: LevMaxTheme.mono(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTacticalBottomNavBar() {
    final items = [
      {'label': 'QUESTS', 'icon': Icons.shield_moon},
      {'label': 'DUNGEON', 'icon': Icons.shield_outlined},
      {'label': 'TREASURY', 'icon': Icons.storefront},
      {'label': 'ARCHIVE', 'icon': Icons.menu_book_outlined},
      {'label': 'HUNTER', 'icon': Icons.person_outline},
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
          top: BorderSide(
            color: LevMaxTheme.surfaceContainerHighest,
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: List.generate(items.length, (index) {
          final item = items[index];
          final isSelected = _currentIndex == index;
          final color = isSelected
              ? LevMaxTheme.primaryContainer
              : LevMaxTheme.outline;

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
                  Icon(item['icon'] as IconData, size: 22, color: color),
                  const SizedBox(height: 4),
                  Text(
                    item['label'] as String,
                    style: LevMaxTheme.mono(
                      fontSize: 10,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
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
      ShopPage(
        player: _currentPlayer!,
        onPlayerUpdated: _loadPlayerAndCheckPenalty,
      ),
      FeedbackTab(
        player: _currentPlayer!,
        onPlayerUpdated: _loadPlayerAndCheckPenalty,
      ),
      ProfileTab(
        player: _currentPlayer!,
        onPlayerUpdated: _loadPlayerAndCheckPenalty,
      ),
    ];

    return Scaffold(
      backgroundColor: LevMaxTheme.background,
      appBar: null,
      body: pages[_currentIndex],
      bottomNavigationBar: _buildTacticalBottomNavBar(),
    );
  }
}
