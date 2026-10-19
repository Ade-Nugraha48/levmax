// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/ui/auth/login_page.dart
// Deskripsi: Redesain Google Stitch - [ System Awakening Portal ] (Prompt 2 - Bagian 1)
//            Mengusung estetika Monolith Portal, Rotating Shield Reticle,
//            Live Optical Chamber HUD (Laser Scan), & Autentikasi Biometrik Ganda.
// ==============================================================================

import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../helpers/user_info.dart';
import '../../services/auth_service.dart';
import '../../services/biometric_service.dart';
import '../onboarding/onboarding_page.dart';
import '../main_navigation_page.dart';
import 'register_page.dart';
import 'face_scan_camera_page.dart';
import 'fingerprint_scan_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailOrUsernameController = TextEditingController();
  final _passwordController = TextEditingController();

  late AnimationController _rotationController;
  late AnimationController _laserController;
  late AnimationController _pulseController;

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _rememberToken = true;
  String? _errorMessage;

  // State Biometrik Perangkat
  BiometricCapability? _capability;
  bool _isFaceConfigured = false;
  bool _isFingerprintConfigured = false;

  @override
  void initState() {
    super.initState();

    // Rotasi pelan pada Outer Concentric Ring
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();

    // Laser sweep vertikal di dalam Optical Chamber
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    // Pulse beacon animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _initBiometricState();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _laserController.dispose();
    _pulseController.dispose();
    _emailOrUsernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Inisialisasi deteksi hardware biometrik & akun yang terhubung
  Future<void> _initBiometricState() async {
    final cap = await BiometricService.checkCapability();
    final faceConfigured = await UserInfo.getFaceIdEnabled();
    final fpConfigured = await UserInfo.getFingerprintEnabled();
    final bioEmail = await UserInfo.getBiometricEmail();
    final savedEmail = await UserInfo.getEmail();
    final savedUsername = await UserInfo.getUsername();

    if (mounted) {
      setState(() {
        _capability = cap;
        _isFaceConfigured = faceConfigured;
        _isFingerprintConfigured = fpConfigured;

        if (_emailOrUsernameController.text.isEmpty) {
          if (bioEmail != null && bioEmail.isNotEmpty) {
            _emailOrUsernameController.text = bioEmail;
          } else if (savedEmail != null && savedEmail.isNotEmpty) {
            _emailOrUsernameController.text = savedEmail;
          } else if (savedUsername != null && savedUsername.isNotEmpty) {
            _emailOrUsernameController.text = savedUsername;
          }
        }
      });
    }
  }

  // ============================================================================
  // LOGIKA LOGIN KREDENSIAL (JALAN UTAMA) & LAZY ENROLLMENT
  // ============================================================================
  Future<void> _handlePasswordLogin() async {
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

      final pendingSetup = await UserInfo.getPendingBiometricSetup();
      final hasAnyBio = _isFaceConfigured || _isFingerprintConfigured;
      final canUseHardware = _capability?.hasBiometrics ?? false;

      if ((pendingSetup || !hasAnyBio) && canUseHardware && user != null) {
        await _showLazyEnrollmentDialog(user.id);
      }

      if (!mounted) return;

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
  // DIALOG LAZY ENROLLMENT (OPSI TERPISAH: FACE ID / FINGERPRINT)
  // ============================================================================
  Future<void> _showLazyEnrollmentDialog(int userId) async {
    final cap = _capability;
    final hasFace = cap?.hasFace ?? true;
    final hasFp = cap?.hasFingerprint ?? true;

    final choice = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF171B26),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF00F0FF), width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.security, color: Color(0xFF00F0FF), size: 26),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Hubungkan Akses Biometrik?',
                style: TextStyle(color: Color(0xFF00F0FF), fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: const Text(
          'Login berhasil! Apakah Anda ingin menghubungkan sensor biometrik untuk akses cepat login Hunter di kemudian hari?',
          style: TextStyle(color: Color(0xFFDFE2F1), fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'skip'),
            child: const Text('NANTI SAJA', style: TextStyle(color: Colors.grey)),
          ),
          if (hasFace)
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx, 'face'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF00F0FF)),
              ),
              child: const Text('FACE ID', style: TextStyle(color: Color(0xFF00F0FF))),
            ),
          if (hasFp)
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, 'fingerprint'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00F0FF),
                foregroundColor: Colors.black,
              ),
              child: const Text('FINGERPRINT', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );

    await UserInfo.setPendingBiometricSetup(false);

    if (choice == 'face') {
      if (!mounted) return;
      final scanSuccess = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => const FaceScanCameraPage(
            mode: FaceScanMode.register,
            title: 'REGISTRASI WAJAH HUNTER',
            subtitle: 'Pindai wajah Anda melalui kamera depan',
          ),
        ),
      );

      if (scanSuccess == true) {
        final res = await AuthService.setFaceIdStatusForUser(
          userId: userId,
          enable: true,
        );
        if (res['success'] == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Face Scan Kamera berhasil dihubungkan! Anda dapat login dengan scan wajah.'),
              backgroundColor: Color(0xFF00F0FF),
            ),
          );
        }
      }
    } else if (choice == 'fingerprint') {
      if (!mounted) return;
      final scanSuccess = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => const FingerprintScanPage(
            mode: FingerprintScanMode.enroll,
            title: 'REGISTRASI SIDIK JARI HUNTER',
            subtitle: 'Lakukan 3 sentuhan bertahap untuk merekam patokan sidik jari sekuritas',
          ),
        ),
      );

      if (scanSuccess == true) {
        final res = await AuthService.setFingerprintStatusForUser(
          userId: userId,
          enable: true,
        );
        if (res['success'] == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sensor sidik jari berhasil dihubungkan! Anda dapat login dengan fingerprint.'),
              backgroundColor: Color(0xFF00F0FF),
            ),
          );
        }
      }
    }
  }

  // ============================================================================
  // LOGIKA LOGIN FACE SCAN KAMERA (OPSIONAL 1)
  // ============================================================================
  Future<void> _handleFaceIdLogin() async {
    FocusScope.of(context).unfocus();

    final hasEnrolled = await UserInfo.getHasEnrolledFace();
    if (!hasEnrolled) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF171B26),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'WAJAH PATOKAN BELUM DISETOR',
                  style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
          content: const Text(
            'Untuk menggunakan Face ID, Anda harus menyetor wajah Anda terlebih dahulu sebagai patokan sekuritas. Silakan setor wajah sekarang atau masuk dengan Email & Password.',
            style: TextStyle(color: Color(0xFFDFE2F1), fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('BATAL', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                final enrolled = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const FaceScanCameraPage(
                      mode: FaceScanMode.enroll,
                      title: 'SETOR WAJAH PATOKAN',
                      subtitle: 'Posisikan wajah Anda di dalam lingkaran pemindai',
                    ),
                  ),
                );
                if (enrolled == true && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Wajah patokan berhasil disetor! Silakan masuk dengan Password untuk menautkan akun, atau coba login Face ID jika akun sudah terhubung.'),
                      backgroundColor: Color(0xFF00F0FF),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.face, color: Colors.black, size: 18),
              label: const Text('SETOR WAJAH SEKARANG', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00F0FF),
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      );
      return;
    }

    final isConfigured = await UserInfo.getFaceIdEnabled();
    final bioUserId = await UserInfo.getBiometricUserId();

    if (!isConfigured || bioUserId == null || bioUserId <= 0) {
      await UserInfo.setPendingBiometricSetup(true);
      if (!mounted) return;
      _showSystemNotificationBottomSheet(
        title: 'FACE SCAN BELUM TERHUBUNG',
        message: 'PERINGATAN SISTEM: Face Scan Kamera belum dihubungkan pada akun Hunter di perangkat ini. Silakan login menggunakan Email & Password terlebih dahulu.',
        method: 'Face ID',
      );
      return;
    }

    if (!mounted) return;

    final scanSuccess = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const FaceScanCameraPage(
          mode: FaceScanMode.login,
          title: 'SISTEM PEMINDAIAN WAJAH HUNTER',
          subtitle: 'Arahkan wajah Anda ke kamera depan HP Samsung',
        ),
      ),
    );

    if (!mounted) return;

    if (scanSuccess == true) {
      final result = await AuthService.finalizeFaceScanLogin();
      if (!mounted) return;
      _handleBiometricAuthResponse(result);
    } else {
      _showErrorSnackBar('Pemindaian wajah kamera dibatalkan atau tidak cocok.');
    }
  }

  // ============================================================================
  // LOGIKA LOGIN FINGERPRINT (OPSIONAL 2)
  // ============================================================================
  Future<void> _handleFingerprintLogin() async {
    FocusScope.of(context).unfocus();

    final hasEnrolledFp = await UserInfo.getHasEnrolledFingerprint();
    if (!hasEnrolledFp) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF171B26),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'SIDIK JARI PATOKAN BELUM DISETOR',
                  style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
          content: const Text(
            'Untuk menggunakan Fingerprint, Anda harus menyetor sidik jari Anda terlebih dahulu sebagai patokan sekuritas (3 sentuhan bertahap). Silakan setor sidik jari sekarang atau masuk dengan Email & Password.',
            style: TextStyle(color: Color(0xFFDFE2F1), fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('BATAL', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                final enrolled = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const FingerprintScanPage(
                      mode: FingerprintScanMode.enroll,
                      title: 'SETOR SIDIK JARI PATOKAN',
                      subtitle: 'Lakukan 3 sentuhan bertahap untuk merekam patokan sidik jari sekuritas',
                    ),
                  ),
                );
                if (enrolled == true && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Sidik jari patokan berhasil disetor! Silakan masuk dengan Password untuk menautkan akun, atau coba login Fingerprint jika akun sudah terhubung.'),
                      backgroundColor: Color(0xFF00F0FF),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.fingerprint, color: Colors.black, size: 18),
              label: const Text('SETOR SIDIK JARI SEKARANG', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00F0FF),
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      );
      return;
    }

    final isConfigured = await UserInfo.getFingerprintEnabled();
    final bioUserId = await UserInfo.getBiometricUserId();

    if (!isConfigured || bioUserId == null || bioUserId <= 0) {
      await UserInfo.setPendingBiometricSetup(true);
      if (!mounted) return;
      _showSystemNotificationBottomSheet(
        title: 'FINGERPRINT BELUM TERHUBUNG',
        message: 'PERINGATAN SISTEM: Sensor Fingerprint belum dihubungkan pada akun Hunter di perangkat ini. Silakan login menggunakan Email & Password terlebih dahulu.',
        method: 'Fingerprint',
      );
      return;
    }

    if (!mounted) return;

    final scanSuccess = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const FingerprintScanPage(
          mode: FingerprintScanMode.verify,
          title: 'SISTEM PEMINDAIAN SIDIK JARI',
          subtitle: 'Sentuh sensor sidik jari perangkat untuk otorisasi akses',
        ),
      ),
    );

    if (!mounted) return;

    if (scanSuccess == true) {
      final result = await AuthService.finalizeFingerprintLogin();
      if (!mounted) return;
      _handleBiometricAuthResponse(result);
    } else {
      _showErrorSnackBar('Pemindaian sidik jari dibatalkan atau tidak cocok.');
    }
  }

  void _handleBiometricAuthResponse(Map<String, dynamic> result) {
    if (result['success'] == true) {
      final user = result['user'];

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.verified, color: Colors.black),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  result['message'] ?? 'Otorisasi Berhasil!',
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF00F0FF),
          behavior: SnackBarBehavior.floating,
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

  void _showSystemNotificationBottomSheet({
    required String title,
    required String message,
    required String method,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF171B26),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Color(0xFF00F0FF), width: 2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade700,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFF00F0FF), size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF00F0FF),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              message,
              style: const TextStyle(color: Color(0xFFDFE2F1), fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 8),
            Text(
              'Anda dapat mengaktifkan $method kapan saja di Tab Profil setelah login.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00F0FF),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('MASUK DENGAN EMAIL & PASSWORD', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
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
        backgroundColor: const Color(0xFFFF2A54),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F131D),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ==============================================================
              // 1. SYSTEM DIAGNOSTIC HEADER STRIP
              // ==============================================================
              Container(
                color: const Color(0xFF0A0E18),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF00F0FF).withValues(
                                  alpha: 0.4 + (_pulseController.value * 0.6),
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0xFF00F0FF),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'NODE // APEX-01',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: Color(0xFF00F0FF),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const Text(
                      'SYS.VER 4.8.2',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: Color(0xFF849495),
                        fontSize: 10,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ],
                ),
              ),

              // ==============================================================
              // 2. TOP AWAKENING CREST & MONOLITH HEADER
              // ==============================================================
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 20),
                child: Column(
                  children: [
                    // Concentric Rotating Reticle Crest
                    Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Radial Glow Underlay
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF00F0FF).withValues(alpha: 0.15),
                                  blurRadius: 40,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                          ),

                          // Outer Dashed Rotating Ring
                          AnimatedBuilder(
                            animation: _rotationController,
                            builder: (context, child) {
                              return Transform.rotate(
                                angle: _rotationController.value * 2 * math.pi,
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFF00F0FF).withValues(alpha: 0.3),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                          // Inner Hexagonal / Shield Reticle
                          Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              color: const Color(0xFF171B26),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF00F0FF).withValues(alpha: 0.6),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF00F0FF).withValues(alpha: 0.25),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.shield_outlined,
                                color: Color(0xFF00F0FF),
                                size: 30,
                              ),
                            ),
                          ),

                          // Tactical Corner Tick Markers
                          Positioned(
                            top: 0,
                            child: Container(width: 8, height: 2, color: const Color(0xFF00F0FF)),
                          ),
                          Positioned(
                            bottom: 0,
                            child: Container(width: 8, height: 2, color: const Color(0xFF00F0FF)),
                          ),
                          Positioned(
                            left: 0,
                            child: Container(width: 2, height: 8, color: const Color(0xFF00F0FF)),
                          ),
                          Positioned(
                            right: 0,
                            child: Container(width: 2, height: 8, color: const Color(0xFF00F0FF)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Protocol Callout Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF262A35),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF3B494B)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF65F2B5),
                              boxShadow: [
                                BoxShadow(color: Color(0xFF65F2B5), blurRadius: 4),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'PROTOCOL: SECURE // CHANNEL: VIRTUAL AWAKENING',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: Color(0xFF65F2B5),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Main Title
                    const Text(
                      '[ SYSTEM AWAKENING PORTAL ]',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF00F0FF),
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Identify Hunter Credentials to access the System Window & synchronize mana resonance.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFB9CACB),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ==============================================================
              // 3. MAIN CREDENTIAL INPUT FORM (TACTICAL CARD)
              // ==============================================================
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF171B26),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF1C1F2A)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Hunter ID / Email Field
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.badge_outlined, color: Color(0xFF00F0FF), size: 14),
                                SizedBox(width: 6),
                                Text(
                                  'HUNTER CODENAME / EMAIL',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    color: Color(0xFF00F0FF),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'ID: LEVEL_REQUIRED',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: const Color(0xFF849495).withValues(alpha: 0.8),
                                fontSize: 9,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _emailOrUsernameController,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            color: Color(0xFF00F0FF),
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFF0A0E18),
                            hintText: 'hunter_id@monarch.sys',
                            hintStyle: TextStyle(
                              fontFamily: 'monospace',
                              color: const Color(0xFF849495).withValues(alpha: 0.5),
                              fontSize: 12,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            suffixIcon: const Icon(Icons.verified_user, color: Color(0xFF00F0FF), size: 18),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFF1E293B)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFF00F0FF), width: 1.5),
                            ),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Hunter ID wajib diisi' : null,
                        ),
                        const SizedBox(height: 16),

                        // Security Key / Password Field
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.enhanced_encryption, color: Color(0xFFD2BBFF), size: 14),
                                SizedBox(width: 6),
                                Text(
                                  'SECURITY KEY [SHA-256]',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    color: Color(0xFFD2BBFF),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '256-BIT MESH',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: Color(0xFF4EDEA3),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            color: Color(0xFFD2BBFF),
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFF0A0E18),
                            hintText: '••••••••••••••••',
                            hintStyle: TextStyle(
                              fontFamily: 'monospace',
                              color: const Color(0xFF849495).withValues(alpha: 0.5),
                              fontSize: 12,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                color: const Color(0xFF849495),
                                size: 18,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFF1E293B)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFD2BBFF), width: 1.5),
                            ),
                          ),
                          validator: (v) => (v == null || v.isEmpty) ? 'Password wajib diisi' : null,
                        ),
                        const SizedBox(height: 12),

                        // Helper Options Strip (Remember Vessel Token + Recover / Register)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _rememberToken = !_rememberToken;
                                });
                              },
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: Checkbox(
                                      value: _rememberToken,
                                      activeColor: const Color(0xFF00F0FF),
                                      checkColor: Colors.black,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                      onChanged: (val) {
                                        setState(() {
                                          _rememberToken = val ?? true;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Remember Vessel Token',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      color: Color(0xFFB9CACB),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const RegisterPage()),
                                );
                              },
                              child: const Text(
                                'Daftar Akun?',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  color: Color(0xFF00F0FF),
                                  fontSize: 11,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Primary Sovereign Action CTA
                        ElevatedButton(
                          onPressed: _isLoading ? null : _handlePasswordLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00F0FF),
                            foregroundColor: const Color(0xFF002022),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 8,
                            shadowColor: const Color(0xFF00F0FF).withValues(alpha: 0.4),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'ENTER THE SYSTEM [LOGIN]',
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    SizedBox(width: 6),
                                    Icon(Icons.keyboard_double_arrow_right, size: 20),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ==============================================================
              // 4. TACTICAL BIOMETRIC DIVIDER
              // ==============================================================
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Expanded(child: Divider(color: Color(0xFF313540), thickness: 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF262A35),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'OR EXECUTE BIOMETRIC AWAKENING',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: Color(0xFF00F0FF),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ),
                    const Expanded(child: Divider(color: Color(0xFF313540), thickness: 1)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ==============================================================
              // 5. DUAL BIOMETRIC QUICK ACTION BUTTONS
              // ==============================================================
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // Face ID Scan Button
                    Expanded(
                      child: GestureDetector(
                        onTap: _handleFaceIdLogin,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF171B26),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _isFaceConfigured
                                  ? const Color(0xFF00F0FF).withValues(alpha: 0.6)
                                  : const Color(0xFF262A35),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF262A35),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.face, color: Color(0xFF00F0FF), size: 20),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'FACE ID SCAN',
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        color: Color(0xFF00F0FF),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    Text(
                                      'APERTURE READY',
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        color: Color(0xFF849495),
                                        fontSize: 9,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Fingerprint Scan Button
                    Expanded(
                      child: GestureDetector(
                        onTap: _handleFingerprintLogin,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF171B26),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _isFingerprintConfigured
                                  ? const Color(0xFFD2BBFF).withValues(alpha: 0.6)
                                  : const Color(0xFF262A35),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6001D1).withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.fingerprint, color: Color(0xFFD2BBFF), size: 20),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'FINGERPRINT',
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        color: Color(0xFFD2BBFF),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    Text(
                                      'OPTICAL SENSOR',
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        color: Color(0xFF849495),
                                        fontSize: 9,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // ==============================================================
              // 6. LIVE OPTICAL CHAMBER HUD CONTAINER (FACE APERTURE RETICLE)
              // ==============================================================
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GestureDetector(
                  onTap: _handleFaceIdLogin,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF171B26),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF1E293B)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Chamber Header
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0A0E18).withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0xFF4EDEA3),
                                      boxShadow: [
                                        BoxShadow(color: Color(0xFF4EDEA3), blurRadius: 4),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    '[ LIVE OPTICAL CHAMBER ]',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      color: Color(0xFF65F2B5),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                              const Text(
                                'FPS: 60.0 • 1080P',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  color: Color(0xFF849495),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Aperture Viewport Reticle with animated sweep laser
                        SizedBox(
                          width: 170,
                          height: 170,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Circular Aperture Chamber Background
                              Container(
                                width: 170,
                                height: 170,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF0A0E18),
                                  border: Border.all(
                                    color: const Color(0xFF00F0FF).withValues(alpha: 0.2),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF00F0FF).withValues(alpha: 0.1),
                                      blurRadius: 16,
                                    ),
                                  ],
                                ),
                              ),

                              // Face Silhouette Vector Drawing
                              CustomPaint(
                                size: const Size(130, 130),
                                painter: _FaceSilhouettePainter(
                                  color: const Color(0xFF00F0FF).withValues(alpha: 0.65),
                                ),
                              ),

                              // Animated Sweep Laser Scanline
                              AnimatedBuilder(
                                animation: _laserController,
                                builder: (context, child) {
                                  final topOffset = 20.0 + (_laserController.value * 120.0);
                                  return Positioned(
                                    top: topOffset,
                                    left: 20,
                                    right: 20,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          height: 20,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Colors.transparent,
                                                const Color(0xFF00F0FF).withValues(alpha: 0.25),
                                              ],
                                            ),
                                          ),
                                        ),
                                        Container(
                                          height: 2,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF00F0FF),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Color(0xFF00F0FF),
                                                blurRadius: 10,
                                                spreadRadius: 2,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),

                              // Cyberpunk Corner L-Brackets
                              const Positioned(
                                top: 12,
                                left: 12,
                                child: _CornerBracket(isTop: true, isLeft: true),
                              ),
                              const Positioned(
                                top: 12,
                                right: 12,
                                child: _CornerBracket(isTop: true, isLeft: false),
                              ),
                              const Positioned(
                                bottom: 12,
                                left: 12,
                                child: _CornerBracket(isTop: false, isLeft: true),
                              ),
                              const Positioned(
                                bottom: 12,
                                right: 12,
                                child: _CornerBracket(isTop: false, isLeft: false),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Telemetry Status Row Below Aperture
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.videocam_outlined, color: Color(0xFF65F2B5), size: 14),
                                SizedBox(width: 4),
                                Text(
                                  '[ Real-time Camera Verification ]',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    color: Color(0xFF65F2B5),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'MATCH: 99.4%',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: Color(0xFF00F0FF),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Dynamic Striped Biometric Progress Bar (68%)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Calibrating Vessel Biometrics',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    color: Color(0xFF849495),
                                    fontSize: 10,
                                  ),
                                ),
                                Text(
                                  '68%',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    color: Color(0xFF00F0FF),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: const Color(0xFF262A35),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Stack(
                                children: [
                                  FractionallySizedBox(
                                    widthFactor: 0.68,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00F0FF),
                                        borderRadius: BorderRadius.circular(3),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0xFF00F0FF),
                                            blurRadius: 6,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Sensor Guidance Prompt Box
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0A0E18),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF1E293B)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.lens_blur, color: Color(0xFF00F0FF), size: 16),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Align face with system sensor • Keep head level in the reticle.',
                                  style: TextStyle(
                                    color: Color(0xFFDFE2F1),
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Coordinates Telemetry Footer
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'OPTICAL: 99.4%',
                              style: TextStyle(fontFamily: 'monospace', color: Color(0xFF849495), fontSize: 9),
                            ),
                            Text(
                              'LATENCY: 12ms',
                              style: TextStyle(fontFamily: 'monospace', color: Color(0xFF849495), fontSize: 9),
                            ),
                            Text(
                              'CHAMBER: ONLINE',
                              style: TextStyle(fontFamily: 'monospace', color: Color(0xFF4EDEA3), fontSize: 9),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ==============================================================
              // 7. BOTTOM GLOBAL FOOTNOTE
              // ==============================================================
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'SYSTEM AWAKENING PROTOCOL SECURED BY HUNTER INTEGRITY MESH v4.8',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: Color(0xFF849495),
                    fontSize: 9,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ==============================================================================
// CUSTOM PAINTER: CYBERPUNK FACE SILHOUETTE
// ==============================================================================
class _FaceSilhouettePainter extends CustomPainter {
  final Color color;
  const _FaceSilhouettePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;

    final cx = size.width / 2;
    final cy = size.height / 2;

    // Head Contour Oval
    final headRect = Rect.fromCenter(center: Offset(cx, cy - 6), width: 62, height: 82);
    canvas.drawOval(headRect, paint);

    // Crosshairs
    canvas.drawLine(Offset(cx - 24, cy - 6), Offset(cx + 24, cy - 6), paint..strokeWidth = 0.8);
    canvas.drawLine(Offset(cx, cy - 36), Offset(cx, cy + 24), paint..strokeWidth = 0.8);

    // Left and Right Eye Reticles
    canvas.drawCircle(Offset(cx - 14, cy - 10), 3.5, paint..strokeWidth = 1.0);
    canvas.drawCircle(Offset(cx + 14, cy - 10), 3.5, paint..strokeWidth = 1.0);

    // Smile / Jaw Target Arc
    final mouthRect = Rect.fromCenter(center: Offset(cx, cy + 14), width: 18, height: 10);
    canvas.drawArc(mouthRect, 0.2, math.pi - 0.4, false, paint);

    // Neck line segments
    canvas.drawLine(Offset(cx - 16, cy + 34), Offset(cx - 24, cy + 50), paint);
    canvas.drawLine(Offset(cx + 16, cy + 34), Offset(cx + 24, cy + 50), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ==============================================================================
// WIDGET: CYBERPUNK RETICLE CORNER BRACKET
// ==============================================================================
class _CornerBracket extends StatelessWidget {
  final bool isTop;
  final bool isLeft;

  const _CornerBracket({required this.isTop, required this.isLeft});

  @override
  Widget build(BuildContext context) {
    const size = 12.0;
    const thickness = 2.0;
    const color = Color(0xFF00F0FF);

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _BracketPainter(isTop: isTop, isLeft: isLeft, thickness: thickness, color: color),
      ),
    );
  }
}

class _BracketPainter extends CustomPainter {
  final bool isTop;
  final bool isLeft;
  final double thickness;
  final Color color;

  _BracketPainter({
    required this.isTop,
    required this.isLeft,
    required this.thickness,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke;

    final startX = isLeft ? 0.0 : size.width;
    final endX = isLeft ? size.width : 0.0;
    final startY = isTop ? 0.0 : size.height;
    final endY = isTop ? size.height : 0.0;

    // Horizontal arm
    canvas.drawLine(Offset(startX, startY), Offset(endX, startY), paint);
    // Vertical arm
    canvas.drawLine(Offset(startX, startY), Offset(startX, endY), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
