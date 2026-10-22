// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/ui/penalty/penalty_minigame_page.dart
// Deskripsi: Adapter & Re-export ke lib/ui/gamification/penalty_game_page.dart
// ==============================================================================

export '../gamification/penalty_game_page.dart';

import 'package:flutter/material.dart';

import '../gamification/penalty_game_page.dart';

class PenaltyMiniGamePage extends StatelessWidget {
  const PenaltyMiniGamePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PenaltyGamePage();
  }
}
