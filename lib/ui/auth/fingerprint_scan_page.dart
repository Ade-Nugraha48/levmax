// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/ui/auth/fingerprint_scan_page.dart
// Deskripsi: Layar Pemindai & Perekaman Sidik Jari Asli (Fingerprint Scan HUD)
//            Mewajibkan "Setor Sidik Jari" (Enrollment) sebagai patokan sekuritas
//            dengan prosedur serupa dan simetris terhadap Face Scan.
// ==============================================================================

import 'dart:async';

import 'package:flutter/material.dart';

import '../../helpers/user_info.dart';
import '../../services/biometric_service.dart';

enum FingerprintScanMode {
  login,
  register,
  toggle,
  verify,
  enroll, // Setor sidik jari patokan sekuritas
}

enum FingerprintFeedback { neutral, scanning, warning, error, success }

class FingerprintScanPage extends StatefulWidget {
  final FingerprintScanMode mode;
  final String title;
  final String subtitle;

  const FingerprintScanPage({
    super.key,
    this.mode = FingerprintScanMode.login,
    this.title = 'SISTEM PEMINDAIAN SIDIK JARI HUNTER',
    this.subtitle = 'Tempelkan jari Anda pada sensor HP Samsung',
  });

  @override
  State<FingerprintScanPage> createState() => _FingerprintScanPageState();
}

class _FingerprintScanPageState extends State<FingerprintScanPage>
    with TickerProviderStateMixin {
  late FingerprintScanMode _currentMode;
  bool _hasEnrolledBaseline = false;
  bool _isCheckingBaseline = true;

  // Status Pemindaian & Sampel
  bool _isScanning = false;
  int _currentSample = 0;
  static const int _targetSamples =
      3; // 3 kali konfirmasi sentuhan untuk setor patokan

  double _scanProgress = 0.0;
  String _statusText = 'MEMPERSIAPKAN SENSOR SIDIK JARI...';
  FingerprintFeedback _feedback = FingerprintFeedback.neutral;
  bool _isScanComplete = false;

  // Animasi Pulsing & Laser
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _laserController;
  late Animation<double> _laserAnimation;

  @override
  void initState() {
    super.initState();
    _currentMode = widget.mode;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _laserAnimation = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(parent: _laserController, curve: Curves.easeInOut),
    );

    _initializeFingerprintSystem();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _laserController.dispose();
    super.dispose();
  }

  /// Memeriksa status setor sidik jari sebelum memulai pemindaian
  Future<void> _initializeFingerprintSystem() async {
    _hasEnrolledBaseline = await UserInfo.getHasEnrolledFingerprint();

    if (mounted) {
      setState(() {
        _isCheckingBaseline = false;
      });
    }

    // Jika mode adalah login / verify / toggle tapi BELUM setor sidik jari:
    // Wajib setor sidik jari terlebih dahulu!
    if (!_hasEnrolledBaseline &&
        (_currentMode == FingerprintScanMode.login ||
            _currentMode == FingerprintScanMode.verify ||
            _currentMode == FingerprintScanMode.toggle)) {
      if (mounted) {
        setState(() {
          _statusText = 'PATOKAN SIDIK JARI BELUM DISETOR';
          _feedback = FingerprintFeedback.warning;
        });
      }
      return;
    }

    // Beri jeda 400ms agar UI me-render HUD terlebih dahulu lalu memicu sensor
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) {
      _triggerSensorAuthentication();
    }
  }

  /// Memulai dialog hardware sensor sidik jari (BiometricPrompt)
  Future<void> _triggerSensorAuthentication() async {
    if (_isScanning || _isScanComplete) return;

    setState(() {
      _isScanning = true;
      _feedback = FingerprintFeedback.scanning;
      if (_currentMode == FingerprintScanMode.enroll) {
        _statusText =
            'TEMPELKAN JARI ANDA KE SENSOR (${_currentSample + 1}/$_targetSamples)...';
      } else {
        _statusText = 'TEMPELKAN JARI ANDA PADA SENSOR HP SAMSUNG...';
      }
    });

    final reason = _currentMode == FingerprintScanMode.enroll
        ? 'Tempelkan sidik jari Anda untuk merekam sampel patokan (${_currentSample + 1}/$_targetSamples)'
        : 'Tempelkan sidik jari Anda pada sensor untuk verifikasi Hunter LevMax';

    final result = await BiometricService.authenticateFingerprint(
      reason: reason,
    );

    if (!mounted) return;

    setState(() {
      _isScanning = false;
    });

    if (result.success) {
      _onSensorSuccess();
    } else {
      setState(() {
        _feedback = FingerprintFeedback.error;
        _statusText =
            result.errorMessage ?? 'Pemindaian sidik jari dibatalkan.';
      });
    }
  }

  /// Penanganan saat satu sentuhan sidik jari berhasil divalidasi sensor
  void _onSensorSuccess() async {
    // KASUS A: MODE SETOR SIDIK JARI (ENROLLMENT)
    if (_currentMode == FingerprintScanMode.enroll) {
      _currentSample++;
      final progress = (_currentSample / _targetSamples).clamp(0.0, 1.0);

      setState(() {
        _scanProgress = progress;
        _feedback = FingerprintFeedback.success;
      });

      if (_currentSample < _targetSamples) {
        setState(() {
          _statusText =
              'SAMPEL $_currentSample BERHASIL! ANGKAT & TEMPELKAN KEMBALI JARI ANDA...';
        });

        // Beri jeda singkat agar user mengangkat jari lalu minta sentuhan berikutnya
        await Future.delayed(const Duration(milliseconds: 900));
        if (mounted) {
          _triggerSensorAuthentication();
        }
      } else {
        // Semua 3 sampel selesai disetor
        _isScanComplete = true;
        await UserInfo.saveEnrolledFingerprint();
        await UserInfo.setFingerprintEnabled(true);

        setState(() {
          _scanProgress = 1.0;
          _statusText =
              'PATOKAN SIDIK JARI BERHASIL DISIMPAN KE SISTEM LEVMAX!';
        });

        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          Navigator.pop(context, true);
        }
      }
    }
    // KASUS B: MODE LOGIN / VERIFIKASI / TOGGLE
    else {
      _isScanComplete = true;
      setState(() {
        _scanProgress = 1.0;
        _feedback = FingerprintFeedback.success;
        _statusText = 'OTORISASI SIDIK JARI BERHASIL DISAHKAN!';
      });

      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  /// Beralih secara dinamis ke mode "Setor Sidik Jari"
  void _switchToEnrollmentMode() {
    setState(() {
      _currentMode = FingerprintScanMode.enroll;
      _currentSample = 0;
      _scanProgress = 0.0;
      _statusText = 'MEMPERSIAPKAN PEREKAMAN PATOKAN SIDIK JARI...';
      _feedback = FingerprintFeedback.neutral;
    });
    _triggerSensorAuthentication();
  }

  Color _getScannerColor() {
    if (_isScanComplete) return const Color(0xFF00E5FF);
    switch (_feedback) {
      case FingerprintFeedback.success:
        return const Color(0xFF00E5FF);
      case FingerprintFeedback.error:
        return const Color(0xFFFF1744);
      case FingerprintFeedback.warning:
        return const Color(0xFFFFB300);
      case FingerprintFeedback.scanning:
        return const Color(0xFF00E5FF);
      case FingerprintFeedback.neutral:
        return const Color(0xFF7B1FA2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scannerColor = _getScannerColor();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            children: [
              // Top App Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Color(0xFF00E5FF),
                    ),
                    onPressed: () => Navigator.pop(context, false),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131B2E).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: scannerColor, width: 1.2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _currentMode == FingerprintScanMode.enroll
                              ? Icons.app_registration
                              : Icons.fingerprint,
                          color: scannerColor,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _currentMode == FingerprintScanMode.enroll
                              ? 'SETOR SIDIK JARI PATOKAN'
                              : 'VERIFIKASI SENSOR SIDIK JARI',
                          style: TextStyle(
                            color: scannerColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 48), // Spacer penyeimbang
                ],
              ),

              const SizedBox(height: 16),
              Text(
                _currentMode == FingerprintScanMode.enroll
                    ? 'SETOR PATOKAN SIDIK JARI HUNTER'
                    : widget.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _currentMode == FingerprintScanMode.enroll
                    ? 'Lakukan 3 sentuhan bertahap untuk merekam patokan sidik jari sekuritas'
                    : widget.subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),

              const Spacer(),

              // KARTU JIKA PATOKAN BELUM DISETOR
              if (!_hasEnrolledBaseline &&
                  !_isCheckingBaseline &&
                  _currentMode != FingerprintScanMode.enroll)
                Container(
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131B2E).withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFFFB300),
                      width: 1.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFB300).withValues(alpha: 0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Color(0xFFFFB300),
                            size: 28,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'SIDIK JARI PATOKAN BELUM DISETOR',
                              style: TextStyle(
                                color: Color(0xFFFFB300),
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Sistem keamanan LevMax mewajibkan Anda untuk menyetor sidik jari patokan terlebih dahulu agar sensor dapat digunakan untuk otorisasi.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _switchToEnrollmentMode,
                        icon: const Icon(
                          Icons.fingerprint,
                          color: Colors.black,
                        ),
                        label: const Text(
                          'SETOR SIDIK JARI SEKARANG',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00E5FF),
                          foregroundColor: Colors.black,
                          minimumSize: const Size.fromHeight(46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                // CYBERPUNK FINGERPRINT SCANNER APERTURE
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Ring Luar Cyberpunk
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseAnimation.value,
                            child: Container(
                              width: 220,
                              height: 220,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF131B2E)
                                    .withValues(alpha: 0.6),
                                border: Border.all(
                                  color: scannerColor.withValues(alpha: 0.4),
                                  width: 2.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: scannerColor.withValues(alpha: 0.35),
                                    blurRadius: 36,
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
                            ),
                          );
                        },
                      ),

                      // Ring Dalam Pemindai
                      Container(
                        width: 170,
                        height: 170,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF0A0E1A),
                          border: Border.all(color: scannerColor, width: 2.5),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.fingerprint,
                            size: 96,
                            color: scannerColor,
                          ),
                        ),
                      ),

                      // Laser Scan Vertikal
                      if (_isScanning)
                        AnimatedBuilder(
                          animation: _laserAnimation,
                          builder: (context, child) {
                            return Positioned(
                              top: 110 + (_laserAnimation.value * 70),
                              child: Container(
                                width: 140,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: scannerColor,
                                  boxShadow: [
                                    BoxShadow(
                                      color: scannerColor.withValues(
                                        alpha: 0.9,
                                      ),
                                      blurRadius: 12,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),

              const Spacer(),

              // BOTTOM HUD PANEL STATUS
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF131B2E).withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: scannerColor, width: 1.8),
                  boxShadow: [
                    BoxShadow(
                      color: scannerColor.withValues(alpha: 0.3),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _isScanComplete
                                  ? Icons.verified
                                  : Icons.fingerprint,
                              color: scannerColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isScanComplete
                                  ? 'SELESAI DISAHKAN'
                                  : _currentMode == FingerprintScanMode.enroll
                                  ? 'PROGRES SETOR PATOKAN'
                                  : 'STATUS SENSOR',
                              style: TextStyle(
                                color: scannerColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${(_scanProgress * 100).toInt()}%',
                          style: TextStyle(
                            color: scannerColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: _scanProgress,
                      backgroundColor: const Color(0xFF0A0E1A),
                      color: scannerColor,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _statusText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: scannerColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Tombol Pemicu Ulang jika sensor tertutup/batal
              if (!_isScanning &&
                  !_isScanComplete &&
                  (_hasEnrolledBaseline ||
                      _currentMode == FingerprintScanMode.enroll))
                ElevatedButton.icon(
                  onPressed: _triggerSensorAuthentication,
                  icon: const Icon(Icons.fingerprint, color: Colors.black),
                  label: Text(
                    _currentMode == FingerprintScanMode.enroll
                        ? 'TEMPELKAN SAMPEL ${_currentSample + 1}/$_targetSamples'
                        : 'PINDAI ULANG SIDIK JARI',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5FF),
                    foregroundColor: Colors.black,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
