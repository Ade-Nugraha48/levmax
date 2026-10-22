// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/ui/auth/onboarding_page.dart
// Deskripsi: Superprompt Prompt 8 - The Awakening Trial (Onboarding Kamera AI & ML Kit)
//            Fase 1: Kalkulasi BMI & Temp Rank (E atau F).
//            Fase 2: Ujian Kemampuan Fisik AI (4 Sesi x 60 Detik: Push-up, Sit-up, Squat, Pull-up)
//                    dengan google_mlkit_pose_detection real-time joint angle validation.
//            Fase 3: Penentuan Rank Akhir, Bonus Threshold Sync ke Supabase & Hive, lalu ke /main.
// ==============================================================================

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../helpers/levmax_theme.dart';
import '../../helpers/user_info.dart';
import '../../models/user_model.dart';
import '../../services/supabase_api_service.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

/// Sesi Ujian Fisik
enum WorkoutSessionType {
  pushup('PUSH-UP', 'Dada & Triceps', 35, Icons.fitness_center),
  situp('SIT-UP', 'Core & Abdominal', 35, Icons.sports_gymnastics),
  squat('SQUAT', 'Quadriceps & Glutes', 40, Icons.accessibility_new),
  pullup('PULL-UP', 'Lats & Biceps', 5, Icons.horizontal_rule);

  final String title;
  final String muscleGroup;
  final int bonusThreshold;
  final IconData icon;
  const WorkoutSessionType(this.title, this.muscleGroup, this.bonusThreshold, this.icon);
}

class _OnboardingPageState extends State<OnboardingPage>
    with TickerProviderStateMixin {
  // ============================================================================
  // FASE OPERASI ONBOARDING (1: BMI, 2: KAMERA AI, 3: HASIL RANK & SYNC)
  // ============================================================================
  int _currentPhase = 1;

  // ----------------------------------------------------------------------------
  // FASE 1: STATISTIK ANTROPOMETRI (VESSEL METRICS & BMI)
  // ----------------------------------------------------------------------------
  double _tbCm = 175.0;
  double _bbKg = 68.0;
  final TextEditingController _tbController = TextEditingController(text: '175');
  final TextEditingController _bbController = TextEditingController(text: '68');

  // ----------------------------------------------------------------------------
  // FASE 2: UJIAN KEMAMPUAN FISIK KAMERA AI (ML KIT POSE DETECTION)
  // ----------------------------------------------------------------------------
  CameraController? _cameraController;
  List<CameraDescription> _availableCameras = [];
  bool _isCameraReady = false;
  bool _isCameraError = false;
  String _cameraErrorMessage = '';
  int _selectedCameraIndex = 0;

  // ML Kit Pose Detector
  PoseDetector? _poseDetector;
  bool _isProcessingFrame = false;
  bool _isSessionActive = false;

  // Urutan Sesi Latihan (1. Push-up -> 2. Sit-up -> 3. Squat -> 4. Pull-up)
  int _currentSessionIndex = 0;
  final List<WorkoutSessionType> _sessions = [
    WorkoutSessionType.pushup,
    WorkoutSessionType.situp,
    WorkoutSessionType.squat,
    WorkoutSessionType.pullup,
  ];

  // Counter Repetisi Tiap Sesi
  int _pushupCount = 0;
  int _situpCount = 0;
  int _squatCount = 0;
  int _pullupCount = 0;

  // State Deteksi Repetisi (State Machine Inflection Point)
  bool _isJointFlexed = false; // Inflection point (posisi bawah/tertekuk)
  double _currentJointAngle = 180.0;
  String _poseFeedbackText = 'Posisikan seluruh tubuh terlihat dalam reticle';

  // Timer 60 Detik per Sesi
  static const int _sessionDurationSeconds = 60;
  int _remainingSeconds = _sessionDurationSeconds;
  Timer? _countdownTimer;

  // ----------------------------------------------------------------------------
  // FASE 3: SINKRONISASI SUPABASE & ANIMASI
  // ----------------------------------------------------------------------------
  bool _isSyncing = false;
  late AnimationController _pulseController;
  late AnimationController _scanLaserController;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _scanLaserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _tbController.addListener(() {
      final val = double.tryParse(_tbController.text);
      if (val != null && val >= 100 && val <= 250 && val != _tbCm) {
        setState(() => _tbCm = val);
      }
    });

    _bbController.addListener(() {
      final val = double.tryParse(_bbController.text);
      if (val != null && val >= 30 && val <= 250 && val != _bbKg) {
        setState(() => _bbKg = val);
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scanLaserController.dispose();
    _countdownTimer?.cancel();
    _stopCamera();
    _poseDetector?.close();
    _tbController.dispose();
    _bbController.dispose();
    super.dispose();
  }

  // ============================================================================
  // KALKULASI BMI & RANKING LOGIC
  // ============================================================================

  /// Kalkulasi Skor BMI: BB (kg) / (TB (m))^2
  double get _calculatedBmi {
    final heightMeter = _tbCm / 100.0;
    if (heightMeter <= 0) return 22.0;
    final bmi = _bbKg / (heightMeter * heightMeter);
    return double.parse(bmi.toStringAsFixed(1));
  }

  /// Logika Rank Sementara (Temp Rank):
  /// - Normal (18.5 - 24.9) -> 'E'
  /// - Underweight (< 18.5) atau Overweight/Obese (>= 25) -> 'F'
  String get _tempRank {
    final bmi = _calculatedBmi;
    if (bmi >= 18.5 && bmi <= 24.9) {
      return 'E';
    } else {
      return 'F';
    }
  }

  /// Status Kategori BMI
  String get _bmiCategoryText {
    final bmi = _calculatedBmi;
    if (bmi < 18.5) return 'UNDERWEIGHT // RECOVERY REQ';
    if (bmi <= 24.9) return 'NORMAL // COMBAT READY';
    if (bmi <= 29.9) return 'OVERWEIGHT // CONDITIONING';
    return 'OBESE // HEAVY RECALIBRATION';
  }

  Color get _bmiCategoryColor {
    final bmi = _calculatedBmi;
    if (bmi >= 18.5 && bmi <= 24.9) return LevMaxTheme.tertiaryContainer;
    if (bmi < 18.5) return const Color(0xFFFFA000);
    return LevMaxTheme.hpRed;
  }

  /// Evaluasi Apakah Pengguna Memenuhi Seluruh Threshold Bonus:
  /// Push-up > 35, Sit-up > 35, Squat > 40, Pull-up > 5 (Semua Terpenuhi)
  bool get _isBonusRankAchieved {
    return _pushupCount > WorkoutSessionType.pushup.bonusThreshold &&
        _situpCount > WorkoutSessionType.situp.bonusThreshold &&
        _squatCount > WorkoutSessionType.squat.bonusThreshold &&
        _pullupCount > WorkoutSessionType.pullup.bonusThreshold;
  }

  /// Penentuan Rank Akhir:
  /// - Jika temp_rank == 'E' & performa bonus -> Final Rank = 'D'
  /// - Jika temp_rank == 'F' & performa bonus -> Final Rank = 'E'
  /// - Tanpa bonus -> Final Rank = temp_rank
  String get _finalRank {
    final base = _tempRank;
    if (_isBonusRankAchieved) {
      if (base == 'E') return 'D';
      if (base == 'F') return 'E';
    }
    return base;
  }

  // ============================================================================
  // INISIALISASI KAMERA & GOOGLE ML KIT POSE DETECTOR (FASE 2)
  // ============================================================================

  Future<void> _startPhysicalTrials() async {
    setState(() {
      _currentPhase = 2;
      _currentSessionIndex = 0;
      _pushupCount = 0;
      _situpCount = 0;
      _squatCount = 0;
      _pullupCount = 0;
      _remainingSeconds = _sessionDurationSeconds;
    });

    await _initializeCameraAndDetector();
    _startSessionTimer();
  }

  Future<void> _initializeCameraAndDetector() async {
    try {
      // Inisialisasi ML Kit Pose Detector
      _poseDetector = PoseDetector(
        options: PoseDetectorOptions(
          mode: PoseDetectionMode.stream,
          model: PoseDetectionModel.base,
        ),
      );

      // Ambil daftar kamera perangkat
      _availableCameras = await availableCameras();
      if (_availableCameras.isEmpty) {
        setState(() {
          _isCameraError = true;
          _cameraErrorMessage = 'Tidak ada sensor kamera terdeteksi pada perangkat.';
        });
        return;
      }

      // Pilih kamera depan sebagai preferensi agar user dapat melihat layar saat latihan
      int frontCamIndex = _availableCameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      _selectedCameraIndex = frontCamIndex != -1 ? frontCamIndex : 0;

      await _setupCameraController(_availableCameras[_selectedCameraIndex]);
    } catch (e) {
      debugPrint('[Onboarding Camera] Inisialisasi gagal: $e');
      if (mounted) {
        setState(() {
          _isCameraError = true;
          _cameraErrorMessage = 'Kamera tidak dapat diakses: $e\nMode simulasi AI tetap aktif.';
        });
      }
    }
  }

  Future<void> _setupCameraController(CameraDescription cameraDescription) async {
    _cameraController?.dispose();

    final controller = CameraController(
      cameraDescription,
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
        _isCameraReady = true;
        _isCameraError = false;
        _isSessionActive = true;
      });

      // Mulai loop pemrosesan frame berkala
      _startLivePoseDetectionLoop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCameraReady = false;
          _isCameraError = true;
          _cameraErrorMessage = 'Gagal membuka aperture kamera: $e';
        });
      }
    }
  }

  /// Mengalihkan antara kamera depan dan kamera belakang
  Future<void> _toggleCameraLens() async {
    if (_availableCameras.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _availableCameras.length;
    setState(() {
      _isCameraReady = false;
    });
    await _setupCameraController(_availableCameras[_selectedCameraIndex]);
  }

  Future<void> _stopCamera() async {
    _isSessionActive = false;
    try {
      await _cameraController?.dispose();
    } catch (_) {}
    _cameraController = null;
  }

  // ============================================================================
  // LOOP DETEKSI POSE & LOGIKA SUDUT SENDI ML KIT REAL-TIME
  // ============================================================================

  /// Loop pemindaian frame kamera untuk ML Kit Pose Detection
  void _startLivePoseDetectionLoop() async {
    while (_isSessionActive && mounted && _currentPhase == 2) {
      if (!_isProcessingFrame &&
          _cameraController != null &&
          _cameraController!.value.isInitialized) {
        _isProcessingFrame = true;

        try {
          // Ambil frame snapshot dari kamera
          final xFile = await _cameraController!.takePicture();
          final file = File(xFile.path);

          if (await file.exists()) {
            final inputImage = InputImage.fromFile(file);
            final poses = await _poseDetector?.processImage(inputImage);

            // Bersihkan file frame temporer untuk menghemat memori
            try {
              await file.delete();
            } catch (_) {}

            if (mounted && poses != null && poses.isNotEmpty) {
              _processPoseLandmarks(poses.first);
            }
          }
        } catch (e) {
          // Tangani jika camera sibuk atau drop frame
          debugPrint('[Pose Loop] Frame processing skip: $e');
        } finally {
          _isProcessingFrame = false;
        }
      }

      // Interval 180ms agar pemrosesan berjalan mulus tanpa overheating pada Android/Samsung M31
      await Future.delayed(const Duration(milliseconds: 180));
    }
  }

  /// ==========================================================================
  /// FUNGSI MATEMATIKA: MENGHITUNG SUDUT SENDI ANTARA 3 TITIK LANDMARK
  /// Sudut dihitung pada vertex B (titik sendi siku/lutut/pinggul).
  /// Formula: arccos((BA . BC) / (|BA| * |BC|))
  /// ==========================================================================
  double _calculateJointAngle(PoseLandmark p1, PoseLandmark p2, PoseLandmark p3) {
    final radians = math.atan2(p3.y - p2.y, p3.x - p2.x) -
        math.atan2(p1.y - p2.y, p1.x - p2.x);
    var angle = (radians * 180.0 / math.pi).abs();
    if (angle > 180.0) {
      angle = 360.0 - angle;
    }
    return angle;
  }

  /// Memproses titik landmark tubuh berdasarkan jenis sesi latihan aktif
  void _processPoseLandmarks(Pose pose) {
    final currentSession = _sessions[_currentSessionIndex];

    switch (currentSession) {
      // ------------------------------------------------------------------------
      // 1. PUSH-UP: Deteksi Sudut Siku (Elbow) antara Shoulder, Elbow, & Wrist
      // ------------------------------------------------------------------------
      case WorkoutSessionType.pushup:
        final shoulder = pose.landmarks[PoseLandmarkType.leftShoulder] ??
            pose.landmarks[PoseLandmarkType.rightShoulder];
        final elbow = pose.landmarks[PoseLandmarkType.leftElbow] ??
            pose.landmarks[PoseLandmarkType.rightElbow];
        final wrist = pose.landmarks[PoseLandmarkType.leftWrist] ??
            pose.landmarks[PoseLandmarkType.rightWrist];

        if (shoulder != null && elbow != null && wrist != null) {
          // KOMENTAR KOMPREHENSIF - PUSH-UP JOINT ANGLE:
          // Titik vertex adalah Siku (Elbow).
          // Posisi Bawah (Dada turun menyentuh lantai): Sudut siku <= 90 derajat.
          // Posisi Atas (Lengan lurus terkunci): Sudut siku >= 160 derajat.
          final angle = _calculateJointAngle(shoulder, elbow, wrist);

          setState(() {
            _currentJointAngle = angle;
          });

          if (angle <= 90.0) {
            // Pengguna berhasil turun secara sah
            if (!_isJointFlexed) {
              _isJointFlexed = true;
              setState(() {
                _poseFeedbackText = 'KEDALAMAN SAH! Dorong tubuh ke atas!';
              });
            }
          } else if (angle >= 155.0 && _isJointFlexed) {
            // Repetisi komplit saat kembali ke ekstensi penuh
            _isJointFlexed = false;
            HapticFeedback.mediumImpact();
            setState(() {
              _pushupCount++;
              _poseFeedbackText = 'REPETISI SAH +1! Pertahankan ritme.';
            });
          }
        } else {
          setState(() {
            _poseFeedbackText = 'Arahkan kamera ke bahu, siku, dan tangan Anda.';
          });
        }
        break;

      // ------------------------------------------------------------------------
      // 2. SIT-UP: Deteksi Fleksi Pinggul (Hip) antara Shoulder, Hip, & Knee
      // ------------------------------------------------------------------------
      case WorkoutSessionType.situp:
        final shoulder = pose.landmarks[PoseLandmarkType.leftShoulder] ??
            pose.landmarks[PoseLandmarkType.rightShoulder];
        final hip = pose.landmarks[PoseLandmarkType.leftHip] ??
            pose.landmarks[PoseLandmarkType.rightHip];
        final knee = pose.landmarks[PoseLandmarkType.leftKnee] ??
            pose.landmarks[PoseLandmarkType.rightKnee];

        if (shoulder != null && hip != null && knee != null) {
          // KOMENTAR KOMPREHENSIF - SIT-UP JOINT ANGLE:
          // Titik vertex adalah Pinggul (Hip).
          // Posisi Bawah (Punggung di lantai): Sudut pinggul >= 140 derajat.
          // Posisi Atas (Tubuh naik mendekati lutut): Sudut pinggul <= 80 derajat.
          final angle = _calculateJointAngle(shoulder, hip, knee);

          setState(() {
            _currentJointAngle = angle;
          });

          if (angle <= 80.0) {
            // Puncak kontraksi sit-up tercapai
            if (!_isJointFlexed) {
              _isJointFlexed = true;
              setState(() {
                _poseFeedbackText = 'KONTRAKSI OPTIMAL! Turunkan punggung perlahan.';
              });
            }
          } else if (angle >= 135.0 && _isJointFlexed) {
            // Punggung kembali menyentuh matras -> 1 Repetisi Sah
            _isJointFlexed = false;
            HapticFeedback.mediumImpact();
            setState(() {
              _situpCount++;
              _poseFeedbackText = 'SIT-UP SAH +1! Angkat kembali tubuh Anda.';
            });
          }
        }
        break;

      // ------------------------------------------------------------------------
      // 3. SQUAT: Deteksi Sudut Lutut (Knee) antara Hip, Knee, & Ankle
      // ------------------------------------------------------------------------
      case WorkoutSessionType.squat:
        final hip = pose.landmarks[PoseLandmarkType.leftHip] ??
            pose.landmarks[PoseLandmarkType.rightHip];
        final knee = pose.landmarks[PoseLandmarkType.leftKnee] ??
            pose.landmarks[PoseLandmarkType.rightKnee];
        final ankle = pose.landmarks[PoseLandmarkType.leftAnkle] ??
            pose.landmarks[PoseLandmarkType.rightAnkle];

        if (hip != null && knee != null && ankle != null) {
          // KOMENTAR KOMPREHENSIF - SQUAT JOINT ANGLE:
          // Titik vertex adalah Lutut (Knee).
          // Posisi Bawah (Paha sejajar lantai / Deep Squat): Sudut lutut <= 95 derajat.
          // Posisi Berdiri (Tegak sempurna): Sudut lutut >= 160 derajat.
          final angle = _calculateJointAngle(hip, knee, ankle);

          setState(() {
            _currentJointAngle = angle;
          });

          if (angle <= 95.0) {
            // Titik terendah squat tercapai
            if (!_isJointFlexed) {
              _isJointFlexed = true;
              setState(() {
                _poseFeedbackText = 'KEDALAMAN TERCAPAI! Berdiri tegak!';
              });
            }
          } else if (angle >= 155.0 && _isJointFlexed) {
            // Pengguna berdiri sempurna -> 1 Repetisi Sah
            _isJointFlexed = false;
            HapticFeedback.mediumImpact();
            setState(() {
              _squatCount++;
              _poseFeedbackText = 'SQUAT SAH +1! Turun kembali.';
            });
          }
        }
        break;

      // ------------------------------------------------------------------------
      // 4. PULL-UP: Deteksi Fleksi Siku & Angkat Dagu di Atas Palang
      // ------------------------------------------------------------------------
      case WorkoutSessionType.pullup:
        final shoulder = pose.landmarks[PoseLandmarkType.leftShoulder] ??
            pose.landmarks[PoseLandmarkType.rightShoulder];
        final elbow = pose.landmarks[PoseLandmarkType.leftElbow] ??
            pose.landmarks[PoseLandmarkType.rightElbow];
        final wrist = pose.landmarks[PoseLandmarkType.leftWrist] ??
            pose.landmarks[PoseLandmarkType.rightWrist];

        if (shoulder != null && elbow != null && wrist != null) {
          // KOMENTAR KOMPREHENSIF - PULL-UP JOINT ANGLE:
          // Titik vertex adalah Siku (Elbow overhead).
          // Posisi Atas (Dagu melampaui palang / siku tertekuk): Sudut siku <= 80 derajat.
          // Posisi Bawah (Dead hang / lengan memanjang): Sudut siku >= 150 derajat.
          final angle = _calculateJointAngle(shoulder, elbow, wrist);

          setState(() {
            _currentJointAngle = angle;
          });

          if (angle <= 80.0) {
            if (!_isJointFlexed) {
              _isJointFlexed = true;
              setState(() {
                _poseFeedbackText = 'PULL-UP TERCAPAI! Turunkan badan perlahan.';
              });
            }
          } else if (angle >= 150.0 && _isJointFlexed) {
            _isJointFlexed = false;
            HapticFeedback.mediumImpact();
            setState(() {
              _pullupCount++;
              _poseFeedbackText = 'PULL-UP SAH +1! Tarik kembali tubuh Anda.';
            });
          }
        }
        break;
    }
  }

  // ============================================================================
  // TIMER & ALUR PERGANTIAN SESI (1 MENIT PER SESI)
  // ============================================================================

  void _startSessionTimer() {
    _countdownTimer?.cancel();
    _remainingSeconds = _sessionDurationSeconds;
    _isJointFlexed = false;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      if (_remainingSeconds > 1) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
        _onSessionTimeExpired();
      }
    });
  }

  /// Dipanggil saat 60 detik per sesi habis
  void _onSessionTimeExpired() {
    HapticFeedback.heavyImpact();

    if (_currentSessionIndex < _sessions.length - 1) {
      // Pindah ke sesi berikutnya secara otomatis
      setState(() {
        _currentSessionIndex++;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'SESI SELESAI! Bersiap untuk ujian ${_sessions[_currentSessionIndex].title}',
            style: LevMaxTheme.mono(fontSize: 11, fontWeight: FontWeight.bold),
          ),
          backgroundColor: LevMaxTheme.surfaceContainerHigh,
          duration: const Duration(seconds: 2),
        ),
      );

      _startSessionTimer();
    } else {
      // 4 Sesi selesai! Masuk ke Fase 3
      _finishAllSessionsAndShowResults();
    }
  }

  /// Navigasi ke Fase 3 (Penentuan Rank Akhir)
  void _finishAllSessionsAndShowResults() {
    _countdownTimer?.cancel();
    _stopCamera();

    setState(() {
      _currentPhase = 3;
    });
  }

  /// Helper untuk simulasi penambahan repetisi secara manual (misal testing tanpa kamera)
  void _simulateRepetition() {
    HapticFeedback.selectionClick();
    setState(() {
      switch (_sessions[_currentSessionIndex]) {
        case WorkoutSessionType.pushup:
          _pushupCount++;
          break;
        case WorkoutSessionType.situp:
          _situpCount++;
          break;
        case WorkoutSessionType.squat:
          _squatCount++;
          break;
        case WorkoutSessionType.pullup:
          _pullupCount++;
          break;
      }
      _poseFeedbackText = 'MANUAL TEST REP +1 VALIDATED';
    });
  }

  // ============================================================================
  // FASE 3: SINKRONISASI DATA KE SUPABASE & HIVE, LALU KE /MAIN
  // ============================================================================

  Future<void> _syncAwakeningToSupabase() async {
    setState(() {
      _isSyncing = true;
    });

    try {
      final userId = await UserInfo.getUserId();
      final username = await UserInfo.getUsername() ?? 'Hunter';
      final email = await UserInfo.getEmail() ?? '$username@monarch.sys';

      // 1. Ambil data User lama dari cache atau Supabase
      UserModel? currentUser = SupabaseApiService.getPlayerCache();
      if (currentUser == null && userId != null && userId.isNotEmpty) {
        currentUser = await SupabaseApiService.getUserById(userId);
      }

      // 2. Buat objek UserModel baru dengan data antropometri & ranking hasil uji fisik
      final updatedUser = (currentUser ??
              UserModel.initial(
                id: userId ?? '1',
                username: username,
                email: email,
              ))
          .copyWith(
        height: _tbCm.toInt(),
        weight: _bbKg,
        bmiScore: _calculatedBmi,
        maxPushup: _pushupCount,
        maxSitup: _situpCount,
        maxSquat: _squatCount,
        maxPullup: _pullupCount,
        rank: _finalRank,
        isOnboarded: true,
      );

      // 3. Simpan perubahan ke Supabase Cloud REST API
      await SupabaseApiService.updateUser(updatedUser);

      // 4. Update status lokal di Hive authBox & playerBox
      await UserInfo.setIsOnboarded(true);
      await SupabaseApiService.savePlayerCache(updatedUser);

      if (!mounted) return;

      // 5. Berikan visual dialog keberhasilan Awakening
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: LevMaxTheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: LevMaxTheme.primaryContainer, width: 2),
          ),
          title: Center(
            child: Text(
              'AWAKENING CONFIRMED',
              style: LevMaxTheme.headline(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: LevMaxTheme.primaryContainer,
                letterSpacing: 1.5,
              ),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: LevMaxTheme.primaryContainer.withValues(alpha: 0.15),
                  border: Border.all(color: LevMaxTheme.primaryContainer, width: 2),
                ),
                child: Center(
                  child: Text(
                    _finalRank,
                    style: LevMaxTheme.headline(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: LevMaxTheme.primaryContainer,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Selamat, Hunter ${updatedUser.username}!\nAnda resmi dibangkitkan ke dalam Sistem dengan status Rank $_finalRank.',
                textAlign: TextAlign.center,
                style: LevMaxTheme.mono(fontSize: 11, color: LevMaxTheme.onSurface),
              ),
            ],
          ),
          actions: [
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushReplacementNamed(context, '/main');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: LevMaxTheme.primaryContainer,
                  foregroundColor: LevMaxTheme.onPrimaryFixed,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text(
                  'MASUKI GERBANG SYSTEM WINDOW',
                  style: LevMaxTheme.mono(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('[Onboarding Sync Error] $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sinkronisasi error: $e. Melanjutkan offline...'),
            backgroundColor: LevMaxTheme.hpRed,
          ),
        );
        await UserInfo.setIsOnboarded(true);
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/main');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  // ============================================================================
  // BUILD UTAMA (ROUTING ANTAR FASE 1, 2, & 3)
  // ============================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LevMaxTheme.surfaceContainerLowest,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: _buildPhaseContent(),
        ),
      ),
    );
  }

  Widget _buildPhaseContent() {
    switch (_currentPhase) {
      case 1:
        return _buildPhase1BmiMetrics();
      case 2:
        return _buildPhase2CameraTrial();
      case 3:
      default:
        return _buildPhase3FinalRankSync();
    }
  }

  // ============================================================================
  // UI FASE 1: KALKULASI BMI & STATUS SEMENTARA
  // ============================================================================
  Widget _buildPhase1BmiMetrics() {
    return SingleChildScrollView(
      key: const ValueKey('phase_1_bmi'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Center(
            child: Column(
              children: [
                Text(
                  '// PHASE 01: VESSEL ANTHROPOMETRY //',
                  style: LevMaxTheme.mono(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: LevMaxTheme.primary,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'KALIBRASI METRIK TUBUH & BMI',
                  style: LevMaxTheme.headline(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: LevMaxTheme.primaryContainer,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Sistem membutuhkan data fisik awal Anda untuk menghitung Rank Sementara dan kapasitas mana vessel.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: LevMaxTheme.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Input Card: Tinggi Badan & Berat Badan
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: LevMaxTheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Tinggi Badan
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.height, color: LevMaxTheme.primaryContainer, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'TINGGI BADAN (TB)',
                          style: LevMaxTheme.mono(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: LevMaxTheme.primary,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${_tbCm.toInt()} CM',
                      style: LevMaxTheme.headline(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: LevMaxTheme.primaryContainer,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _tbCm,
                  min: 120.0,
                  max: 220.0,
                  activeColor: LevMaxTheme.primaryContainer,
                  inactiveColor: const Color(0xFF1E293B),
                  onChanged: (val) {
                    setState(() {
                      _tbCm = val;
                      _tbController.text = val.toInt().toString();
                    });
                  },
                ),
                const SizedBox(height: 16),

                // 2. Berat Badan
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.monitor_weight_outlined,
                            color: LevMaxTheme.secondary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'BERAT BADAN (BB)',
                          style: LevMaxTheme.mono(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: LevMaxTheme.primary,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${_bbKg.toStringAsFixed(1)} KG',
                      style: LevMaxTheme.headline(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: LevMaxTheme.secondary,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _bbKg,
                  min: 35.0,
                  max: 160.0,
                  activeColor: LevMaxTheme.secondary,
                  inactiveColor: const Color(0xFF1E293B),
                  onChanged: (val) {
                    setState(() {
                      _bbKg = val;
                      _bbController.text = val.toStringAsFixed(1);
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Card Hasil Kalkulasi BMI & Temp Rank
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: LevMaxTheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _bmiCategoryColor.withValues(alpha: 0.6),
                width: 1.5,
              ),
            ),
            child: Column(
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
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: LevMaxTheme.outline,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$_calculatedBmi',
                          style: LevMaxTheme.headline(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: _bmiCategoryColor,
                          ),
                        ),
                        Text(
                          _bmiCategoryText,
                          style: LevMaxTheme.mono(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: _bmiCategoryColor,
                          ),
                        ),
                      ],
                    ),

                    // Badge Temp Rank
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: LevMaxTheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _bmiCategoryColor, width: 1.5),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'TEMP RANK',
                            style: LevMaxTheme.mono(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: LevMaxTheme.outline,
                            ),
                          ),
                          Text(
                            _tempRank,
                            style: LevMaxTheme.headline(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: _bmiCategoryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(color: Color(0xFF1E293B)),
                const SizedBox(height: 8),
                Text(
                  _tempRank == 'E'
                      ? '✓ BMI Normal (18.5 - 24.9): Memenuhi syarat Temp Rank E. Tuntaskan 4 sesi latihan fisik untuk peluang promosi ke Rank D!'
                      : '⚠ BMI di luar rentang normal: Dialokasikan ke Temp Rank F. Anda tetap berpeluang naik ke Rank E jika menembus target ujian!',
                  style: LevMaxTheme.mono(
                    fontSize: 10,
                    color: LevMaxTheme.onSurfaceVariant,
                  ).copyWith(height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // CTA: Masuk ke Fase 2 (Kamera AI)
          GestureDetector(
            onTap: _startPhysicalTrials,
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.videocam, color: LevMaxTheme.onPrimary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'MASUKI ARENA UJIAN FISIK (4 SESI AI)',
                    style: LevMaxTheme.mono(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: LevMaxTheme.onPrimary,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ============================================================================
  // UI FASE 2: ARENA UJIAN KAMERA AI (ML KIT POSE DETECTION)
  // ============================================================================
  Widget _buildPhase2CameraTrial() {
    final currentSession = _sessions[_currentSessionIndex];

    int currentCount = 0;
    switch (currentSession) {
      case WorkoutSessionType.pushup:
        currentCount = _pushupCount;
        break;
      case WorkoutSessionType.situp:
        currentCount = _situpCount;
        break;
      case WorkoutSessionType.squat:
        currentCount = _squatCount;
        break;
      case WorkoutSessionType.pullup:
        currentCount = _pullupCount;
        break;
    }

    return Stack(
      key: const ValueKey('phase_2_camera'),
      children: [
        // 1. Kamera Viewfinder / Feed
        Positioned.fill(
          child: _isCameraReady && _cameraController != null
              ? AspectRatio(
                  aspectRatio: _cameraController!.value.aspectRatio,
                  child: CameraPreview(_cameraController!),
                )
              : Container(
                  color: const Color(0xFF070B14),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.camera_alt_outlined,
                            size: 48, color: LevMaxTheme.outline),
                        const SizedBox(height: 12),
                        Text(
                          _isCameraError
                              ? _cameraErrorMessage
                              : 'MENGINISIALISASI SENSOR POSE KAMERA...',
                          textAlign: TextAlign.center,
                          style: LevMaxTheme.mono(
                            fontSize: 11,
                            color: _isCameraError
                                ? LevMaxTheme.hpRed
                                : LevMaxTheme.primaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),

        // 2. Futuristic Bounding Box & HUD Reticle Overlay
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 80),
              decoration: BoxDecoration(
                border: Border.all(
                  color: LevMaxTheme.primaryContainer.withValues(alpha: 0.4),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                children: [
                  // Tactical Corner Notches
                  _buildCornerReticle(top: 0, left: 0),
                  _buildCornerReticle(top: 0, right: 0),
                  _buildCornerReticle(bottom: 0, left: 0),
                  _buildCornerReticle(bottom: 0, right: 0),

                  // Laser Scan Animation
                  AnimatedBuilder(
                    animation: _scanLaserController,
                    builder: (context, child) {
                      return Align(
                        alignment: Alignment(0, (_scanLaserController.value * 2) - 1),
                        child: Container(
                          height: 2,
                          color: LevMaxTheme.primaryContainer.withValues(alpha: 0.7),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),

        // 3. TOP STRIP: TIMER 60 DETIK & PROGRESS SESI
        Positioned(
          top: 12,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: LevMaxTheme.surfaceContainerLowest.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: LevMaxTheme.primaryContainer, width: 1.2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Info Sesi Aktif
                Row(
                  children: [
                    Icon(currentSession.icon,
                        color: LevMaxTheme.primaryContainer, size: 20),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SESI ${_currentSessionIndex + 1}/4 // ${currentSession.title}',
                          style: LevMaxTheme.mono(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: LevMaxTheme.primaryContainer,
                          ),
                        ),
                        Text(
                          'Target Bonus: > ${currentSession.bonusThreshold} Reps',
                          style: LevMaxTheme.mono(fontSize: 9, color: LevMaxTheme.outline),
                        ),
                      ],
                    ),
                  ],
                ),

                // Countdown Timer Besar 60 Detik
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _remainingSeconds <= 10
                        ? LevMaxTheme.hpRed.withValues(alpha: 0.2)
                        : LevMaxTheme.primaryContainer.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _remainingSeconds <= 10
                          ? LevMaxTheme.hpRed
                          : LevMaxTheme.primaryContainer,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.timer,
                        size: 16,
                        color: _remainingSeconds <= 10
                            ? LevMaxTheme.hpRed
                            : LevMaxTheme.primaryContainer,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '00:${_remainingSeconds.toString().padLeft(2, '0')}',
                        style: LevMaxTheme.headline(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _remainingSeconds <= 10
                              ? LevMaxTheme.hpRed
                              : LevMaxTheme.primaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // 4. CENTER HUD: COUNTER REPETISI MENYALA & FEEDBACK DETEKSI
        Positioned(
          bottom: 120,
          left: 16,
          right: 16,
          child: Column(
            children: [
              // Real-time Angle & Posture Status
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _isJointFlexed
                        ? LevMaxTheme.tertiaryContainer
                        : const Color(0xFF334155),
                  ),
                ),
                child: Text(
                  _poseFeedbackText,
                  style: LevMaxTheme.mono(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _isJointFlexed
                        ? LevMaxTheme.tertiaryContainer
                        : LevMaxTheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Angka Repetisi Menyala Besar di Tengah
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: LevMaxTheme.surfaceContainerLowest.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: LevMaxTheme.primaryContainer, width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x5500F0FF),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      '${currentSession.title} REPS',
                      style: LevMaxTheme.mono(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: LevMaxTheme.outline,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      '$currentCount',
                      style: LevMaxTheme.headline(
                        fontSize: 54,
                        fontWeight: FontWeight.bold,
                        color: LevMaxTheme.primaryContainer,
                      ),
                    ),
                    Text(
                      'SUDUT SENDI: ${_currentJointAngle.toStringAsFixed(0)}°',
                      style: LevMaxTheme.mono(
                        fontSize: 10,
                        color: LevMaxTheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 5. BOTTOM ACTIONS: TOGGLE LENS, SIMULASI REP, & NEXT SESSION
        Positioned(
          bottom: 24,
          left: 16,
          right: 16,
          child: Row(
            children: [
              // Switch Camera Lens
              IconButton(
                icon: const Icon(Icons.flip_camera_ios, color: Colors.white70),
                onPressed: _toggleCameraLens,
                tooltip: 'Ganti Kamera',
              ),
              const SizedBox(width: 8),

              // Manual Rep Simulation (Untuk Testing Cepat & Fail-safe)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _simulateRepetition,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LevMaxTheme.surfaceContainerHighest,
                    foregroundColor: LevMaxTheme.primaryContainer,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: LevMaxTheme.primaryContainer),
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(
                    '+1 REP MANUAL',
                    style: LevMaxTheme.mono(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Skip / Next Session Button
              ElevatedButton(
                onPressed: _onSessionTimeExpired,
                style: ElevatedButton.styleFrom(
                  backgroundColor: LevMaxTheme.primaryContainer,
                  foregroundColor: LevMaxTheme.onPrimaryFixed,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                child: Text(
                  _currentSessionIndex < _sessions.length - 1 ? 'LANJUT >>' : 'HASIL >>',
                  style: LevMaxTheme.mono(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCornerReticle({double? top, double? bottom, double? left, double? right}) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          border: Border(
            top: top != null
                ? const BorderSide(color: LevMaxTheme.primaryContainer, width: 3)
                : BorderSide.none,
            bottom: bottom != null
                ? const BorderSide(color: LevMaxTheme.primaryContainer, width: 3)
                : BorderSide.none,
            left: left != null
                ? const BorderSide(color: LevMaxTheme.primaryContainer, width: 3)
                : BorderSide.none,
            right: right != null
                ? const BorderSide(color: LevMaxTheme.primaryContainer, width: 3)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // UI FASE 3: PENENTUAN RANK AKHIR & SYNC KE SUPABASE
  // ============================================================================
  Widget _buildPhase3FinalRankSync() {
    return SingleChildScrollView(
      key: const ValueKey('phase_3_results'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Center(
            child: Column(
              children: [
                Text(
                  '// PHASE 03: AWAKENING EVALUATION //',
                  style: LevMaxTheme.mono(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: LevMaxTheme.primary,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'HASIL UJIAN KEMAMPUAN FISIK',
                  style: LevMaxTheme.headline(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: LevMaxTheme.primaryContainer,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Big Rank Badge Monolith
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: LevMaxTheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: LevMaxTheme.primaryContainer,
                width: 2.0,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x3300F0FF),
                  blurRadius: 20,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  'HUNTER RANK DIANUGERAHKAN',
                  style: LevMaxTheme.mono(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: LevMaxTheme.outline,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: LevMaxTheme.surfaceContainerLowest,
                    border: Border.all(color: LevMaxTheme.primaryContainer, width: 2.5),
                  ),
                  child: Center(
                    child: Text(
                      _finalRank,
                      style: LevMaxTheme.headline(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: LevMaxTheme.primaryContainer,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _finalRank == 'D'
                      ? 'RANK D // EXPERIENCED STRIKER'
                      : (_finalRank == 'E'
                          ? 'RANK E // AWAKENED COMBATANT'
                          : 'RANK F // RECRUIT HUNTER'),
                  style: LevMaxTheme.mono(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: LevMaxTheme.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isBonusRankAchieved
                        ? LevMaxTheme.tertiaryContainer.withValues(alpha: 0.15)
                        : Colors.white10,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _isBonusRankAchieved
                        ? '★ BONUS RANK +1 TINGKAT DIAPLIKASIKAN!'
                        : 'STANDAR EVALUASI // TIDAK MENCAPAI SELURUH THRESHOLD BONUS',
                    style: LevMaxTheme.mono(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: _isBonusRankAchieved
                          ? LevMaxTheme.tertiaryContainer
                          : LevMaxTheme.outline,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Detail Rincian 4 Latihan Fisik
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: LevMaxTheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RINCIAN UJIAN 4 SESI (1 MENIT PER WO):',
                  style: LevMaxTheme.mono(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: LevMaxTheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                _buildWorkoutScoreRow(
                  WorkoutSessionType.pushup.title,
                  _pushupCount,
                  WorkoutSessionType.pushup.bonusThreshold,
                ),
                _buildWorkoutScoreRow(
                  WorkoutSessionType.situp.title,
                  _situpCount,
                  WorkoutSessionType.situp.bonusThreshold,
                ),
                _buildWorkoutScoreRow(
                  WorkoutSessionType.squat.title,
                  _squatCount,
                  WorkoutSessionType.squat.bonusThreshold,
                ),
                _buildWorkoutScoreRow(
                  WorkoutSessionType.pullup.title,
                  _pullupCount,
                  WorkoutSessionType.pullup.bonusThreshold,
                ),
                const Divider(color: Color(0xFF1E293B)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'BMI: $_calculatedBmi ($_tempRank Temp)',
                      style: LevMaxTheme.mono(fontSize: 10, color: LevMaxTheme.outline),
                    ),
                    Text(
                      'TB: ${_tbCm.toInt()} cm | BB: ${_bbKg.toInt()} kg',
                      style: LevMaxTheme.mono(fontSize: 10, color: LevMaxTheme.outline),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // CTA: Sinkronisasi ke Supabase & Masuk ke Main
          GestureDetector(
            onTap: _isSyncing ? null : _syncAwakeningToSupabase,
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
                child: _isSyncing
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
                            'KONFIRMASI KEBANGKITAN & AWALI PERJALANAN',
                            style: LevMaxTheme.mono(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: LevMaxTheme.onPrimary,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward, color: LevMaxTheme.onPrimary, size: 18),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildWorkoutScoreRow(String name, int count, int threshold) {
    final isPassed = count > threshold;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            name,
            style: LevMaxTheme.mono(fontSize: 11, color: LevMaxTheme.onSurface),
          ),
          Row(
            children: [
              Text(
                '$count Reps ',
                style: LevMaxTheme.mono(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isPassed ? LevMaxTheme.tertiaryContainer : LevMaxTheme.onSurface,
                ),
              ),
              Text(
                '(Target: >$threshold)',
                style: LevMaxTheme.mono(fontSize: 9, color: LevMaxTheme.outline),
              ),
              const SizedBox(width: 8),
              Icon(
                isPassed ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 14,
                color: isPassed ? LevMaxTheme.tertiaryContainer : LevMaxTheme.outline,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
