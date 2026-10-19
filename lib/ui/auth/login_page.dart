// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/ui/auth/login_page.dart
// Deskripsi: Halaman Login Hunter Kredensial Enkripsi SHA-256 & Biometrik
//            dengan tombol terpisah untuk Sidik Jari & Face ID Scan.
// ==============================================================================

import 'package:flutter/material.dart';
import '../../helpers/user_info.dart';
import '../../services/auth_service.dart';
import '../onboarding/onboarding_page.dart';
import '../main_navigation_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailOrUsernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _prefillSavedIdentifier();
  }

  /// Mengisi otomatis email atau username yang terakhir diingat di perangkat
  Future<void> _prefillSavedIdentifier() async {
    final savedEmail = await UserInfo.getEmail();
    final savedUsername = await UserInfo.getUsername();
    if (mounted) {
      if (savedEmail != null && savedEmail.isNotEmpty) {
        _emailOrUsernameController.text = savedEmail;
      } else if (savedUsername != null && savedUsername.isNotEmpty) {
        _emailOrUsernameController.text = savedUsername;
      }
    }
  }

  @override
  void dispose() {
    _emailOrUsernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ============================================================================
  // LOGIKA LOGIN KREDENSIAL (EMAIL/USERNAME + PASSWORD)
  // ============================================================================
  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();

    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await AuthService.loginUser(
      email: _emailOrUsernameController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (res['success'] == true) {
      final user = res['user'];

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.black),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  res['message'] ?? 'Otorisasi Diterima! Selamat datang.',
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF00E5FF),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

      if (user != null && user.isOnboarded) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigationPage()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const OnboardingPage()),
        );
      }
    } else {
      setState(() {
        _errorMessage = res['message'] ?? 'Gagal masuk ke Sistem.';
      });

      _showErrorSnackBar(_errorMessage!);
    }
  }

  // ============================================================================
  // LOGIKA LOGIN BIOMETRIK (SIDIK JARI / FACE ID SCAN)
  // ============================================================================
  Future<void> _handleBiometricAuth({required String mode}) async {
    FocusScope.of(context).unfocus();

    // 1. Cek apakah perangkat mendukung hardware biometrik
    final canCheckHardware = await AuthService.canAuthenticateWithBiometrics();
    final isBiometricConfigured = await UserInfo.getBiometricEnabled();

    // SKENARIO A: User belum pernah mengatur/mengaktifkan biometrik di perangkat
    if (!isBiometricConfigured || !canCheckHardware) {
      if (!mounted) return;
      _showBiometricNotConfiguredDialog();
      return;
    }

    // SKENARIO B: Biometrik sudah aktif dan terkonfigurasi
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final reason = mode == 'face'
        ? 'Arahkan wajah Anda ke kamera untuk pemindaian Face ID Hunter'
        : 'Tempelkan sidik jari Anda pada sensor untuk otorisasi Hunter';

    final result = await AuthService.loginBiometric(reason: reason);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result['success'] == true) {
      final user = result['user'];

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(mode == 'face' ? Icons.face : Icons.fingerprint, color: Colors.black),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  result['message'] ?? 'Otorisasi Biometrik Berhasil!',
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF00E5FF),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

      if (user != null && user.isOnboarded) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigationPage()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const OnboardingPage()),
        );
      }
    } else {
      _showErrorSnackBar(result['message'] ?? 'Autentikasi biometrik dibatalkan.');
    }
  }

  // Dialog visual khusus untuk Skenario A
  void _showBiometricNotConfiguredDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131B2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF00E5FF), width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.fingerprint, color: Color(0xFF00E5FF), size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Biometrik Belum Aktif',
                style: TextStyle(
                  color: Color(0xFF00E5FF),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          'Biometrik belum dikonfigurasi. Silakan login menggunakan password terlebih dahulu, lalu aktifkan fitur ini melalui menu Profil.',
          style: TextStyle(color: Colors.white, fontSize: 13, height: 1.5),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('MENGERTI', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFFF1744),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF131B2E),
                      border: Border.all(color: const Color(0xFF00E5FF), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      size: 44,
                      color: Color(0xFF00E5FF),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                const Text(
                  'LEVMAX SYSTEM',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4.0,
                    color: Color(0xFF00E5FF),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Verifikasi Otorisasi Hunter Solo Leveling',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 32),

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF1744).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFF1744)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Color(0xFFFF1744), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Color(0xFFFF1744), fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Field Email atau Username
                      TextFormField(
                        controller: _emailOrUsernameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Email atau Username Hunter',
                          labelStyle: const TextStyle(color: Color(0xFF00E5FF)),
                          prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF00E5FF)),
                          filled: true,
                          fillColor: const Color(0xFF131B2E),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF1E293B)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF1E293B)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF00E5FF), width: 2),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Harap masukkan email atau username Hunter.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Field Password dengan Hide/Show Toggle
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Password Akses (SHA-256)',
                          labelStyle: const TextStyle(color: Color(0xFF00E5FF)),
                          prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF00E5FF)),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: const Color(0xFF00E5FF),
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          filled: true,
                          fillColor: const Color(0xFF131B2E),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF1E293B)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF1E293B)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF00E5FF), width: 2),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Harap masukkan password.';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Tombol Submit Login Utama
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5FF),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 6,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                        )
                      : const Text(
                          'ENTER THE SYSTEM (LOGIN)',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                        ),
                ),
                const SizedBox(height: 18),

                // PEMISAH ATAU (OR)
                Row(
                  children: [
                    const Expanded(child: Divider(color: Color(0xFF1E293B), thickness: 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'ATAU OTORISASI CEPAT',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider(color: Color(0xFF1E293B), thickness: 1)),
                  ],
                ),
                const SizedBox(height: 18),

                // BARIS TOMBOL BIOMETRIK: SIDIK JARI & FACE ID SCAN
                Row(
                  children: [
                    // 1. Tombol Sidik Jari
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : () => _handleBiometricAuth(mode: 'fingerprint'),
                        icon: const Icon(Icons.fingerprint, color: Color(0xFF00E5FF), size: 22),
                        label: const Text(
                          'SIDIK JARI',
                          style: TextStyle(
                            color: Color(0xFF00E5FF),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF00E5FF), width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // 2. Tombol Face ID Scan
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : () => _handleBiometricAuth(mode: 'face'),
                        icon: const Icon(Icons.face_unlock_outlined, color: Color(0xFFD500F9), size: 22),
                        label: const Text(
                          'FACE ID SCAN',
                          style: TextStyle(
                            color: Color(0xFFD500F9),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFD500F9), width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Link Navigasi ke Halaman Registrasi
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Belum memiliki otorisasi Hunter? ',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const RegisterPage()),
                        );
                      },
                      child: const Text(
                        'DAFTAR SEKARANG',
                        style: TextStyle(
                          color: Color(0xFF00E5FF),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
