// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/helpers/debug_config.dart
// Deskripsi: Konfigurasi Global Debug & QA Bypass untuk Pengujian dan Presentasi.
// ==============================================================================

class DebugConfig {
  /// Flag override untuk memaksa aplikasi menganggap jam sistem sudah pukul 21:00
  /// Digunakan untuk demo validasi Misi Appearance (Skincare Looksmaxxing).
  static bool forceHour21 = false;

  /// Memeriksa apakah Misi Appearance memenuhi syarat waktu (> 21:00 atau dipaksa via QA Panel)
  static bool get isAppearanceUnlocked {
    if (forceHour21) return true;
    final int currentHour = DateTime.now().hour;
    return currentHour >= 21;
  }
}
