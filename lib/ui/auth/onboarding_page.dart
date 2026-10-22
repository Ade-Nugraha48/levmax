// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/ui/auth/onboarding_page.dart
// Deskripsi: Superprompt Prompt 8 - "The Awakening Trial"
//            Fase 1: Vessel Metrics (Input BMI & Penentuan Temp Rank E / F)
//            Fase 2: The Physical Trial (Live Camera Feed + ML-Kit Pose Detection
//                    Stream Processing, Penghitungan Sudut Sendi dengan atan2,
//                    State Machine Naik/Turun, Timer 60s, & Jeda Istirahat 5s)
//            Fase 3: Result & Re-Awakening Sync (Evaluasi Promosi Rank, Hive
//                    Auth/Player Cache, dan Sinkronisasi Cloud Supabase users)
// ==============================================================================

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../helpers/levmax_theme.dart';
import '../../helpers/user_info.dart';
import '../../models/user_model.dart';
import '../../services/supabase_api_service.dart';

/// Jenis Ujian Fisik dalam The Awakening Trial
enum WorkoutSessionType {
  pushup('PUSH-UP', 'Dada & Triceps', 30, Icons.fitness_center),
  situp('SIT-UP', 'Core & Abdomen', 30, Icons.sports_gymnastics),
  squat('SQUAT', 'Quadriceps & Glutes', 40, Icons.accessibility_new),
  pullup('PULL-UP', 'Lats & Biceps', 2, Icons.horizontal_rule);

  final String title;
  final String muscleGroup;
  final int bonusThreshold;
  final IconData icon;
  const WorkoutSessionType(
    this.title,
    this.muscleGroup,
    this.bonusThreshold,
    this.icon,
  );
}

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with TickerProviderStateMixin {
  // PageController untuk Navigasi 3 Fase
  final PageController _pageController = PageController();
  int _activePageIndex = 0;

  // ============================================================================
  // FASE 1 STATE: STATISTIK ANTROPOMETRI (VESSEL METRICS & BMI)
  // ============================================================================
  double _tbCm = 175.0;
  double _bbKg = 68.0;
  String _tempRank = 'E'; // Default kalkulasi awal
  double _calculatedBmi = 22.2;

  // ============================================================================
  // FASE 2 STATE: THE PHYSICAL TRIAL (KAMERA & ML-KIT POSE DETECTION)
  // ============================================================================
  CameraController? _cameraController;
  List<CameraDescription> _availableCameras = [];
  int _selectedCameraIndex = 0;
  bool _isCameraInitialized = false;
  bool _isCameraError = false;
  String _cameraErrorMessage = '';

  // Google ML Kit Pose Detector
  PoseDetector? _poseDetector;
  bool _isProcessingFrame = false;
  bool _isSessionActive = false;

  // Daftar Sesi Latihan: Push-up -> Sit-up -> Squat -> Pull-up
  final List<WorkoutSessionType> _sessions = [
    WorkoutSessionType.pushup,
    WorkoutSessionType.situp,
    WorkoutSessionType.squat,
    WorkoutSessionType.pullup,
  ];
  int _currentSessionIndex = 0;
  WorkoutSessionType get _currentSession => _sessions[_currentSessionIndex];

  // State Machine Inflection Point (Naik / Turun)
  bool _isDownPosition = false;

  // Hasil Akhir Repetisi
  int _pushupCount = 0;
  int _situpCount = 0;
  int _squatCount = 0;
  int _pullupCount = 0;

  // Timer & ValueNotifiers untuk UI 60 FPS tanpa setState di imageStream
  Timer? _trialTimer;
  Timer? _restTimer;
  final ValueNotifier<int> _remainingSecondsNotifier = ValueNotifier<int>(60);
  final ValueNotifier<int> _repCountNotifier = ValueNotifier<int>(0);
  final ValueNotifier<double> _angleNotifier = ValueNotifier<double>(180.0);
  final ValueNotifier<String> _feedbackNotifier = ValueNotifier<String>(
    'POSISIKAN SELURUH TUBUH DALAM RETICLE KAMERA',
  );
  final ValueNotifier<bool> _isRestingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<int> _restSecondsNotifier = ValueNotifier<int>(5);

  // Animasi Glitch & HUD Pulse
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Map rotasi perangkat resmi Android
  static final Map<DeviceOrientation, int> _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  @override
  void initState() {
    super.initState();
    _calculateBmiAndTempRank();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Inisialisasi Google ML Kit Pose Detector dengan mode stream
    final options = PoseDetectorOptions(
      mode: PoseDetectionMode.stream,
      model: PoseDetectionModel.base,
    );
    _poseDetector = PoseDetector(options: options);
  }

  @override
  void dispose() {
    _trialTimer?.cancel();
    _restTimer?.cancel();
    _pulseController.dispose();
    _stopAndDisposeCamera();
    _poseDetector?.close();
    _remainingSecondsNotifier.dispose();
    _repCountNotifier.dispose();
    _angleNotifier.dispose();
    _feedbackNotifier.dispose();
    _isRestingNotifier.dispose();
    _restSecondsNotifier.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // ============================================================================
  // LOGIKA MATEMATIKA KALKULASI SUDUT SENDI (ATAN2 SESUAI PERSYARATAN)
  // ============================================================================

  /// Menghitung sudut sendi antara 3 titik landmark tubuh:
  /// firstPoint (titik awal), midPoint (sendi vertex), lastPoint (titik akhir).
  /// Menggunakan atan2 untuk akurasi radian dan mengonversinya ke rentang 0 - 180 derajat.
  double getAngle(
    PoseLandmark firstPoint,
    PoseLandmark midPoint,
    PoseLandmark lastPoint,
  ) {
    final radians =
        math.atan2(lastPoint.y - midPoint.y, lastPoint.x - midPoint.x) -
        math.atan2(firstPoint.y - midPoint.y, firstPoint.x - midPoint.x);
    var angle = (radians * 180.0 / math.pi).abs();
    if (angle > 180.0) {
      angle = 360.0 - angle;
    }
    return angle;
  }

  // ============================================================================
  // LOGIKA KONVERSI CAMERAIMAGE KE INPUTIMAGE (ML-KIT YUV420 ROTASI SENSOR)
  // ============================================================================

  /// Mengonversi CameraImage stream menjadi InputImage untuk ML Kit
  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_cameraController == null || _availableCameras.isEmpty) return null;

    final camera = _availableCameras[_selectedCameraIndex];
    final sensorOrientation = camera.sensorOrientation;

    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation =
          _orientations[_cameraController!.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    rotation ??= InputImageRotation.rotation0deg;

    // Deteksi Format Pixel
    final format =
        InputImageFormatValue.fromRawValue(image.format.raw) ??
        (Platform.isAndroid
            ? InputImageFormat.nv21
            : InputImageFormat.bgra8888);

    // Gabungkan seluruh plane bytes (Y, U, V)
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: format,
      bytesPerRow: image.planes.first.bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }

  /// Callback pemrosesan frame realtime kamera
  Future<void> _processCameraImage(CameraImage image) async {
    // Hindari pemrosesan ganda, kondisi jeda istirahat, atau sesi non-aktif
    if (_isProcessingFrame ||
        !_isSessionActive ||
        _isRestingNotifier.value ||
        _activePageIndex != 1) {
      return;
    }

    _isProcessingFrame = true;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) {
        _isProcessingFrame = false;
        return;
      }

      final poses = await _poseDetector?.processImage(inputImage);
      if (poses != null && poses.isNotEmpty && _isSessionActive) {
        _evaluatePose(poses.first);
      } else {
        _feedbackNotifier.value = 'MENCARI SILUET HUNTER DALAM RETICLE...';
      }
    } catch (e) {
      debugPrint('[ML-Kit Pose Stream] Error: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }

  // ============================================================================
  // STATE MACHINE EVALUASI SENDI NAIK / TURUN SESI UJIAN FISIK
  // ============================================================================

  void _evaluatePose(Pose pose) {
    PoseLandmark? p1Left, p2Left, p3Left;
    PoseLandmark? p1Right, p2Right, p3Right;

    double lowerThreshold = 90.0;
    double upperThreshold = 150.0;

    switch (_currentSession) {
      case WorkoutSessionType.pushup:
        // Push-up: Bahu (shoulder), Siku (elbow), Pergelangan Tangan (wrist)
        p1Left = pose.landmarks[PoseLandmarkType.leftShoulder];
        p2Left = pose.landmarks[PoseLandmarkType.leftElbow];
        p3Left = pose.landmarks[PoseLandmarkType.leftWrist];

        p1Right = pose.landmarks[PoseLandmarkType.rightShoulder];
        p2Right = pose.landmarks[PoseLandmarkType.rightElbow];
        p3Right = pose.landmarks[PoseLandmarkType.rightWrist];

        lowerThreshold = 90.0; // Siku tertekuk maksimal saat dada turun
        upperThreshold = 155.0; // Lengan lurus saat mendorong ke atas
        break;

      case WorkoutSessionType.situp:
        // Sit-up: Bahu (shoulder), Pinggul (hip), Lutut (knee)
        p1Left = pose.landmarks[PoseLandmarkType.leftShoulder];
        p2Left = pose.landmarks[PoseLandmarkType.leftHip];
        p3Left = pose.landmarks[PoseLandmarkType.leftKnee];

        p1Right = pose.landmarks[PoseLandmarkType.rightShoulder];
        p2Right = pose.landmarks[PoseLandmarkType.rightHip];
        p3Right = pose.landmarks[PoseLandmarkType.rightKnee];

        lowerThreshold = 75.0; // Badan ditekuk ke atas mendekati lutut
        upperThreshold = 125.0; // Badan kembali berbaring di matras
        break;

      case WorkoutSessionType.squat:
        // Squat: Pinggul (hip), Lutut (knee), Pergelangan Kaki (ankle)
        p1Left = pose.landmarks[PoseLandmarkType.leftHip];
        p2Left = pose.landmarks[PoseLandmarkType.leftKnee];
        p3Left = pose.landmarks[PoseLandmarkType.leftAnkle];

        p1Right = pose.landmarks[PoseLandmarkType.rightHip];
        p2Right = pose.landmarks[PoseLandmarkType.rightKnee];
        p3Right = pose.landmarks[PoseLandmarkType.rightAnkle];

        lowerThreshold = 95.0; // Paha sejajar lantai saat jongkok
        upperThreshold = 160.0; // Kaki berdiri tegak lurus sempurna
        break;

      case WorkoutSessionType.pullup:
        // Pull-up: Pergelangan Tangan (wrist), Siku (elbow), Bahu (shoulder)
        p1Left = pose.landmarks[PoseLandmarkType.leftWrist];
        p2Left = pose.landmarks[PoseLandmarkType.leftElbow];
        p3Left = pose.landmarks[PoseLandmarkType.leftShoulder];

        p1Right = pose.landmarks[PoseLandmarkType.rightWrist];
        p2Right = pose.landmarks[PoseLandmarkType.rightElbow];
        p3Right = pose.landmarks[PoseLandmarkType.rightShoulder];

        lowerThreshold = 85.0; // Dagu melewati bar, siku tertekuk
        upperThreshold = 150.0; // Lengan menggantung lurus ke bawah
        break;
    }

    // Tentukan sisi tubuh terbaik dengan likelihood kepercayaan tertinggi
    double? detectedAngle;
    final bool leftValid =
        p1Left != null &&
        p2Left != null &&
        p3Left != null &&
        p1Left.likelihood > 0.4 &&
        p2Left.likelihood > 0.4 &&
        p3Left.likelihood > 0.4;

    final bool rightValid =
        p1Right != null &&
        p2Right != null &&
        p3Right != null &&
        p1Right.likelihood > 0.4 &&
        p2Right.likelihood > 0.4 &&
        p3Right.likelihood > 0.4;

    if (leftValid && rightValid) {
      final angleL = getAngle(p1Left, p2Left, p3Left);
      final angleR = getAngle(p1Right, p2Right, p3Right);
      detectedAngle = (angleL + angleR) / 2.0;
    } else if (leftValid) {
      detectedAngle = getAngle(p1Left, p2Left, p3Left);
    } else if (rightValid) {
      detectedAngle = getAngle(p1Right, p2Right, p3Right);
    }

    if (detectedAngle == null) {
      _feedbackNotifier.value = 'RETICLE: SELURUH SENDI HARUS TERLIHAT';
      return;
    }

    _angleNotifier.value = detectedAngle;

    // STATE MACHINE NAIK/TURUN:
    // Jika sudut < threshold bawah -> isDownPosition = true
    // Jika sudut > threshold atas DAN isDownPosition == true -> repCount++ & isDownPosition = false
    if (detectedAngle < lowerThreshold) {
      if (!_isDownPosition) {
        _isDownPosition = true;
        _feedbackNotifier.value = 'POSISI TERTEKUK TERCAPAI! DORONG PENUH!';
      }
    } else if (detectedAngle > upperThreshold && _isDownPosition) {
      _isDownPosition = false;
      _repCountNotifier.value++;
      _feedbackNotifier.value = 'REPETISI VALID: ${_repCountNotifier.value}!';
    } else if (_isDownPosition) {
      _feedbackNotifier.value = 'TAHAN & KEMBALIKAN KE POSISI SEMULA';
    } else {
      _feedbackNotifier.value = 'TURUNKAN BADAN UNTUK REPETISI BERIKUTNYA';
    }
  }

  // ============================================================================
  // INISIALISASI & KONTROL KAMERA DEPAN
  // ============================================================================

  Future<void> _initCamera() async {
    try {
      _availableCameras = await availableCameras();
      if (_availableCameras.isEmpty) {
        setState(() {
          _isCameraError = true;
          _cameraErrorMessage = 'Tidak ada hardware kamera yang terdeteksi.';
        });
        return;
      }

      // Utamakan kamera depan untuk ujian fisik mandiri
      final frontIndex = _availableCameras.indexWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
      );
      _selectedCameraIndex = frontIndex != -1 ? frontIndex : 0;

      await _setupCameraController(_availableCameras[_selectedCameraIndex]);
    } catch (e) {
      setState(() {
        _isCameraError = true;
        _cameraErrorMessage = 'Gagal menginisialisasi kamera: $e';
      });
    }
  }

  Future<void> _setupCameraController(CameraDescription cameraDesc) async {
    await _cameraController?.dispose();

    final controller = CameraController(
      cameraDesc,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    _cameraController = controller;

    try {
      await controller.initialize();
      if (!mounted) return;

      setState(() {
        _isCameraInitialized = true;
        _isCameraError = false;
        _isSessionActive = true;
      });

      // Mulai stream gambar tanpa setState (UI lancar 60 FPS)
      await controller.startImageStream(_processCameraImage);

      // Mulai timer 60 detik untuk sesi 1
      _startTrialTimer();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCameraInitialized = false;
          _isCameraError = true;
          _cameraErrorMessage = 'Gagal membuka live stream kamera: $e';
        });
      }
    }
  }

  Future<void> _toggleCameraLens() async {
    if (_availableCameras.length < 2) return;
    _selectedCameraIndex =
        (_selectedCameraIndex + 1) % _availableCameras.length;
    setState(() {
      _isCameraInitialized = false;
    });
    await _setupCameraController(_availableCameras[_selectedCameraIndex]);
  }

  Future<void> _stopAndDisposeCamera() async {
    _isSessionActive = false;
    _trialTimer?.cancel();
    _restTimer?.cancel();
    try {
      if (_cameraController?.value.isStreamingImages ?? false) {
        await _cameraController?.stopImageStream();
      }
      await _cameraController?.dispose();
    } catch (_) {}
    _cameraController = null;
    _isCameraInitialized = false;
  }

  // ============================================================================
  // SIKLUS TRIAL: 60 DETIK LATIHAN -> 5 DETIK REST -> LANJUT SESI BERIKUTNYA
  // ============================================================================

  void _startTrialTimer() {
    _trialTimer?.cancel();
    _remainingSecondsNotifier.value = 60;
    _isDownPosition = false;
    _repCountNotifier.value = 0;
    _feedbackNotifier.value = 'MULAI SESI ${_currentSession.title}!';

    _trialTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSecondsNotifier.value > 0) {
        _remainingSecondsNotifier.value--;
      } else {
        timer.cancel();
        _onTrialSessionFinished();
      }
    });
  }

  /// Menyimpan hasil repetisi sesi dan memulai jeda istirahat 5 detik
  void _onTrialSessionFinished() {
    // 1. Simpan hasil sesi aktif
    final count = _repCountNotifier.value;
    switch (_currentSession) {
      case WorkoutSessionType.pushup:
        _pushupCount = count;
        break;
      case WorkoutSessionType.situp:
        _situpCount = count;
        break;
      case WorkoutSessionType.squat:
        _squatCount = count;
        break;
      case WorkoutSessionType.pullup:
        _pullupCount = count;
        break;
    }

    // 2. Cek apakah seluruh 4 sesi telah selesai
    if (_currentSessionIndex >= _sessions.length - 1) {
      _completeAllTrials();
      return;
    }

    // 3. Masuki jeda istirahat 5 detik (REST PROTOCOL)
    _isRestingNotifier.value = true;
    _restSecondsNotifier.value = 5;

    _restTimer?.cancel();
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_restSecondsNotifier.value > 1) {
        _restSecondsNotifier.value--;
      } else {
        timer.cancel();
        _isRestingNotifier.value = false;
        if (mounted) {
          setState(() {
            _currentSessionIndex++;
          });
          _startTrialTimer();
        }
      }
    });
  }

  /// Menghentikan kamera dan melangkah ke FASE 3 (Result & Awakening Sync)
  Future<void> _completeAllTrials() async {
    _trialTimer?.cancel();
    _restTimer?.cancel();
    _isSessionActive = false;
    await _stopAndDisposeCamera();

    if (mounted) {
      _pageController.animateToPage(
        2,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  // ============================================================================
  // LOGIKA HITUNG BMI & EVALUASI RANK AWAKENING
  // ============================================================================

  void _calculateBmiAndTempRank() {
    final heightM = _tbCm / 100.0;
    if (heightM > 0) {
      _calculatedBmi = _bbKg / (heightM * heightM);
    } else {
      _calculatedBmi = 22.0;
    }

    // Aturan GDD: BMI Normal (18.5 - 24.9) -> E, selain itu F
    if (_calculatedBmi >= 18.5 && _calculatedBmi <= 24.9) {
      _tempRank = 'E';
    } else {
      _tempRank = 'F';
    }
  }

  /// Menghitung Rank Akhir berdasarkan Repetisi Ujian Fisik
  /// Jika Push-up > 30, Sit-up > 30, Squat > 40, Pull-up > 2 -> Naik 1 Rank
  Map<String, dynamic> _evaluateFinalAwakening() {
    final bool meetsPromotion =
        _pushupCount > 30 &&
        _situpCount > 30 &&
        _squatCount > 40 &&
        _pullupCount > 2;

    String finalRank = _tempRank;
    if (meetsPromotion) {
      if (_tempRank == 'E') {
        finalRank = 'D';
      } else if (_tempRank == 'F') {
        finalRank = 'E';
      }
    }

    return {'promoted': meetsPromotion, 'finalRank': finalRank};
  }

  // ============================================================================
  // EKSEKUSI FINAL: SYNC KE HIVE & SUPABASE LALU REDIRECT KE /MAIN
  // ============================================================================

  Future<void> _executeAwakeningSync() async {
    final eval = _evaluateFinalAwakening();
    final finalRank = eval['finalRank'] as String;

    // Tampilkan loading dialog bertema Solo Leveling
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Container(
          padding: const EdgeInsets.all(28),
          margin: const EdgeInsets.symmetric(horizontal: 32),
          decoration: BoxDecoration(
            color: const Color(0xFF0F131D),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: LevMaxTheme.primaryContainer, width: 2),
            boxShadow: [
              BoxShadow(
                color: LevMaxTheme.primaryContainer.withValues(alpha: 0.3),
                blurRadius: 24,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  LevMaxTheme.primaryContainer,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'SYNCHRONIZING VESSEL TO SYSTEM...',
                textAlign: TextAlign.center,
                style: LevMaxTheme.headline(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: LevMaxTheme.primaryContainer,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Mengukir Data Hunter ke Blockchain & Cloud Database...',
                textAlign: TextAlign.center,
                style: LevMaxTheme.mono(
                  fontSize: 11,
                  color: LevMaxTheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      // 1. Ambil data user aktif dari Cache / UserInfo
      final cachedPlayer = SupabaseApiService.getPlayerCache();
      final userId = await UserInfo.getUserID();
      final username = await UserInfo.getUsername() ?? 'Hunter';
      final email = await UserInfo.getEmail() ?? 'hunter@system.sys';

      final userToUpdate =
          (cachedPlayer ??
                  UserModel.initial(
                    id: userId,
                    username: username,
                    email: email,
                  ))
              .copyWith(
                height: _tbCm.toInt(),
                weight: _bbKg,
                bmiScore: double.parse(_calculatedBmi.toStringAsFixed(2)),
                maxPushup: _pushupCount,
                maxSitup: _situpCount,
                maxSquat: _squatCount,
                maxPullup: _pullupCount,
                rank: finalRank,
                isOnboarded: true,
              );

      // 2. Simpan status onboarding dan cache lokal ke Hive
      await UserInfo.setIsOnboarded(true);
      await UserInfo.setLoginStatus(true);
      await SupabaseApiService.savePlayerCache(userToUpdate);

      // 3. Kirim update ke tabel users di Supabase via REST / SDK yang telah disempurnakan
      await SupabaseApiService.updateUser(userToUpdate);

      // Tutup dialog
      if (mounted) Navigator.pop(context);

      // 4. Redirect ke Main Navigation
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/main');
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint('[Awakening Sync] Error: $e');

      // Tetap lanjutkan ke main karena cache lokal sudah onboarded
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/main');
      }
    }
  }

  // ============================================================================
  // BUILD UTAMA (PAGEVIEW 3 FASE)
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E18),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (index) {
          setState(() {
            _activePageIndex = index;
          });
        },
        children: [
          _buildPhase1VesselMetrics(),
          _buildPhase2PhysicalTrial(),
          _buildPhase3ResultSync(),
        ],
      ),
    );
  }

  // ============================================================================
  // UI FASE 1: VESSEL METRICS (INPUT TINGGI, BERAT & HITUNG BMI)
  // ============================================================================

  Widget _buildPhase1VesselMetrics() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            // Header Top Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '// PHASE 01: VESSEL ANTHROPOMETRY //',
                    style: LevMaxTheme.mono(
                      fontSize: 11,
                      color: LevMaxTheme.primaryContainer,
                      letterSpacing: 1.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: LevMaxTheme.primaryContainer.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: LevMaxTheme.primaryContainer),
                  ),
                  child: Text(
                    'STEP 1 OF 3',
                    style: LevMaxTheme.mono(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: LevMaxTheme.primaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'KALIBRASI METRIK TUBUH & BMI',
              style: LevMaxTheme.headline(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Sistem memerlukan kalibrasi fisik awal untuk menghitung daya tahan mana dan menentukan Temporary Hunter Rank Anda.',
              style: TextStyle(
                fontSize: 13,
                color: LevMaxTheme.onSurfaceVariant.withValues(alpha: 0.9),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),

            // Card Input Tinggi Badan (TB)
            _buildMetricInputCard(
              title: 'TINGGI BADAN (TB)',
              unit: 'CM',
              value: _tbCm,
              min: 120,
              max: 220,
              accentColor: LevMaxTheme.primaryContainer,
              onChanged: (val) {
                setState(() {
                  _tbCm = val;
                  _calculateBmiAndTempRank();
                });
              },
            ),
            const SizedBox(height: 16),

            // Card Input Berat Badan (BB)
            _buildMetricInputCard(
              title: 'BERAT BADAN (BB)',
              unit: 'KG',
              value: _bbKg,
              min: 35,
              max: 150,
              accentColor: const Color(0xFFD2BBFF),
              onChanged: (val) {
                setState(() {
                  _bbKg = val;
                  _calculateBmiAndTempRank();
                });
              },
            ),
            const SizedBox(height: 24),

            // Card Kalkulasi Real-time BMI & Rank Sementara
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF131826),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _tempRank == 'E'
                      ? LevMaxTheme.tertiaryFixed
                      : const Color(0xFFFFB4AB),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        (_tempRank == 'E'
                                ? LevMaxTheme.tertiaryFixed
                                : const Color(0xFFFFB4AB))
                            .withValues(alpha: 0.15),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'INDEX BODY MASS (BMI)',
                            style: LevMaxTheme.mono(
                              fontSize: 11,
                              color: LevMaxTheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _calculatedBmi.toStringAsFixed(1),
                            style: LevMaxTheme.headline(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            _calculatedBmi < 18.5
                                ? 'UNDERWEIGHT // KEKURANGAN BOBOT'
                                : _calculatedBmi <= 24.9
                                ? 'NORMAL // COMBAT READY'
                                : 'OVERWEIGHT // PERLU KONDISIONING',
                            style: LevMaxTheme.mono(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _tempRank == 'E'
                                  ? LevMaxTheme.tertiaryFixed
                                  : const Color(0xFFFFB4AB),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A0E18),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _tempRank == 'E'
                                ? LevMaxTheme.tertiaryFixed
                                : const Color(0xFFFFB4AB),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'TEMP RANK',
                              style: LevMaxTheme.mono(
                                fontSize: 9,
                                color: LevMaxTheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              _tempRank,
                              style: LevMaxTheme.headline(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: _tempRank == 'E'
                                    ? LevMaxTheme.tertiaryFixed
                                    : const Color(0xFFFFB4AB),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFF1E2638)),
                  const SizedBox(height: 8),
                  Text(
                    _tempRank == 'E'
                        ? '✓ BMI Anda Normal (18.5 - 24.9): Memenuhi syarat Temp Rank E! Selesaikan 4 sesi tes fisik untuk peluang promosi ke Rank D.'
                        : '⚠ BMI di luar rentang normal: Terdaftar pada Temp Rank F. Anda dapat meningkatkan rank melalui Ujian Fisik kamera.',
                    style: TextStyle(
                      fontSize: 11,
                      color: LevMaxTheme.onSurfaceVariant.withValues(
                        alpha: 0.9,
                      ),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Tombol CALCULATE VESSEL & PROCEED
            ElevatedButton(
              onPressed: () async {
                _pageController.animateToPage(
                  1,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                );
                await _initCamera();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: LevMaxTheme.primaryContainer,
                foregroundColor: LevMaxTheme.onPrimaryFixed,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 6,
                shadowColor: LevMaxTheme.primaryContainer.withValues(
                  alpha: 0.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.videocam, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'MASUKI THE PHYSICAL TRIAL (4 SESI AI)',
                    style: LevMaxTheme.headline(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: LevMaxTheme.onPrimaryFixed,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricInputCard({
    required String title,
    required String unit,
    required double value,
    required double min,
    required double max,
    required Color accentColor,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF131826),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E2638)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: LevMaxTheme.mono(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: LevMaxTheme.onSurfaceVariant,
                  letterSpacing: 1.0,
                ),
              ),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: value.toInt().toString(),
                      style: LevMaxTheme.headline(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: accentColor,
                      ),
                    ),
                    TextSpan(
                      text: ' $unit',
                      style: LevMaxTheme.mono(
                        fontSize: 12,
                        color: LevMaxTheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: accentColor,
              inactiveTrackColor: const Color(0xFF222B3E),
              thumbColor: Colors.white,
              overlayColor: accentColor.withValues(alpha: 0.2),
              trackHeight: 6,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // UI FASE 2: THE PHYSICAL TRIAL (KAMERA FULLSCREEN + HUD VALUE NOTIFIER)
  // ============================================================================

  Widget _buildPhase2PhysicalTrial() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Layer Background Camera Preview
        if (_isCameraInitialized && _cameraController != null)
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _cameraController!.value.previewSize?.height ?? 1080,
              height: _cameraController!.value.previewSize?.width ?? 1920,
              child: CameraPreview(_cameraController!),
            ),
          )
        else
          Container(
            color: const Color(0xFF070A12),
            child: Center(
              child: _isCameraError
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.videocam_off,
                            color: Color(0xFFFFB4AB),
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _cameraErrorMessage,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFFFB4AB),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _initCamera,
                            child: const Text('COBA ULANG KAMERA'),
                          ),
                        ],
                      ),
                    )
                  : const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        LevMaxTheme.primaryContainer,
                      ),
                    ),
            ),
          ),

        // 2. Layer Overlay Border Reticle Solo Leveling HUD
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, _) => Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: LevMaxTheme.primaryContainer.withValues(
                      alpha: _pulseAnimation.value * 0.4 + 0.1,
                    ),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),

        // 3. Layer Konten Atas: Header Trial & Muscle Group
        SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F131D).withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: LevMaxTheme.primaryContainer,
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '[ TRIAL ${_currentSessionIndex + 1}/4: ${_currentSession.title} ]',
                          style: LevMaxTheme.headline(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: LevMaxTheme.primaryContainer,
                            letterSpacing: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Target Fokus: ${_currentSession.muscleGroup} • Bonus Target: >${_currentSession.bonusThreshold}',
                          style: LevMaxTheme.mono(
                            fontSize: 10,
                            color: LevMaxTheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.cameraswitch,
                      color: LevMaxTheme.primaryContainer,
                    ),
                    onPressed: _toggleCameraLens,
                  ),
                ],
              ),
            ),
          ),
        ),

        // 4. Layer Tengah: Countdown Timer Besar (ValueListenableBuilder - Zero Lag)
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<int>(
                valueListenable: _remainingSecondsNotifier,
                builder: (context, seconds, child) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A0E18).withValues(alpha: 0.75),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: seconds <= 10
                            ? const Color(0xFFFFB4AB)
                            : LevMaxTheme.primaryContainer,
                        width: 3,
                      ),
                    ),
                    child: Text(
                      '$seconds',
                      style: LevMaxTheme.headline(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: seconds <= 10
                            ? const Color(0xFFFFB4AB)
                            : LevMaxTheme.primaryContainer,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Text(
                'DETIK TERSISA',
                style: LevMaxTheme.mono(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),

        // 5. Layer Bawah: Counter Repetisi Besar & Feedback Pose
        SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F131D).withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF1E2638), width: 1.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Realtime Repetisi & Sudut Sendi
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'REPETISI SAAT INI',
                            style: LevMaxTheme.mono(
                              fontSize: 10,
                              color: LevMaxTheme.onSurfaceVariant,
                            ),
                          ),
                          ValueListenableBuilder<int>(
                            valueListenable: _repCountNotifier,
                            builder: (context, count, child) {
                              return Text(
                                '$count',
                                style: LevMaxTheme.headline(
                                  fontSize: 42,
                                  fontWeight: FontWeight.w900,
                                  color: LevMaxTheme.primaryContainer,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'SUDUT SENDI (ATAN2)',
                            style: LevMaxTheme.mono(
                              fontSize: 10,
                              color: LevMaxTheme.onSurfaceVariant,
                            ),
                          ),
                          ValueListenableBuilder<double>(
                            valueListenable: _angleNotifier,
                            builder: (context, angle, child) {
                              return Text(
                                '${angle.toInt()}°',
                                style: LevMaxTheme.headline(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: _isDownPosition
                                      ? LevMaxTheme.tertiaryFixed
                                      : Colors.white,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Feedback Realtime ML Kit
                  ValueListenableBuilder<String>(
                    valueListenable: _feedbackNotifier,
                    builder: (context, feedback, child) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A0E18),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: LevMaxTheme.primaryContainer.withValues(
                              alpha: 0.4,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.radar,
                              color: LevMaxTheme.primaryContainer,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                feedback,
                                style: LevMaxTheme.mono(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),

                  // Tombol Manual / Dev Skip untuk evaluasi cepat
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('+1 Rep Manual'),
                        onPressed: () {
                          _repCountNotifier.value++;
                        },
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.fast_forward, size: 16),
                        label: const Text('Lewati Sesi Ini'),
                        onPressed: _onTrialSessionFinished,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // 6. Layer Jeda Istirahat (REST OVERLAY 5 DETIK)
        ValueListenableBuilder<bool>(
          valueListenable: _isRestingNotifier,
          builder: (context, isResting, child) {
            if (!isResting) return const SizedBox.shrink();

            return Container(
              color: const Color(0xFF060913).withValues(alpha: 0.94),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(28.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '// SYSTEM REST PROTOCOL //',
                        style: LevMaxTheme.mono(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF65F2B5),
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'AMBIL NAPAS & RELAKSASI OTOT',
                        style: LevMaxTheme.headline(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Menyiapkan sesi berikutnya: [TRIAL ${_currentSessionIndex + 2}/4: ${_sessions[math.min(_currentSessionIndex + 1, _sessions.length - 1)].title}]',
                        textAlign: TextAlign.center,
                        style: LevMaxTheme.mono(
                          fontSize: 12,
                          color: LevMaxTheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ValueListenableBuilder<int>(
                        valueListenable: _restSecondsNotifier,
                        builder: (ctx, restSec, _) {
                          return Text(
                            '$restSec',
                            style: LevMaxTheme.headline(
                              fontSize: 72,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF65F2B5),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ============================================================================
  // UI FASE 3: RESULT & RE-AWAKENING SYNC (RANGKUMAN & SINKRONISASI SUPABASE)
  // ============================================================================

  Widget _buildPhase3ResultSync() {
    final eval = _evaluateFinalAwakening();
    final bool promoted = eval['promoted'] as bool;
    final String finalRank = eval['finalRank'] as String;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Text(
                '// PHASE 03: AWAKENING EVALUATION //',
                style: LevMaxTheme.mono(
                  fontSize: 11,
                  color: LevMaxTheme.primaryContainer,
                  letterSpacing: 2.0,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'HASIL EVALUASI UJIAN FISIK',
                style: LevMaxTheme.headline(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Card Peringkat Rank Akhir
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF131826),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: promoted
                      ? LevMaxTheme.tertiaryFixed
                      : LevMaxTheme.primaryContainer,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        (promoted
                                ? LevMaxTheme.tertiaryFixed
                                : LevMaxTheme.primaryContainer)
                            .withValues(alpha: 0.25),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    promoted ? 'PROMOTED AWAKENING' : 'AWAKENING CONFIRMED',
                    style: LevMaxTheme.mono(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: promoted
                          ? LevMaxTheme.tertiaryFixed
                          : LevMaxTheme.primaryContainer,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'RANK $finalRank',
                    style: LevMaxTheme.headline(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: promoted
                          ? LevMaxTheme.tertiaryFixed
                          : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    promoted
                        ? '★ Selamat! Repetisi Anda melampaui seluruh target bonus. Rank dinaikkan dari $_tempRank ke $finalRank!'
                        : 'Peringkat Vessel Anda dikonfirmasi pada Rank $finalRank berdasarkan Metrik BMI & Ujian Fisik.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: LevMaxTheme.onSurfaceVariant.withValues(
                        alpha: 0.9,
                      ),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Rangkuman 4 Sesi Ujian Fisik
            Text(
              'RANGKUMAN REPETISI 60 DETIK',
              style: LevMaxTheme.mono(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: LevMaxTheme.onSurfaceVariant,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 10),

            _buildTrialSummaryRow(
              title: 'PUSH-UP',
              reps: _pushupCount,
              target: 30,
              icon: Icons.fitness_center,
            ),
            const SizedBox(height: 8),
            _buildTrialSummaryRow(
              title: 'SIT-UP',
              reps: _situpCount,
              target: 30,
              icon: Icons.sports_gymnastics,
            ),
            const SizedBox(height: 8),
            _buildTrialSummaryRow(
              title: 'SQUAT',
              reps: _squatCount,
              target: 40,
              icon: Icons.accessibility_new,
            ),
            const SizedBox(height: 8),
            _buildTrialSummaryRow(
              title: 'PULL-UP',
              reps: _pullupCount,
              target: 2,
              icon: Icons.horizontal_rule,
            ),
            const SizedBox(height: 28),

            // Tombol Konfirmasi & Sinkronisasi
            ElevatedButton(
              onPressed: _executeAwakeningSync,
              style: ElevatedButton.styleFrom(
                backgroundColor: LevMaxTheme.primaryContainer,
                foregroundColor: LevMaxTheme.onPrimaryFixed,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 6,
                shadowColor: LevMaxTheme.primaryContainer.withValues(
                  alpha: 0.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bolt, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'KONFIRMASI & AKTIFKAN SISTEM HUNTER',
                    style: LevMaxTheme.headline(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: LevMaxTheme.onPrimaryFixed,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTrialSummaryRow({
    required String title,
    required int reps,
    required int target,
    required IconData icon,
  }) {
    final bool passed = reps >= target;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF131826),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E2638)),
      ),
      child: Row(
        children: [
          Icon(icon, color: LevMaxTheme.primaryContainer, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: LevMaxTheme.mono(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Bonus Threshold: >$target reps',
                  style: LevMaxTheme.mono(
                    fontSize: 10,
                    color: LevMaxTheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$reps reps',
                style: LevMaxTheme.headline(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: passed ? LevMaxTheme.tertiaryFixed : Colors.white,
                ),
              ),
              Text(
                passed ? 'TARGET MET' : 'STANDARD',
                style: LevMaxTheme.mono(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: passed
                      ? LevMaxTheme.tertiaryFixed
                      : LevMaxTheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
