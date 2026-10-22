// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/ui/auth/register_page.dart
// Deskripsi: Layanan Registrasi Akun Hunter (Enkripsi SHA-256 & Supabase Auth)
//            dengan Biometric Setup Langsung (Face ID & Fingerprint via local_auth)
//            dan Redirect ke LoginPage setelah pendaftaran berhasil.
// ==============================================================================

import 'package:flutter/material.dart';
import '../../helpers/levmax_theme.dart';
import '../../helpers/user_info.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/biometric_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // Form Controllers
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // State Keamanan & Visibilitas Password
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  // Biometric Setup State (local_auth Langsung di Registrasi)
  bool _faceIdVerified = false;
  bool _fingerprintVerified = false;
  BiometricCapability? _capability;

  // Animasi Glitch / Pulse HUD
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _detectBiometrics();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Memeriksa ketersediaan hardware biometrik di perangkat pengguna
  Future<void> _detectBiometrics() async {
    final cap = await BiometricService.checkCapability();
    if (mounted) {
      setState(() {
        _capability = cap;
      });
    }
  }

  // ============================================================================
  // BIOMETRIC VERIFICATION (local_auth On-The-Spot Verification)
  // ============================================================================

  /// Menjalankan verifikasi Face ID langsung di halaman registrasi
  Future<void> _setupFaceId() async {
    FocusScope.of(context).unfocus();

    if (_faceIdVerified) {
      // Toggle off jika user ingin membatalkan
      setState(() {
        _faceIdVerified = false;
      });
      await UserInfo.disableFaceId();
      _showSnack(
        'Face ID dinonaktifkan untuk registrasi.',
        isError: false,
      );
      return;
    }

    final hasHardware = _capability?.hasBiometrics ?? true;
    if (!hasHardware) {
      _showSnack('Sensor biometrik tidak didukung pada perangkat ini.', isError: true);
      return;
    }

    try {
      final result = await BiometricService.authenticateFace(
        reason: 'Pindai wajah Anda untuk mengaktifkan Face ID Hunter LevMax',
      );

      if (result.success) {
        setState(() {
          _faceIdVerified = true;
        });

        // Simpan preferensi langsung ke Hive authBox
        await UserInfo.setFaceIdEnabled(true);
        await UserInfo.setBiometricEnabled(true);

        _showSnack(
          'Face ID Berhasil Diverifikasi & Diaktifkan!',
          isSuccess: true,
        );
      } else {
        _showSnack(
          result.errorMessage ?? 'Verifikasi Face ID dibatalkan atau tidak cocok.',
          isError: true,
        );
      }
    } catch (e) {
      _showSnack('Gagal menginisialisasi sensor Face ID: $e', isError: true);
    }
  }

  /// Menjalankan verifikasi Fingerprint langsung di halaman registrasi
  Future<void> _setupFingerprint() async {
    FocusScope.of(context).unfocus();

    if (_fingerprintVerified) {
      // Toggle off jika user ingin membatalkan
      setState(() {
        _fingerprintVerified = false;
      });
      await UserInfo.disableFingerprint();
      _showSnack(
        'Fingerprint dinonaktifkan untuk registrasi.',
        isError: false,
      );
      return;
    }

    final hasHardware = _capability?.hasBiometrics ?? true;
    if (!hasHardware) {
      _showSnack('Sensor fingerprint tidak didukung pada perangkat ini.', isError: true);
      return;
    }

    try {
      final result = await BiometricService.authenticateFingerprint(
        reason: 'Tempelkan sidik jari pada sensor untuk mendaftarkan Fingerprint Hunter',
      );

      if (result.success) {
        setState(() {
          _fingerprintVerified = true;
        });

        // Simpan preferensi langsung ke Hive authBox
        await UserInfo.setFingerprintEnabled(true);
        await UserInfo.setBiometricEnabled(true);

        _showSnack(
          'Sensor Sidik Jari Berhasil Diverifikasi & Terhubung!',
          isSuccess: true,
        );
      } else {
        _showSnack(
          result.errorMessage ?? 'Verifikasi sidik jari dibatalkan atau gagal.',
          isError: true,
        );
      }
    } catch (e) {
      _showSnack('Gagal menginisialisasi sensor Fingerprint: $e', isError: true);
    }
  }

  // ============================================================================
  // LOGIKA UTAMA SUBMIT REGISTRASI
  // ============================================================================
  Future<void> _handleRegister() async {
    FocusScope.of(context).unfocus();

    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      return;
    }

    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _isLoading = true;
    });

    Map<String, dynamic> res;
    try {
      res = await AuthService.registerUser(
        username: username,
        email: email,
        password: password,
        isFaceId: _faceIdVerified,
        isFingerprint: _fingerprintVerified,
      );
    } catch (e) {
      res = {
        'success': false,
        'message': 'Gagal memproses pendaftaran ke Sistem: $e',
      };
    }

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (res['success'] == true) {
      final user = res['user'] as UserModel?;

      // Simpan kredensial biometrik ke Hive authBox jika diverifikasi
      if (_faceIdVerified || _fingerprintVerified) {
        await UserInfo.setBiometricEnabled(true);
        if (_faceIdVerified) await UserInfo.setFaceIdEnabled(true);
        if (_fingerprintVerified) await UserInfo.setFingerprintEnabled(true);
        await UserInfo.setBiometricEmail(email);
        if (user != null) {
          await UserInfo.setBiometricUserId(user.id);
        }
      }

      // Pastikan status login di-reset agar user login ulang sesuai requirement
      await UserInfo.setLoginStatus(false);

      if (!mounted) return;

      // Berikan notifikasi sukses yang megah
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.verified, color: LevMaxTheme.primaryContainer, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Registrasi Berhasil! Silakan Login Ulang untuk mengaktifkan Vessel.',
                  style: LevMaxTheme.mono(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: LevMaxTheme.onPrimaryFixed,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: LevMaxTheme.surfaceContainerHighest,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: LevMaxTheme.primaryContainer, width: 1.5),
          ),
          duration: const Duration(seconds: 4),
        ),
      );

      // Arahkan kembali ke LoginPage sesuai diagram navigasi:
      // Login -> Belum punya akun? -> Register -> Login Ulang -> Cek is_onboarded -> Onboarding Kamera -> Main Navigation
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    } else {
      _showSnack(res['message'] ?? 'Registrasi gagal diproses.', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false, bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: LevMaxTheme.mono(
            fontSize: 11,
            color: isError
                ? LevMaxTheme.hpRed
                : (isSuccess ? LevMaxTheme.primaryContainer : LevMaxTheme.onSurface),
          ),
        ),
        backgroundColor: LevMaxTheme.surfaceContainerLow,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isError
                ? LevMaxTheme.hpRed
                : (isSuccess ? LevMaxTheme.primaryContainer : LevMaxTheme.outline),
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // BUILD UI (SOLO LEVELING TACTICAL AWAKENING AESTHETIC)
  // ============================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LevMaxTheme.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: LevMaxTheme.primaryContainer, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          'AWAKEN NEW VESSEL',
          style: LevMaxTheme.headline(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: LevMaxTheme.primaryContainer,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Subtitle
              Center(
                child: Column(
                  children: [
                    Text(
                      '[ INITIALIZE HUNTER PROFILE ]',
                      style: LevMaxTheme.mono(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: LevMaxTheme.primary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Daftarkan identitas Anda ke dalam Sistem untuk membuka potensi kekuatan tak terbatas.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: LevMaxTheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Tactical Form Card
              Container(
                decoration: BoxDecoration(
                  color: LevMaxTheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Username
                      _buildFieldHeader('HUNTER CODENAME / USERNAME', Icons.badge_outlined),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _usernameController,
                        style: LevMaxTheme.mono(fontSize: 13, color: LevMaxTheme.primary),
                        decoration: _buildInputDecoration(
                          hint: 'sung_jinwoo',
                          icon: Icons.person_outline,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Username wajib diisi';
                          }
                          if (value.trim().length < 3) {
                            return 'Username minimal 3 karakter';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // 2. Email
                      _buildFieldHeader('VESSEL EMAIL ADDRESS', Icons.email_outlined),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: LevMaxTheme.mono(fontSize: 13, color: LevMaxTheme.primary),
                        decoration: _buildInputDecoration(
                          hint: 'hunter@monarch.sys',
                          icon: Icons.alternate_email,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Email wajib diisi';
                          }
                          final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                          if (!regex.hasMatch(value.trim())) {
                            return 'Format email tidak valid';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // 3. Password
                      _buildFieldHeader('SECURITY KEY (PASSWORD)', Icons.lock_outline),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: LevMaxTheme.mono(fontSize: 13, color: LevMaxTheme.primary),
                        decoration: _buildInputDecoration(
                          hint: 'Minimal 8 karakter',
                          icon: Icons.key_outlined,
                          suffix: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: LevMaxTheme.outline,
                              size: 18,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Password wajib diisi';
                          }
                          if (value.length < 8) {
                            return 'Password minimal 8 karakter';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // 4. Konfirmasi Password
                      _buildFieldHeader('CONFIRM SECURITY KEY', Icons.lock_clock_outlined),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirm,
                        style: LevMaxTheme.mono(fontSize: 13, color: LevMaxTheme.primary),
                        decoration: _buildInputDecoration(
                          hint: 'Ulangi password di atas',
                          icon: Icons.verified_user_outlined,
                          suffix: IconButton(
                            icon: Icon(
                              _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                              color: LevMaxTheme.outline,
                              size: 18,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirm = !_obscureConfirm;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Konfirmasi password wajib diisi';
                          }
                          if (value != _passwordController.text) {
                            return 'Password konfirmasi tidak cocok';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ================================================================
              // BIOMETRIC SETUP SECTION (ELEGAN & TERVERIFIKASI LANGSUNG)
              // ================================================================
              Container(
                decoration: BoxDecoration(
                  color: LevMaxTheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: (_faceIdVerified || _fingerprintVerified)
                        ? LevMaxTheme.primaryContainer.withValues(alpha: 0.5)
                        : const Color(0xFF1E293B),
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.fingerprint, color: LevMaxTheme.primaryContainer, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'BIOMETRIC VESSEL LINKAGE',
                          style: LevMaxTheme.headline(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: LevMaxTheme.primaryContainer,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Verifikasi dan tautkan sensor biometrik perangkat saat ini untuk Quick Login instan tanpa password.',
                      style: TextStyle(
                        fontSize: 11,
                        color: LevMaxTheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Grid 2 Tombol Setup Biometrik Elegan
                    Row(
                      children: [
                        // Tombol 1: Face ID Setup
                        Expanded(
                          child: GestureDetector(
                            onTap: _setupFaceId,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              decoration: BoxDecoration(
                                color: _faceIdVerified
                                    ? LevMaxTheme.primaryContainer.withValues(alpha: 0.15)
                                    : LevMaxTheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _faceIdVerified
                                      ? LevMaxTheme.primaryContainer
                                      : const Color(0xFF334155),
                                  width: _faceIdVerified ? 1.5 : 1.0,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    _faceIdVerified ? Icons.face : Icons.face_unlock_outlined,
                                    size: 28,
                                    color: _faceIdVerified
                                        ? LevMaxTheme.primaryContainer
                                        : LevMaxTheme.outline,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'FACE ID',
                                    style: LevMaxTheme.mono(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: _faceIdVerified
                                          ? LevMaxTheme.primaryContainer
                                          : LevMaxTheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _faceIdVerified
                                          ? LevMaxTheme.primaryContainer.withValues(alpha: 0.2)
                                          : Colors.black26,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      _faceIdVerified ? 'VERIFIED ✓' : 'TAP TO SETUP',
                                      style: LevMaxTheme.mono(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.bold,
                                        color: _faceIdVerified
                                            ? LevMaxTheme.primaryContainer
                                            : LevMaxTheme.outline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Tombol 2: Fingerprint Setup
                        Expanded(
                          child: GestureDetector(
                            onTap: _setupFingerprint,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              decoration: BoxDecoration(
                                color: _fingerprintVerified
                                    ? LevMaxTheme.secondary.withValues(alpha: 0.15)
                                    : LevMaxTheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _fingerprintVerified
                                      ? LevMaxTheme.secondary
                                      : const Color(0xFF334155),
                                  width: _fingerprintVerified ? 1.5 : 1.0,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.fingerprint,
                                    size: 28,
                                    color: _fingerprintVerified
                                        ? LevMaxTheme.secondary
                                        : LevMaxTheme.outline,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'FINGERPRINT',
                                    style: LevMaxTheme.mono(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: _fingerprintVerified
                                          ? LevMaxTheme.secondary
                                          : LevMaxTheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _fingerprintVerified
                                          ? LevMaxTheme.secondary.withValues(alpha: 0.2)
                                          : Colors.black26,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      _fingerprintVerified ? 'VERIFIED ✓' : 'TAP TO SETUP',
                                      style: LevMaxTheme.mono(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.bold,
                                        color: _fingerprintVerified
                                            ? LevMaxTheme.secondary
                                            : LevMaxTheme.outline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ================================================================
              // CTA BUTTON: REGISTER HUNTER VESSEL
              // ================================================================
              GestureDetector(
                onTap: _isLoading ? null : _handleRegister,
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: LevMaxTheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x3300F0FF),
                        blurRadius: 18,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: LevMaxTheme.onPrimary,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'AWAKEN VESSEL [REGISTER]',
                                style: LevMaxTheme.mono(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: LevMaxTheme.onPrimary,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.bolt,
                                color: LevMaxTheme.onPrimary,
                                size: 18,
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Link ke LoginPage
              Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  children: [
                    Text(
                      'Sudah memiliki Vessel Hunter?',
                      style: LevMaxTheme.mono(
                        fontSize: 11,
                        color: LevMaxTheme.onSurfaceVariant,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Text(
                        '[ MASUK KE SISTEM / LOGIN ]',
                        style: LevMaxTheme.mono(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: LevMaxTheme.primaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldHeader(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: LevMaxTheme.primaryContainer),
        const SizedBox(width: 6),
        Text(
          label,
          style: LevMaxTheme.mono(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: LevMaxTheme.primary,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }

  InputDecoration _buildInputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: LevMaxTheme.surfaceContainerLowest,
      hintText: hint,
      hintStyle: LevMaxTheme.mono(fontSize: 12, color: LevMaxTheme.outline),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      prefixIcon: Icon(icon, size: 18, color: LevMaxTheme.outline),
      suffixIcon: suffix,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF1E293B)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF1E293B)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: LevMaxTheme.primaryContainer, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: LevMaxTheme.hpRed, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: LevMaxTheme.hpRed, width: 1.5),
      ),
    );
  }
}
