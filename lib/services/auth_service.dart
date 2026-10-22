// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/services/auth_service.dart
// Deskripsi: Layanan Autentikasi Modern Solo Leveling - Enkripsi SHA-256 (Tanpa Firebase),
//            Token-Bound Biometric Session (Face ID & Fingerprint via BiometricService),
//            REST API Supabase via package:http, & Manajemen Sesi SharedPreferences.
// ==============================================================================

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import '../helpers/user_info.dart';
import '../models/user_model.dart';
import 'biometric_service.dart';
import 'supabase_api_service.dart';

class AuthService {
  // ============================================================================
  // ENKRIPSI & KEAMANAN KRIPTOGRAFI (SHA-256)
  // ============================================================================

  /// Mengenkripsi password plaintext menjadi representasi hash SHA-256 (64 karakter heksadesimal).
  /// Sesuai standar industri: password mentah tidak pernah disimpan di database Supabase maupun lokal.
  static String hashPassword(String password) {
    final bytes = utf8.encode(password.trim());
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Menghasilkan Token Sesi Kriptografis Unik menggunakan salt waktu mikrodetik dan SHA-256.
  static String generateSessionToken(String identifier) {
    final salt = '${DateTime.now().microsecondsSinceEpoch}_${identifier}_levmax_auth_token';
    final bytes = utf8.encode(salt);
    return sha256.convert(bytes).toString();
  }

  // ============================================================================
  // REGISTRASI USER BARU (POST KE TABEL 'users' SUPABASE) - ALUR 1
  // ============================================================================

  /// Mendaftarkan Hunter baru ke dalam Database Supabase via HTTP REST API
  static Future<Map<String, dynamic>> registerUser({
    required String username,
    required String email,
    required String password,
    bool isBiometric = false,
    bool? isFaceId,
    bool? isFingerprint,
  }) async {
    final trimmedUsername = username.trim();
    final trimmedEmail = email.trim();

    // 1. Validasi form dasar
    if (trimmedUsername.isEmpty || trimmedEmail.isEmpty || password.isEmpty) {
      return {
        'success': false,
        'message': 'Semua kolom input wajib diisi.',
      };
    }

    if (trimmedUsername.length < 3) {
      return {
        'success': false,
        'message': 'Username minimal terdiri dari 3 karakter.',
      };
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(trimmedEmail)) {
      return {
        'success': false,
        'message': 'Format alamat email tidak valid.',
      };
    }

    if (password.length < 8) {
      return {
        'success': false,
        'message': 'Password minimal terdiri dari 8 karakter demi keamanan akun Hunter.',
      };
    }

    // 2. Pemeriksaan duplikasi akun di Supabase
    final existingUser = await SupabaseApiService.getUserByUsername(trimmedUsername);
    if (existingUser != null) {
      return {
        'success': false,
        'message': 'Username "$trimmedUsername" sudah digunakan Hunter lain. Silakan pilih nama lain.',
      };
    }

    final existingEmail = await SupabaseApiService.getUserByEmail(trimmedEmail);
    if (existingEmail != null) {
      return {
        'success': false,
        'message': 'Email "$trimmedEmail" sudah terdaftar di Sistem. Silakan masuk atau gunakan email lain.',
      };
    }

    // 3. Enkripsi Password Plaintext menggunakan SHA-256
    final hashedPassword = hashPassword(password);

    final effectiveFace = isFaceId ?? isBiometric;
    final effectiveFp = isFingerprint ?? isBiometric;
    final effectiveBio = isBiometric || effectiveFace || effectiveFp;

    // 4. Inisialisasi Objek Hunter Level 1 Rank F dengan UUID v4 standar RFC 4122
    final newUserId = generateUuidV4();
    final newUser = UserModel.initial(
      id: newUserId,
      username: trimmedUsername,
      email: trimmedEmail,
      passwordHash: hashedPassword,
      biometricEnabled: effectiveBio,
    );

    // 5. Kirim data Hunter ke Supabase Cloud Database
    final createdUser = await SupabaseApiService.createUser(newUser);
    if (createdUser == null) {
      return {
        'success': false,
        'message': 'Gagal menyimpan data Hunter ke Supabase. Periksa koneksi internet Anda.',
      };
    }

    // 6. Buat Token Sesi dan simpan status lokal ke Hive / SharedPreferences
    final token = generateSessionToken(createdUser.username);
    final expiresAt = DateTime.now().add(const Duration(hours: 1));

    await UserInfo.setToken(token);
    await UserInfo.setUserID(createdUser.id);
    await UserInfo.setUsername(createdUser.username);
    await UserInfo.setEmail(createdUser.email);
    await UserInfo.setLoginStatus(true);
    await UserInfo.setIsOnboarded(createdUser.isOnboarded);
    await UserInfo.setLastActive(DateTime.now().toIso8601String());

    // Simpan Token-Bound Biometric Session jika diaktifkan saat registrasi
    if (effectiveBio) {
      await UserInfo.setBiometricEnabled(true);
      if (effectiveFace) await UserInfo.setFaceIdEnabled(true);
      if (effectiveFp) await UserInfo.setFingerprintEnabled(true);
      await UserInfo.setBiometricUserId(createdUser.id);
      await UserInfo.setBiometricEmail(createdUser.email);
    }

    // 7. Simpan Token Sesi ke tabel user_tokens di Supabase jika tabel tersedia
    try {
      await SupabaseApiService.saveUserToken(
        userId: createdUser.id,
        authKey: token,
        expiresAt: expiresAt,
      );
    } catch (_) {}

    return {
      'success': true,
      'user': createdUser,
      'message': 'Registrasi Hunter berhasil! Bangkitkan kekuatan Anda sekarang.',
    };
  }

  // ============================================================================
  // LOGIN KREDENSIAL PENGGUNA (EMAIL / USERNAME & PASSWORD) - ALUR 2
  // ============================================================================

  /// Autentikasi Pengguna menggunakan Email atau Username dan Password
  static Future<Map<String, dynamic>> loginUser({
    required String email,
    required String password,
  }) async {
    final identifier = email.trim();
    if (identifier.isEmpty || password.isEmpty) {
      return {
        'success': false,
        'message': 'Email/Username dan Password wajib diisi.',
      };
    }

    // 1. Ambil data user dari Supabase
    UserModel? user;
    if (identifier.contains('@')) {
      user = await SupabaseApiService.getUserByEmail(identifier);
    } else {
      user = await SupabaseApiService.getUserByUsername(identifier);
    }
    user ??= await SupabaseApiService.getUserByEmail(identifier);

    if (user == null) {
      return {
        'success': false,
        'message': 'Akun Hunter tidak ditemukan. Pastikan email atau username Anda benar.',
      };
    }

    // 2. Cocokkan Hash Password SHA-256
    final inputHash = hashPassword(password);
    if (user.passwordHash.isNotEmpty && user.passwordHash != inputHash) {
      return {
        'success': false,
        'message': 'Password salah! Akses Sistem ditolak.',
      };
    }

    // 3. Buat Token Sesi Baru (Masa aktif 1 Jam / 60 Menit)
    final token = generateSessionToken(user.username);
    final expiresAt = DateTime.now().add(const Duration(hours: 1));

    // 4. Simpan status ke SharedPreferences (Lapisan 1)
    await UserInfo.setToken(token);
    await UserInfo.setUserID(user.id);
    await UserInfo.setUsername(user.username);
    await UserInfo.setEmail(user.email);
    await UserInfo.setLoginStatus(true);
    await UserInfo.setIsOnboarded(user.isOnboarded);
    await UserInfo.setLastActive(DateTime.now().toIso8601String());

    // Jika di database user sudah mengaktifkan biometrik, sinkronkan ke perangkat ini
    if (user.biometricEnabled) {
      await UserInfo.setBiometricEnabled(true);
      final hasFace = await UserInfo.getFaceIdEnabled();
      final hasFp = await UserInfo.getFingerprintEnabled();
      if (!hasFace && !hasFp) {
        await UserInfo.setFaceIdEnabled(true);
        await UserInfo.setFingerprintEnabled(true);
      }
      await UserInfo.setBiometricUserId(user.id);
      await UserInfo.setBiometricEmail(user.email);
    }

    // 5. Simpan Token Sesi ke Supabase user_tokens
    await SupabaseApiService.saveUserToken(
      userId: user.id,
      authKey: token,
      expiresAt: expiresAt,
    );

    // 6. Simpan cache ke Hive
    await SupabaseApiService.savePlayerCache(user);

    return {
      'success': true,
      'user': user,
      'message': 'Selamat datang kembali, Hunter ${user.username}!',
    };
  }

  // ============================================================================
  // LOGIN BIOMETRIK TERPISAH (FACE ID & FINGERPRINT QUICK LOGIN) - ALUR 2
  // ============================================================================

  /// Melakukan login instan khusus menggunakan Face ID / Face Recognition
  static Future<Map<String, dynamic>> loginFaceId({
    String? reason,
  }) async {
    final isFaceConfigured = await UserInfo.getFaceIdEnabled();
    final biometricUserId = await UserInfo.getBiometricUserId();

    if (!isFaceConfigured || biometricUserId == null || biometricUserId.isEmpty || biometricUserId == '0') {
      return {
        'success': false,
        'notConfigured': true,
        'message': 'PERINGATAN SISTEM: Face ID belum diaktifkan untuk akun Hunter Anda. Silakan login menggunakan Email & Password terlebih dahulu.',
      };
    }

    final authResult = await BiometricService.authenticateFace(
      reason: reason ?? 'Arahkan wajah Anda ke kamera depan untuk otorisasi Face ID LevMax',
    );

    if (!authResult.success) {
      return {
        'success': false,
        'message': authResult.errorMessage ?? 'Autentikasi Face ID dibatalkan.',
        'isLockedOut': authResult.isLockedOut,
      };
    }

    return await _finalizeBiometricSession(biometricUserId, 'Face ID');
  }

  /// Melakukan login instan khusus menggunakan Sensor Sidik Jari (Fingerprint)
  static Future<Map<String, dynamic>> loginFingerprint({
    String? reason,
  }) async {
    final isFpConfigured = await UserInfo.getFingerprintEnabled();
    final biometricUserId = await UserInfo.getBiometricUserId();

    if (!isFpConfigured || biometricUserId == null || biometricUserId.isEmpty || biometricUserId == '0') {
      return {
        'success': false,
        'notConfigured': true,
        'message': 'PERINGATAN SISTEM: Sensor Sidik Jari belum diaktifkan untuk akun Hunter Anda. Silakan login menggunakan Email & Password terlebih dahulu.',
      };
    }

    final authResult = await BiometricService.authenticateFingerprint(
      reason: reason ?? 'Tempelkan sidik jari Anda pada sensor untuk otorisasi Fingerprint LevMax',
    );

    if (!authResult.success) {
      return {
        'success': false,
        'message': authResult.errorMessage ?? 'Autentikasi Sidik Jari dibatalkan.',
        'isLockedOut': authResult.isLockedOut,
      };
    }

    return await _finalizeBiometricSession(biometricUserId, 'Fingerprint');
  }

  /// Melakukan login instan setelah pemindaian kamera wajah (Face Scan Kamera) berhasil
  static Future<Map<String, dynamic>> finalizeFaceScanLogin() async {
    final biometricUserId = await UserInfo.getBiometricUserId();
    if (biometricUserId == null || biometricUserId.isEmpty || biometricUserId == '0') {
      return {
        'success': false,
        'message': 'Akun Hunter belum terdaftar untuk pemindaian wajah.',
      };
    }
    return await finalizeBiometricSession(biometricUserId, 'Face Scan Kamera');
  }

  /// Melakukan login instan setelah pemindaian sidik jari (Fingerprint Scan) berhasil
  static Future<Map<String, dynamic>> finalizeFingerprintLogin() async {
    final biometricUserId = await UserInfo.getBiometricUserId();
    if (biometricUserId == null || biometricUserId.isEmpty || biometricUserId == '0') {
      return {
        'success': false,
        'message': 'Akun Hunter belum terdaftar untuk sensor sidik jari.',
      };
    }
    return await finalizeBiometricSession(biometricUserId, 'Fingerprint');
  }

  /// Mengatur status Fingerprint setelah verifikasi sensor berhasil
  static Future<Map<String, dynamic>> setFingerprintStatusForUser({
    required dynamic userId,
    required bool enable,
  }) async {
    if (enable) {
      await UserInfo.setFingerprintEnabled(true);
      await UserInfo.setBiometricUserId(userId);

      final currentEmail = await UserInfo.getEmail();
      if (currentEmail != null && currentEmail.isNotEmpty) {
        await UserInfo.setBiometricEmail(currentEmail);
      }
    } else {
      await UserInfo.disableFingerprint();
    }

    await _syncSupabaseBiometricStatus(userId);

    return {
      'success': true,
      'message': enable
          ? 'Sensor Sidik Jari berhasil diaktifkan!'
          : 'Sensor Sidik Jari telah dinonaktifkan.',
    };
  }

  /// Mengatur status Face ID setelah verifikasi kamera berhasil
  static Future<Map<String, dynamic>> setFaceIdStatusForUser({
    required dynamic userId,
    required bool enable,
  }) async {
    if (enable) {
      await UserInfo.setFaceIdEnabled(true);
      await UserInfo.setBiometricUserId(userId);

      final currentEmail = await UserInfo.getEmail();
      if (currentEmail != null && currentEmail.isNotEmpty) {
        await UserInfo.setBiometricEmail(currentEmail);
      }
    } else {
      await UserInfo.disableFaceId();
    }

    await _syncSupabaseBiometricStatus(userId);

    return {
      'success': true,
      'message': enable
          ? 'Face ID Kamera berhasil diaktifkan!'
          : 'Face ID telah dinonaktifkan.',
    };
  }

  /// Helper untuk memfinalisasi sesi token setelah autentikasi biometrik berhasil
  static Future<Map<String, dynamic>> _finalizeBiometricSession(dynamic biometricUserId, String methodLabel) =>
      finalizeBiometricSession(biometricUserId, methodLabel);

  static Future<Map<String, dynamic>> finalizeBiometricSession(dynamic biometricUserId, String methodLabel) async {
    UserModel? user;
    final cached = SupabaseApiService.getPlayerCache();
    if (cached != null && (cached.id == biometricUserId.toString() || cached.id == biometricUserId)) {
      user = cached;
    } else {
      user = await SupabaseApiService.getUserById(biometricUserId);
    }

    if (user == null) {
      final bioEmail = await UserInfo.getBiometricEmail();
      if (bioEmail != null && bioEmail.isNotEmpty) {
        user = await SupabaseApiService.getUserByEmail(bioEmail);
      }
    }

    if (user == null) {
      return {
        'success': false,
        'message': 'Profil Hunter tidak ditemukan. Silakan login manual dengan password.',
      };
    }

    final token = generateSessionToken(user.username);
    final expiresAt = DateTime.now().add(const Duration(hours: 1));

    await UserInfo.setToken(token);
    await UserInfo.setUserID(user.id);
    await UserInfo.setUsername(user.username);
    await UserInfo.setEmail(user.email);
    await UserInfo.setLoginStatus(true);
    await UserInfo.setIsOnboarded(user.isOnboarded);
    await UserInfo.updateLastActive();

    await SupabaseApiService.saveUserToken(
      userId: user.id,
      authKey: token,
      expiresAt: expiresAt,
    );

    await SupabaseApiService.savePlayerCache(user.copyWith(biometricEnabled: true));

    return {
      'success': true,
      'user': user,
      'message': 'Otorisasi $methodLabel berhasil. Selamat datang, Hunter ${user.username}!',
    };
  }

  /// Melakukan login instan menggunakan Face ID atau Fingerprint (Umum)
  static Future<Map<String, dynamic>> loginBiometric({
    String? reason,
  }) async {
    final isBiometricConfigured = await UserInfo.getBiometricEnabled();
    final biometricUserId = await UserInfo.getBiometricUserId();

    if (!isBiometricConfigured || biometricUserId == null || biometricUserId.isEmpty || biometricUserId == '0') {
      return {
        'success': false,
        'notConfigured': true,
        'message': 'PERINGATAN SISTEM: Data Biometrik belum terhubung ke akun Player. Silakan login menggunakan Email & Password terlebih dahulu.',
      };
    }

    final authResult = await BiometricService.authenticate(
      localizedReason: reason ?? 'Pindai Face ID atau Sidik Jari untuk otorisasi Hunter LevMax',
    );

    if (!authResult.success) {
      return {
        'success': false,
        'message': authResult.errorMessage ?? 'Autentikasi biometrik dibatalkan.',
        'isLockedOut': authResult.isLockedOut,
      };
    }

    return await _finalizeBiometricSession(biometricUserId, 'Biometrik');
  }

  // ============================================================================
  // PENGATURAN TOGGLE FACE ID & FINGERPRINT TERPISAH (PROFIL) - ALUR 4
  // ============================================================================

  /// Mengaktifkan atau menonaktifkan Face ID secara independen dengan verifikasi wajib
  static Future<Map<String, dynamic>> toggleFaceIdForUser({
    required int userId,
    required bool enable,
    String? localizedReason,
  }) async {
    final authResult = await BiometricService.authenticateFace(
      reason: localizedReason ?? (enable
          ? 'Pindai Face ID untuk mengaktifkan akses cepat biometrik wajah'
          : 'Konfirmasi Face ID untuk menonaktifkan fitur ini'),
    );

    if (!authResult.success) {
      return {
        'success': false,
        'message': authResult.errorMessage ?? 'Verifikasi Face ID dibatalkan.',
      };
    }

    if (enable) {
      await UserInfo.setFaceIdEnabled(true);
      await UserInfo.setBiometricUserId(userId);

      final currentEmail = await UserInfo.getEmail();
      if (currentEmail != null && currentEmail.isNotEmpty) {
        await UserInfo.setBiometricEmail(currentEmail);
      }
    } else {
      await UserInfo.disableFaceId();
    }

    await _syncSupabaseBiometricStatus(userId);

    return {
      'success': true,
      'message': enable
          ? 'Face ID / Biometrik Wajah berhasil diaktifkan!'
          : 'Face ID telah dinonaktifkan.',
    };
  }

  /// Mengaktifkan atau menonaktifkan Fingerprint secara independen dengan verifikasi wajib
  static Future<Map<String, dynamic>> toggleFingerprintForUser({
    required dynamic userId,
    required bool enable,
    String? localizedReason,
  }) async {
    final authResult = await BiometricService.authenticateFingerprint(
      reason: localizedReason ?? (enable
          ? 'Tempelkan sidik jari Anda untuk mengaktifkan akses cepat Fingerprint'
          : 'Konfirmasi sidik jari Anda untuk menonaktifkan fitur ini'),
    );

    if (!authResult.success) {
      return {
        'success': false,
        'message': authResult.errorMessage ?? 'Verifikasi sidik jari dibatalkan.',
      };
    }

    if (enable) {
      await UserInfo.setFingerprintEnabled(true);
      await UserInfo.setBiometricUserId(userId);

      final currentEmail = await UserInfo.getEmail();
      if (currentEmail != null && currentEmail.isNotEmpty) {
        await UserInfo.setBiometricEmail(currentEmail);
      }
    } else {
      await UserInfo.disableFingerprint();
    }

    await _syncSupabaseBiometricStatus(userId);

    return {
      'success': true,
      'message': enable
          ? 'Fingerprint / Sensor Sidik Jari berhasil diaktifkan!'
          : 'Fingerprint telah dinonaktifkan.',
    };
  }

  /// Helper untuk mensinkronisasi status umum biometric_enabled ke Supabase
  static Future<void> _syncSupabaseBiometricStatus(dynamic userId) async {
    final isAnyActive = await UserInfo.getBiometricEnabled();

    UserModel? user;
    if (userId != null && userId.toString().isNotEmpty && userId.toString() != '0') {
      user = await SupabaseApiService.getUserById(userId);
    }
    user ??= SupabaseApiService.getPlayerCache();

    if (user != null) {
      final updatedUser = user.copyWith(biometricEnabled: isAnyActive);
      await SupabaseApiService.savePlayerCache(updatedUser);

      if (updatedUser.id.isNotEmpty && updatedUser.id != '0') {
        await SupabaseApiService.updateUser(updatedUser);
      }
    }
  }

  /// Mengaktifkan atau menonaktifkan Face ID / Biometrik umum (Backward Compatibility)
  static Future<Map<String, dynamic>> toggleBiometricForUser({
    required dynamic userId,
    required bool enable,
    String? localizedReason,
  }) async {
    final authResult = await BiometricService.authenticate(
      localizedReason: localizedReason ?? (enable
          ? 'Pindai Face ID atau Sidik Jari untuk mengaktifkan login instan Hunter'
          : 'Konfirmasi biometrik Anda untuk menonaktifkan fitur ini'),
    );

    if (!authResult.success) {
      return {
        'success': false,
        'message': authResult.errorMessage ?? 'Verifikasi biometrik dibatalkan.',
      };
    }

    if (enable) {
      await UserInfo.setFaceIdEnabled(true);
      await UserInfo.setFingerprintEnabled(true);
      await UserInfo.setBiometricEnabled(true);
      await UserInfo.setBiometricUserId(userId);

      final currentEmail = await UserInfo.getEmail();
      if (currentEmail != null && currentEmail.isNotEmpty) {
        await UserInfo.setBiometricEmail(currentEmail);
      }
    } else {
      await UserInfo.disableBiometrics();
    }

    await _syncSupabaseBiometricStatus(userId);

    return {
      'success': true,
      'message': enable
          ? 'Face ID & Fingerprint berhasil dihubungkan ke akun Hunter!'
          : 'Biometrik telah dinonaktifkan.',
    };
  }

  // ============================================================================
  // LOGOUT (MENCABUT TOKEN & AMANKAN KREDENSIAL BIOMETRIK)
  // ============================================================================

  /// Logout Hunter: Menghapus token dari Supabase & mencabut sesi login aktif
  static Future<void> logout() async {
    try {
      final userId = await UserInfo.getUserID();
      final token = await UserInfo.getToken();

      if (userId != null && token != null) {
        await SupabaseApiService.deleteUserToken(userId: userId, authKey: token);
      }
    } catch (e) {
      debugPrint('Logout delete token error: $e');
    }

    // Mencabut token sesi aktif, mempertahankan biometric_user_id & biometric_email
    await UserInfo.logout();
  }

  // Forwarding aliases untuk backward-compatibility
  static Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    bool biometricEnabled = false,
  }) async {
    return registerUser(
      username: username,
      email: email,
      password: password,
      isBiometric: biometricEnabled,
    );
  }

  static Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    return loginUser(
      email: username,
      password: password,
    );
  }
}
