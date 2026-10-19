// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/helpers/user_info.dart
// Deskripsi: Lapisan 1 Arsitektur DB - Manajemen Sesi Login via SharedPreferences
//            dengan validasi kedaluwarsa sesi otomatis 60 menit (Auto-Logout).
//            Standar Industri: Mempertahankan preferensi biometrik lokal saat logout.
// ==============================================================================

import 'package:shared_preferences/shared_preferences.dart';

class UserInfo {
  // Kunci-kunci penyimpanan SharedPreferences
  static const String keyToken = 'token';
  static const String keyUserID = 'userID';
  static const String keyUsername = 'username';
  static const String keyEmail = 'email';
  static const String keyLogin = 'login';
  static const String keyIsOnboarded = 'isOnboarded';
  static const String keyBiometricEnabled = 'biometricEnabled';
  static const String keyLastActive = 'last_active_timestamp';

  // ============================================================================
  // TOKEN & USER IDENTITY
  // ============================================================================

  /// Menyimpan token autentikasi sesi (auth_key)
  static Future<bool> setToken(String value) async {
    final pref = await SharedPreferences.getInstance();
    return await pref.setString(keyToken, value);
  }

  /// Mengambil token autentikasi sesi
  static Future<String?> getToken() async {
    final pref = await SharedPreferences.getInstance();
    return pref.getString(keyToken);
  }

  /// Menyimpan ID unik Player (user_id di PostgreSQL Supabase)
  static Future<bool> setUserID(int value) async {
    final pref = await SharedPreferences.getInstance();
    return await pref.setInt(keyUserID, value);
  }

  /// Mengambil ID unik Player
  static Future<int?> getUserID() async {
    final pref = await SharedPreferences.getInstance();
    return pref.getInt(keyUserID);
  }

  /// Menyimpan Username Hunter
  static Future<bool> setUsername(String value) async {
    final pref = await SharedPreferences.getInstance();
    return await pref.setString(keyUsername, value);
  }

  /// Mengambil Username Hunter
  static Future<String?> getUsername() async {
    final pref = await SharedPreferences.getInstance();
    return pref.getString(keyUsername);
  }

  /// Menyimpan Email terdaftar
  static Future<bool> setEmail(String value) async {
    final pref = await SharedPreferences.getInstance();
    return await pref.setString(keyEmail, value);
  }

  /// Mengambil Email terdaftar
  static Future<String?> getEmail() async {
    final pref = await SharedPreferences.getInstance();
    return pref.getString(keyEmail);
  }

  // ============================================================================
  // STATUS LOGIN & ONBOARDING
  // ============================================================================

  /// Menyimpan status login aktif (true jika sudah login)
  static Future<bool> setLoginStatus(bool value) async {
    final pref = await SharedPreferences.getInstance();
    return await pref.setBool(keyLogin, value);
  }

  /// Mengambil status login aktif
  static Future<bool> getLoginStatus() async {
    final pref = await SharedPreferences.getInstance();
    return pref.getBool(keyLogin) ?? false;
  }

  /// Menyimpan status penyelesaian Onboarding fisik Player
  static Future<bool> setIsOnboarded(bool value) async {
    final pref = await SharedPreferences.getInstance();
    return await pref.setBool(keyIsOnboarded, value);
  }

  /// Mengambil status penyelesaian Onboarding fisik Player
  static Future<bool> getIsOnboarded() async {
    final pref = await SharedPreferences.getInstance();
    return pref.getBool(keyIsOnboarded) ?? false;
  }

  // ============================================================================
  // PREFERENSI BIOMETRIK LOKAL
  // ============================================================================

  /// Menyimpan status aktivasi biometrik lokal (Fingerprint / Face ID)
  static Future<bool> setBiometricEnabled(bool value) async {
    final pref = await SharedPreferences.getInstance();
    return await pref.setBool(keyBiometricEnabled, value);
  }

  /// Mengambil status aktivasi biometrik lokal
  static Future<bool> getBiometricEnabled() async {
    final pref = await SharedPreferences.getInstance();
    return pref.getBool(keyBiometricEnabled) ?? false;
  }

  /// Alias pembantu untuk memeriksa apakah biometrik aktif di sesi lokal
  static Future<bool> isBiometricEnabledLocal() async {
    return await getBiometricEnabled();
  }

  // ============================================================================
  // MANAJEMEN WAKTU & TIMEOUT SESI (AUTO-LOGOUT 60 MENIT)
  // ============================================================================

  /// Menyimpan timestamp waktu aktivitas terakhir dalam format ISO-8601
  static Future<bool> setLastActive(String isoTime) async {
    final pref = await SharedPreferences.getInstance();
    return await pref.setString(keyLastActive, isoTime);
  }

  /// Mengambil timestamp waktu aktivitas terakhir
  static Future<String?> getLastActive() async {
    final pref = await SharedPreferences.getInstance();
    return pref.getString(keyLastActive);
  }

  /// Memperbarui timestamp aktivitas ke waktu saat ini (setiap ada interaksi aktif)
  static Future<void> updateLastActive() async {
    final nowIso = DateTime.now().toIso8601String();
    await setLastActive(nowIso);
  }

  /// Memeriksa apakah sesi telah kedaluwarsa (> 60 menit dari aktivitas terakhir).
  /// Sesuai Spesifikasi FR-1.2:
  /// - Jika user tidak sedang login -> return true.
  /// - Jika timestamp kosong atau rusak -> panggil logout() & return true.
  /// - Jika selisih waktu saat ini dengan last_active >= 60 menit -> panggil logout() & return true.
  /// - Jika masih dalam batas waktu -> perbarui last_active ke waktu saat ini & return false.
  static Future<bool> checkSessionTimeout() async {
    final pref = await SharedPreferences.getInstance();
    final isLoggedIn = pref.getBool(keyLogin) ?? false;
    
    // Jika tidak dalam kondisi login, sesi dianggap tidak aktif
    if (!isLoggedIn) {
      return true;
    }

    final lastActiveStr = pref.getString(keyLastActive);
    if (lastActiveStr == null || lastActiveStr.isEmpty) {
      // Data waktu aktivitas tidak valid -> amankan dengan auto-logout
      await logout();
      return true;
    }

    final lastActive = DateTime.tryParse(lastActiveStr);
    if (lastActive == null) {
      await logout();
      return true;
    }

    final differenceInMinutes = DateTime.now().difference(lastActive).inMinutes;

    // Batas waktu inaktif toleransi maksimal: 60 menit (1 Jam)
    if (differenceInMinutes >= 60) {
      // Sesi telah kedaluwarsa -> bersihkan sesi aktif (Auto-Logout)
      await logout();
      return true;
    }

    // Sesi masih valid: perbarui timestamp aktivitas terakhir ke waktu saat ini
    await setLastActive(DateTime.now().toIso8601String());
    return false;
  }

  // ============================================================================
  // LOGOUT (STANDAR INDUSTRI)
  // ============================================================================

  /// Menghapus otorisasi sesi aktif saat Logout.
  /// STANDAR INDUSTRI APLIKASI MODERN:
  /// Hanya mencabut sesi (token, status login, dan timestamp aktivitas).
  /// Kredensial pengenal (username/email/userID) dan preferensi biometrik (keyBiometricEnabled)
  /// TETAP DIPERTAHANKAN pada perangkat ini agar user dapat login kembali menggunakan
  /// Sidik Jari / Face ID tanpa harus mengetik password berulang kali.
  static Future<void> logout() async {
    final pref = await SharedPreferences.getInstance();
    await pref.remove(keyToken);
    await pref.setBool(keyLogin, false);
    await pref.remove(keyLastActive);
  }

  /// Reset total data aplikasi jika user ingin menghapus seluruh jejak lokal (Factory Reset)
  static Future<void> clearAll() async {
    final pref = await SharedPreferences.getInstance();
    await pref.clear();
  }
}
