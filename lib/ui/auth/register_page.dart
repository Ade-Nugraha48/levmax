// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/ui/auth/register_page.dart
// Deskripsi: Layanan Registrasi Akun Hunter Enkripsi SHA-256 (FR-1.1)
//            dengan opsi verifikasi pemindaian biometrik instan pada saat pendaftaran.
// ==============================================================================

import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../onboarding/onboarding_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _biometricEnabled = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ============================================================================
  // LOGIKA VERIFIKASI BIOMETRIK SAAT CHECKBOX/SWITCH DICENTANG
  // ============================================================================
  Future<void> _handleBiometricToggle(bool value) async {
    // Jika user mematikan checkbox, langsung set false tanpa pemindaian
    if (!value) {
      setState(() {
        _biometricEnabled = false;
      });
      return;
    }

    // 1. Cek apakah perangkat mendukung sensor biometrik
    final isSupported = await AuthService.canAuthenticateWithBiometrics();
    if (!isSupported) {
      if (!mounted) return;
      _showWarningSnackBar(
        'Perangkat tidak mendukung sensor biometrik atau belum ada sidik jari/wajah yang didaftarkan di pengaturan Android.',
      );
      setState(() {
        _biometricEnabled = false;
      });
      return;
    }

    // 2. Panggil pemindai sidik jari / Face ID saat itu juga untuk verifikasi awal
    final authSuccess = await AuthService.authenticateWithBiometrics(
      reason: 'Verifikasi sensor biometrik Anda untuk mengaktifkan login instan Hunter',
    );

    if (!mounted) return;

    if (authSuccess) {
      setState(() {
        _biometricEnabled = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.black),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Sensor biometrik terverifikasi dan siap digunakan!',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF00E5FF),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else {
      setState(() {
        _biometricEnabled = false;
      });
      _showWarningSnackBar('Verifikasi biometrik dibatalkan atau tidak cocok.');
    }
  }

  // ============================================================================
  // LOGIKA SUBMIT REGISTRASI
  // ============================================================================
  Future<void> _handleRegister() async {
    FocusScope.of(context).unfocus();

    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await AuthService.registerUser(
      username: _usernameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      isBiometric: _biometricEnabled,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.verified, color: Colors.black),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  res['message'] ?? 'Hunter Berhasil Dibangkitkan!',
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

      // Setelah registrasi sukses, lanjut ke Onboarding Fisik BMI & Target Awal
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingPage()),
        (route) => false,
      );
    } else {
      setState(() {
        _errorMessage = res['message'] ?? 'Registrasi gagal diproses Sistem.';
      });
      _showErrorSnackBar(_errorMessage!);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: const Color(0xFFFF1744),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showWarningSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: const Color(0xFFFFA000),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        title: const Text('REKRUTMEN HUNTER'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF00E5FF)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              // Header Badge Solo Leveling
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7B1FA2).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF7B1FA2)),
                  ),
                  child: const Text(
                    'AWAKENING REGISTRATION',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                      color: Color(0xFF00E5FF),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Daftarkan Identitas Hunter Anda',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Sistem akan mencatat data Anda ke PostgreSQL Supabase & Rantai Blok Anti-Cheat',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 24),

              // Pesan Error jika ada
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
                    // Username Field
                    TextFormField(
                      controller: _usernameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Username Hunter',
                        labelStyle: const TextStyle(color: Color(0xFF00E5FF)),
                        prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF00E5FF)),
                        filled: true,
                        fillColor: const Color(0xFF131B2E),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                          return 'Username wajib diisi.';
                        }
                        if (value.trim().length < 3) {
                          return 'Username minimal 3 karakter.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Email Field
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Alamat Email',
                        labelStyle: const TextStyle(color: Color(0xFF00E5FF)),
                        prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF00E5FF)),
                        filled: true,
                        fillColor: const Color(0xFF131B2E),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                          return 'Email wajib diisi.';
                        }
                        final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                        if (!emailRegex.hasMatch(value.trim())) {
                          return 'Format alamat email tidak valid.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Password Field (Minimal 8 Karakter)
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Password (Minimal 8 Karakter)',
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
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                          return 'Password wajib diisi.';
                        }
                        if (value.length < 8) {
                          return 'Password minimal 8 karakter.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Confirm Password Field
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirm,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Konfirmasi Password',
                        labelStyle: const TextStyle(color: Color(0xFF00E5FF)),
                        prefixIcon: const Icon(Icons.lock_reset, color: Color(0xFF00E5FF)),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                            color: const Color(0xFF00E5FF),
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureConfirm = !_obscureConfirm;
                            });
                          },
                        ),
                        filled: true,
                        fillColor: const Color(0xFF131B2E),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                          return 'Konfirmasi password wajib diisi.';
                        }
                        if (value != _passwordController.text) {
                          return 'Konfirmasi password tidak cocok.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),

                    // Checkbox / Switch Biometrik dengan trigger verifikasi awal
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131B2E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _biometricEnabled
                              ? const Color(0xFF00E5FF)
                              : const Color(0xFF1E293B),
                          width: _biometricEnabled ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.fingerprint,
                            color: _biometricEnabled
                                ? const Color(0xFF00E5FF)
                                : Colors.grey,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Aktifkan Login Biometrik',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Memicu pemindaian sidik jari/wajah saat dicentang untuk verifikasi awal',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Checkbox(
                            value: _biometricEnabled,
                            activeColor: const Color(0xFF00E5FF),
                            checkColor: Colors.black,
                            onChanged: (val) => _handleBiometricToggle(val ?? false),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Tombol Submit Register
              ElevatedButton(
                onPressed: _isLoading ? null : _handleRegister,
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
                        'AWAKEN AS HUNTER (DAFTAR)',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                      ),
              ),
              const SizedBox(height: 20),

              // Link Kembali ke Login
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Sudah memiliki otorisasi? ',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text(
                      'MASUK KE SISTEM',
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
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
