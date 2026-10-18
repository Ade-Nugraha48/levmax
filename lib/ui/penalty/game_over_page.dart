// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/ui/penalty/game_over_page.dart
// Deskripsi: Layar Game Over Solo Leveling: "SYSTEM TERMINATED: ANDA TIDAK LAYAK"
//            saat HP <= 0 beserta aksi Re-Awakening (Bab 5 & FR-6.2)
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../helpers/boxes.dart';
import '../../models/quest_model.dart';
import '../../models/user_model.dart';
import '../../services/blockchain_service.dart';
import '../../services/supabase_api_service.dart';
import '../main_navigation_page.dart';

class GameOverPage extends StatefulWidget {
  const GameOverPage({super.key});

  @override
  State<GameOverPage> createState() => _GameOverPageState();
}

class _GameOverPageState extends State<GameOverPage> {
  bool _isLoading = false;

  Future<void> _handleReAwakening() async {
    setState(() {
      _isLoading = true;
    });

    final player = SupabaseApiService.getPlayerCache();
    final updatedPlayer = (player ?? UserModel(username: 'Hunter', email: '')).copyWith(
      level: 1,
      rank: 'F',
      hp: 100,
      exp: 0,
      gold: 0,
      isPenaltyActive: false,
    );

    // Perbarui ke Supabase & Hive
    await SupabaseApiService.updateUser(updatedPlayer);

    // Catat Re-Awakening ke Rantai Blok Anti-Cheat
    await BlockchainService.addBlock(
      'RE-AWAKENING: Player reset to Level 1 (Rank F), HP 100, EXP 0 after System Termination.',
      userId: updatedPlayer.id,
    );

    // Reset status quest di box
    final questBox = Hive.box<QuestModel>(HiveBoxes.questBox);
    for (int i = 0; i < questBox.length; i++) {
      final q = questBox.getAt(i);
      if (q != null) {
        q.isCompleted = false;
        q.currentValue = 0;
        await q.save();
      }
    }

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('RE-AWAKENING BERHASIL! Anda terlahir kembali sebagai Hunter Level 1.'),
        backgroundColor: Color(0xFF00E5FF),
      ),
    );

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainNavigationPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon Tengkorak / Glitch System Terminated
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1E0A10),
                    border: Border.all(color: const Color(0xFFFF1744), width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF1744).withValues(alpha: 0.5),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.dangerous_outlined,
                    size: 80,
                    color: Color(0xFFFF1744),
                  ),
                ),
                const SizedBox(height: 32),

                // Judul Fatal Solo Leveling
                const Text(
                  'SYSTEM TERMINATED',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4.0,
                    color: Color(0xFFFF1744),
                  ),
                ),
                const SizedBox(height: 8),

                const Text(
                  'ANDA TIDAK LAYAK',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3.0,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),

                // Penjelasan
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16080B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFF1744).withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    'Health Points (HP) Anda telah terkuras habis hingga 0 akibat pengabaian quest dan kegagalan bertahan di Penalty Zone.\n\nSistem mencabut seluruh atribut Hunter Anda.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // Tombol Re-Awakening
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _handleReAwakening,
                  icon: _isLoading
                      ? const SizedBox.shrink()
                      : const Icon(Icons.refresh, color: Colors.black),
                  label: _isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                        )
                      : const Text(
                          'RE-AWAKENING (RESET KE LEVEL 1 / RANK F)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5FF),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 8,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
