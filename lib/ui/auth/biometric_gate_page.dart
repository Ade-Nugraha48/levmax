// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/ui/auth/biometric_gate_page.dart
// Deskripsi: Layar Kunci Biometrik Sistem (Alur 3) - Validasi Sesi Aktif
//            dengan auto-scan Face ID / Fingerprint saat buka aplikasi & fallback Password.
// ==============================================================================

import 'package:flutter/material.dart';

import '../../helpers/user_info.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_api_service.dart';
import '../onboarding/onboarding_page.dart';
import '../main_navigation_page.dart';
import '../penalty/game_over_page.dart';
import 'login_page.dart';
import 'face_scan_camera_page.dart';
import 'fingerprint_scan_page.dart';

class BiometricGatePage extends StatefulWidget {
  const BiometricGatePage({super.key});

  @override
  State<BiometricGatePage> createState() => _BiometricGatePageState();
}

class _BiometricGatePageState extends State<BiometricGatePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  bool _isScanning = false;
  String _statusMessage = 'MENGIDENTIFIKASI HUNTER...';
  String _userIdentifier = 'Hunter LevMax';
  bool _faceEnabled = false;
  bool _fingerprintEnabled = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadUserAndTriggerScan();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  /// Memuat profil biometrik tanpa memicu pemindaian otomatis
  Future<void> _loadUserAndTriggerScan() async {
    final bioEmail = await UserInfo.getBiometricEmail();
    final username = await UserInfo.getUsername();
    final face = await UserInfo.getFaceIdEnabled();
    final fp = await UserInfo.getFingerprintEnabled();

    if (mounted) {
      setState(() {
        _faceEnabled = face;
        _fingerprintEnabled = fp;
        if (bioEmail != null && bioEmail.isNotEmpty) {
          _userIdentifier = bioEmail;
        } else if (username != null && username.isNotEmpty) {
          _userIdentifier = username;
        }
        _statusMessage = 'PILIH METODE PEMINDAIAN DI BAWAH';
      });
    }
  }

  /// Eksekusi pemindaian Face ID melalui kamera depan fisik
  Future<void> _executeFaceScan() async {
    if (_isScanning) return;

    setState(() {
      _isScanning = true;
      _statusMessage = 'MEMINDAI WAJAH VIA KAMERA DEPAN...';
    });

    final scanSuccess = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const FaceScanCameraPage(
          mode: FaceScanMode.verify,
          title: 'VERIFIKASI WAJAH HUNTER',
          subtitle: 'Arahkan wajah Anda ke kamera depan HP Samsung',
        ),
      ),
    );

    if (!mounted) return;

    setState(() {
      _isScanning = false;
    });

    if (scanSuccess == true) {
      final res = await AuthService.finalizeFaceScanLogin();
      if (!mounted) return;
      _handleGateResult(res);
    } else {
      setState(() {
        _statusMessage = 'Pemindaian wajah kamera dibatalkan.';
      });
    }
  }

  /// Eksekusi pemindaian Fingerprint
  Future<void> _executeFingerprintScan() async {
    if (_isScanning) return;

    setState(() {
      _isScanning = true;
      _statusMessage = 'MEMINDAI SIDIK JARI HUNTER...';
    });

    final scanSuccess = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const FingerprintScanPage(
          mode: FingerprintScanMode.verify,
          title: 'VERIFIKASI SIDIK JARI HUNTER',
          subtitle: 'Tempelkan jari Anda pada sensor HP Samsung',
        ),
      ),
    );

    if (!mounted) return;

    setState(() {
      _isScanning = false;
    });

    if (scanSuccess == true) {
      final bioUserId = await UserInfo.getBiometricUserId();
      if (bioUserId != null &&
          bioUserId.toString().isNotEmpty &&
          bioUserId.toString() != '0') {
        final res = await AuthService.finalizeBiometricSession(
          bioUserId,
          'Fingerprint',
        );
        if (!mounted) return;
        _handleGateResult(res);
      } else {
        final res = await AuthService.loginFingerprint();
        if (!mounted) return;
        _handleGateResult(res);
      }
    } else {
      setState(() {
        _statusMessage = 'Pemindaian sidik jari dibatalkan.';
      });
    }
  }

  /// Eksekusi pemindaian biometrik umum fallback
  Future<void> _executeGeneralScan() async {
    if (_isScanning) return;

    setState(() {
      _isScanning = true;
      _statusMessage = 'MEMINDAI BIOMETRIK HUNTER...';
    });

    final res = await AuthService.loginBiometric(
      reason: 'Pindai biometrik untuk membuka Status Window Hunter',
    );

    if (!mounted) return;

    setState(() {
      _isScanning = false;
    });

    _handleGateResult(res);
  }

  void _handleGateResult(Map<String, dynamic> res) async {
    if (res['success'] == true) {
      setState(() {
        _statusMessage = 'OTORISASI DISETUJUI!';
      });

      final isOnboarded = await UserInfo.getIsOnboarded();
      final player = SupabaseApiService.getPlayerCache();

      if (!mounted) return;

      if (!isOnboarded) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const OnboardingPage()),
        );
      } else if (player != null && player.hp <= 0) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const GameOverPage()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigationPage()),
        );
      }
    } else {
      setState(() {
        _statusMessage = res['message'] ?? 'Verifikasi biometrik gagal.';
      });
    }
  }

  /// Fallback: Beralih menggunakan Password
  Future<void> _fallbackToPassword() async {
    await UserInfo.autoLogout();
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),

              // Badge Otorisasi Sistem Solo Leveling
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7B1FA2).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF7B1FA2)),
                  ),
                  child: const Text(
                    'SYSTEM BIOMETRIC GATEWAY',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                      color: Color(0xFF00E5FF),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Animasi Aura Pemindaian Wajah / Biometrik
              Center(
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF131B2E),
                          border: Border.all(
                            color: const Color(0xFF00E5FF),
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00E5FF)
                                  .withValues(alpha: 0.35),
                              blurRadius: 30,
                              spreadRadius: 6,
                            ),
                            BoxShadow(
                              color: const Color(0xFF7B1FA2)
                                  .withValues(alpha: 0.25),
                              blurRadius: 40,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: Icon(
                          _faceEnabled
                              ? Icons.face_unlock_outlined
                              : Icons.fingerprint,
                          size: 64,
                          color: const Color(0xFF00E5FF),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),

              // Judul & Indikasi Hunter
              const Text(
                'VERIFIKASI IDENTITAS',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3.0,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Terhubung: $_userIdentifier',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF00E5FF),
                ),
              ),
              const SizedBox(height: 16),

              // Pesan Status Sistem
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF131B2E),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                child: Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color:
                        _statusMessage.contains('gagal') ||
                            _statusMessage.contains('batal')
                        ? const Color(0xFFFF1744)
                        : const Color(0xFF00E5FF),
                  ),
                ),
              ),

              const Spacer(),

              // Tombol-tombol Pemindaian Sesuai Opsi Aktif
              if (_faceEnabled && _fingerprintEnabled) ...[
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isScanning ? null : _executeFaceScan,
                        icon: const Icon(
                          Icons.face_unlock_outlined,
                          color: Colors.black,
                          size: 20,
                        ),
                        label: const Text(
                          'PINDAI WAJAH',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00E5FF),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isScanning ? null : _executeFingerprintScan,
                        icon: const Icon(
                          Icons.fingerprint,
                          color: Colors.black,
                          size: 20,
                        ),
                        label: const Text(
                          'PINDAI SIDIK JARI',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00E5FF),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (_faceEnabled) ...[
                ElevatedButton.icon(
                  onPressed: _isScanning ? null : _executeFaceScan,
                  icon: const Icon(
                    Icons.face_unlock_outlined,
                    color: Colors.black,
                  ),
                  label: Text(
                    _isScanning ? 'MEMINDAI...' : 'PINDAI FACE ID',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5FF),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ] else if (_fingerprintEnabled) ...[
                ElevatedButton.icon(
                  onPressed: _isScanning ? null : _executeFingerprintScan,
                  icon: const Icon(Icons.fingerprint, color: Colors.black),
                  label: Text(
                    _isScanning ? 'MEMINDAI...' : 'PINDAI SIDIK JARI',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5FF),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ] else ...[
                ElevatedButton.icon(
                  onPressed: _isScanning ? null : _executeGeneralScan,
                  icon: const Icon(Icons.security, color: Colors.black),
                  label: Text(
                    _isScanning ? 'MEMINDAI...' : 'PINDAI BIOMETRIK',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5FF),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),

              // Tombol Fallback ke Password
              OutlinedButton.icon(
                onPressed: _fallbackToPassword,
                icon: const Icon(
                  Icons.lock_outline,
                  color: Colors.grey,
                  size: 20,
                ),
                label: const Text(
                  'GUNAKAN PASSWORD',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF1E293B)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
