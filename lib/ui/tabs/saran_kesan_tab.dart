// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/ui/tabs/saran_kesan_tab.dart
// Deskripsi: Adapter & re-export untuk backwards compatibility ke FeedbackTab
// ==============================================================================

import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import 'feedback_tab.dart';

export 'feedback_tab.dart';

class SaranKesanTab extends StatelessWidget {
  final UserModel player;
  final VoidCallback? onPlayerUpdated;

  const SaranKesanTab({super.key, required this.player, this.onPlayerUpdated});

  @override
  Widget build(BuildContext context) {
    return FeedbackTab(player: player, onPlayerUpdated: onPlayerUpdated);
  }
}
