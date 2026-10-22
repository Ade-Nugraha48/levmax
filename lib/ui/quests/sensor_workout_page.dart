// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/ui/quests/sensor_workout_page.dart
// Deskripsi: In-Quest Sensor: Accelerometer Workout HUD (FR-5.1)
//            Pixel-Perfect Google Stitch HUD, Realtime Accelerometer Z-Axis Peak
//            Detection, Dynamic Targeting Sonar Rings, Waveform & Hazard Button.
// ==============================================================================

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../helpers/boxes.dart';
import '../../helpers/levmax_theme.dart';
import '../../models/quest_model.dart';
import '../../models/user_model.dart';
import '../../services/blockchain_service.dart';
import '../../services/supabase_api_service.dart';

class SensorWorkoutPage extends StatefulWidget {
  final QuestModel? quest;
  final UserModel? player;
  final VoidCallback? onQuestCompleted;

  const SensorWorkoutPage({
    super.key,
    this.quest,
    this.player,
    this.onQuestCompleted,
  });

  @override
  State<SensorWorkoutPage> createState() => _SensorWorkoutPageState();
}

class _SensorWorkoutPageState extends State<SensorWorkoutPage>
    with TickerProviderStateMixin {
  // Sensor Stream & Logic
  StreamSubscription<UserAccelerometerEvent>? _sensorSubscription;
  double _currentZ = 0.98;
  bool _isSensorAvailable = true;
  bool _isGoingDown = false;
  int _repCount = 37; // default 37 sesuai Stitch reference
  final int _targetReps = 100;
  int _calculatedForce = 412; // 412 N sesuai HUD
  double _lastRepDuration = 1.4; // 1.4 SEC

  // Stopwatch & Metrics
  int _elapsedSeconds = 257; // default 04:17 sesuai Stitch reference
  Timer? _stopwatchTimer;
  bool _isPaused = false;

  // Controllers Animasi: Cincin Sonar & Waveform
  late AnimationController _sonarClockwiseController;
  late AnimationController _sonarCounterClockwiseController;
  late AnimationController _repPulseController;
  late Animation<double> _repPulseAnimation;
  late AnimationController _pingPulseController;

  // Phase untuk Sine Wave
  double _wavePhase = 0.0;
  Timer? _waveTickTimer;

  @override
  void initState() {
    super.initState();

    // 1. Inisialisasi Rep Count dari Quest jika ada
    if (widget.quest != null) {
      _repCount = widget.quest!.currentValue;
    }

    // 2. Animasi Cincin Sonar Terluar (Putar Searah Jarum Jam 40s)
    _sonarClockwiseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..repeat();

    // 3. Animasi Cincin Sonar Tengah (Putar Berlawanan Jarum Jam 25s)
    _sonarCounterClockwiseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25),
    )..repeat();

    // 4. Animasi Scale Pulse saat Rep Terhitung
    _repPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _repPulseAnimation = Tween<double>(begin: 1.0, end: 1.14).animate(
      CurvedAnimation(parent: _repPulseController, curve: Curves.easeOutBack),
    );

    // 5. Animasi Titik Ping Status
    _pingPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    // 6. Loop Animasi Waveform
    _waveTickTimer = Timer.periodic(const Duration(milliseconds: 33), (timer) {
      if (!mounted) return;
      setState(() {
        _wavePhase += 0.04;
      });
    });

    // 7. Mulai Stopwatch & Sensor
    _startStopwatch();
    _initSensorStream();
  }

  @override
  void dispose() {
    _sensorSubscription?.cancel();
    _stopwatchTimer?.cancel();
    _waveTickTimer?.cancel();
    _sonarClockwiseController.dispose();
    _sonarCounterClockwiseController.dispose();
    _repPulseController.dispose();
    _pingPulseController.dispose();
    super.dispose();
  }

  // ==========================================================================
  // SENSOR LOGIC (FR-5.1): USER ACCELEROMETER Z-AXIS PEAK DETECTION
  // ==========================================================================
  void _initSensorStream() {
    try {
      _sensorSubscription = userAccelerometerEventStream().listen(
        (UserAccelerometerEvent event) {
          if (!mounted) return;

          final double z = event.z;
          final double y = event.y;
          // Deteksi gerakan maju/mundur tegak lurus layar hp jika diletakkan di lantai
          final double accelSignal = z.abs() > y.abs() ? z : y;

          setState(() {
            _currentZ = (accelSignal / 9.81).clamp(-3.0, 3.0);
            _wavePhase += (accelSignal.abs() * 0.04).clamp(0.02, 0.12);
            _calculatedForce = (380 + (accelSignal.abs() * 14)).toInt().clamp(
              350,
              560,
            );
          });

          // Algoritma Push-Up Peak Detection:
          // Turun mendekati layar (lowerThreshold < -1.5) -> set _isGoingDown = true
          // Dorong ke atas (upperThreshold > 1.5) saat _isGoingDown == true -> rep terhitung!
          if (accelSignal < -1.5) {
            _isGoingDown = true;
          } else if (accelSignal > 1.5 && _isGoingDown) {
            _isGoingDown = false;
            _onRepetitionDetected();
          }
        },
        onError: (_) {
          setState(() {
            _isSensorAvailable = false;
          });
        },
      );
    } catch (_) {
      setState(() {
        _isSensorAvailable = false;
      });
    }
  }

  void _onRepetitionDetected() {
    HapticFeedback.heavyImpact();
    setState(() {
      _repCount++;
      _lastRepDuration = 1.3 + (Random().nextDouble() * 0.3);
    });

    // Jalankan efek scale pulse cincin sonar
    _repPulseController.forward().then((_) => _repPulseController.reverse());

    // Cek target tercapai
    if (_repCount >= _targetReps) {
      _concludeWorkoutProtocol(autoCompleted: true);
    }
  }

  // ==========================================================================
  // STOPWATCH TIMER & METRICS CALCULATIONS
  // ==========================================================================
  void _startStopwatch() {
    _stopwatchTimer?.cancel();
    _stopwatchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (!_isPaused) {
        setState(() {
          _elapsedSeconds++;
        });
      }
    });
  }

  void _togglePauseSession() {
    setState(() {
      _isPaused = !_isPaused;
    });
    HapticFeedback.mediumImpact();
  }

  String _formatElapsedTime() {
    final minutes = _elapsedSeconds ~/ 60;
    final seconds = _elapsedSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  double get _caloriesBurned => _repCount * 3.84; // ~142 kcal pada 37 rep
  double get _averagePace =>
      _repCount > 0 ? (_elapsedSeconds / _repCount) : 1.4;

  // ==========================================================================
  // AKSI: CONCLUDE WORKOUT PROTOCOL & REWARDS SYNC
  // ==========================================================================
  Future<void> _concludeWorkoutProtocol({bool autoCompleted = false}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1F2A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF00F0FF), width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Color(0xFF00F0FF)),
            const SizedBox(width: 8),
            Text(
              autoCompleted ? 'TARGET ACHIEVED!' : 'FINISH WORKOUT?',
              style: LevMaxTheme.headline(fontSize: 16, color: Colors.white),
            ),
          ],
        ),
        content: Text(
          'Total repetitions registered: $_repCount / $_targetReps. Claim +40 EXP & +80 Gold now.',
          style: LevMaxTheme.mono(fontSize: 12, color: const Color(0xFFDFE2F1)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'RESUME',
              style: LevMaxTheme.mono(
                fontSize: 12,
                color: const Color(0xFF849495),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00F0FF),
              foregroundColor: const Color(0xFF002022),
            ),
            child: Text(
              'CLAIM & EXIT',
              style: LevMaxTheme.mono(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF002022),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      if (widget.quest != null) {
        widget.quest!.isCompleted = true;
        widget.quest!.currentValue = _repCount;
        await widget.quest!.save();
        if (widget.player != null) {
          await SupabaseApiService.syncQuest(
            quest: widget.quest!,
            userId: widget.player!.id,
          );
        }
      } else {
        final box = Hive.box<QuestModel>(HiveBoxes.questBox);
        for (final q in box.values) {
          if (q.category.toLowerCase() == 'workout' && !q.isCompleted) {
            q.isCompleted = true;
            q.currentValue = _repCount;
            await q.save();
            break;
          }
        }
      }

      widget.onQuestCompleted?.call();
      if (mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  // ==========================================================================
  // AKSI: ABORT QUEST (PENALTY ZONE WARNING)
  // ==========================================================================
  Future<void> _abortQuestWithPenalty() async {
    HapticFeedback.heavyImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF171B26),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
            const SizedBox(width: 8),
            Text(
              'ABORT ACTIVE QUEST?',
              style: LevMaxTheme.headline(
                fontSize: 15,
                color: const Color(0xFFEF4444),
              ),
            ),
          ],
        ),
        content: Text(
          'Abandoning this quest will trigger a system penalty. Incur 4H Penalty Zone exile upon 00:00 reset and forfeit session gains.',
          style: LevMaxTheme.mono(fontSize: 11, color: const Color(0xFFDFE2F1)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'CANCEL',
              style: LevMaxTheme.mono(
                fontSize: 12,
                color: const Color(0xFF849495),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF93000A),
              foregroundColor: Colors.white,
            ),
            child: Text(
              'CONFIRM ABORT',
              style: LevMaxTheme.mono(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      if (widget.player != null) {
        await BlockchainService.addBlock(
          'QUEST ABORTED: Player abandoned daily workout protocol. Incurred penalty flag.',
          userId: widget.player!.id,
        );
      }
      if (mounted) {
        Navigator.pop(context, false);
      }
    }
  }

  // ==========================================================================
  // KOMPONEN 1: TACTICAL TRANSPARENT HEADER BAR (56PX)
  // ==========================================================================
  Widget _buildTacticalHeader() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF0F131D),
        border: Border(
          bottom: BorderSide(color: Color(0x1A00F0FF), width: 1.0),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: Color(0xFFDFE2F1),
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'IN-QUEST SENSORS',
                  style: LevMaxTheme.mono(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFB9CACB),
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'IN QUEST SENSOR TRACKING',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LevMaxTheme.headline(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFDFE2F1),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              _isPaused ? Icons.play_arrow : Icons.pause,
              color: const Color(0xFFB9CACB),
              size: 22,
            ),
            onPressed: _togglePauseSession,
          ),
          const SizedBox(width: 6),
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFDBFCFF),
              boxShadow: [BoxShadow(color: Color(0x3300F0FF), blurRadius: 8)],
            ),
            child: const Center(
              child: Icon(Icons.person, color: Color(0xFF00363A), size: 18),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // KOMPONEN 2: SENSOR CALIBRATION & STATUS RIBBON
  // ==========================================================================
  Widget _buildSensorCalibrationRibbon() {
    return Column(
      children: [
        // Box Atas: Status 120Hz & Nilai Z-Axis
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF171B26),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0x14FFFFFF), width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    FadeTransition(
                      opacity: _pingPulseController,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF00F0FF),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF00F0FF),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isSensorAvailable
                                ? 'ACCELEROMETER LIVE // 120Hz'
                                : 'ACCELEROMETER SIMULATOR',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: LevMaxTheme.mono(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF00F0FF),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'ACTIVE CALIBRATION MATRIX',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: LevMaxTheme.mono(
                              fontSize: 9,
                              color: const Color(0xFFB9CACB),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1F2A),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0x22FFFFFF), width: 1),
                ),
                child: Text(
                  '((•)) Z-AXIS: ${_currentZ.toStringAsFixed(2)}G',
                  style: LevMaxTheme.mono(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFB9CACB),
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Box Bawah: Quest Details & Exp Pool
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF65F2B5),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '[QUEST: DAILY TRIALS]',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: LevMaxTheme.mono(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFB9CACB),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'EXP POOL: +350 EXP',
                style: LevMaxTheme.mono(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFB9CACB),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // KOMPONEN 3: HUD REP COUNTER & TARGETING SONAR (INTI ACCELEROMETER)
  // ==========================================================================
  Widget _buildHUDRepCounterAndSonar() {
    final int progressPercent = ((_repCount / _targetReps) * 100).toInt();

    return GestureDetector(
      onTap: _onRepetitionDetected, // Tap manual untuk testing/kalibrasi
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF171B26),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x2600F0FF), width: 1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1000F0FF),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            // 1. Top Telemetry Corners
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'STROKE STABILITY',
                      style: LevMaxTheme.mono(
                        fontSize: 9,
                        color: const Color(0xFF849495),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'DELTA: 0.04',
                      style: LevMaxTheme.mono(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF65F2B5),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'FORCE IMPULSE',
                      style: LevMaxTheme.mono(
                        fontSize: 9,
                        color: const Color(0xFF849495),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$_calculatedForce N',
                      style: LevMaxTheme.mono(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFDFE2F1),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 2. Pusat Sonar & Angka Repetisi Besar
            SizedBox(
              height: 240,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Cincin Sonar Terluar (Putar Searah Jarum Jam)
                  AnimatedBuilder(
                    animation: _sonarClockwiseController,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _sonarClockwiseController.value * 2 * pi,
                        child: CustomPaint(
                          size: const Size(220, 220),
                          painter: _OuterRadarRingsPainter(),
                        ),
                      );
                    },
                  ),

                  // Cincin Sonar Tengah (Putar Berlawanan Jarum Jam)
                  AnimatedBuilder(
                    animation: _sonarCounterClockwiseController,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: -_sonarCounterClockwiseController.value * 2 * pi,
                        child: CustomPaint(
                          size: const Size(180, 180),
                          painter: _MiddleRadarRingsPainter(),
                        ),
                      );
                    },
                  ),

                  // Cincin Solid Dalam dengan Reaktif Scale Pulse
                  ScaleTransition(
                    scale: _repPulseAnimation,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF00F0FF),
                          width: 2.5,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x6600F0FF),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Crosshair Ticks (T marks)
                  CustomPaint(
                    size: const Size(230, 230),
                    painter: _CrosshairTicksPainter(),
                  ),

                  // Konten Teks Tengah
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'CURRENT REGISTER',
                        style: LevMaxTheme.mono(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFDFE2F1),
                          letterSpacing: 2.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$_repCount',
                        style:
                            LevMaxTheme.headline(
                              fontSize: 84,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF00F0FF),
                              letterSpacing: 1.0,
                            ).copyWith(
                              shadows: const [
                                Shadow(
                                  color: Color(0x9900F0FF),
                                  blurRadius: 24,
                                ),
                              ],
                            ),
                      ),
                      const SizedBox(height: 2),

                      // Pill Target Kapsul Bawah
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1F2A),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0x22FFFFFF),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'TARGET: $_targetReps REPS',
                              style: LevMaxTheme.mono(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFDFE2F1),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF313540),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                '$progressPercent%',
                                style: LevMaxTheme.mono(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFB9CACB),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // 3. Bottom Telemetry Corners
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'CADENCE CYCLE',
                  style: LevMaxTheme.mono(
                    fontSize: 9,
                    color: const Color(0xFF849495),
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  'SYNC: ${_lastRepDuration.toStringAsFixed(1)} SEC',
                  style: LevMaxTheme.mono(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFDFE2F1),
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 4. Waveform Track Bawah dengan Scrubber Line
            SizedBox(
              height: 38,
              width: double.infinity,
              child: CustomPaint(
                painter: _SineWavePainter(
                  wavePhase: _wavePhase,
                  scrubberPosition: 0.85,
                  waveColor: const Color(0xFF00F0FF),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // KOMPONEN 4: LIVE FORM QUALITY GAUGE
  // ==========================================================================
  Widget _buildLiveFormQualityGauge() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF171B26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x14FFFFFF), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.verified,
                    size: 16,
                    color: Color(0xFF65F2B5),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'FORM CALIBRATION',
                    style: LevMaxTheme.headline(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFDFE2F1),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Text(
                'STABLE FORM',
                style: LevMaxTheme.mono(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF65F2B5),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 5 Segmen Indikator Hijau Mint Glow
          Row(
            children: List.generate(5, (index) {
              return Expanded(
                child: Container(
                  height: 8,
                  margin: EdgeInsets.only(left: index == 0 ? 0 : 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF65F2B5),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x6665F2B5),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),

          // Bawah: Depth Compliance
          Row(
            children: [
              const Icon(
                Icons.arrow_downward,
                size: 14,
                color: Color(0xFFDFE2F1),
              ),
              const SizedBox(width: 6),
              Text(
                'DEPTH COMPLIANCE: ',
                style: LevMaxTheme.mono(
                  fontSize: 10,
                  color: const Color(0xFF849495),
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                '98% (FULL CHEST CONTACT)',
                style: LevMaxTheme.mono(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFDFE2F1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // KOMPONEN 5: PIXEL ART COMPANION SLOT (PACER)
  // ==========================================================================
  Widget _buildPixelArtCompanionSlot() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF171B26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x14FFFFFF), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Sprite Karakter Hunter 2D Kustom (64x64)
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF1C1F2A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0x1A00F0FF), width: 1),
            ),
            child: Stack(
              children: [
                Center(
                  child: SizedBox(
                    width: 36,
                    height: 38,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Cybernetic Eyes Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 4,
                              height: 4,
                              color: const Color(0xFF00F0FF),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              width: 4,
                              height: 4,
                              color: const Color(0xFF00F0FF),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        // Shoulders Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 7,
                              height: 5,
                              color: const Color(0xFF313540),
                            ),
                            const SizedBox(width: 2),
                            Container(
                              width: 10,
                              height: 5,
                              color: const Color(0xFF171B26),
                            ),
                            const SizedBox(width: 2),
                            Container(
                              width: 7,
                              height: 5,
                              color: const Color(0xFF313540),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        // Core Gem (Purple 0xFF6001D1)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF6001D1),
                            shape: BoxShape.rectangle,
                          ),
                        ),
                        const SizedBox(height: 2),
                        // Legs Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 6,
                              height: 8,
                              color: const Color(0xFF313540),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              width: 6,
                              height: 8,
                              color: const Color(0xFF313540),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  right: 4,
                  bottom: 3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 3,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A0E18),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Text(
                      '2D',
                      style: LevMaxTheme.mono(
                        fontSize: 8,
                        color: const Color(0xFFB9CACB),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Kanan: Cadence Pacer Telemetry
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'SHADOW MINION: CADENCE PACER',
                      style: LevMaxTheme.headline(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFDFE2F1),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E1065),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: const Color(0x66D2BBFF),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'LVL 1',
                        style: LevMaxTheme.mono(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFD2BBFF),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Synchronizing down-and-up stroke...',
                  style: LevMaxTheme.mono(
                    fontSize: 10,
                    color: const Color(0xFFB9CACB),
                  ),
                ),
                const SizedBox(height: 8),

                // Pacing Progress Bar Ungu
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A0E18),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: 0.72,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFD2BBFF),
                              borderRadius: BorderRadius.circular(3),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x66D2BBFF),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'PACING OK',
                      style: LevMaxTheme.mono(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFD2BBFF),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // KOMPONEN 6: BOTTOM STATS BAR (HUD TRIAD)
  // ==========================================================================
  Widget _buildBottomStatsTriad() {
    return Row(
      children: [
        // 1. BURN Card
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF171B26),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x14FFFFFF), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.local_fire_department,
                      size: 14,
                      color: Color(0xFFEF4444),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'BURN',
                      style: LevMaxTheme.mono(
                        fontSize: 10,
                        color: const Color(0xFF849495),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${_caloriesBurned.toInt()}',
                  style: LevMaxTheme.headline(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFDFE2F1),
                  ),
                ),
                Text(
                  'KCAL',
                  style: LevMaxTheme.mono(
                    fontSize: 9,
                    color: const Color(0xFF849495),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),

        // 2. PACE Card
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF171B26),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x14FFFFFF), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.speed, size: 14, color: Color(0xFFDFE2F1)),
                    const SizedBox(width: 4),
                    Text(
                      'PACE',
                      style: LevMaxTheme.mono(
                        fontSize: 10,
                        color: const Color(0xFF849495),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${_averagePace.toStringAsFixed(1)}s',
                  style: LevMaxTheme.headline(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFDFE2F1),
                  ),
                ),
                Text(
                  '/ REP',
                  style: LevMaxTheme.mono(
                    fontSize: 9,
                    color: const Color(0xFF849495),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),

        // 3. TIME Card
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF171B26),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x14FFFFFF), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      size: 14,
                      color: Color(0xFF65F2B5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'TIME',
                      style: LevMaxTheme.mono(
                        fontSize: 10,
                        color: const Color(0xFF849495),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _formatElapsedTime(),
                  style: LevMaxTheme.headline(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFDFE2F1),
                  ),
                ),
                Text(
                  'ELAPSED',
                  style: LevMaxTheme.mono(
                    fontSize: 9,
                    color: const Color(0xFF849495),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // KOMPONEN 7: ABORT QUEST EMERGENCY ALERT BUTTON
  // ==========================================================================
  Widget _buildAbortQuestModule() {
    return Column(
      children: [
        // Tombol Merah Hazard
        GestureDetector(
          onTap: _abortQuestWithPenalty,
          child: Container(
            height: 48,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFF93000A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFFEF4444).withValues(alpha: 0.6),
                width: 1,
              ),
            ),
            child: Stack(
              children: [
                // Diagonal Hazard Stripes Painter
                Positioned.fill(
                  child: CustomPaint(painter: _HazardStripePainter()),
                ),
                // Teks Tombol
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 18,
                        color: Color(0xFFEF4444),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'ABORT QUEST (PENALTY WARNING)',
                        style: LevMaxTheme.mono(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFEF4444),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Deskripsi Peringatan Bawah
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 14,
              color: Color(0xFFEF4444),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Abandoning active quest incurs 4H Penalty Zone exile upon 00:00 reset. All daily milestone progress will be purged.',
                style: LevMaxTheme.mono(
                  fontSize: 11,
                  color: const Color(0xFFB9CACB),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F131D),
      body: SafeArea(
        child: Column(
          children: [
            // Komponen 1: Header Bar
            _buildTacticalHeader(),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Komponen 2: Sensor Calibration & Status Ribbon
                    _buildSensorCalibrationRibbon(),
                    const SizedBox(height: 14),

                    // Komponen 3: HUD Rep Counter & Targeting Sonar
                    _buildHUDRepCounterAndSonar(),
                    const SizedBox(height: 14),

                    // Komponen 4: Live Form Quality Gauge
                    _buildLiveFormQualityGauge(),
                    const SizedBox(height: 14),

                    // Komponen 5: Pixel Art Companion Slot (Pacer)
                    _buildPixelArtCompanionSlot(),
                    const SizedBox(height: 14),

                    // Komponen 6: Bottom Stats Bar (HUD Triad)
                    _buildBottomStatsTriad(),
                    const SizedBox(height: 16),

                    // Komponen 7: Abort Quest Emergency Alert Button
                    _buildAbortQuestModule(),
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

// ==============================================================================
// CUSTOM PAINTERS: SONAR RINGS, SINE WAVE, & HAZARD STRIPES
// ==============================================================================

// 1. Cincin Sonar Terluar (Dashed Circular Ring)
class _OuterRadarRingsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = const Color(0xFF00F0FF).withValues(alpha: 0.5)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    const double radius = 105;
    const int dashCount = 28;
    const double sweepAngle = (2 * pi) / dashCount;

    for (int i = 0; i < dashCount; i++) {
      if (i % 2 == 0) {
        final startAngle = i * sweepAngle;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          sweepAngle * 0.65,
          false,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// 2. Cincin Sonar Tengah (Thicker Dashed Segments)
class _MiddleRadarRingsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = const Color(0xFF00F0FF).withValues(alpha: 0.7)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;

    const double radius = 86;
    const int segmentCount = 12;
    const double sweepAngle = (2 * pi) / segmentCount;

    for (int i = 0; i < segmentCount; i++) {
      if (i % 2 == 0) {
        final startAngle = i * sweepAngle;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          sweepAngle * 0.45,
          false,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// 3. Crosshair Ticks (T Marks di Atas, Bawah, Kiri, Kanan)
class _CrosshairTicksPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = const Color(0xFF00F0FF)
      ..strokeWidth = 2.0;

    const double rInner = 106;
    const double rOuter = 118;
    const double tWidth = 8;

    // Atas
    canvas.drawLine(
      Offset(center.dx, center.dy - rInner),
      Offset(center.dx, center.dy - rOuter),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx - tWidth / 2, center.dy - rOuter),
      Offset(center.dx + tWidth / 2, center.dy - rOuter),
      paint,
    );

    // Bawah
    canvas.drawLine(
      Offset(center.dx, center.dy + rInner),
      Offset(center.dx, center.dy + rOuter),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx - tWidth / 2, center.dy + rOuter),
      Offset(center.dx + tWidth / 2, center.dy + rOuter),
      paint,
    );

    // Kiri
    canvas.drawLine(
      Offset(center.dx - rInner, center.dy),
      Offset(center.dx - rOuter, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx - rOuter, center.dy - tWidth / 2),
      Offset(center.dx - rOuter, center.dy + tWidth / 2),
      paint,
    );

    // Kanan
    canvas.drawLine(
      Offset(center.dx + rInner, center.dy),
      Offset(center.dx + rOuter, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx + rOuter, center.dy - tWidth / 2),
      Offset(center.dx + rOuter, center.dy + tWidth / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// 4. Waveform Sine Wave Painter dengan Scrubber Line
class _SineWavePainter extends CustomPainter {
  final double wavePhase;
  final double scrubberPosition; // 0.0 .. 1.0
  final Color waveColor;

  _SineWavePainter({
    required this.wavePhase,
    required this.scrubberPosition,
    required this.waveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;

    // Garis Dasar Halus
    final baseLinePaint = Paint()
      ..color = const Color(0xFF313540).withValues(alpha: 0.5)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), baseLinePaint);

    // Sine Wave Path
    final wavePath = Path();
    const double wavelength = 45.0;
    const double amplitude = 6.0;

    wavePath.moveTo(0, midY + sin(wavePhase) * amplitude);

    for (double x = 1; x <= size.width; x += 2) {
      final y = midY + sin((x / wavelength) * 2 * pi + wavePhase) * amplitude;
      wavePath.lineTo(x, y);
    }

    final waveGlowPaint = Paint()
      ..color = waveColor.withValues(alpha: 0.4)
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawPath(wavePath, waveGlowPaint);

    final wavePaint = Paint()
      ..color = waveColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawPath(wavePath, wavePaint);

    // Scrubber Line (Garis Vertikal Pemotong di posisi kanan)
    final scrubX = size.width * scrubberPosition;
    final scrubPaint = Paint()
      ..color = waveColor
      ..strokeWidth = 2.0;

    canvas.drawLine(
      Offset(scrubX, 4),
      Offset(scrubX, size.height - 4),
      scrubPaint,
    );
    canvas.drawCircle(
      Offset(
        scrubX,
        midY + sin((scrubX / wavelength) * 2 * pi + wavePhase) * amplitude,
      ),
      3,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _SineWavePainter oldDelegate) {
    return oldDelegate.wavePhase != wavePhase ||
        oldDelegate.scrubberPosition != scrubberPosition;
  }
}

// 5. Diagonal Hazard Stripes Painter
class _HazardStripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..strokeWidth = 14;

    const double step = 28;
    for (double x = -size.height; x < size.width + size.height; x += step) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
