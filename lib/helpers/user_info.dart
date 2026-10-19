// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/helpers/user_info.dart
// Deskripsi: Lapisan 1 Arsitektur DB - Manajemen Sesi Login via SharedPreferences
//            dengan validasi kedaluwarsa sesi otomatis 60 menit (Auto-Logout)
//            dan penyimpanan Token-Bound Biometric Session (Standar Industri).
// ==============================================================================

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class UserInfo {
  // ============================================================================
  // KUNCI PENYIMPANAN SESI & IDENTITAS (STANDAR SPESIFIKASI)
  // ============================================================================
  static const String keyToken = 'token';
  static const String keyUserID = 'userID';
  static const String keyUsername = 'username';
  static const String keyEmail = 'email';
  static const String keyLogin = 'login';
  static const String keyIsOnboarded = 'isOnboarded';
  static const String keyLastActive = 'lastActive';

  // Kunci-kunci spesifik Face ID & Fingerprint Perangkat (Terpisah)
  static const String keyBiometricEnabled = 'biometric_enabled';
  static const String keyFaceIdEnabled = 'face_id_enabled';
  static const String keyFingerprintEnabled = 'fingerprint_enabled';
  static const String keyBiometricUserId = 'biometric_user_id';
  static const String keyBiometricEmail = 'biometric_email';
  static const String keyPendingBiometricSetup = 'pending_biometric_setup';

  // Kunci Patokan Wajah Sekuritas (Setor Wajah / Face Enrollment)
  static const String keyHasEnrolledFace = 'has_enrolled_face';
  static const String keyEnrolledFaceTemplate = 'enrolled_face_template';
  static const String keyFaceEnrolledAt = 'face_enrolled_at';

  // Kunci Patokan Sidik Jari Sekuritas (Setor Sidik Jari / Fingerprint Enrollment)
  static const String keyHasEnrolledFingerprint = 'has_enrolled_fingerprint';
  static const String keyFingerprintEnrolledAt = 'fingerprint_enrolled_at';

  // ============================================================================
  // TOKEN & USER IDENTITY
  // ============================================================================

  /// Menyimpan auth_key token sesi aktif (dari tabel user_tokens Supabase)
  static Future<bool> setToken(String value) async {
    final pref = await SharedPreferences.getInstance();
    return await pref.setString(keyToken, value);
  }

  /// Mengambil auth_key token sesi aktif
  static Future<String?> getToken() async {
    final pref = await SharedPreferences.getInstance();
    return pref.getString(keyToken);
  }

  /// Menyimpan ID unik Player yang sedang aktif (userID di PostgreSQL)
  static Future<bool> setUserID(int value) async {
    final pref = await SharedPreferences.getInstance();
    return await pref.setInt(keyUserID, value);
  }

  /// Mengambil ID unik Player yang sedang aktif
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
  // MANAJEMEN SESI BIOMETRIK LOKAL (FACE ID & FINGERPRINT TERPISAH)
  // ============================================================================

  /// Menyimpan status apakah Face ID aktif di perangkat ini
  static Future<bool> setFaceIdEnabled(bool value) async {
    final pref = await SharedPreferences.getInstance();
    final res = await pref.setBool(keyFaceIdEnabled, value);
    // Sinkronkan key umum biometric_enabled
    final fp = pref.getBool(keyFingerprintEnabled) ?? false;
    await pref.setBool(keyBiometricEnabled, value || fp);
    return res;
  }

  /// Mengambil status apakah Face ID aktif di perangkat ini
  static Future<bool> getFaceIdEnabled() async {
    final pref = await SharedPreferences.getInstance();
    return pref.getBool(keyFaceIdEnabled) ?? false;
  }

  /// Menyimpan status apakah Fingerprint aktif di perangkat ini
  static Future<bool> setFingerprintEnabled(bool value) async {
    final pref = await SharedPreferences.getInstance();
    final res = await pref.setBool(keyFingerprintEnabled, value);
    // Sinkronkan key umum biometric_enabled
    final face = pref.getBool(keyFaceIdEnabled) ?? false;
    await pref.setBool(keyBiometricEnabled, value || face);
    return res;
  }

  /// Mengambil status apakah Fingerprint aktif di perangkat ini
  static Future<bool> getFingerprintEnabled() async {
    final pref = await SharedPreferences.getInstance();
    return pref.getBool(keyFingerprintEnabled) ?? false;
  }

  /// Menyimpan status apakah Face ID/Biometrik aktif di perangkat ini (Umum)
  static Future<bool> setBiometricEnabled(bool value) async {
    final pref = await SharedPreferences.getInstance();
    return await pref.setBool(keyBiometricEnabled, value);
  }

  /// Mengambil status apakah salah satu biometrik (Face ID atau Fingerprint) aktif
  static Future<bool> getBiometricEnabled() async {
    final pref = await SharedPreferences.getInstance();
    final face = pref.getBool(keyFaceIdEnabled) ?? false;
    final fp = pref.getBool(keyFingerprintEnabled) ?? false;
    final general = pref.getBool(keyBiometricEnabled) ?? false;
    return face || fp || general;
  }

  /// Menyimpan User ID pemilik biometrik di perangkat ini
  /// PENTING: Nilai ini TIDAK dihapus saat normal logout agar user bisa Quick Login dengan Face ID
  static Future<bool> setBiometricUserId(int value) async {
    final pref = await SharedPreferences.getInstance();
    return await pref.setInt(keyBiometricUserId, value);
  }

  /// Mengambil User ID pemilik biometrik di perangkat ini
  static Future<int?> getBiometricUserId() async {
    final pref = await SharedPreferences.getInstance();
    return pref.getInt(keyBiometricUserId);
  }

  /// Menyimpan Email akun yang terhubung dengan Face ID di perangkat ini
  /// Digunakan untuk menampilkan teks ramah: "Masuk kembali sebagai player@levmax.com dengan Face ID"
  static Future<bool> setBiometricEmail(String value) async {
    final pref = await SharedPreferences.getInstance();
    return await pref.setString(keyBiometricEmail, value);
  }

  /// Mengambil Email akun yang terhubung dengan Face ID di perangkat ini
  static Future<String?> getBiometricEmail() async {
    final pref = await SharedPreferences.getInstance();
    return pref.getString(keyBiometricEmail);
  }

  /// Menyimpan flag pending lazy enrollment (saat user klik Face ID sebelum setup)
  static Future<bool> setPendingBiometricSetup(bool value) async {
    final pref = await SharedPreferences.getInstance();
    return await pref.setBool(keyPendingBiometricSetup, value);
  }

  /// Mengambil flag pending lazy enrollment
  static Future<bool> getPendingBiometricSetup() async {
    final pref = await SharedPreferences.getInstance();
    return pref.getBool(keyPendingBiometricSetup) ?? false;
  }

  // ============================================================================
  // PATOKAN WAJAH SEKURITAS (SETOR WAJAH / ENROLLMENT FACE ID)
  // ============================================================================

  /// Menyimpan status apakah user telah menyetor wajah patokan
  static Future<bool> setHasEnrolledFace(bool value) async {
    final pref = await SharedPreferences.getInstance();
    return await pref.setBool(keyHasEnrolledFace, value);
  }

  /// Memeriksa apakah user sudah menyetor wajah patokan yang valid
  static Future<bool> getHasEnrolledFace() async {
    final pref = await SharedPreferences.getInstance();
    final hasEnrolled = pref.getBool(keyHasEnrolledFace) ?? false;
    final template = pref.getString(keyEnrolledFaceTemplate);
    return hasEnrolled && (template != null && template.isNotEmpty);
  }

  /// Menyimpan template vektor biometrik patokan wajah Hunter
  static Future<bool> saveEnrolledFaceTemplate(Map<String, double> template) async {
    final pref = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(template);
    final nowIso = DateTime.now().toIso8601String();
    await pref.setString(keyFaceEnrolledAt, nowIso);
    await pref.setString(keyEnrolledFaceTemplate, jsonStr);
    return await pref.setBool(keyHasEnrolledFace, true);
  }

  /// Mengambil template vektor biometrik patokan wajah Hunter
  static Future<Map<String, double>?> getEnrolledFaceTemplate() async {
    final pref = await SharedPreferences.getInstance();
    final jsonStr = pref.getString(keyEnrolledFaceTemplate);
    if (jsonStr == null || jsonStr.isEmpty) return null;
    try {
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
    } catch (_) {
      return null;
    }
  }

  /// Mengambil waktu ISO saat wajah patokan didaftarkan
  static Future<String?> getFaceEnrolledAt() async {
    final pref = await SharedPreferences.getInstance();
    return pref.getString(keyFaceEnrolledAt);
  }

  /// Menghapus patokan wajah yang tersimpan di perangkat ini
  static Future<bool> deleteEnrolledFaceTemplate() async {
    final pref = await SharedPreferences.getInstance();
    await pref.remove(keyEnrolledFaceTemplate);
    await pref.remove(keyFaceEnrolledAt);
    return await pref.setBool(keyHasEnrolledFace, false);
  }

  // ============================================================================
  // PATOKAN SIDIK JARI SEKURITAS (SETOR SIDIK JARI / ENROLLMENT FINGERPRINT)
  // ============================================================================

  /// Menyimpan status apakah user telah menyetor sidik jari patokan
  static Future<bool> setHasEnrolledFingerprint(bool value) async {
    final pref = await SharedPreferences.getInstance();
    return await pref.setBool(keyHasEnrolledFingerprint, value);
  }

  /// Memeriksa apakah user sudah menyetor sidik jari patokan
  static Future<bool> getHasEnrolledFingerprint() async {
    final pref = await SharedPreferences.getInstance();
    return pref.getBool(keyHasEnrolledFingerprint) ?? false;
  }

  /// Menyimpan status konfirmasi setoran sidik jari patokan Hunter
  static Future<bool> saveEnrolledFingerprint() async {
    final pref = await SharedPreferences.getInstance();
    final nowIso = DateTime.now().toIso8601String();
    await pref.setString(keyFingerprintEnrolledAt, nowIso);
    return await pref.setBool(keyHasEnrolledFingerprint, true);
  }

  /// Mengambil waktu ISO saat sidik jari patokan didaftarkan
  static Future<String?> getFingerprintEnrolledAt() async {
    final pref = await SharedPreferences.getInstance();
    return pref.getString(keyFingerprintEnrolledAt);
  }

  /// Menghapus patokan sidik jari yang tersimpan di perangkat ini
  static Future<bool> deleteEnrolledFingerprint() async {
    final pref = await SharedPreferences.getInstance();
    await pref.remove(keyFingerprintEnrolledAt);
    return await pref.setBool(keyHasEnrolledFingerprint, false);
  }

  // ============================================================================
  // MANAJEMEN WAKTU & TIMEOUT SESI 1 JAM (AUTO-LOGOUT 60 MENIT)
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

  /// Memperbarui timestamp aktivitas ke waktu saat ini
  static Future<void> updateLastActive() async {
    final nowIso = DateTime.now().toIso8601String();
    await setLastActive(nowIso);
  }

  /// Menghitung selisih menit sejak aktivitas terakhir
  static Future<int> getInactiveMinutes() async {
    final pref = await SharedPreferences.getInstance();
    final lastActiveStr = pref.getString(keyLastActive);
    if (lastActiveStr == null || lastActiveStr.isEmpty) return 999999;
    final lastActive = DateTime.tryParse(lastActiveStr);
    if (lastActive == null) return 999999;
    return DateTime.now().difference(lastActive).inMinutes;
  }

  /// Memeriksa apakah sesi telah kedaluwarsa (> 60 menit dari aktivitas terakhir).
  /// Sesuai Spesifikasi:
  /// - Jika tidak login -> return true.
  /// - Jika inaktif > 60 menit -> panggil autoLogout() dan return true.
  /// - Jika masih valid -> perbarui lastActive dan return false.
  static Future<bool> checkSessionTimeout() async {
    final pref = await SharedPreferences.getInstance();
    final isLoggedIn = pref.getBool(keyLogin) ?? false;
    
    if (!isLoggedIn) {
      return true;
    }

    final inactiveMins = await getInactiveMinutes();
    if (inactiveMins >= 60) {
      // Sesi 1 jam habis -> cabut sesi aktif (Auto-Logout)
      await autoLogout();
      return true;
    }

    // Sesi masih valid: perbarui timestamp aktivitas terakhir
    await updateLastActive();
    return false;
  }

  // ============================================================================
  // LOGOUT SESI STANDAR INDUSTRI
  // ============================================================================

  /// Auto-Logout saat sesi inaktif melebihi 60 menit:
  /// Mencabut token dan status login, namun TETAP MEMPERTAHANKAN biometric_user_id & biometric_email
  /// agar user dapat membuka kembali aplikasi secara instan menggunakan Face ID / Biometrik.
  static Future<void> autoLogout() async {
    final pref = await SharedPreferences.getInstance();
    await pref.remove(keyToken);
    await pref.setBool(keyLogin, false);
    await pref.remove(keyLastActive);
  }

  /// Normal Logout (dipicu user di menu profil):
  /// Sama seperti auto-logout, mempertahankan biometric_user_id & biometric_email pada perangkat
  /// untuk fitur Quick Login yang aman.
  static Future<void> logout() async {
    await autoLogout();
  }

  /// Menonaktifkan fitur Face ID pada perangkat ini
  static Future<void> disableFaceId() async {
    final pref = await SharedPreferences.getInstance();
    await pref.setBool(keyFaceIdEnabled, false);
    final fp = pref.getBool(keyFingerprintEnabled) ?? false;
    await pref.setBool(keyBiometricEnabled, fp);
    if (!fp) {
      await pref.remove(keyBiometricUserId);
      await pref.remove(keyBiometricEmail);
    }
  }

  /// Menonaktifkan fitur Fingerprint pada perangkat ini
  static Future<void> disableFingerprint() async {
    final pref = await SharedPreferences.getInstance();
    await pref.setBool(keyFingerprintEnabled, false);
    final face = pref.getBool(keyFaceIdEnabled) ?? false;
    await pref.setBool(keyBiometricEnabled, face);
    if (!face) {
      await pref.remove(keyBiometricUserId);
      await pref.remove(keyBiometricEmail);
    }
  }

  /// Menonaktifkan fitur Biometrik sepenuhnya pada perangkat ini:
  /// Menghapus biometric_enabled, face_id_enabled, fingerprint_enabled, biometric_user_id, dan biometric_email.
  static Future<void> disableBiometrics() async {
    final pref = await SharedPreferences.getInstance();
    await pref.setBool(keyBiometricEnabled, false);
    await pref.setBool(keyFaceIdEnabled, false);
    await pref.setBool(keyFingerprintEnabled, false);
    await pref.remove(keyBiometricUserId);
    await pref.remove(keyBiometricEmail);
    await pref.remove(keyPendingBiometricSetup);
  }

  /// Reset total data aplikasi jika user ingin menghapus seluruh jejak lokal (Factory Reset)
  static Future<void> clearAll() async {
    final pref = await SharedPreferences.getInstance();
    await pref.clear();
  }
}
