// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/ui/auth/face_scan_camera_page.dart
// Deskripsi: Layar Pemindai Wajah Asli Menggunakan Kamera Depan Fisik & ML Kit Face Detection.
//            Mewajibkan "Setor Wajah" (Enrollment) sebagai patokan sekuritas,
//            menolak autentikasi jika wajah tidak terdeteksi atau tidak cocok.
// ==============================================================================

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../helpers/face_biometric_helper.dart';
import '../../helpers/user_info.dart';

enum FaceScanMode {
  login,
  register,
  toggle,
  verify,
  enroll, // Setor wajah patokan sekuritas
}

enum FaceScanFeedback {
  neutral,
  noFace,
  warning,
  mismatch,
  success,
}

class FaceScanCameraPage extends StatefulWidget {
  final FaceScanMode mode;
  final String title;
  final String subtitle;

  const FaceScanCameraPage({
    super.key,
    this.mode = FaceScanMode.login,
    this.title = 'SISTEM PEMINDAIAN WAJAH HUNTER',
    this.subtitle = 'Posisikan wajah Anda tepat di dalam lingkaran pemindai',
  });

  @override
  State<FaceScanCameraPage> createState() => _FaceScanCameraPageState();
}

class _FaceScanCameraPageState extends State<FaceScanCameraPage>
    with TickerProviderStateMixin {
  CameraController? _cameraController;
  List<CameraDescription> _availableCameras = [];
  bool _isCameraInitialized = false;
  bool _isCameraError = false;
  String _errorMessage = '';

  // Google ML Kit Face Detector
  late FaceDetector _faceDetector;
  bool _isProcessingFrame = false;
  bool _isScanningActive = false;

  // Mode Operasi & Patokan Wajah
  late FaceScanMode _currentMode;
  FaceBiometricVector? _baselineTemplate;
  bool _hasEnrolledBaseline = false;
  bool _isCheckingBaseline = true;

  // Koleksi Sampel Saat "Setor Wajah" (Enrollment)
  final List<FaceBiometricVector> _enrollmentSamples = [];
  static const int _targetEnrollmentSamples = 5;

  // Verifikasi Streak Saat Login / Verify
  int _consecutiveMatchCount = 0;
  static const int _targetMatchStreak = 3;

  // Animasi Laser & Aperture
  late AnimationController _scanLaserController;
  late Animation<double> _scanLaserAnimation;
  late AnimationController _rotationController;

  double _scanProgress = 0.0;
  String _statusText = 'MENGINISIALISASI SENSOR KAMERA...';
  FaceScanFeedback _feedbackState = FaceScanFeedback.neutral;
  bool _isScanComplete = false;

  @override
  void initState() {
    super.initState();
    _currentMode = widget.mode;

    // Inisialisasi ML Kit Face Detector dengan deteksi landmark presisi tinggi
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableLandmarks: true,
        enableClassification: true,
        enableTracking: true,
        performanceMode: FaceDetectorMode.accurate,
        minFaceSize: 0.15,
      ),
    );

    _scanLaserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _scanLaserAnimation = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanLaserController, curve: Curves.easeInOut),
    );

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _initializeFaceSystem();
  }

  @override
  void dispose() {
    _isScanningActive = false;
    _scanLaserController.dispose();
    _rotationController.dispose();
    _cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  /// Memeriksa ketersediaan patokan wajah dan inisialisasi kamera depan
  Future<void> _initializeFaceSystem() async {
    // 1. Cek apakah sudah pernah setor wajah
    _hasEnrolledBaseline = await UserInfo.getHasEnrolledFace();
    if (_hasEnrolledBaseline) {
      final templateMap = await UserInfo.getEnrolledFaceTemplate();
      if (templateMap != null) {
        _baselineTemplate = FaceBiometricVector.fromMap(templateMap);
      } else {
        _hasEnrolledBaseline = false;
      }
    }

    if (mounted) {
      setState(() {
        _isCheckingBaseline = false;
      });
    }

    // Jika mode adalah login / verify / toggle tetapi BELUM setor wajah:
    // User harus diarahkan untuk setor wajah terlebih dahulu!
    if (!_hasEnrolledBaseline &&
        (_currentMode == FaceScanMode.login ||
            _currentMode == FaceScanMode.verify ||
            _currentMode == FaceScanMode.toggle)) {
      if (mounted) {
        setState(() {
          _statusText = 'PATOKAN WAJAH BELUM DISETOR';
          _feedbackState = FaceScanFeedback.warning;
        });
      }
      return;
    }

    await _initCamera();
  }

  /// Inisialisasi Hardware Kamera Depan Samsung Galaxy M31 / Android
  Future<void> _initCamera() async {
    try {
      _availableCameras = await availableCameras();
      if (_availableCameras.isEmpty) {
        if (mounted) {
          setState(() {
            _isCameraError = true;
            _errorMessage = 'Tidak ditemukan hardware kamera pada perangkat ini.';
          });
        }
        return;
      }

      // Cari kamera depan (front-facing)
      CameraDescription frontCamera = _availableCameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => _availableCameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();

      if (!mounted) return;

      setState(() {
        _isCameraInitialized = true;
        _isScanningActive = true;
        if (_currentMode == FaceScanMode.enroll || _currentMode == FaceScanMode.register) {
          _statusText = 'ARAHKAN WAJAH KE DALAM LINGKARAN UNTUK SETOR PATOKAN';
        } else {
          _statusText = 'ARAHKAN WAJAH KE KAMERA UNTUK VERIFIKASI';
        }
      });

      // Mulai loop pemindaian deteksi wajah nyata (Real On-Device Face Detection)
      _startLiveFaceDetectionLoop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCameraError = true;
          _errorMessage = 'Gagal mengakses kamera: $e\nHarap pastikan izin kamera diaktifkan.';
        });
      }
    }
  }

  /// Loop berkelanjutan untuk memproses frame kamera depan secara aman
  void _startLiveFaceDetectionLoop() async {
    while (_isScanningActive && mounted && !_isScanComplete) {
      if (!_isProcessingFrame &&
          _cameraController != null &&
          _cameraController!.value.isInitialized) {
        _isProcessingFrame = true;
        try {
          // Ambil frame JPEG langsung dari CameraController
          final xFile = await _cameraController!.takePicture();
          final file = File(xFile.path);

          if (await file.exists()) {
            final inputImage = InputImage.fromFile(file);
            final faces = await _faceDetector.processImage(inputImage);

            // Bersihkan file sementara pratinjau
            try {
              await file.delete();
            } catch (_) {}

            if (mounted && _isScanningActive && !_isScanComplete) {
              _evaluateDetectedFaces(faces);
            }
          }
        } catch (e) {
          debugPrint('Face detection frame error: $e');
        } finally {
          _isProcessingFrame = false;
        }
      }

      // Interval 220ms antara deteksi agar perangkat tetap sejuk dan responsif
      await Future.delayed(const Duration(milliseconds: 220));
    }
  }

  /// Evaluasi Hasil Deteksi Wajah ML Kit Realtime
  void _evaluateDetectedFaces(List<Face> faces) {
    // 1. KASUS KRUSIAL: Tidak ada wajah di depan kamera
    if (faces.isEmpty) {
      setState(() {
        _feedbackState = FaceScanFeedback.noFace;
        _statusText = 'WAJAH TIDAK TERDETEKSI! Posisikan wajah di dalam lingkaran';
        _consecutiveMatchCount = 0;
        if (_currentMode != FaceScanMode.enroll) {
          _scanProgress = 0.0;
        }
      });
      return;
    }

    // 2. KASUS: Lebih dari satu wajah terdeteksi dalam frame
    if (faces.length > 1) {
      setState(() {
        _feedbackState = FaceScanFeedback.warning;
        _statusText = 'TERDETEKSI LEBIH DARI 1 WAJAH! Pastikan hanya wajah Anda';
        _consecutiveMatchCount = 0;
      });
      return;
    }

    final face = faces.first;

    // 3. Evaluasi Kualitas Pose & Posisi Wajah
    final eval = FaceBiometricHelper.evaluateFace(face);
    if (!eval.isEligible || eval.vector == null) {
      setState(() {
        _feedbackState = FaceScanFeedback.warning;
        _statusText = eval.statusMessage;
        _consecutiveMatchCount = 0;
      });
      return;
    }

    final liveVector = eval.vector!;

    // 4. CABANG A: MODE SETOR WAJAH (ENROLLMENT)
    if (_currentMode == FaceScanMode.enroll || _currentMode == FaceScanMode.register) {
      _processEnrollmentStep(liveVector);
    }
    // 5. CABANG B: MODE VERIFIKASI / LOGIN (VERIFY DENGAN PATOKAN)
    else {
      _processVerificationStep(liveVector);
    }
  }

  /// Pemrosesan pengumpulan sampel saat "Setor Wajah"
  void _processEnrollmentStep(FaceBiometricVector liveVector) async {
    _enrollmentSamples.add(liveVector);
    final count = _enrollmentSamples.length;
    final progress = (count / _targetEnrollmentSamples).clamp(0.0, 1.0);

    setState(() {
      _scanProgress = progress;
      _feedbackState = FaceScanFeedback.success;
      _statusText = 'MEREKAM PATOKAN WAJAH: $count/$_targetEnrollmentSamples (TETAP DIAM)';
    });

    if (count >= _targetEnrollmentSamples) {
      _isScanComplete = true;
      _isScanningActive = false;

      // Hitung rata-rata sampel untuk dijadikan baseline stabil
      final averageBaseline = FaceBiometricHelper.averageVectors(_enrollmentSamples);

      // Simpan baseline ke SharedPreferences via UserInfo
      await UserInfo.saveEnrolledFaceTemplate(averageBaseline.toMap());
      await UserInfo.setFaceIdEnabled(true);

      setState(() {
        _scanProgress = 1.0;
        _statusText = 'WAJAH PATOKAN BERHASIL DISIMPAN KE SISTEM!';
      });

      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  /// Pemrosesan verifikasi live face terhadap baseline template yang telah disetor
  void _processVerificationStep(FaceBiometricVector liveVector) async {
    if (_baselineTemplate == null) {
      setState(() {
        _feedbackState = FaceScanFeedback.warning;
        _statusText = 'PATOKAN WAJAH TIDAK DITEMUKAN! Harap setor wajah.';
      });
      return;
    }

    // Hitung tingkat kecocokan (Similarity Score)
    final similarity = liveVector.similarityWith(_baselineTemplate!);
    final matchPercentage = (similarity * 100).toInt();

    // Ambang batas standar keamanan industri: 70% kecocokan landmark geometri
    if (similarity >= 0.70) {
      _consecutiveMatchCount++;
      final progress = (_consecutiveMatchCount / _targetMatchStreak).clamp(0.0, 1.0);

      setState(() {
        _feedbackState = FaceScanFeedback.success;
        _scanProgress = progress;
        _statusText = 'WAJAH SESUAI ($matchPercentage% COCOK) - MENYAHKAN OTORISASI...';
      });

      if (_consecutiveMatchCount >= _targetMatchStreak) {
        _isScanComplete = true;
        _isScanningActive = false;

        setState(() {
          _scanProgress = 1.0;
          _statusText = 'OTORISASI WAJAH HUNTER BERHASIL DISAHKAN!';
        });

        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          Navigator.pop(context, true);
        }
      }
    } else {
      // Wajah tidak cocok dengan patokan
      _consecutiveMatchCount = 0;
      setState(() {
        _feedbackState = FaceScanFeedback.mismatch;
        _scanProgress = 0.0;
        _statusText = 'WAJAH TIDAK COCOK DENGAN PATOKAN! ($matchPercentage% cocok)';
      });
    }
  }

  /// Beralih secara dinamis ke mode "Setor Wajah" (Enrollment)
  void _switchToEnrollmentMode() {
    setState(() {
      _currentMode = FaceScanMode.enroll;
      _enrollmentSamples.clear();
      _scanProgress = 0.0;
      _statusText = 'MEMPERSIAPKAN SENSOR SETOR WAJAH...';
      _feedbackState = FaceScanFeedback.neutral;
    });
    _initCamera();
  }

  Color _getApertureBorderColor() {
    if (_isScanComplete) return const Color(0xFF00E5FF);
    switch (_feedbackState) {
      case FaceScanFeedback.success:
        return const Color(0xFF00E5FF);
      case FaceScanFeedback.mismatch:
        return const Color(0xFFFF1744);
      case FaceScanFeedback.noFace:
        return const Color(0xFFFFB300);
      case FaceScanFeedback.warning:
        return const Color(0xFFFF9100);
      case FaceScanFeedback.neutral:
        return const Color(0xFF00E5FF).withValues(alpha: 0.6);
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = _getApertureBorderColor();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: SafeArea(
        child: Stack(
          children: [
            // 1. LAYER PRATINJAU KAMERA DEPAN
            if (_isCameraInitialized && _cameraController != null)
              Positioned.fill(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _cameraController!.value.previewSize?.height ?? 1,
                    height: _cameraController!.value.previewSize?.width ?? 1,
                    child: CameraPreview(_cameraController!),
                  ),
                ),
              )
            else if (_isCameraError)
              Positioned.fill(
                child: Container(
                  color: const Color(0xFF0A0E1A),
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.camera_alt_outlined, color: Color(0xFFFF1744), size: 64),
                        const SizedBox(height: 16),
                        const Text(
                          'AKSES KAMERA TERHAMBAT',
                          style: TextStyle(color: Color(0xFFFF1744), fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _initCamera,
                          icon: const Icon(Icons.refresh, color: Colors.black),
                          label: const Text('COBA LAGI'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00E5FF),
                            foregroundColor: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Positioned.fill(
                child: Container(
                  color: const Color(0xFF0A0E1A),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Color(0xFF00E5FF)),
                        SizedBox(height: 16),
                        Text(
                          'MENGHUBUNGKAN KE KAMERA DEPAN...',
                          style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // 2. LAYER OVERLAY GELAP DENGAN CUT-OUT LINGKARAN WAJAH
            Positioned.fill(
              child: CustomPaint(
                painter: FaceApertureOverlayPainter(
                  isComplete: _isScanComplete,
                  progress: _scanProgress,
                  borderColor: borderColor,
                ),
              ),
            ),

            // 3. LAYER ANIMASI LASER PEMINDAI
            if (_isCameraInitialized && !_isScanComplete)
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final centerX = constraints.maxWidth / 2;
                    final centerY = constraints.maxHeight * 0.42;
                    final radius = constraints.maxWidth * 0.38;

                    return AnimatedBuilder(
                      animation: _scanLaserAnimation,
                      builder: (context, child) {
                        final laserY = centerY + (_scanLaserAnimation.value * radius);

                        return Stack(
                          children: [
                            Positioned(
                              left: centerX - radius + 10,
                              right: constraints.maxWidth - (centerX + radius) + 10,
                              top: laserY,
                              child: Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  color: borderColor,
                                  boxShadow: [
                                    BoxShadow(
                                      color: borderColor.withValues(alpha: 0.8),
                                      blurRadius: 12,
                                      spreadRadius: 2,
                                    ),
                                    BoxShadow(
                                      color: const Color(0xFF7B1FA2).withValues(alpha: 0.6),
                                      blurRadius: 20,
                                      spreadRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),

            // 4. LAYER HUD ELEMEN SOLO LEVELING & KONTROL
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  children: [
                    // Top App Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF00E5FF)),
                          onPressed: () => Navigator.pop(context, false),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF131B2E).withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: borderColor, width: 1.2),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _currentMode == FaceScanMode.enroll
                                    ? Icons.app_registration
                                    : Icons.videocam_outlined,
                                color: borderColor,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _currentMode == FaceScanMode.enroll
                                    ? 'SETOR WAJAH PATOKAN'
                                    : 'VERIFIKASI WAJAH FISIK',
                                style: TextStyle(
                                  color: borderColor,
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

                    const SizedBox(height: 12),
                    Text(
                      _currentMode == FaceScanMode.enroll
                          ? 'SETOR PATOKAN WAJAH HUNTER'
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
                      _currentMode == FaceScanMode.enroll
                          ? 'Posisikan wajah Anda tegak ke kamera untuk merekam struktur biometrik'
                          : widget.subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),

                    const Spacer(),

                    // KARTU KHUSUS: JIKA BELUM SETOR WAJAH DAN BUKAN MODE ENROLL
                    if (!_hasEnrolledBaseline &&
                        !_isCheckingBaseline &&
                        _currentMode != FaceScanMode.enroll)
                      Container(
                        padding: const EdgeInsets.all(20),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF131B2E).withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFFFB300), width: 1.8),
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
                                Icon(Icons.warning_amber_rounded, color: Color(0xFFFFB300), size: 28),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'WAJAH PATOKAN BELUM DISETOR',
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
                              'Sistem keamanan LevMax mewajibkan Anda untuk menyetor wajah patokan terlebih dahulu agar sistem dapat memvalidasi identitas Hunter Anda.',
                              style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _switchToEnrollmentMode,
                              icon: const Icon(Icons.face, color: Colors.black),
                              label: const Text('SETOR WAJAH SEKARANG', style: TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00E5FF),
                                foregroundColor: Colors.black,
                                minimumSize: const Size.fromHeight(46),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      // BOTTOM HUD PANEL STATUS DETEKSI
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF131B2E).withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: borderColor,
                            width: 1.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: borderColor.withValues(alpha: 0.35),
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
                                          : _feedbackState == FaceScanFeedback.mismatch
                                              ? Icons.highlight_off
                                              : _feedbackState == FaceScanFeedback.noFace
                                                  ? Icons.person_off_outlined
                                                  : Icons.face_retouching_natural,
                                      color: borderColor,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _isScanComplete
                                          ? 'SELESAI DISAHKAN'
                                          : _currentMode == FaceScanMode.enroll
                                              ? 'PROGRES SETOR PATOKAN'
                                              : 'STATUS KECOCOKAN',
                                      style: TextStyle(
                                        color: borderColor,
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
                                    color: borderColor,
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
                              color: borderColor,
                              minHeight: 6,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _statusText,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: borderColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// CustomPainter untuk membuat efek aperture lingkaran scanner wajah futuristik dengan dynamic border color
class FaceApertureOverlayPainter extends CustomPainter {
  final bool isComplete;
  final double progress;
  final Color borderColor;

  FaceApertureOverlayPainter({
    required this.isComplete,
    required this.progress,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.42);
    final radius = size.width * 0.38;

    // 1. Gambar latar belakang gelap di luar aperture lingkaran
    final bgPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final circlePath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));

    final overlayPath = Path.combine(PathOperation.difference, bgPath, circlePath);
    final overlayPaint = Paint()
      ..color = const Color(0xFF0A0E1A).withValues(alpha: 0.88);
    canvas.drawPath(overlayPath, overlayPaint);

    // 2. Gambar lingkaran border pemindai
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = isComplete ? 3.5 : 2.5;
    canvas.drawCircle(center, radius, borderPaint);

    // 3. Gambar sudut target cyberpunk (Target corners)
    final cornerPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    const double cornerLen = 28.0;
    final double offset = radius + 8.0;

    // Kiri Atas
    canvas.drawLine(Offset(center.dx - offset, center.dy - offset + cornerLen), Offset(center.dx - offset, center.dy - offset), cornerPaint);
    canvas.drawLine(Offset(center.dx - offset, center.dy - offset), Offset(center.dx - offset + cornerLen, center.dy - offset), cornerPaint);

    // Kanan Atas
    canvas.drawLine(Offset(center.dx + offset - cornerLen, center.dy - offset), Offset(center.dx + offset, center.dy - offset), cornerPaint);
    canvas.drawLine(Offset(center.dx + offset, center.dy - offset), Offset(center.dx + offset, center.dy - offset + cornerLen), cornerPaint);

    // Kiri Bawah
    canvas.drawLine(Offset(center.dx - offset, center.dy + offset - cornerLen), Offset(center.dx - offset, center.dy + offset), cornerPaint);
    canvas.drawLine(Offset(center.dx - offset, center.dy + offset), Offset(center.dx - offset + cornerLen, center.dy + offset), cornerPaint);

    // Kanan Bawah
    canvas.drawLine(Offset(center.dx + offset - cornerLen, center.dy + offset), Offset(center.dx + offset, center.dy + offset), cornerPaint);
    canvas.drawLine(Offset(center.dx + offset, center.dy + offset), Offset(center.dx + offset, center.dy + offset - cornerLen), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant FaceApertureOverlayPainter oldDelegate) {
    return oldDelegate.isComplete != isComplete ||
        oldDelegate.progress != progress ||
        oldDelegate.borderColor != borderColor;
  }
}
