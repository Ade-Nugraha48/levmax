// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/services/biometric_service.dart
// Deskripsi: Layanan Hardware Biometrik Tingkat Produksi - Deteksi Cerdas
//            Face ID (Weak/Class 2 Samsung M31) & Fingerprint (Strong/Class 3),
//            Eksekusi Autentikasi Aman, & Translasi Error Komprehensif.
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;

/// Model representasi kemampuan hardware biometrik pada perangkat fisik
class BiometricCapability {
  final bool hasBiometrics;
  final List<BiometricType> availableTypes;
  final bool hasFace;
  final bool hasFingerprint;

  BiometricCapability({
    required this.hasBiometrics,
    required this.availableTypes,
    required this.hasFace,
    required this.hasFingerprint,
  });

  /// Label UI adaptif sesuai perangkat pengguna
  String get displayLabel {
    if (!hasBiometrics) return 'Biometrik Tidak Tersedia';
    if (hasFace && hasFingerprint) return 'Face ID / Biometrik Sistem';
    if (hasFace) return 'Face ID / Biometrik Wajah';
    if (hasFingerprint) return 'Fingerprint';
    return 'Autentikasi Biometrik';
  }

  /// Ikon UI adaptif
  IconData get displayIcon {
    if (hasFace) return Icons.face_unlock_outlined;
    if (hasFingerprint) return Icons.fingerprint;
    return Icons.security;
  }
}

/// Model hasil autentikasi biometrik dengan rincian edge cases
class BiometricAuthResult {
  final bool success;
  final String? errorMessage;
  final String? errorCode;
  final bool isNotEnrolled;
  final bool isLockedOut;
  final bool isPermanentlyLockedOut;
  final bool isPasscodeNotSet;
  final bool isCancelled;

  const BiometricAuthResult({
    required this.success,
    this.errorMessage,
    this.errorCode,
    this.isNotEnrolled = false,
    this.isLockedOut = false,
    this.isPermanentlyLockedOut = false,
    this.isPasscodeNotSet = false,
    this.isCancelled = false,
  });

  factory BiometricAuthResult.ok() {
    return const BiometricAuthResult(success: true);
  }

  factory BiometricAuthResult.error(
    String message, {
    String? errorCode,
    bool isNotEnrolled = false,
    bool isLockedOut = false,
    bool isPermanentlyLockedOut = false,
    bool isPasscodeNotSet = false,
    bool isCancelled = false,
  }) {
    return BiometricAuthResult(
      success: false,
      errorMessage: message,
      errorCode: errorCode,
      isNotEnrolled: isNotEnrolled,
      isLockedOut: isLockedOut,
      isPermanentlyLockedOut: isPermanentlyLockedOut,
      isPasscodeNotSet: isPasscodeNotSet,
      isCancelled: isCancelled,
    );
  }
}

class BiometricService {
  static final LocalAuthentication _localAuth = LocalAuthentication();

  // ============================================================================
  // DETEKSI HARDWARE & SENSOR (Samsung Galaxy M31 / Android)
  // ============================================================================

  /// Memeriksa apakah perangkat memiliki sensor biometrik aktif & didukung OS
  static Future<bool> canAuthenticate() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck || isSupported;
    } catch (e) {
      debugPrint('Biometric canAuthenticate error: $e');
      return false;
    }
  }

  /// Deteksi cerdas ketersediaan Face ID dan Fingerprint di perangkat
  /// Pada Samsung Galaxy M31: Face Recognition diklasifikasikan sebagai BiometricType.weak
  static Future<BiometricCapability> checkCapability() async {
    final supported = await canAuthenticate();
    if (!supported) {
      return BiometricCapability(
        hasBiometrics: false,
        availableTypes: [],
        hasFace: false,
        hasFingerprint: false,
      );
    }

    try {
      final types = await _localAuth.getAvailableBiometrics();

      // Face Recognition di Samsung Galaxy M31 masuk ke tipe .face atau .weak
      final hasFace =
          types.contains(BiometricType.face) ||
          types.contains(BiometricType.weak);
      final hasFingerprint =
          types.contains(BiometricType.fingerprint) ||
          types.contains(BiometricType.strong);

      return BiometricCapability(
        hasBiometrics: types.isNotEmpty || supported,
        availableTypes: types,
        hasFace: hasFace,
        hasFingerprint: hasFingerprint,
      );
    } catch (e) {
      debugPrint('Biometric checkCapability error: $e');
      return BiometricCapability(
        hasBiometrics: supported,
        availableTypes: [],
        hasFace: false,
        hasFingerprint: true, // Asumsi fallback umum Android
      );
    }
  }

  // ============================================================================
  // EKSEKUSI PEMINDAIAN BIOMETRIK & TRANSLASI ERROR EDGE CASES
  // ============================================================================

  /// Menjalankan pemindaian khusus Face ID / Face Recognition
  static Future<BiometricAuthResult> authenticateFace({String? reason}) async {
    return authenticate(
      localizedReason:
          reason ??
          'Arahkan wajah Anda ke kamera depan untuk Face Recognition LevMax',
    );
  }

  /// Menjalankan pemindaian khusus Fingerprint / Sensor Sidik Jari
  static Future<BiometricAuthResult> authenticateFingerprint({
    String? reason,
  }) async {
    return authenticate(
      localizedReason:
          reason ??
          'Tempelkan sidik jari Anda pada sensor untuk otorisasi Hunter LevMax',
    );
  }

  /// Menjalankan pemindaian wajah atau sidik jari dengan penanganan lengkap kode error Android
  static Future<BiometricAuthResult> authenticate({
    required String localizedReason,
  }) async {
    final canAuth = await canAuthenticate();
    if (!canAuth) {
      return BiometricAuthResult.error(
        'Perangkat ini tidak memiliki sensor biometrik yang kompatibel.',
        errorCode: auth_error.notAvailable,
      );
    }

    try {
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          // KRUSIAL untuk Samsung M31:
          // biometricOnly di-set false agar BiometricPrompt mengizinkan sensor Class 2 / Weak (Face Unlock 2D)
          biometricOnly: false,
          stickyAuth:
              true, // Mencegah interupsi saat aplikasi kehilangan fokus sejenak
          useErrorDialogs: true, // Memunculkan dialog sistem bawaan Android jika sensor gagal
        ),
      );

      if (didAuthenticate) {
        return BiometricAuthResult.ok();
      } else {
        return BiometricAuthResult.error(
          'Pemindaian biometrik dibatalkan oleh pengguna.',
          isCancelled: true,
        );
      }
    } on PlatformException catch (e) {
      debugPrint(
        'Biometric PlatformException caught: code=${e.code}, msg=${e.message}',
      );

      switch (e.code) {
        case auth_error.notAvailable:
          return BiometricAuthResult.error(
            'Perangkat ini tidak memiliki sensor biometrik yang kompatibel.',
            errorCode: e.code,
          );

        case auth_error.notEnrolled:
          return BiometricAuthResult.error(
            'Anda belum mendaftarkan Face Recognition atau Sidik Jari di Pengaturan HP Samsung Anda.',
            errorCode: e.code,
            isNotEnrolled: true,
          );

        case auth_error.passcodeNotSet:
          return BiometricAuthResult.error(
            'Harap atur PIN/Pola kunci layar HP Anda terlebih dahulu sebelum mengaktifkan Face ID.',
            errorCode: e.code,
            isPasscodeNotSet: true,
          );

        case auth_error.lockedOut:
          return BiometricAuthResult.error(
            'Pemindaian wajah dibekukan sementara karena terlalu banyak percobaan. Coba lagi dalam 30 detik atau gunakan Password.',
            errorCode: e.code,
            isLockedOut: true,
          );

        case auth_error.permanentlyLockedOut:
          return BiometricAuthResult.error(
            'Biometrik terkunci penuh oleh sistem Android. Silakan masuk menggunakan Password.',
            errorCode: e.code,
            isPermanentlyLockedOut: true,
          );

        default:
          final msg = e.message?.toLowerCase() ?? '';
          if (msg.contains('cancel') || msg.contains('user')) {
            return BiometricAuthResult.error(
              'Pemindaian biometrik dibatalkan oleh pengguna.',
              errorCode: e.code,
              isCancelled: true,
            );
          }
          return BiometricAuthResult.error(
            'Terjadi kendala pada sensor biometrik: ${e.message ?? 'Coba lagi beberapa saat.'}',
            errorCode: e.code,
          );
      }
    } catch (e) {
      debugPrint('Biometric unknown error: $e');
      return BiometricAuthResult.error(
        'Gagal memverifikasi biometrik. Silakan gunakan password.',
      );
    }
  }
}
