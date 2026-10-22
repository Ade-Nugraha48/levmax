// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/helpers/user_info.dart
// Deskripsi: Manajemen Sesi & Kredensial Pengguna via Hive (authBox)
//            Menggantikan SharedPreferences lama untuk efisiensi & kecepatan I/O.
// ==============================================================================

import 'dart:convert';
import 'package:hive/hive.dart';
import 'hive_boxes.dart';

class UserInfo {
  // ============================================================================
  // KUNCI-KUNCI PENYIMPANAN DI AUTH_BOX
  // ============================================================================
  static const String keyAccessToken = HiveBoxes.keyAccessToken;
  static const String keyUserId = HiveBoxes.keyUserId;
  static const String keyIsBiometricEnabled = HiveBoxes.keyIsBiometricEnabled;
  static const String keyBiometricCredential = HiveBoxes.keyBiometricCredential;

  // Kunci Profil & Keadaan Sesi
  static const String keyUsername = HiveBoxes.keyUsername;
  static const String keyEmail = HiveBoxes.keyEmail;
  static const String keyIsLoggedIn = HiveBoxes.keyIsLoggedIn;
  static const String keyIsOnboarded = HiveBoxes.keyIsOnboarded;
  static const String keyLastActive = HiveBoxes.keyLastActive;
  static const String keyFaceIdEnabled = HiveBoxes.keyFaceIdEnabled;
  static const String keyFingerprintEnabled = HiveBoxes.keyFingerprintEnabled;
  static const String keyBiometricUserId = 'biometric_user_id';
  static const String keyBiometricEmail = 'biometric_email';
  static const String keyPendingBiometricSetup = 'pending_biometric_setup';

  // Kunci Keamanan Wajah & Sidik Jari
  static const String keyHasEnrolledFace = 'has_enrolled_face';
  static const String keyEnrolledFaceTemplate = 'enrolled_face_template';
  static const String keyFaceEnrolledAt = 'face_enrolled_at';
  static const String keyHasEnrolledFingerprint = 'has_enrolled_fingerprint';
  static const String keyFingerprintEnrolledAt = 'fingerprint_enrolled_at';

  static Future<Box> _ensureAuthBox() async {
    if (Hive.isBoxOpen(HiveBoxes.authBox)) {
      return Hive.box(HiveBoxes.authBox);
    }
    return await Hive.openBox(HiveBoxes.authBox);
  }

  /// Memperbarui stempel waktu aktivitas terakhir ke waktu saat ini
  static Future<void> updateLastActive() async {
    await setLastActive(DateTime.now().toIso8601String());
  }

  // ============================================================================
  // TOKEN & USER IDENTITY (UUID)
  // ============================================================================

  /// Menyimpan access_token sesi aktif
  static Future<void> setToken(String value) async {
    final box = await _ensureAuthBox();
    await box.put(keyAccessToken, value);
  }

  /// Mengambil access_token sesi aktif
  static Future<String?> getToken() async {
    final box = await _ensureAuthBox();
    return box.get(keyAccessToken) as String?;
  }

  /// Menyimpan ID unik Player (UUID String)
  static Future<void> setUserId(String value) async {
    final box = await _ensureAuthBox();
    await box.put(keyUserId, value);
  }

  /// Mengambil ID unik Player (UUID String)
  static Future<String?> getUserId() async {
    final box = await _ensureAuthBox();
    final val = box.get(keyUserId);
    return val?.toString();
  }

  /// Alias serbaguna untuk setUserID (mendukung String UUID maupun legacy int)
  static Future<void> setUserID(dynamic value) async {
    final box = await _ensureAuthBox();
    await box.put(keyUserId, value?.toString() ?? '');
  }

  /// Alias serbaguna untuk getUserID (mengembalikan UUID String)
  static Future<dynamic> getUserID() async {
    return await getUserId();
  }

  /// Menyimpan Username Hunter
  static Future<void> setUsername(String value) async {
    final box = await _ensureAuthBox();
    await box.put(keyUsername, value);
  }

  /// Mengambil Username Hunter
  static Future<String?> getUsername() async {
    final box = await _ensureAuthBox();
    return box.get(keyUsername) as String?;
  }

  /// Menyimpan Email terdaftar
  static Future<void> setEmail(String value) async {
    final box = await _ensureAuthBox();
    await box.put(keyEmail, value);
  }

  /// Mengambil Email terdaftar
  static Future<String?> getEmail() async {
    final box = await _ensureAuthBox();
    return box.get(keyEmail) as String?;
  }

  // ============================================================================
  // STATUS LOGIN & ONBOARDING
  // ============================================================================

  /// Menyimpan status login aktif
  static Future<void> setLoginStatus(bool value) async {
    final box = await _ensureAuthBox();
    await box.put(keyIsLoggedIn, value);
  }

  /// Mengambil status login aktif
  static Future<bool> getLoginStatus() async {
    final box = await _ensureAuthBox();
    return (box.get(keyIsLoggedIn) as bool?) ?? false;
  }

  /// Menyimpan status penyelesaian Onboarding fisik Player
  static Future<void> setIsOnboarded(bool value) async {
    final box = await _ensureAuthBox();
    await box.put(keyIsOnboarded, value);
  }

  /// Mengambil status penyelesaian Onboarding fisik Player
  static Future<bool> getIsOnboarded() async {
    final box = await _ensureAuthBox();
    return (box.get(keyIsOnboarded) as bool?) ?? false;
  }

  // ============================================================================
  // KREDENSIAL BIOMETRIK & INTEGRASI PERANGKAT
  // ============================================================================

  /// Menyimpan status umum biometrik aktif
  static Future<void> setBiometricEnabled(bool value) async {
    final box = await _ensureAuthBox();
    await box.put(keyIsBiometricEnabled, value);
  }

  /// Mengambil status umum biometrik aktif
  static Future<bool> getBiometricEnabled() async {
    final box = await _ensureAuthBox();
    return (box.get(keyIsBiometricEnabled) as bool?) ?? false;
  }

  /// Menyimpan kredensial/token biometrik perangkat
  static Future<void> setBiometricCredential(String value) async {
    final box = await _ensureAuthBox();
    await box.put(keyBiometricCredential, value);
  }

  /// Mengambil kredensial/token biometrik perangkat
  static Future<String?> getBiometricCredential() async {
    final box = await _ensureAuthBox();
    return box.get(keyBiometricCredential) as String?;
  }

  /// Menyimpan status Face ID aktif
  static Future<void> setFaceIdEnabled(bool value) async {
    final box = await _ensureAuthBox();
    await box.put(keyFaceIdEnabled, value);
    final fp = (box.get(keyFingerprintEnabled) as bool?) ?? false;
    await box.put(keyIsBiometricEnabled, value || fp);
  }

  /// Mengambil status Face ID aktif
  static Future<bool> getFaceIdEnabled() async {
    final box = await _ensureAuthBox();
    return (box.get(keyFaceIdEnabled) as bool?) ?? false;
  }

  /// Menyimpan status Fingerprint aktif
  static Future<void> setFingerprintEnabled(bool value) async {
    final box = await _ensureAuthBox();
    await box.put(keyFingerprintEnabled, value);
    final face = (box.get(keyFaceIdEnabled) as bool?) ?? false;
    await box.put(keyIsBiometricEnabled, value || face);
  }

  /// Mengambil status Fingerprint aktif
  static Future<bool> getFingerprintEnabled() async {
    final box = await _ensureAuthBox();
    return (box.get(keyFingerprintEnabled) as bool?) ?? false;
  }

  static Future<void> setBiometricUserId(dynamic value) async {
    final box = await _ensureAuthBox();
    await box.put(keyBiometricUserId, value?.toString() ?? '');
  }

  static Future<String?> getBiometricUserId() async {
    final box = await _ensureAuthBox();
    return box.get(keyBiometricUserId)?.toString();
  }

  static Future<void> setBiometricEmail(String value) async {
    final box = await _ensureAuthBox();
    await box.put(keyBiometricEmail, value);
  }

  static Future<String?> getBiometricEmail() async {
    final box = await _ensureAuthBox();
    return box.get(keyBiometricEmail) as String?;
  }

  static Future<void> setPendingBiometricSetup(bool value) async {
    final box = await _ensureAuthBox();
    await box.put(keyPendingBiometricSetup, value);
  }

  static Future<bool> getPendingBiometricSetup() async {
    final box = await _ensureAuthBox();
    return (box.get(keyPendingBiometricSetup) as bool?) ?? false;
  }

  static Future<void> setHasEnrolledFace(bool value) async {
    final box = await _ensureAuthBox();
    await box.put(keyHasEnrolledFace, value);
  }

  static Future<bool> getHasEnrolledFace() async {
    final box = await _ensureAuthBox();
    return (box.get(keyHasEnrolledFace) as bool?) ?? false;
  }

  /// Menonaktifkan Face ID
  static Future<void> disableFaceId() async {
    await setFaceIdEnabled(false);
  }

  /// Menonaktifkan Fingerprint
  static Future<void> disableFingerprint() async {
    await setFingerprintEnabled(false);
  }

  /// Menonaktifkan seluruh biometrik
  static Future<void> disableBiometrics() async {
    await setBiometricEnabled(false);
    await setFaceIdEnabled(false);
    await setFingerprintEnabled(false);
  }

  static Future<void> saveEnrolledFaceTemplate(dynamic template) async {
    final box = await _ensureAuthBox();
    if (template is Map) {
      await box.put(keyEnrolledFaceTemplate, jsonEncode(template));
    } else {
      await box.put(keyEnrolledFaceTemplate, template?.toString());
    }
    await box.put(keyHasEnrolledFace, true);
    await box.put(keyFaceEnrolledAt, DateTime.now().toIso8601String());
  }

  static Future<void> setEnrolledFaceTemplate(String value) async {
    final box = await _ensureAuthBox();
    await box.put(keyEnrolledFaceTemplate, value);
  }

  static Future<Map<String, dynamic>?> getEnrolledFaceTemplate() async {
    final box = await _ensureAuthBox();
    final raw = box.get(keyEnrolledFaceTemplate);
    if (raw == null) return null;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return null;
  }

  static Future<void> setFaceEnrolledAt(String value) async {
    final box = await _ensureAuthBox();
    await box.put(keyFaceEnrolledAt, value);
  }

  static Future<String?> getFaceEnrolledAt() async {
    final box = await _ensureAuthBox();
    return box.get(keyFaceEnrolledAt) as String?;
  }

  static Future<void> saveEnrolledFingerprint([dynamic template]) async {
    final box = await _ensureAuthBox();
    await box.put(keyHasEnrolledFingerprint, true);
    await box.put(keyFingerprintEnrolledAt, DateTime.now().toIso8601String());
  }

  static Future<void> setHasEnrolledFingerprint(bool value) async {
    final box = await _ensureAuthBox();
    await box.put(keyHasEnrolledFingerprint, value);
  }

  static Future<bool> getHasEnrolledFingerprint() async {
    final box = await _ensureAuthBox();
    return (box.get(keyHasEnrolledFingerprint) as bool?) ?? false;
  }

  static Future<void> setFingerprintEnrolledAt(String value) async {
    final box = await _ensureAuthBox();
    await box.put(keyFingerprintEnrolledAt, value);
  }

  static Future<String?> getFingerprintEnrolledAt() async {
    final box = await _ensureAuthBox();
    return box.get(keyFingerprintEnrolledAt) as String?;
  }

  /// Auto logout alias untuk sesi kedaluwarsa
  static Future<void> autoLogout() async {
    await logout();
  }

  // ============================================================================
  // SESI AKTIF & AUTO-TIMEOUT (60 MENIT)
  // ============================================================================

  /// Menyimpan stempel waktu aktivitas terakhir
  static Future<void> setLastActive(String isoTimestamp) async {
    final box = await _ensureAuthBox();
    await box.put(keyLastActive, isoTimestamp);
  }

  /// Mengambil stempel waktu aktivitas terakhir
  static Future<String?> getLastActive() async {
    final box = await _ensureAuthBox();
    return box.get(keyLastActive) as String?;
  }

  /// Memeriksa apakah sesi telah kedaluwarsa (> 60 menit inaktif)
  static Future<bool> checkSessionTimeout() async {
    final lastActiveStr = await getLastActive();
    if (lastActiveStr == null || lastActiveStr.isEmpty) return false;

    try {
      final lastActive = DateTime.parse(lastActiveStr);
      final diff = DateTime.now().difference(lastActive);
      return diff.inMinutes >= 60;
    } catch (_) {
      return false;
    }
  }

  /// Mengeluarkan pengguna dan membersihkan data sesi di authBox
  static Future<void> logout() async {
    final box = await _ensureAuthBox();
    await box.delete(keyAccessToken);
    await box.delete(keyUserId);
    await box.delete(keyUsername);
    await box.delete(keyEmail);
    await box.delete(keyIsLoggedIn);
    await box.delete(keyIsOnboarded);
    await box.delete(keyLastActive);
  }

  /// Membersihkan seluruh data di AuthBox
  static Future<void> clearSession() async {
    await logout();
  }
}
