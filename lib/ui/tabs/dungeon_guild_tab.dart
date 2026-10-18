// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/ui/tabs/dungeon_guild_tab.dart
// Deskripsi: Tab 2 Bottom Navigation Bar: Peta Dungeon LBS, Konversi Waktu Server,
//            Guild Exchange Konversi Mata Uang, & Rantai Blok Ledger (FR-3.2 & FR-4.1 - FR-4.3)
// ==============================================================================

import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/blockchain_service.dart';

class DungeonGuildTab extends StatefulWidget {
  final UserModel player;
  final VoidCallback onPlayerUpdated;

  const DungeonGuildTab({
    super.key,
    required this.player,
    required this.onPlayerUpdated,
  });

  @override
  State<DungeonGuildTab> createState() => _DungeonGuildTabState();
}

class _DungeonGuildTabState extends State<DungeonGuildTab> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF131B2E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF00E5FF)),
            ),
            child: Row(
              children: [
                const Icon(Icons.map, color: Color(0xFF00E5FF), size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DUNGEON & GUILD EXCHANGE',
                        style: TextStyle(
                          color: Color(0xFF00E5FF),
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Text(
                        'Lacak LBS Koordinat Jogging, Konversi Waktu, Kurs Gold, & Blockchain',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Ringkasan Kurs Gold
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF131B2E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'GUILD EXCHANGE: KURS GOLD',
                  style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Text(
                  'Saldo Hunter: ${widget.player.gold} Gold',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
                ),
                const SizedBox(height: 6),
                Text(
                  '• IDR: Rp ${(widget.player.gold * 1000).toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}\n• USD: \$${(widget.player.gold * 1000 / 16200).toStringAsFixed(2)}\n• EUR: €${(widget.player.gold * 1000 / 17500).toStringAsFixed(2)}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Blockchain Status
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF131B2E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'STATUS BLOCKCHAIN ANTI-CHEAT',
                      style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Icon(
                      BlockchainService.isChainValid() ? Icons.verified : Icons.warning,
                      color: BlockchainService.isChainValid() ? Colors.greenAccent : Colors.redAccent,
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  BlockchainService.isChainValid()
                      ? 'Integritas Rantai Blok Valid (SHA-256 Terverifikasi Aman).'
                      : 'PERINGATAN: Integritas Rantai Blok Terkompromi!',
                  style: TextStyle(
                    color: BlockchainService.isChainValid() ? Colors.greenAccent : Colors.redAccent,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Total Blok Tercatat: ${BlockchainService.getBlocks().length} Blok',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
