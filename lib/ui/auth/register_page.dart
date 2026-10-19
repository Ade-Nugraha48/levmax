// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/ui/auth/register_page.dart
// Deskripsi: Layanan Registrasi Akun Hunter Enkripsi SHA-256 (Alur 1)
//            dengan opsi aktivasi Face ID / Biometrik & penanganan NotEnrolled dialog.
// ==============================================================================

import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/biometric_service.dart';
import '../onboarding/onboarding_page.dart';
import 'face_scan_camera_page.dart';

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
  bool _faceIdEnabled = false;
  bool _fingerprintEnabled = false;
  bool _isLoading = false;
  String? _errorMessage;

  BiometricCapability? _capability;

  @override
  void initState() {
    super.initState();
    _detectBiometricCapability();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _detectBiometricCapability() async {
    final cap = await BiometricService.checkCapability();
    if (mounted) {
      setState(() {
        _capability = cap;
      });
    }
  }

  // ============================================================================
  // LOGIKA SUBMIT REGISTRASI DENGAN VERIFIKASI FACE ID & FINGERPRINT (ALUR 1)
  // ============================================================================
  Future<void> _handleRegister() async {
    FocusScope.of(context).unfocus();

    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      return;
    }

    bool finalFaceChoice = _faceIdEnabled;
    bool finalFpChoice = _fingerprintEnabled;

    // Jika user mengaktifkan Face ID, buka kamera depan untuk Face Scan
    if (_faceIdEnabled) {
      final scanSuccess = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => const FaceScanCameraPage(
            mode: FaceScanMode.register,
            title: 'REGISTRASI WAJAH HUNTER',
            subtitle: 'Pindai wajah Anda melalui kamera depan HP Samsung',
          ),
        ),
      );

      if (scanSuccess != true) {
        if (!mounted) return;
        final continueWithout = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF131B2E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Face Scan Dibatalkan', style: TextStyle(color: Color(0xFFFFA000))),
            content: const Text('Pemindaian wajah dibatalkan. Apakah Anda ingin tetap melanjutkan registrasi tanpa mengaktifkan Face ID?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('BATAL', style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E5FF), foregroundColor: Colors.black),
                child: const Text('LANJUTKAN', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
        if (continueWithout != true) return;
        finalFaceChoice = false;
      }
    }

    // Jika user mengaktifkan Fingerprint, verifikasi sidik jari
    if (_fingerprintEnabled && finalFaceChoice == false) {
      // Jika Face ID belum/tidak diverifikasi, verifikasi Fingerprint
      final authResult = await BiometricService.authenticateFingerprint(
        reason: 'Verifikasi sidik jari untuk mendaftarkan otorisasi Fingerprint Hunter',
      );

      if (!authResult.success) {
        if (!mounted) return;
        final continueWithout = await _showBiometricFailedDialog(authResult, 'Fingerprint');
        if (continueWithout != true) {
          return;
        }
        finalFpChoice = false;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await AuthService.registerUser(
      username: _usernameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      isFaceId: finalFaceChoice,
      isFingerprint: finalFpChoice,
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

  /// Dialog penanganan saat verifikasi Face ID atau Fingerprint gagal / NotEnrolled
  Future<bool?> _showBiometricFailedDialog(BiometricAuthResult result, String methodName) {
    String message = result.errorMessage ?? 'Verifikasi biometrik tidak berhasil.';
    if (result.isNotEnrolled) {
      message = 'Sensor $methodName belum didaftarkan di Pengaturan HP Samsung Anda.';
    }

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131B2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFFFA000), width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFFFA000), size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$methodName Belum Terverifikasi',
                style: const TextStyle(color: Color(0xFFFFA000), fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Text(
          '$message\n\nApakah Anda ingin tetap melanjutkan pendaftaran akun tanpa mengaktifkan $methodName untuk saat ini?',
          style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('BATAL', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
            ),
            child: const Text('LANJUTKAN', style: TextStyle(fontWeight: FontWeight.bold)),
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
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: const Color(0xFFFF1744),
        behavior: SnackBarBehavior.floating,
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

                    // Switch 1: Opsi Face ID (Jika didukung hardware)
                    if (_capability?.hasFace ?? true)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF131B2E),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _faceIdEnabled ? const Color(0xFF00E5FF) : const Color(0xFF1E293B),
                            width: _faceIdEnabled ? 1.5 : 1.0,
                          ),
                        ),
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          secondary: Icon(
                            Icons.face_unlock_outlined,
                            color: _faceIdEnabled ? const Color(0xFF00E5FF) : Colors.grey,
                            size: 26,
                          ),
                          title: const Text(
                            'Aktifkan Face ID untuk Akses Cepat',
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Verifikasi wajah saat menekan tombol Daftar',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
                          ),
                          activeThumbColor: const Color(0xFF00E5FF),
                          value: _faceIdEnabled,
                          onChanged: (val) {
                            setState(() {
                              _faceIdEnabled = val;
                            });
                          },
                        ),
                      ),
                    if (_capability?.hasFace ?? true) const SizedBox(height: 12),

                    // Switch 2: Opsi Fingerprint (Jika didukung hardware)
                    if (_capability?.hasFingerprint ?? true)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF131B2E),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _fingerprintEnabled ? const Color(0xFF00E5FF) : const Color(0xFF1E293B),
                            width: _fingerprintEnabled ? 1.5 : 1.0,
                          ),
                        ),
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          secondary: Icon(
                            Icons.fingerprint,
                            color: _fingerprintEnabled ? const Color(0xFF00E5FF) : Colors.grey,
                            size: 26,
                          ),
                          title: const Text(
                            'Aktifkan Fingerprint untuk Akses Cepat',
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Verifikasi sidik jari saat menekan tombol Daftar',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
                          ),
                          activeThumbColor: const Color(0xFF00E5FF),
                          value: _fingerprintEnabled,
                          onChanged: (val) {
                            setState(() {
                              _fingerprintEnabled = val;
                            });
                          },
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

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
