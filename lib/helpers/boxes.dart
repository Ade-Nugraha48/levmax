// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/helpers/boxes.dart
// Deskripsi: Definisi konstanta nama box Hive NoSQL (Lapisan 2 Arsitektur DB)
// ==============================================================================

class HiveBoxes {
  /// Box untuk menyimpan Daily Quest hari ini, Plan esok hari, & Extra Quest Penalti
  static const String questBox = 'quest_box';

  /// Box untuk menyimpan rantai blok transaksi hash SHA-256 (Anti-Cheat Ledger)
  static const String blockchainBox = 'blockchain_box';

  /// Box untuk menyimpan cache data statistik RPG & profil Player secara Offline-First
  static const String playerBox = 'player_cache_box';

  /// Box untuk menyimpan riwayat input Saran & Kesan mata kuliah secara lokal
  static const String feedbackBox = 'feedback_box';
}
