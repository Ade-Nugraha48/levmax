// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/services/auth_service.dart
// Deskripsi: Layanan Autentikasi Enkripsi SHA-256 (Tanpa Firebase),
//            Biometrik Fingerprint/Face ID, & Manajemen Sesi Sesuai FR-1.1 s.d. FR-1.5
// ==============================================================================

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import '../helpers/user_info.dart';
import '../models/user_model.dart';
import 'supabase_api_service.dart';

class AuthService {
  static final LocalAuthentication _localAuth = LocalAuthentication();

  /// Enkripsi Password Plaintext menggunakan algoritma SHA-256
  static String hashPassword(String password) {
    final bytes = utf8.encode(password.trim());
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Menghasilkan Token Sesi Acak Terenkripsi SHA-256
  static String generateSessionToken(String username) {
    final salt = '${DateTime.now().microsecondsSinceEpoch}_$username';
    final bytes = utf8.encode(salt);
    return sha256.convert(bytes).toString();
  }

  // ==========================================================================
  // AUTENTIKASI BIOMETRIK (local_auth)
  // ==========================================================================

  /// Memeriksa apakah perangkat mendukung sensor biometrik
  static Future<bool> canAuthenticateWithBiometrics() async {
    try {
      final canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return canAuthenticateWithBiometrics || isDeviceSupported;
    } catch (_) {
      return false;
    }
  }

  /// Meminta verifikasi sidik jari atau Face ID kepada pengguna
  static Future<bool> authenticateWithBiometrics({
    String reason = 'Gunakan biometrik untuk membuka Status Window Hunter Anda',
  }) async {
    try {
      final isAvailable = await canAuthenticateWithBiometrics();
      if (!isAvailable) return false;

      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  // ==========================================================================
  // REGISTRASI & LOGIN
  // ==========================================================================

  /// Registrasi Akun Baru (FR-1.1)
  static Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    bool biometricEnabled = false,
  }) async {
    final trimmedUsername = username.trim();
    final trimmedEmail = email.trim();

    if (trimmedUsername.isEmpty || trimmedEmail.isEmpty || password.isEmpty) {
      return {'success': false, 'message': 'Semua kolom input wajib diisi.'};
    }

    if (password.length < 6) {
      return {'success': false, 'message': 'Password minimal terdiri dari 6 karakter.'};
    }

    // Periksa apakah username atau email sudah terdaftar
    final existingUser = await SupabaseApiService.getUserByUsername(trimmedUsername);
    if (existingUser != null) {
      return {'success': false, 'message': 'Username "$trimmedUsername" sudah digunakan Hunter lain.'};
    }

    final existingEmail = await SupabaseApiService.getUserByEmail(trimmedEmail);
    if (existingEmail != null) {
      return {'success': false, 'message': 'Email "$trimmedEmail" sudah terdaftar di sistem.'};
    }

    // Enkripsi password SHA-256
    final hashedPassword = hashPassword(password);

    // Inisialisasi Player Level 1 Rank F
    final initialId = DateTime.now().millisecondsSinceEpoch % 1000000;
    final newUser = UserModel.initial(
      id: initialId,
      username: trimmedUsername,
      email: trimmedEmail,
      passwordHash: hashedPassword,
      biometricEnabled: biometricEnabled,
    );

    // Simpan ke Supabase & Cache Hive
    final createdUser = await SupabaseApiService.createUser(newUser);

    // Buat token sesi
    final token = generateSessionToken(createdUser.username);
    final expiresAt = DateTime.now().add(const Duration(hours: 1));

    // Simpan Lapisan 1 SharedPreferences
    await UserInfo.setToken(token);
    await UserInfo.setUserID(createdUser.id);
    await UserInfo.setUsername(createdUser.username);
    await UserInfo.setEmail(createdUser.email);
    await UserInfo.setLoginStatus(true);
    await UserInfo.setIsOnboarded(createdUser.isOnboarded);
    await UserInfo.setBiometricEnabled(createdUser.biometricEnabled);
    await UserInfo.setLastActive(DateTime.now().toIso8601String());

    // Simpan token ke Supabase user_tokens
    await SupabaseApiService.saveUserToken(
      userId: createdUser.id,
      authKey: token,
      expiresAt: expiresAt,
    );

    return {'success': true, 'user': createdUser, 'message': 'Registrasi Hunter berhasil! Bangkitkan kekuatan Anda.'};
  }

  /// Login Kredensial Pengguna (FR-1.2)
  static Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final trimmedUsername = username.trim();
    if (trimmedUsername.isEmpty || password.isEmpty) {
      return {'success': false, 'message': 'Username dan password wajib diisi.'};
    }

    // Ambil data user dari Supabase (atau fallback Hive)
    final user = await SupabaseApiService.getUserByUsername(trimmedUsername);
    if (user == null) {
      return {'success': false, 'message': 'Akun Hunter tidak ditemukan. Silakan registrasi terlebih dahulu.'};
    }

    // Cocokkan hash password SHA-256
    final inputHash = hashPassword(password);
    if (user.passwordHash.isNotEmpty && user.passwordHash != inputHash) {
      return {'success': false, 'message': 'Password salah! Akses Sistem ditolak.'};
    }

    // Buat token sesi 1 jam
    final token = generateSessionToken(user.username);
    final expiresAt = DateTime.now().add(const Duration(hours: 1));

    // Simpan data ke SharedPreferences (Lapisan 1)
    await UserInfo.setToken(token);
    await UserInfo.setUserID(user.id);
    await UserInfo.setUsername(user.username);
    await UserInfo.setEmail(user.email);
    await UserInfo.setLoginStatus(true);
    await UserInfo.setIsOnboarded(user.isOnboarded);
    await UserInfo.setBiometricEnabled(user.biometricEnabled);
    await UserInfo.setLastActive(DateTime.now().toIso8601String());

    // Simpan token ke Supabase
    await SupabaseApiService.saveUserToken(
      userId: user.id,
      authKey: token,
      expiresAt: expiresAt,
    );

    // Perbarui cache Hive
    await SupabaseApiService.savePlayerCache(user);

    return {'success': true, 'user': user, 'message': 'Selamat datang kembali, Hunter ${user.username}!'};
  }

  /// Logout (FR-1.5): Hapus sesi SharedPreferences & Token Supabase
  static Future<void> logout() async {
    final userId = await UserInfo.getUserID();
    final token = await UserInfo.getToken();

    if (userId != null && token != null) {
      await SupabaseApiService.deleteUserToken(userId: userId, authKey: token);
    }

    await UserInfo.logout();
  }
}
