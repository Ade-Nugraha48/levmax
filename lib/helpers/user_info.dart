// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/helpers/user_info.dart
// Deskripsi: Lapisan 1 Arsitektur DB - Manajemen Sesi Login via SharedPreferences
//            dengan validasi kedaluwarsa sesi otomatis 60 menit (1 Jam).
// ==============================================================================

import 'package:shared_preferences/shared_preferences.dart';

class UserInfo {
  static const String keyToken = 'token';
  static const String keyUserID = 'userID';
  static const String keyUsername = 'username';
  static const String keyEmail = 'email';
  static const String keyLogin = 'login';
  static const String keyIsOnboarded = 'isOnboarded';
  static const String keyBiometricEnabled = 'biometricEnabled';
  static const String keyLastActive = 'last_active_timestamp';

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

  /// Menyimpan ID unik Player (user_id)
  static Future<bool> setUserID(int value) async {
    final pref = await SharedPreferences.getInstance();
    return await pref.setInt(keyUserID, value);
  }

  /// Mengambil ID unik Player
  static Future<int?> getUserID() async {
    final pref = await SharedPreferences.getInstance();
    return pref.getInt(keyUserID);
  }

  /// Menyimpan Username
  static Future<bool> setUsername(String value) async {
    final pref = await SharedPreferences.getInstance();
    return await pref.setString(keyUsername, value);
  }

  /// Mengambil Username
  static Future<String?> getUsername() async {
    final pref = await SharedPreferences.getInstance();
    return pref.getString(keyUsername);
  }

  /// Menyimpan Email
  static Future<bool> setEmail(String value) async {
    final pref = await SharedPreferences.getInstance();
    return await pref.setString(keyEmail, value);
  }

  /// Mengambil Email
  static Future<String?> getEmail() async {
    final pref = await SharedPreferences.getInstance();
    return pref.getString(keyEmail);
  }

  /// Menyimpan status login aktif
  static Future<bool> setLoginStatus(bool value) async {
    final pref = await SharedPreferences.getInstance();
    return await pref.setBool(keyLogin, value);
  }

  /// Mengambil status login aktif
  static Future<bool> getLoginStatus() async {
    final pref = await SharedPreferences.getInstance();
    return pref.getBool(keyLogin) ?? false;
  }

  /// Menyimpan status onboarding fisik Player
  static Future<bool> setIsOnboarded(bool value) async {
    final pref = await SharedPreferences.getInstance();
    return await pref.setBool(keyIsOnboarded, value);
  }

  /// Mengambil status onboarding fisik Player
  static Future<bool> getIsOnboarded() async {
    final pref = await SharedPreferences.getInstance();
    return pref.getBool(keyIsOnboarded) ?? false;
  }

  /// Menyimpan preferensi biometrik (Fingerprint / Face ID)
  static Future<bool> setBiometricEnabled(bool value) async {
    final pref = await SharedPreferences.getInstance();
    return await pref.setBool(keyBiometricEnabled, value);
  }

  /// Mengambil status preferensi biometrik
  static Future<bool> getBiometricEnabled() async {
    final pref = await SharedPreferences.getInstance();
    return pref.getBool(keyBiometricEnabled) ?? false;
  }

  /// Menyimpan waktu aktivitas terakhir dalam format ISO-8601
  static Future<bool> setLastActive(String isoTime) async {
    final pref = await SharedPreferences.getInstance();
    return await pref.setString(keyLastActive, isoTime);
  }

  /// Mengambil timestamp waktu aktivitas terakhir
  static Future<String?> getLastActive() async {
    final pref = await SharedPreferences.getInstance();
    return pref.getString(keyLastActive);
  }

  /// Memperbarui timestamp aktivitas ke waktu saat ini
  static Future<void> updateLastActive() async {
    final nowIso = DateTime.now().toIso8601String();
    await setLastActive(nowIso);
  }

  /// Memeriksa apakah sesi telah kedaluwarsa (> 60 menit dari aktivitas terakhir).
  /// Sesuai Spesifikasi FR-1.2: jika selisih > 60 menit, panggil pref.clear() (auto-logout)
  /// dan kembalikan true. Jika sesi masih berlaku, perbarui last_active dan kembalikan false.
  static Future<bool> checkSessionTimeout() async {
    final pref = await SharedPreferences.getInstance();
    final isLoggedIn = pref.getBool(keyLogin) ?? false;
    if (!isLoggedIn) {
      return true; // Tidak sedang login
    }

    final lastActiveStr = pref.getString(keyLastActive);
    if (lastActiveStr == null || lastActiveStr.isEmpty) {
      await pref.clear();
      return true; // Tidak ada riwayat aktivitas, auto-logout
    }

    final lastActive = DateTime.tryParse(lastActiveStr);
    if (lastActive == null) {
      await pref.clear();
      return true;
    }

    final differenceInMinutes = DateTime.now().difference(lastActive).inMinutes;

    // Sesuai aturan: jika selisih waktu sekarang dengan last_active_timestamp > 60 menit (1 jam)
    if (differenceInMinutes >= 60) {
      await pref.clear();
      return true; // Sesi habis, panggil auto-logout
    }

    // Sesi masih valid, perbarui timestamp ke waktu saat ini
    await pref.setString(keyLastActive, DateTime.now().toIso8601String());
    return false;
  }

  /// Menghapus seluruh data sesi di SharedPreferences saat Logout
  static Future<void> logout() async {
    final pref = await SharedPreferences.getInstance();
    await pref.clear();
  }
}
