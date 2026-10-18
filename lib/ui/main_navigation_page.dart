// Halaman Navigasi Utama Aplikasi
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../helpers/boxes.dart';
import '../helpers/user_info.dart';
import '../models/quest_model.dart';
import '../models/user_model.dart';
import '../services/notification_service.dart';
import '../services/supabase_api_service.dart';
import 'game_over_page.dart';
import 'penalty_minigame_page.dart';
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
  // Indeks tab aktif
  int _selectedIndex = 0;
  UserModel? _currentPlayer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Memuat data pemain dan mengecek penalti harian
    _loadPlayerAndCheckPenalty();
  }

  // Pengecekan pergantian hari dan status penalti
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

    // Pengecekan kondisi Game Over jika HP <= 0
    if (player.hp <= 0) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const GameOverPage()),
      );
      return;
    }

    // Validasi pergantian tanggal harian (lewat 23:59)
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (player.lastActiveDate.isNotEmpty && player.lastActiveDate != today) {
      final questBox = Hive.box<QuestModel>(HiveBoxes.questBox);
      final hasIncompleteQuests = questBox.values.any((q) => !q.isCompleted);

      if (hasIncompleteQuests) {
        int hpDeduction = 20;
        if (player.isPenaltyActive) {
          hpDeduction = 40;
        }

        final newHp = max(0, player.hp - hpDeduction);
        const isPenaltyActive = true;

        // Tambahkan quest hukuman ekstra
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

        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showPenaltyWarningDialog();
          });
        }
      } else {
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

  // Dialog peringatan penalti aktif
  void _showPenaltyWarningDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131B2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFFF1744), width: 2),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Color(0xFFFF1744)),
            SizedBox(width: 8),
            Text('PENALTY ZONE AKTIF', style: TextStyle(color: Color(0xFFFF1744), fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Daily Quest kemarin tidak selesai sebelum 23:59!\nHP Anda telah dikurangi oleh Sistem.\n\nMasuki Penalty Zone sekarang dan selesaikan Mini-Game Survival untuk memulihkan +10 HP!',
          style: TextStyle(color: Colors.white70, fontSize: 13),
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
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF1744)),
            child: const Text('MASUKI PENALTY ZONE', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _currentPlayer == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0E1A),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
        ),
      );
    }

    // Daftar halaman 4 tab
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
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bolt, color: Color(0xFF00E5FF), size: 24),
            const SizedBox(width: 6),
            const Text(
              'LEVMAX',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 3.0,
                color: Color(0xFF00E5FF),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _currentPlayer!.rankColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _currentPlayer!.rankColor),
              ),
              child: Text(
                'RANK ${_currentPlayer!.rank}',
                style: TextStyle(
                  color: _currentPlayer!.rankColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF00E5FF)),
            onPressed: _loadPlayerAndCheckPenalty,
          ),
        ],
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFF1E293B), width: 1.0)),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          backgroundColor: const Color(0xFF0A0E1A),
          selectedItemColor: const Color(0xFF00E5FF),
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 11,
          unselectedFontSize: 10,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.assignment),
              label: 'Status & Quest',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.map),
              label: 'Dungeon & Guild',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.rate_review),
              label: 'Saran & Kesan',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profil Player',
            ),
          ],
        ),
      ),
    );
  }
}
