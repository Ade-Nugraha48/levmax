// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/services/auth_service.dart
// Deskripsi: Layanan Autentikasi Modern Solo Leveling - Enkripsi SHA-256 (Tanpa Firebase),
//            Biometrik Fingerprint & Face ID (Samsung Galaxy M31 / Android), 
//            REST API Supabase via package:http, & Manajemen Sesi SharedPreferences.
// ==============================================================================

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import '../helpers/user_info.dart';
import '../models/user_model.dart';
import 'supabase_api_service.dart';

class AuthService {
  // Instance resmi local_auth untuk pemindaian hardware biometrik Android
  static final LocalAuthentication _localAuth = LocalAuthentication();

  // ============================================================================
  // ENKRIPSI & KEAMANAN KRIPTOGRAFI (SHA-256)
  // ============================================================================

  /// Mengenkripsi password plaintext menjadi representasi hash SHA-256 (64 karakter heksadesimal).
  /// Sesuai standar industri: password mentah tidak pernah disimpan di database Supabase.
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
  // VERIFIKASI HARDWARE & AUTENTIKASI BIOMETRIK (local_auth)
  // ============================================================================

  /// Memeriksa ketersediaan hardware sensor biometrik (Fingerprint / Face ID) di perangkat
  static Future<bool> canAuthenticateWithBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck || isSupported;
    } catch (e) {
      debugPrint('canAuthenticateWithBiometrics error: $e');
      return false;
    }
  }

  /// Mendapatkan daftar tipe biometrik yang tersedia di perangkat (Fingerprint, Face, dll)
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  /// Meminta verifikasi fisik biometrik kepada Hunter melalui prompt sistem Android
  /// CATATAN: biometricOnly di-set false agar mendukung sensor Face Unlock (Class 2) & Fingerprint di Samsung M31
  static Future<bool> authenticateWithBiometrics({
    String reason = 'Gunakan sensor sidik jari atau Face ID untuk verifikasi otorisasi Hunter',
  }) async {
    try {
      final isAvailable = await canAuthenticateWithBiometrics();
      if (!isAvailable) return false;

      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,       // Menjaga dialog tetap aktif jika ada interupsi sistem
          biometricOnly: false,   // Mendukung Fingerprint & Face ID di berbagai versi Android
          useErrorDialogs: true,  // Tampilkan pesan dialog error bawaan Android jika gagal
        ),
      );
    } on PlatformException catch (e) {
      debugPrint('Biometric PlatformException: $e');
      return false;
    } catch (e) {
      debugPrint('Biometric general exception: $e');
      return false;
    }
  }

  /// Helper Reusable untuk Halaman Profil: Mengubah status toggle biometrik user
  /// Dilengkapi verifikasi sensor saat user mengaktifkannya (ON)
  static Future<Map<String, dynamic>> toggleBiometricForUser({
    required int userId,
    required bool enable,
    String? localizedReason,
  }) async {
    if (enable) {
      // 1. Validasi kemampuan perangkat fisik
      final isSupported = await canAuthenticateWithBiometrics();
      if (!isSupported) {
        return {
          'success': false,
          'message': 'Perangkat Anda tidak memiliki sensor biometrik yang aktif atau terdaftar.',
        };
      }

      // 2. Minta verifikasi sidik jari/wajah Hunter secara langsung
      final verified = await authenticateWithBiometrics(
        reason: localizedReason ?? 'Verifikasi sidik jari atau Face ID Anda untuk mengaktifkan fitur ini.',
      );

      if (!verified) {
        return {
          'success': false,
          'message': 'Verifikasi biometrik dibatalkan atau tidak cocok.',
        };
      }
    }

    // 3. Simpan perubahan ke SharedPreferences (Lapisan 1)
    await UserInfo.setBiometricEnabled(enable);

    // 4. Perbarui data ke Cache Hive dan Cloud Database Supabase
    UserModel? user;
    if (userId > 0) {
      user = await SupabaseApiService.getUserById(userId);
    }
    user ??= SupabaseApiService.getPlayerCache();

    if (user != null) {
      final updatedUser = user.copyWith(biometricEnabled: enable);
      // Simpan segera ke cache Hive lokal
      await SupabaseApiService.savePlayerCache(updatedUser);

      // Simpan ke Cloud Database Supabase jika terhubung
      if (updatedUser.id > 0) {
        await SupabaseApiService.updateUser(updatedUser);
      }
    }

    return {
      'success': true,
      'message': enable
          ? 'Login Biometrik berhasil diaktifkan!'
          : 'Login Biometrik telah dinonaktifkan.',
    };
  }

  // ============================================================================
  // REGISTRASI USER BARU (POST KE TABEL 'users' SUPABASE)
  // ============================================================================

  /// Mendaftarkan Hunter baru ke dalam Database Supabase via HTTP REST API
  static Future<Map<String, dynamic>> registerUser({
    required String username,
    required String email,
    required String password,
    bool isBiometric = false,
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

    // Validasi panjang username
    if (trimmedUsername.length < 3) {
      return {
        'success': false,
        'message': 'Username minimal terdiri dari 3 karakter.',
      };
    }

    // Validasi format email menggunakan Regular Expression
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(trimmedEmail)) {
      return {
        'success': false,
        'message': 'Format alamat email tidak valid.',
      };
    }

    // Validasi panjang password minimal 8 karakter (sesuai spesifikasi)
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

    // 4. Inisialisasi Objek Hunter Level 1 Rank F
    final tempId = DateTime.now().millisecondsSinceEpoch % 1000000;
    final newUser = UserModel.initial(
      id: tempId,
      username: trimmedUsername,
      email: trimmedEmail,
      passwordHash: hashedPassword,
      biometricEnabled: isBiometric,
    );

    // 5. Kirim HTTP POST ke Supabase REST API
    final createdUser = await SupabaseApiService.createUser(newUser);

    // 6. Buat Token Sesi dan simpan status lokal ke SharedPreferences
    final token = generateSessionToken(createdUser.username);
    final expiresAt = DateTime.now().add(const Duration(hours: 1));

    await UserInfo.setToken(token);
    await UserInfo.setUserID(createdUser.id);
    await UserInfo.setUsername(createdUser.username);
    await UserInfo.setEmail(createdUser.email);
    await UserInfo.setLoginStatus(true);
    await UserInfo.setIsOnboarded(createdUser.isOnboarded);
    await UserInfo.setBiometricEnabled(isBiometric);
    await UserInfo.setLastActive(DateTime.now().toIso8601String());

    // 7. Simpan Token Sesi ke tabel user_tokens di Supabase
    await SupabaseApiService.saveUserToken(
      userId: createdUser.id,
      authKey: token,
      expiresAt: expiresAt,
    );

    return {
      'success': true,
      'user': createdUser,
      'message': 'Registrasi Hunter berhasil! Bangkitkan kekuatan Anda sekarang.',
    };
  }

  // ============================================================================
  // LOGIN KREDENSIAL PENGGUNA (EMAIL / USERNAME & PASSWORD)
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

    // 1. Ambil data user dari Supabase (bisa mencari via Email atau Username)
    UserModel? user;
    if (identifier.contains('@')) {
      user = await SupabaseApiService.getUserByEmail(identifier);
    } else {
      user = await SupabaseApiService.getUserByUsername(identifier);
    }

    // Jika belum ditemukan dan input tidak mengandung @, coba fallback ke email
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
    // Jika user di database memiliki biometricEnabled = true, sinkronkan ke lokal
    if (user.biometricEnabled) {
      await UserInfo.setBiometricEnabled(true);
    }
    await UserInfo.setLastActive(DateTime.now().toIso8601String());

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
  // LOGIN BIOMETRIK (SIDIK JARI / FACE ID SCAN)
  // ============================================================================

  /// Melakukan login instan menggunakan sensor biometrik (Sidik Jari atau Face ID)
  static Future<Map<String, dynamic>> loginBiometric({
    int? userId,
    String? reason,
  }) async {
    // 1. Periksa ketersediaan hardware
    final canAuth = await canAuthenticateWithBiometrics();
    if (!canAuth) {
      return {
        'success': false,
        'message': 'Perangkat tidak memiliki sensor biometrik yang aktif.',
      };
    }

    // 2. Minta pemindaian sidik jari / Face ID
    final authOk = await authenticateWithBiometrics(
      reason: reason ?? 'Pindai sidik jari atau Face ID Anda untuk masuk ke LevMax',
    );

    if (!authOk) {
      return {
        'success': false,
        'message': 'Autentikasi biometrik dibatalkan atau tidak cocok.',
      };
    }

    // 3. Cari data profil Hunter dari Cache Hive, ID, atau identifier yang tersimpan di SharedPreferences
    UserModel? user;
    final cached = SupabaseApiService.getPlayerCache();
    if (cached != null) {
      user = cached;
    } else {
      final savedId = userId ?? await UserInfo.getUserID();
      if (savedId != null && savedId > 0) {
        user = await SupabaseApiService.getUserById(savedId);
      }
    }

    // Fallback: Jika cache belum ada, gunakan email/username tersimpan
    if (user == null) {
      final savedEmail = await UserInfo.getEmail();
      final savedUsername = await UserInfo.getUsername();
      if (savedEmail != null && savedEmail.isNotEmpty) {
        user = await SupabaseApiService.getUserByEmail(savedEmail);
      } else if (savedUsername != null && savedUsername.isNotEmpty) {
        user = await SupabaseApiService.getUserByUsername(savedUsername);
      }
    }

    if (user == null) {
      return {
        'success': false,
        'message': 'Data Hunter belum tersimpan di perangkat. Silakan login dengan password sekali terlebih dahulu.',
      };
    }

    // 4. Perbarui sesi aktif & token baru
    final token = generateSessionToken(user.username);
    final expiresAt = DateTime.now().add(const Duration(hours: 1));

    await UserInfo.setToken(token);
    await UserInfo.setUserID(user.id);
    await UserInfo.setUsername(user.username);
    await UserInfo.setEmail(user.email);
    await UserInfo.setLoginStatus(true);
    await UserInfo.setIsOnboarded(user.isOnboarded);
    await UserInfo.setBiometricEnabled(true);
    await UserInfo.updateLastActive();

    // 5. Simpan token baru ke Supabase
    await SupabaseApiService.saveUserToken(
      userId: user.id,
      authKey: token,
      expiresAt: expiresAt,
    );

    // 6. Simpan cache Player terbaru
    await SupabaseApiService.savePlayerCache(user.copyWith(biometricEnabled: true));

    return {
      'success': true,
      'user': user,
      'message': 'Autentikasi biometrik berhasil. Selamat datang, Hunter ${user.username}!',
    };
  }

  // ============================================================================
  // HELPER KOMPATIBILITAS (FORWARDING ALIASES)
  // ============================================================================

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

  /// Logout Hunter: menghapus token dari Supabase & mencabut sesi aktif SharedPreferences
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

    // Standar Industri: Cabut sesi aktif, jangan hapus flag biometrik yang sudah aktif di perangkat ini!
    await UserInfo.logout();
  }
}
