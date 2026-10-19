// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/ui/auth/login_page.dart
// Deskripsi: Halaman Login Hunter Kredensial Enkripsi SHA-256 (Jalan Utama)
//            dengan Pilihan Terpisah & Opsional: Face ID & Fingerprint (Alur 2).
// ==============================================================================

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

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailOrUsernameController = TextEditingController();
  final _passwordController = TextEditingController();

  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  // State Biometrik Perangkat (Terpisah)
  BiometricCapability? _capability;
  bool _isFaceConfigured = false;
  bool _isFingerprintConfigured = false;
  String? _biometricEmail;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _initBiometricState();
  }

  @override
  void dispose() {
    _glowController.dispose();
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
        _biometricEmail = bioEmail;

        // Auto pre-fill identifier terakhir
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

      // Cek apakah ada flag Pending Biometric Setup atau belum mengaktifkan salah satu
      final pendingSetup = await UserInfo.getPendingBiometricSetup();
      final hasAnyBio = _isFaceConfigured || _isFingerprintConfigured;
      final canUseHardware = _capability?.hasBiometrics ?? false;

      if ((pendingSetup || !hasAnyBio) && canUseHardware && user != null) {
        // Tampilkan dialog Lazy Enrollment: "Hubungkan Face ID / Fingerprint Sekarang?"
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
        backgroundColor: const Color(0xFF131B2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF00E5FF), width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.security, color: Color(0xFF00E5FF), size: 26),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Hubungkan Akses Biometrik?',
                style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: const Text(
          'Login berhasil! Apakah Anda ingin menghubungkan sensor biometrik untuk akses cepat login Hunter di kemudian hari?',
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
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
                side: const BorderSide(color: Color(0xFF00E5FF)),
              ),
              child: const Text('FACE ID', style: TextStyle(color: Color(0xFF00E5FF))),
            ),
          if (hasFp)
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, 'fingerprint'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
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
              backgroundColor: Color(0xFF00E5FF),
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
        final res = await AuthService.toggleFingerprintForUser(
          userId: userId,
          enable: true,
          localizedReason: 'Konfirmasi sidik jari untuk mengaktifkan sensor fingerprint',
        );
        if (res['success'] == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sensor sidik jari berhasil dihubungkan! Anda dapat login dengan fingerprint.'),
              backgroundColor: Color(0xFF00E5FF),
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

    // 1. Cek apakah pengguna sudah pernah setor wajah patokan sekuritas
    final hasEnrolled = await UserInfo.getHasEnrolledFace();
    if (!hasEnrolled) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF131B2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFFFB300), width: 1.5),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFFFB300), size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'WAJAH PATOKAN BELUM DISETOR',
                  style: TextStyle(color: Color(0xFFFFB300), fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
          content: const Text(
            'Untuk menggunakan Face ID, Anda harus menyetor wajah Anda terlebih dahulu sebagai patokan sekuritas. Silakan setor wajah sekarang atau masuk dengan Email & Password.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
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
                      backgroundColor: Color(0xFF00E5FF),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.face, color: Colors.black, size: 18),
              label: const Text('SETOR WAJAH SEKARANG', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
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

    // Buka Layar Kamera Depan Fisik Realtime untuk Verifikasi
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

    // 1. Cek apakah pengguna sudah pernah setor sidik jari patokan sekuritas
    final hasEnrolledFp = await UserInfo.getHasEnrolledFingerprint();
    if (!hasEnrolledFp) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF131B2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFFFB300), width: 1.5),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFFFB300), size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'SIDIK JARI PATOKAN BELUM DISETOR',
                  style: TextStyle(color: Color(0xFFFFB300), fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
          content: const Text(
            'Untuk menggunakan Fingerprint, Anda harus menyetor sidik jari Anda terlebih dahulu sebagai patokan sekuritas (3 sentuhan bertahap). Silakan setor sidik jari sekarang atau masuk dengan Email & Password.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
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
                      backgroundColor: Color(0xFF00E5FF),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.fingerprint, color: Colors.black, size: 18),
              label: const Text('SETOR SIDIK JARI SEKARANG', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
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
        message: 'PERINGATAN SISTEM: Sensor Sidik Jari belum diaktifkan pada akun Hunter Anda. Silakan login menggunakan Email & Password terlebih dahulu.',
        method: 'Fingerprint',
      );
      return;
    }

    if (!mounted) return;

    // Buka Layar Verifikasi Sidik Jari Asli Realtime
    final scanSuccess = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const FingerprintScanPage(
          mode: FingerprintScanMode.login,
          title: 'SISTEM PEMINDAIAN SIDIK JARI HUNTER',
          subtitle: 'Tempelkan sidik jari Anda pada sensor HP Samsung',
        ),
      ),
    );

    if (!mounted) return;

    if (scanSuccess == true) {
      final result = await AuthService.finalizeBiometricSession(bioUserId, 'Fingerprint');
      if (!mounted) return;
      _handleBiometricAuthResponse(result);
    } else {
      _showErrorSnackBar('Pemindaian sidik jari dibatalkan.');
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
          backgroundColor: const Color(0xFF00E5FF),
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



  /// Modal Bottom Sheet Bergaya Solo Leveling "System Notification"
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
          color: Color(0xFF131B2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Color(0xFF00E5FF), width: 2)),
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
                const Icon(Icons.warning_amber_rounded, color: Color(0xFF00E5FF), size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF00E5FF),
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
              style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.5),
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
                backgroundColor: const Color(0xFF00E5FF),
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
        backgroundColor: const Color(0xFFFF1744),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cap = _capability;
    final hasFaceHardware = cap?.hasFace ?? true;
    final hasFpHardware = cap?.hasFingerprint ?? true;

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
                // Header Logo Solo Leveling
                Center(
                  child: Container(
                    width: 76,
                    height: 76,
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
                      size: 40,
                      color: Color(0xFF00E5FF),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

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
                const SizedBox(height: 4),
                Text(
                  'Portal Otentikasi Hunter Solo Leveling',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),

                // Indikator akun biometrik terhubung
                if ((_isFaceConfigured || _isFingerprintConfigured) && _biometricEmail != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7B1FA2).withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF7B1FA2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.verified_user, color: Color(0xFF00E5FF), size: 16),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Akun Terhubung: $_biometricEmail',
                            style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 11, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

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
                  const SizedBox(height: 16),
                ],

                // ================================================================
                // JALAN UTAMA: INPUT EMAIL/USERNAME & PASSWORD
                // ================================================================
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _emailOrUsernameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Email atau Username Hunter',
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
                        validator: (value) => (value == null || value.trim().isEmpty)
                            ? 'Email atau Username wajib diisi.'
                            : null,
                      ),
                      const SizedBox(height: 14),

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
                        validator: (value) => (value == null || value.isEmpty)
                            ? 'Harap masukkan password Anda.'
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // TOMBOL LOGIN PASSWORD UTAMA
                ElevatedButton(
                  onPressed: _isLoading ? null : _handlePasswordLogin,
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
                const SizedBox(height: 24),

                // ================================================================
                // PEMISAH: PILIHAN OPSIONAL QUICK ACCESS
                // ================================================================
                Row(
                  children: [
                    const Expanded(child: Divider(color: Color(0xFF1E293B), thickness: 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'ATAU PILIH AKSES BIOMETRIK',
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

                // ================================================================
                // DUA TOMBOL TERPISAH: FACE ID & FINGERPRINT
                // ================================================================
                AnimatedBuilder(
                  animation: _glowAnimation,
                  builder: (context, child) {
                    return Row(
                      children: [
                        // TOMBOL 1: FACE ID
                        if (hasFaceHardware)
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF00E5FF).withValues(
                                      alpha: _isFaceConfigured ? _glowAnimation.value * 0.4 : 0.1,
                                    ),
                                    blurRadius: 14,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: OutlinedButton.icon(
                                onPressed: _isLoading ? null : _handleFaceIdLogin,
                                icon: Icon(
                                  Icons.face_unlock_outlined,
                                  color: _isFaceConfigured ? const Color(0xFF00E5FF) : Colors.white70,
                                  size: 20,
                                ),
                                label: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'FACE ID',
                                    style: TextStyle(
                                      color: _isFaceConfigured ? const Color(0xFF00E5FF) : Colors.white,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.8,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: _isFaceConfigured ? const Color(0xFF00E5FF) : const Color(0xFF1E293B),
                                    width: 1.6,
                                  ),
                                  backgroundColor: const Color(0xFF131B2E),
                                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                              ),
                            ),
                          ),

                        // TOMBOL 2: FINGERPRINT
                        if (hasFpHardware)
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.only(left: 6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF7B1FA2).withValues(
                                      alpha: _isFingerprintConfigured ? _glowAnimation.value * 0.5 : 0.1,
                                    ),
                                    blurRadius: 14,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: OutlinedButton.icon(
                                onPressed: _isLoading ? null : _handleFingerprintLogin,
                                icon: Icon(
                                  Icons.fingerprint,
                                  color: _isFingerprintConfigured ? const Color(0xFF00E5FF) : Colors.white70,
                                  size: 20,
                                ),
                                label: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'FINGERPRINT',
                                    style: TextStyle(
                                      color: _isFingerprintConfigured ? const Color(0xFF00E5FF) : Colors.white,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.8,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: _isFingerprintConfigured ? const Color(0xFF00E5FF) : const Color(0xFF1E293B),
                                    width: 1.6,
                                  ),
                                  backgroundColor: const Color(0xFF131B2E),
                                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
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
