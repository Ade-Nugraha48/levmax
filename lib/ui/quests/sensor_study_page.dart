// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/ui/quests/sensor_study_page.dart
// Deskripsi: In-Quest Sensor: Gyroscope Posture Guardian HUD (FR-5.1)
//            Pixel-Perfect Google Stitch HUD, Realtime Accelerometer/Gyroscope,
//            Dynamic Cyber-Spine Visualizer, Deep Work Clock & Nerd-Neck Detection.
// ==============================================================================

import 'dart:async';
import 'dart:io';
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

class SensorStudyPage extends StatefulWidget {
  final QuestModel? quest;
  final UserModel? player;
  final VoidCallback? onQuestCompleted;

  const SensorStudyPage({
    super.key,
    this.quest,
    this.player,
    this.onQuestCompleted,
  });

  @override
  State<SensorStudyPage> createState() => _SensorStudyPageState();
}

class _SensorStudyPageState extends State<SensorStudyPage> with SingleTickerProviderStateMixin {
  // Sensor Stream & Filter
  StreamSubscription<AccelerometerEvent>? _sensorSubscription;
  double _rawPitch = 12.5;
  double _filteredPitch = 12.5;
  bool _isSensorAvailable = true;

  // Slouching / Nerd-Neck Timer
  bool _isNerdNeck = false;
  double _slouchSecondsRemaining = 8.0;
  Timer? _slouchCountdownTimer;

  // Countdown Hero Timer (45 Menit Cap)
  static const int _totalDurationSeconds = 45 * 60; // 2700 detik
  int _remainingSeconds = 32 * 60 + 15; // default 32:15 sesuai Stitch HUD
  bool _isPaused = false;
  Timer? _countdownTimer;

  // Animasi Pulsing untuk HUD
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _initSensorStream();
    _startCountdownTimer();
  }

  @override
  void dispose() {
    _sensorSubscription?.cancel();
    _countdownTimer?.cancel();
    _slouchCountdownTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  // ==========================================================================
  // SENSOR LOGIC (FR-5.1): ACCELEROMETER TILT & LOW-PASS FILTER
  // ==========================================================================
  void _initSensorStream() {
    try {
      _sensorSubscription = accelerometerEventStream().listen(
        (AccelerometerEvent event) {
          if (!mounted) return;

          // Hitung Pitch Kemiringan Maju/Mundur:
          // Sumbu Y = vertikal smartphone, Sumbu Z = kedalaman layar
          final double calculatedPitch = (atan2(event.z.abs(), event.y.abs()) * 180 / pi);

          // Normalisasi kemiringan ke rentang realistis 5° - 45°
          final double clampedPitch = calculatedPitch.clamp(5.0, 45.0);

          setState(() {
            _rawPitch = clampedPitch;
            // Low-pass filter (smoothing) agar jarum / tulang belakang tidak jitter
            _filteredPitch = (_filteredPitch * 0.85) + (_rawPitch * 0.15);

            // Deteksi Nerd-Neck: Jika kemiringan leher > 25°
            if (_filteredPitch > 25.0) {
              if (!_isNerdNeck) {
                _isNerdNeck = true;
                _startSlouchPenaltyCountdown();
              }
            } else {
              if (_isNerdNeck) {
                _isNerdNeck = false;
                _stopSlouchPenaltyCountdown();
              }
            }
          });
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

  // ==========================================================================
  // LOGIKA SLOUCH PENALTY COUNTDOWN (8 DETIK)
  // ==========================================================================
  void _startSlouchPenaltyCountdown() {
    _slouchSecondsRemaining = 8.0;
    _slouchCountdownTimer?.cancel();

    _slouchCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_slouchSecondsRemaining > 1) {
        setState(() {
          _slouchSecondsRemaining -= 1.0;
        });
        HapticFeedback.lightImpact();
      } else {
        // Hukuman penalti aktif (-50 Mana / HP Loss)
        timer.cancel();
        _applySlouchPenalty();
      }
    });
  }

  void _stopSlouchPenaltyCountdown() {
    _slouchCountdownTimer?.cancel();
    setState(() {
      _slouchSecondsRemaining = 8.0;
    });
  }

  Future<void> _applySlouchPenalty() async {
    HapticFeedback.heavyImpact();

    if (widget.player != null) {
      final updatedHp = max(0, widget.player!.hp - 10);
      final updatedPlayer = widget.player!.copyWith(hp: updatedHp);
      await SupabaseApiService.updateUser(updatedPlayer);
      await BlockchainService.addBlock(
        'POSTURE PENALTY: Nerd-neck posture slouch > 25 deg exceeded 8s. Deducted 10 HP.',
        userId: widget.player!.id,
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          content: Row(
            children: [
              const Icon(Icons.warning, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '[SLOUCH PENALTY EXECUTED] Posture failed! -10 HP / -50 Mana.',
                  style: LevMaxTheme.mono(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
      // Reset countdown agar timer dapat berjalan kembali jika pemain masih menunduk
      _startSlouchPenaltyCountdown();
    }
  }

  // ==========================================================================
  // COUNTDOWN HERO TIMER (DEEP WORK PROTOCOL)
  // ==========================================================================
  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (!_isPaused && _remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else if (_remainingSeconds <= 0) {
        timer.cancel();
        _concludeStudyProtocol(autoCompleted: true);
      }
    });
  }

  void _togglePauseSession() {
    setState(() {
      _isPaused = !_isPaused;
    });
    HapticFeedback.mediumImpact();
  }

  // ==========================================================================
  // AKSI: CONCLUDE STUDY PROTOCOL & EXP REWARD
  // ==========================================================================
  Future<void> _concludeStudyProtocol({bool autoCompleted = false}) async {
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
              'CONCLUDE PROTOCOL?',
              style: LevMaxTheme.headline(fontSize: 16, color: Colors.white),
            ),
          ],
        ),
        content: Text(
          'Synchronization finished with 94% Posture Integrity. Confirm completion to claim +30 EXP & +60 Gold.',
          style: LevMaxTheme.mono(fontSize: 12, color: const Color(0xFFDFE2F1)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('RESUME', style: LevMaxTheme.mono(fontSize: 12, color: const Color(0xFF849495))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00F0FF),
              foregroundColor: const Color(0xFF002022),
            ),
            child: Text('CLAIM & EXIT', style: LevMaxTheme.mono(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF002022))),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // Simpan status quest selesai jika ada quest
      if (widget.quest != null) {
        widget.quest!.isCompleted = true;
        widget.quest!.currentValue = widget.quest!.targetValue;
        await widget.quest!.save();
        if (widget.player != null) {
          await SupabaseApiService.syncQuest(quest: widget.quest!, userId: widget.player!.id);
        }
      } else {
        // Cari quest study di Hive jika dibuka via tab
        final box = Hive.box<QuestModel>(HiveBoxes.questBox);
        for (final q in box.values) {
          if (q.category.toLowerCase() == 'study' && !q.isCompleted) {
            q.isCompleted = true;
            q.currentValue = q.targetValue;
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
            icon: const Icon(Icons.arrow_back, color: Color(0xFFDFE2F1), size: 20),
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
                    color: const Color(0xFF00F0FF),
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
              boxShadow: [
                BoxShadow(color: Color(0x3300F0FF), blurRadius: 8),
              ],
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
  // KOMPONEN 2: PROTOCOL TELEMETRY BADGE
  // ==========================================================================
  Widget _buildProtocolTelemetryBadge() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1F2A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x14FFFFFF), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  FadeTransition(
                    opacity: _pulseController,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF00F0FF),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Color(0xFF00F0FF), blurRadius: 6, spreadRadius: 1),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'GYROSCOPE AXIS-6 SYNC',
                    style: LevMaxTheme.mono(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF00F0FF),
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF262A35),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt, size: 12, color: Color(0xFF4EDEA3)),
                    const SizedBox(width: 4),
                    Text(
                      'FOCUS BUFF (+15% EXP)',
                      style: LevMaxTheme.mono(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF4EDEA3),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '[DEEP WORK PROTOCOL]',
                style: LevMaxTheme.headline(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFDFE2F1),
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                '45M CAP // SECTOR-07',
                style: LevMaxTheme.mono(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFB9CACB),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // KOMPONEN 3: INTERACTIVE GYROSCOPE POSTURE GUARDIAN HUD (INTI SENSOR)
  // ==========================================================================
  Widget _buildInteractivePostureGuardianHUD() {
    final isOptimal = _filteredPitch <= 15.0;
    final isCaution = _filteredPitch > 15.0 && _filteredPitch <= 25.0;
    final isSlouching = _filteredPitch > 25.0;

    Color statusColor = const Color(0xFF65F2B5);
    String statusText = 'VESSEL AXIS STABLE';
    if (isCaution) {
      statusColor = const Color(0xFFB9CACB);
      statusText = 'CAUTION TILT DETECTED';
    } else if (isSlouching) {
      statusColor = const Color(0xFFEF4444);
      statusText = 'AXIS CRITICAL';
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF171B26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSlouching ? const Color(0x66EF4444) : const Color(0x1400F0FF),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Bar HUD
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.screen_rotation, size: 16, color: Color(0xFF00F0FF)),
                  const SizedBox(width: 6),
                  Text(
                    'GYRO PITCH: ',
                    style: LevMaxTheme.mono(fontSize: 11, color: const Color(0xFFB9CACB)),
                  ),
                  Text(
                    '${_filteredPitch.toStringAsFixed(1)}°',
                    style: LevMaxTheme.mono(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: isSlouching ? const Color(0xFFEF4444) : const Color(0xFF00F0FF),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF313540),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _isSensorAvailable ? 'REALTIME HUD' : 'SIMULATED HUD',
                  style: LevMaxTheme.mono(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFDFE2F1),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Visualizer Center: _CyberSpinePainter
          SizedBox(
            height: 180,
            child: Stack(
              children: [
                // Custom Paint Radar & Dynamic Cyber Spine
                Positioned.fill(
                  child: CustomPaint(
                    painter: _CyberSpinePainter(
                      pitchAngle: _filteredPitch,
                      isNerdNeck: isSlouching,
                    ),
                  ),
                ),

                // Status Overlay Kanan Bawah
                Positioned(
                  bottom: 6,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A0E18).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: statusColor, blurRadius: 6),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          statusText,
                          style: LevMaxTheme.mono(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Threshold Safety Meter (3 Fase)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF65F2B5),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '0°-15° OPTIMAL',
                    style: LevMaxTheme.mono(
                      fontSize: 10,
                      fontWeight: isOptimal ? FontWeight.bold : FontWeight.w500,
                      color: const Color(0xFF65F2B5),
                    ),
                  ),
                ],
              ),
              Text(
                '16°-24° CAUTION',
                style: LevMaxTheme.mono(
                  fontSize: 10,
                  fontWeight: isCaution ? FontWeight.bold : FontWeight.w500,
                  color: const Color(0xFFB9CACB),
                ),
              ),
              Text(
                '25°+ NERD-NECK',
                style: LevMaxTheme.mono(
                  fontSize: 10,
                  fontWeight: isSlouching ? FontWeight.bold : FontWeight.w500,
                  color: const Color(0xFFEF4444),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Progress Bar Tersegmentasi
          _buildSegmentedPostureProgressBar(),
        ],
      ),
    );
  }

  Widget _buildSegmentedPostureProgressBar() {
    final ratio = (_filteredPitch / 45.0).clamp(0.0, 1.0);
    Color fillColor = const Color(0xFF65F2B5);
    if (_filteredPitch > 25.0) {
      fillColor = const Color(0xFFEF4444);
    } else if (_filteredPitch > 15.0) {
      fillColor = const Color(0xFFFBBF24);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final fillWidth = totalWidth * ratio;

        return Container(
          height: 8,
          decoration: BoxDecoration(
            color: const Color(0xFF313540),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: fillWidth,
                height: 8,
                decoration: BoxDecoration(
                  color: fillColor,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(color: fillColor.withValues(alpha: 0.6), blurRadius: 6),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================================================
  // KOMPONEN 4: POSTURE ALERT MODULE (NERD-NECK WARNING)
  // ==========================================================================
  Widget _buildPostureAlertModule() {
    if (!_isNerdNeck) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x66451A03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF59E0B), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFFCD34D)),
                  const SizedBox(width: 6),
                  Text(
                    'WARNING: NERD-NECK DETECTED!',
                    style: LevMaxTheme.headline(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFFCD34D),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF78350F),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '00:0${_slouchSecondsRemaining.toInt()}s',
                  style: LevMaxTheme.mono(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFFDE68A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Straighten cervical vertebrae. Slouch penalty triggers stat loss (-50 Mana / HP) in 00:0${_slouchSecondsRemaining.toInt()}s.',
            style: LevMaxTheme.mono(
              fontSize: 11,
              color: const Color(0xFFFDE68A),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // KOMPONEN 5: COUNTDOWN HERO CLOCK
  // ==========================================================================
  Widget _buildCountdownHeroClock() {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    final timeStr = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    final completedPercent = (((_totalDurationSeconds - _remainingSeconds) / _totalDurationSeconds) * 100).toInt();
    final elapsedMins = ((_totalDurationSeconds - _remainingSeconds) / 60.0).toStringAsFixed(1);
    final progressRatio = ((_totalDurationSeconds - _remainingSeconds) / _totalDurationSeconds).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1F2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x14FFFFFF), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.timelapse, size: 14, color: Color(0xFF00F0FF)),
              const SizedBox(width: 6),
              Text(
                'REMAINING DEEP WORK',
                style: LevMaxTheme.mono(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFB9CACB),
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Angka Countdown Raksasa (36px Space Grotesk Bold Cyan)
          Text(
            timeStr,
            style: LevMaxTheme.headline(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF00F0FF),
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 12),

          // Bawah: Status Persentase & Menit
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$completedPercent% COMPLETED',
                style: LevMaxTheme.mono(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFDFE2F1),
                ),
              ),
              Text(
                '$elapsedMins / 45.0 MINS',
                style: LevMaxTheme.mono(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFB9CACB),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          GlowingProgressBar(
            progress: progressRatio,
            color: const Color(0xFF00F0FF),
            height: 8,
            trackColor: const Color(0xFF0A0E18),
            glowBlurRadius: 10,
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // KOMPONEN 6: PIXEL ART ASSET & LORE MODULE
  // ==========================================================================
  Widget _buildLoreModule() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF171B26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x14FFFFFF), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Lore
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_stories, size: 16, color: Color(0xFFD2BBFF)),
                  const SizedBox(width: 8),
                  Text(
                    'SCHOLAR VESSEL SANCTUARY',
                    style: LevMaxTheme.headline(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFD2BBFF),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E1065),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0x44D2BBFF), width: 1),
                ),
                child: Text(
                  'S-TIER FOCUS',
                  style: LevMaxTheme.mono(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFD2BBFF),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Gambar Pixel Art dengan Overlay
          Container(
            height: 154,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0x3300F0FF), width: 1),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Render asset gambar lokal hasil generate
                Image.file(
                  File(r'C:\Users\Adi\.gemini\antigravity-ide\brain\5f8ad352-2d94-4c53-ba93-021150af1020\scholar_sanctuary_1792431629553.jpg'),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Image.asset(
                    'assets/images/scholar_sanctuary.jpg',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFF0F131D),
                      child: const Center(
                        child: Icon(Icons.computer, size: 48, color: Color(0xFF00F0FF)),
                      ),
                    ),
                  ),
                ),

                // Gradient Vignette
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0x99000000)],
                    ),
                  ),
                ),

                // Pill Overlays di atas gambar
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xCC0A0E18),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0x3365F2B5)),
                    ),
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
                        const SizedBox(width: 5),
                        Text(
                          'ALIGNMENT: 94% INTEGRITY',
                          style: LevMaxTheme.mono(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xCC0A0E18),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0x33D2BBFF)),
                    ),
                    child: Text(
                      '+240 EXP / HR',
                      style: LevMaxTheme.mono(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFD2BBFF),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Inscription Lore Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1F2A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0x14FFFFFF), width: 1),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.verified, size: 16, color: Color(0xFF00F0FF)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '"The Sovereign hunter yields not to physical fatigue. By mastering cranial posture, the mana pathways flow unobstructed through the cerebral cortex."',
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFFB9CACB),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // KOMPONEN 7: BOTTOM ACTION CONTROLS
  // ==========================================================================
  Widget _buildBottomControls() {
    return Column(
      children: [
        // Tombol 1: Pause Session
        GestureDetector(
          onTap: _togglePauseSession,
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF262A35),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0x3300F0FF), width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.coffee, size: 18, color: Color(0xFF00F0FF)),
                const SizedBox(width: 8),
                Text(
                  _isPaused ? 'RESUME FOCUS SESSION' : 'PAUSE SESSION [TAKE 5M BREAK]',
                  style: LevMaxTheme.mono(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF00F0FF),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Tombol 2: Conclude Study Protocol
        GestureDetector(
          onTap: () => _concludeStudyProtocol(autoCompleted: false),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0x28EF4444),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0x66EF4444), width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.stop_circle_outlined, size: 18, color: Color(0xFFEF4444)),
                const SizedBox(width: 8),
                Text(
                  'CONCLUDE STUDY PROTOCOL',
                  style: LevMaxTheme.mono(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFEF4444),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Komponen 2: Protocol Telemetry Badge
                    _buildProtocolTelemetryBadge(),
                    const SizedBox(height: 14),

                    // Komponen 3: Interactive Gyroscope Posture Guardian HUD
                    _buildInteractivePostureGuardianHUD(),

                    // Komponen 4: Posture Alert Module (Tampil dinamis jika Nerd-Neck)
                    _buildPostureAlertModule(),
                    const SizedBox(height: 14),

                    // Komponen 5: Countdown Hero Clock
                    _buildCountdownHeroClock(),
                    const SizedBox(height: 14),

                    // Komponen 6: Pixel Art Asset & Lore Module
                    _buildLoreModule(),
                    const SizedBox(height: 20),

                    // Komponen 7: Bottom Action Controls
                    _buildBottomControls(),
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
// CUSTOM PAINTER: DYNAMIC CYBER-SPINE & GYROSCOPE HUD VISUALIZER
// ==============================================================================
class _CyberSpinePainter extends CustomPainter {
  final double pitchAngle; // Dalam derajat
  final bool isNerdNeck;

  _CyberSpinePainter({
    required this.pitchAngle,
    required this.isNerdNeck,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // 1. Gambar Background Radar Konsentris
    final radarPaint = Paint()
      ..color = const Color(0xFF313540).withValues(alpha: 0.45)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, 40, radarPaint);
    canvas.drawCircle(center, 70, radarPaint);

    // Garis Crosshair Sumbu Tengah
    canvas.drawLine(Offset(center.dx - 12, center.dy), Offset(center.dx + 12, center.dy), radarPaint);
    canvas.drawLine(Offset(center.dx, center.dy - 12), Offset(center.dx, center.dy + 12), radarPaint);

    // 2. Datum Vertikal Ideal (Garis Putus-Putus)
    final datumPaint = Paint()
      ..color = const Color(0xFF313540).withValues(alpha: 0.7)
      ..strokeWidth = 1.0;
    const dashHeight = 4.0;
    const dashSpace = 4.0;
    double startY = 20;
    while (startY < size.height - 20) {
      canvas.drawLine(Offset(center.dx, startY), Offset(center.dx, startY + dashHeight), datumPaint);
      startY += dashHeight + dashSpace;
    }

    // 3. Kotak Jangkar Dasar Tulang Belakang (Spine Base Anchor)
    final baseRect = Rect.fromCenter(
      center: Offset(center.dx, size.height - 24),
      width: 14,
      height: 8,
    );
    final anchorPaint = Paint()..color = const Color(0xFF00F0FF);
    canvas.drawRRect(RRect.fromRectAndRadius(baseRect, const Radius.circular(2)), anchorPaint);

    // 4. Kalkulasi Defleksi Tulang Belakang Dinamis berdasarkan Pitch
    // Pitch 0°-15° = deviasi halus; > 25° = kurva condong tajam ke kanan
    final double tiltRatio = (pitchAngle / 45.0).clamp(0.0, 1.0);
    final double maxHeadShiftX = 42.0 * tiltRatio; // pergeseran kepala ke arah kanan

    final spineStart = Offset(center.dx, size.height - 28);
    final spineEnd = Offset(center.dx + maxHeadShiftX, 48);

    // Titik Kontrol Lengkung Tulang Belakang
    final controlPoint = Offset(center.dx + (maxHeadShiftX * 0.4), (spineStart.dy + spineEnd.dy) / 2);

    final spinePath = Path()
      ..moveTo(spineStart.dx, spineStart.dy)
      ..quadraticBezierTo(controlPoint.dx, controlPoint.dy, spineEnd.dx, spineEnd.dy);

    // Glow Effect Tulang Belakang
    final spineGlowPaint = Paint()
      ..color = (isNerdNeck ? const Color(0xFFEF4444) : const Color(0xFF00F0FF)).withValues(alpha: 0.5)
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawPath(spinePath, spineGlowPaint);

    // Garis Utama Tulang Belakang
    final spinePaint = Paint()
      ..color = isNerdNeck ? const Color(0xFFEF4444) : const Color(0xFF00F0FF)
      ..strokeWidth = 3.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(spinePath, spinePaint);

    // 5. Vertebrae Nodes (5 Titik Bercahaya di sepanjang kurva)
    final nodePaint = Paint()..color = const Color(0xFFDBFCFF);
    for (double t = 0.2; t <= 0.8; t += 0.2) {
      // Rumus kuadratik bezier: B(t) = (1-t)^2 P0 + 2(1-t)t P1 + t^2 P2
      final double nx = (1 - t) * (1 - t) * spineStart.dx + 2 * (1 - t) * t * controlPoint.dx + t * t * spineEnd.dx;
      final double ny = (1 - t) * (1 - t) * spineStart.dy + 2 * (1 - t) * t * controlPoint.dy + t * t * spineEnd.dy;
      canvas.drawCircle(Offset(nx, ny), 3, nodePaint);
    }

    // 6. Cybernetic Head Outline di ujung Spine
    final headCenter = spineEnd;
    final headRect = Rect.fromCenter(center: headCenter, width: 22, height: 18);

    final headFillPaint = Paint()..color = const Color(0xFF0A0E18);
    final headBorderPaint = Paint()
      ..color = isNerdNeck ? const Color(0xFFEF4444) : const Color(0xFF00F0FF)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    canvas.drawOval(headRect, headFillPaint);
    canvas.drawOval(headRect, headBorderPaint);

    // Visor mata bercahaya di dalam kepala
    final visorPaint = Paint()..color = const Color(0xFF00F0FF);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(headCenter.dx + 2, headCenter.dy), width: 10, height: 3),
        const Radius.circular(1),
      ),
      visorPaint,
    );

    // 7. Gaze Ray (Garis Pandangan Putus-Putus ke Kanan-Bawah)
    final gazeStart = Offset(headCenter.dx + 8, headCenter.dy + 2);
    final gazeEnd = Offset(gazeStart.dx + 30, gazeStart.dy + 16);
    final gazePaint = Paint()
      ..color = const Color(0xFF65F2B5)
      ..strokeWidth = 1.4;

    double gX = gazeStart.dx;
    double gY = gazeStart.dy;
    const gStep = 4.0;
    while (gX < gazeEnd.dx) {
      canvas.drawLine(Offset(gX, gY), Offset(gX + 2, gY + 1), gazePaint);
      gX += gStep;
      gY += (16 / 30) * gStep;
    }
    // Panah ujung gaze
    canvas.drawLine(gazeEnd, Offset(gazeEnd.dx - 4, gazeEnd.dy - 4), gazePaint);
    canvas.drawLine(gazeEnd, Offset(gazeEnd.dx - 5, gazeEnd.dy + 1), gazePaint);

    // 8. Dynamic Tilt Arc Gauge & Teks Derajat
    final arcPaint = Paint()
      ..color = isNerdNeck ? const Color(0xFFEF4444) : const Color(0xFF65F2B5)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;

    final arcRect = Rect.fromCircle(center: center, radius: 76);
    canvas.drawArc(arcRect, -pi / 2 - 0.2, 0.45 * tiltRatio + 0.15, false, arcPaint);

    // Teks Label Derajat "12° OPTIMAL"
    final textSpan = TextSpan(
      text: '${pitchAngle.toStringAsFixed(0)}° ${isNerdNeck ? 'NERD-NECK' : 'OPTIMAL'}',
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 10,
        fontWeight: FontWeight.w900,
        color: isNerdNeck ? const Color(0xFFEF4444) : const Color(0xFF65F2B5),
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(canvas, Offset(headCenter.dx + 16, headCenter.dy - 12));
  }

  @override
  bool shouldRepaint(covariant _CyberSpinePainter oldDelegate) {
    return oldDelegate.pitchAngle != pitchAngle || oldDelegate.isNerdNeck != isNerdNeck;
  }
}
