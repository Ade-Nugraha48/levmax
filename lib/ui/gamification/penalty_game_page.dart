// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/ui/gamification/penalty_game_page.dart
// Deskripsi: Pixel-Perfect Penalty Zone Mini-Game (FR-6.1 & Google Stitch HUD)
//            Survival Tap-Tap 50x Reps vs Poison Centipede dalam 15 Detik.
//            Hazard Marquee Tape, Top Alert System Window, Countdown Timer Card,
//            Centipede Arena with Reticle & Hazard Striping, Giant Strike CTA,
//            Haptic Feedback, Blockchain Audit Log, & Game Over Routing.
// ==============================================================================

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/user_model.dart';
import '../../services/blockchain_service.dart';
import '../../services/supabase_api_service.dart';
import '../main_navigation_page.dart';
import 'game_over_page.dart';

class PenaltyGamePage extends StatefulWidget {
  final UserModel? player;

  const PenaltyGamePage({super.key, this.player});

  @override
  State<PenaltyGamePage> createState() => _PenaltyGamePageState();
}

class _PenaltyGamePageState extends State<PenaltyGamePage>
    with TickerProviderStateMixin {
  // ============================================================================
  // TOKEN WARNA & KONSTANTA EKSAK GOOGLE STITCH HUD
  // ============================================================================
  static const Color surface = Color(0xFF0F131D);
  static const Color surfaceContainerLowest = Color(0xFF0A0E18);
  static const Color surfaceContainerLow = Color(0xFF171B26);
  static const Color surfaceContainer = Color(0xFF1C1F2A);
  static const Color error = Color(0xFFFFB4AB); // Coral/Pink-Red terang
  static const Color errorContainer = Color(0xFF93000A); // Merah darah gelap
  static const Color onSurface = Color(0xFFDFE2F1);
  static const Color onSurfaceVariant = Color(0xFFB9CACB);
  static const Color outline = Color(0xFF849495);
  static const Color cyanAccent = Color(0xFF00F0FF);
  static const Color redGlow = Color(0xFFFF2A54);

  // Target Game
  static const int _targetTaps = 50;
  static const int _initialSeconds = 15;

  int _tapCount = 0;
  int _secondsLeft = _initialSeconds;
  Timer? _countdownTimer;
  bool _isGameOver = false;
  bool _isVictory = false;
  bool _isButtonPressed = false;

  // Controllers Animasi
  late AnimationController _pulseController;
  late AnimationController _rippleController;
  late AnimationController _shakeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rippleAnimation;

  late UserModel _currentPlayer;

  @override
  void initState() {
    super.initState();

    _currentPlayer =
        widget.player ??
        SupabaseApiService.getPlayerCache() ??
        UserModel(username: 'Hunter', email: '');

    // 1. Controller Denyut Pendaran & Marquee Pulse
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );

    // 2. Controller Ripple Cincin Ping Giant CTA
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _rippleAnimation = CurvedAnimation(
      parent: _rippleController,
      curve: Curves.easeOutQuad,
    );

    // 3. Controller Getaran Monster saat terkena Strike
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );

    // Memulai Countdown Survival 15 Detik
    _startTimer();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseController.dispose();
    _rippleController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  // ============================================================================
  // LOGIKA SURVIVAL MINI-GAME (FR-6.1)
  // ============================================================================
  void _startTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft > 1) {
        setState(() {
          _secondsLeft--;
        });
      } else {
        setState(() {
          _secondsLeft = 0;
        });
        timer.cancel();
        if (_tapCount < _targetTaps) {
          _triggerDefeat();
        }
      }
    });
  }

  void _onStrikeTap() {
    if (_isGameOver || _isVictory || _secondsLeft <= 0) return;

    HapticFeedback.lightImpact();

    // Trigger Monster Shake Animation
    _shakeController.forward(from: 0.0);

    setState(() {
      _tapCount++;
    });

    if (_tapCount >= _targetTaps) {
      _triggerVictory();
    }
  }

  Future<void> _triggerVictory() async {
    _countdownTimer?.cancel();
    setState(() {
      _isVictory = true;
    });

    HapticFeedback.heavyImpact();

    try {
      // 1. Pulihkan +10 HP (maksimal 100) dan nonaktifkan penalty
      final newHp = min(100, _currentPlayer.hp + 10);
      final updatedPlayer = _currentPlayer.copyWith(
        hp: newHp,
        isPenaltyActive: false,
      );

      await SupabaseApiService.savePlayerCache(updatedPlayer);

      // 2. Catat ke Blockchain Ledger
      await BlockchainService.addBlock(
        'PENALTY SURVIVED: POISON CENTIPEDE REPELLED WITH $_tapCount TAPS. RECOVERED +10 HP.',
        userId: updatedPlayer.id,
      );

      // 3. Sinkronisasi ke Cloud Supabase
      try {
        await SupabaseApiService.updateUser(updatedPlayer);
      } catch (e) {
        debugPrint('[PenaltyGamePage] Supabase update failed: $e');
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'SURVIVAL SUCCESSFUL: Poison Centipede repelled! +10 HP restored.',
            style: GoogleFonts.jetBrainsMono(
              color: const Color(0xFF002022),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          backgroundColor: cyanAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Kembali ke Main Navigation
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigationPage()),
        (route) => false,
      );
    } catch (e) {
      debugPrint('[PenaltyGamePage] Victory error: $e');
    }
  }

  void _triggerDefeat() {
    _countdownTimer?.cancel();
    setState(() {
      _isGameOver = true;
    });

    HapticFeedback.heavyImpact();

    // Menuju Game Over Screen (Anda Tidak Layak)
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => GameOverPage(
          player: _currentPlayer,
          previousLevel: _currentPlayer.level,
          previousRank: _currentPlayer.rank,
        ),
      ),
    );
  }

  void _confirmAbandon() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: error.withValues(alpha: 0.3)),
          ),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: error, size: 22),
              const SizedBox(width: 8),
              Text(
                'ABANDON PROTOCOL?',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: error,
                ),
              ),
            ],
          ),
          content: Text(
            'Fleeing the Penalty Zone is classified as Treason by The Monarch. '
            'Abandoning will cause instant vessel failure and complete Player Demotion to Rank F.',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              color: onSurfaceVariant,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'STAY & FIGHT',
                style: GoogleFonts.jetBrainsMono(
                  color: cyanAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: errorContainer,
                foregroundColor: error,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _triggerDefeat();
              },
              child: Text(
                'ABANDON (DEMOTE)',
                style: GoogleFonts.jetBrainsMono(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================================
  // KOMPONEN 1: TACTICAL HEADER & HAZARD MARQUEE TAPE
  // ============================================================================
  Widget _buildTacticalHeader() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Sisi Kiri: Tombol Silang 'X' Kustom (Meminta Konfirmasi, bukan pop biasa)
          GestureDetector(
            onTap: _confirmAbandon,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: surfaceContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: const Icon(Icons.close, size: 18, color: onSurface),
            ),
          ),

          // Tengah: SYS_CRITICAL // + Judul PENALTY ZONE MINI GAME
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: redGlow,
                        boxShadow: [
                          BoxShadow(
                            color: redGlow.withValues(
                              alpha: 0.4 + 0.6 * _pulseAnimation.value,
                            ),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(width: 6),
                Text(
                  'SYS_CRITICAL // ',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: error,
                    letterSpacing: 0.6,
                  ),
                ),
                Flexible(
                  child: Text(
                    'PENALTY ZONE MINI...',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: onSurface,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Sisi Kanan: Avatar Pengguna Mini
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: surfaceContainer,
              border: Border.all(
                color: cyanAccent.withValues(alpha: 0.7),
                width: 1.5,
              ),
            ),
            child: const Center(
              child: Icon(Icons.person_outline, size: 18, color: cyanAccent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHazardMarqueeTape() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: errorContainer,
        boxShadow: [
          BoxShadow(
            color: redGlow.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Icon(
                      Icons.warning_amber_rounded,
                      size: 14,
                      color: Color.lerp(
                        error,
                        Colors.white,
                        _pulseAnimation.value,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'EMERGENCY PROTOCOL // MONARCH PENALTY ACTIVE',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      color: error,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF1A0305),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: error.withValues(alpha: 0.4),
                width: 0.8,
              ),
            ),
            child: Text(
              'LVL 0 EXILE',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
                color: error,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // KOMPONEN 2: TOP ALERT SYSTEM WINDOW
  // ============================================================================
  Widget _buildTopAlertSystemWindow() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: errorContainer.withValues(alpha: 0.35),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Baris Atas: Badge Kiri & Kanan
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: errorContainer,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: redGlow.withValues(alpha: 0.3),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Icon(
                          Icons.crisis_alert,
                          size: 13,
                          color: Color.lerp(
                            error,
                            Colors.white,
                            _pulseAnimation.value,
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'PENALTY QUEST ACTIVE',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: error,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),

              // Badge Kanan: PULSE: 178 BPM
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF313540),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.favorite_border, size: 12, color: error),
                    const SizedBox(width: 4),
                    Text(
                      'PULSE: 178 BPM',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Teks Deskripsi Lore dengan Highlight
          RichText(
            text: TextSpan(
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11.5,
                color: onSurfaceVariant,
                height: 1.45,
              ),
              children: const [
                TextSpan(text: 'Daily quest completion failed. Survive the '),
                TextSpan(
                  text: 'Desert of Centipedes',
                  style: TextStyle(
                    color: error,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                    decorationColor: error,
                  ),
                ),
                TextSpan(text: ' or face complete '),
                TextSpan(
                  text: 'Player Deletion',
                  style: TextStyle(
                    color: error,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                    decorationColor: error,
                  ),
                ),
                TextSpan(text: '.'),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Telemetry Bawah (Gelap)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: surfaceContainerLowest.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ZONE: PENALTY DESERT // SECTOR 00',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    color: outline,
                    letterSpacing: 0.4,
                  ),
                ),
                Text(
                  'HUNTER_ID: #${_currentPlayer.id.toString().padLeft(4, '0')}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: onSurface,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // KOMPONEN 3: COUNTDOWN TIMER CARD
  // ============================================================================
  Widget _buildCountdownTimerCard() {
    final minutes = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsLeft % 60).toString().padLeft(2, '0');
    final timerString = '00:$minutes:$seconds';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: error.withValues(alpha: 0.15), width: 1),
        boxShadow: [
          BoxShadow(
            color: redGlow.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Header: Ikon Timer + TIME UNTIL MONARCH EXECUTION
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Icon(
                    Icons.timer_outlined,
                    size: 14,
                    color: Color.lerp(error, redGlow, _pulseAnimation.value),
                  );
                },
              ),
              const SizedBox(width: 6),
              Text(
                'TIME UNTIL MONARCH EXECUTION',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: error,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Angka Timer Raksasa (Space Grotesk 36px Bold)
          Text(
            timerString,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: error,
              letterSpacing: 2.0,
              shadows: const [
                Shadow(
                  color: Color(0x99FF2A54),
                  blurRadius: 16,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Bawah: DEATH RAY CHARGING // FATAL RANGE
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: redGlow,
                      boxShadow: [
                        BoxShadow(
                          color: redGlow.withValues(
                            alpha: 0.4 + 0.6 * _pulseAnimation.value,
                          ),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(width: 6),
              Text(
                'DEATH RAY CHARGING // FATAL RANGE',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9.5,
                  color: outline,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // KOMPONEN 4: CENTIPEDE MONSTER ARENA & RETICLE FRAME
  // ============================================================================
  Widget _buildCentipedeArena() {
    final progress = (_tapCount / _targetTaps).clamp(0.0, 1.0);
    final progressPercent = (progress * 100).toInt();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Target: Belah Ketupat + TARGET: POISON CENTIPEDE & Badge RANK-S
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Transform.rotate(
                    angle: pi / 4,
                    child: Container(width: 8, height: 8, color: error),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'TARGET: POISON CENTIPEDE',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: error,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: error.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: error.withValues(alpha: 0.30),
                    width: 1,
                  ),
                ),
                child: Text(
                  'RANK-S THREAT',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: error,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Area Reticle Centipede Monster
          Center(
            child: SizedBox(
              width: 220,
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 4 Reticle Corner Ticks
                  Positioned(top: 0, left: 0, child: _buildReticleTick()),
                  Positioned(top: 0, right: 0, child: _buildReticleTick()),
                  Positioned(bottom: 0, left: 0, child: _buildReticleTick()),
                  Positioned(bottom: 0, right: 0, child: _buildReticleTick()),

                  // Lingkaran Pendaran Reticle Merah Darah
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Container(
                        width: 184,
                        height: 184,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: errorContainer.withValues(alpha: 0.3),
                          border: Border.all(
                            color: redGlow.withValues(
                              alpha: 0.4 + 0.3 * _pulseAnimation.value,
                            ),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: redGlow.withValues(
                                alpha: 0.2 + 0.2 * _pulseAnimation.value,
                              ),
                              blurRadius: 24,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // Monster Image dengan Shake Effect saat Tap
                  AnimatedBuilder(
                    animation: _shakeController,
                    builder: (context, child) {
                      final offset = sin(_shakeController.value * pi * 4) * 5;
                      return Transform.translate(
                        offset: Offset(offset, 0),
                        child: ClipOval(
                          child: Container(
                            width: 172,
                            height: 172,
                            color: surfaceContainerLowest,
                            child: Image.asset(
                              'assets/images/penalty_centipede.png',
                              fit: BoxFit.cover,
                              errorBuilder: (context, err, stackTrace) {
                                return const Center(
                                  child: Icon(
                                    Icons.bug_report,
                                    size: 68,
                                    color: error,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // Crosshair Reticle Center (+)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: CustomPaint(
                          size: const Size(64, 64),
                          painter: _CrosshairReticlePainter(
                            color: error.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Overlay Pill Bawah Gambar: ENRAGED // SPRINT VELOCITY 84KM/H
                  Positioned(
                    bottom: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: error,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black54,
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        'ENRAGED // SPRINT VELOCITY 84KM/H',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF4A0005),
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Survival Progress Readout
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.directions_run, size: 14, color: error),
                  const SizedBox(width: 6),
                  Text(
                    'SURVIVAL TAPS',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: onSurface,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              Text(
                '$_tapCount / $_targetTaps TAPS REQUIRED ($progressPercent%)',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: error,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Progress Bar Taktis dengan Hazard Pattern Striping
          Container(
            height: 14,
            decoration: BoxDecoration(
              color: surfaceContainerLowest,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: CustomPaint(
                size: Size.infinite,
                painter: _HazardStripedProgressBarPainter(
                  progress: progress,
                  fillColor: error,
                  stripeColor: errorContainer,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),

          // Bawah Progress Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '0 (DEATH ZONE)',
                style: GoogleFonts.jetBrainsMono(fontSize: 9, color: outline),
              ),
              Text(
                'SURVIVAL ESCAPE THRESHOLD: $_targetTaps TAPS',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: outline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReticleTick() {
    return Container(
      width: 10,
      height: 10,
      color: error.withValues(alpha: 0.4),
    );
  }

  // ============================================================================
  // KOMPONEN 5: PRIMARY STRIKE BUTTON (GIANT CTA DENGAN ANIMASI PING/RIPPLE)
  // ============================================================================
  Widget _buildPrimaryStrikeButton() {
    return Column(
      children: [
        Center(
          child: SizedBox(
            width: 170,
            height: 170,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Lapisan Ripple 1 (Paling Luar)
                AnimatedBuilder(
                  animation: _rippleAnimation,
                  builder: (context, child) {
                    final scale = 1.0 + 0.45 * _rippleAnimation.value;
                    final opacity =
                        (1.0 - _rippleAnimation.value).clamp(0.0, 1.0) * 0.4;
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 136,
                        height: 136,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: error.withValues(alpha: opacity),
                            width: 2,
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // Lapisan Ripple 2 (Tengah)
                AnimatedBuilder(
                  animation: _rippleAnimation,
                  builder: (context, child) {
                    final progress2 = (_rippleAnimation.value + 0.5) % 1.0;
                    final scale = 1.0 + 0.30 * progress2;
                    final opacity = (1.0 - progress2).clamp(0.0, 1.0) * 0.5;
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 136,
                        height: 136,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: redGlow.withValues(alpha: opacity),
                            width: 2.5,
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // Giant Circular Strike Button
                GestureDetector(
                  onTapDown: (_) => setState(() => _isButtonPressed = true),
                  onTapUp: (_) => setState(() => _isButtonPressed = false),
                  onTapCancel: () => setState(() => _isButtonPressed = false),
                  onTap: _onStrikeTap,
                  child: AnimatedScale(
                    scale: _isButtonPressed ? 0.94 : 1.0,
                    duration: const Duration(milliseconds: 70),
                    child: Container(
                      width: 136,
                      height: 136,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: error,
                        boxShadow: [
                          BoxShadow(
                            color: redGlow.withValues(alpha: 0.5),
                            blurRadius: 28,
                            spreadRadius: 3,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Crossed Swords Vector Icon
                          CustomPaint(
                            size: const Size(36, 36),
                            painter: _CrossedSwordsPainter(
                              color: errorContainer,
                            ),
                          ),
                          const SizedBox(height: 6),

                          // Text STRIKE
                          Text(
                            'STRIKE',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: errorContainer,
                              letterSpacing: 1.5,
                            ),
                          ),

                          // [TAP RAPIDLY!]
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Opacity(
                                opacity: 0.6 + 0.4 * _pulseAnimation.value,
                                child: Text(
                                  '[TAP RAPIDLY!]',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: errorContainer,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // TAP FREQUENCY: ACCELERATE TO EVADE
        Text(
          'TAP FREQUENCY: ACCELERATE TO EVADE',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 9.5,
            color: outline,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // KOMPONEN 6: BOTTOM WARNING BANNER
  // ============================================================================
  Widget _buildBottomWarningBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: surfaceContainerLow,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left Accent Bar Merah Tebal 4px
            Container(
              width: 4,
              decoration: const BoxDecoration(
                color: error,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(6),
                  bottomLeft: Radius.circular(6),
                ),
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PENALTY STAKES',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: error,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          color: onSurfaceVariant,
                          height: 1.45,
                        ),
                        children: const [
                          TextSpan(
                            text: 'Failure to reach 50 taps before 00:00 will result in ',
                          ),
                          TextSpan(
                            text: 'Total Player Demotion',
                            style: TextStyle(
                              color: error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: ', complete stat nullification, and removal from the Hunter Registry.',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // MAIN BUILD METHOD
  // ============================================================================
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _confirmAbandon();
        }
      },
      child: Scaffold(
        backgroundColor: surface,
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Komponen 1: Header & Hazard Marquee
                _buildTacticalHeader(),
                _buildHazardMarqueeTape(),
                const SizedBox(height: 14),

                // Komponen 2: Top Alert System Window
                _buildTopAlertSystemWindow(),
                const SizedBox(height: 14),

                // Komponen 3: Countdown Timer Card
                _buildCountdownTimerCard(),
                const SizedBox(height: 14),

                // Komponen 4: Centipede Monster Arena
                _buildCentipedeArena(),
                const SizedBox(height: 16),

                // Komponen 5: Primary Strike Button
                _buildPrimaryStrikeButton(),
                const SizedBox(height: 16),

                // Komponen 6: Bottom Warning Banner
                _buildBottomWarningBanner(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==============================================================================
// CUSTOM PAINTER: HAZARD STRIPED PROGRESS BAR (DIAGONAL STRIPES)
// ==============================================================================
class _HazardStripedProgressBarPainter extends CustomPainter {
  final double progress;
  final Color fillColor;
  final Color stripeColor;

  _HazardStripedProgressBarPainter({
    required this.progress,
    required this.fillColor,
    required this.stripeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final fillWidth = size.width * progress;
    final fillRect = Rect.fromLTWH(0, 0, fillWidth, size.height);

    // 1. Draw Solid Fill Base
    final basePaint = Paint()..color = fillColor;
    canvas.drawRect(fillRect, basePaint);

    // 2. Draw Diagonal Hazard Stripes
    final stripePaint = Paint()
      ..color = stripeColor.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    canvas.save();
    canvas.clipRect(fillRect);

    const stripeGap = 10.0;
    for (double x = -size.height; x < fillWidth + size.height; x += stripeGap) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        stripePaint,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HazardStripedProgressBarPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// ==============================================================================
// CUSTOM PAINTER: RETICLE CROSSHAIR (+)
// ==============================================================================
class _CrosshairReticlePainter extends CustomPainter {
  final Color color;

  _CrosshairReticlePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final cx = size.width / 2;
    final cy = size.height / 2;
    const len = 10.0;
    const gap = 6.0;

    // Horizontal left & right
    canvas.drawLine(Offset(cx - gap - len, cy), Offset(cx - gap, cy), paint);
    canvas.drawLine(Offset(cx + gap, cy), Offset(cx + gap + len, cy), paint);

    // Vertical top & bottom
    canvas.drawLine(Offset(cx, cy - gap - len), Offset(cx, cy - gap), paint);
    canvas.drawLine(Offset(cx, cy + gap), Offset(cx, cy + gap + len), paint);

    // Center Dot
    canvas.drawCircle(Offset(cx, cy), 1.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _CrosshairReticlePainter oldDelegate) => false;
}

// ==============================================================================
// CUSTOM PAINTER: CROSSED SWORDS VECTOR ICON
// ==============================================================================
class _CrossedSwordsPainter extends CustomPainter {
  final Color color;

  _CrossedSwordsPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final bladePaint = Paint()
      ..color = color
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;

    final hiltPaint = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    // Sword 1: Top-Left to Bottom-Right
    canvas.drawLine(
      Offset(w * 0.22, h * 0.22),
      Offset(w * 0.78, h * 0.78),
      bladePaint,
    );
    // Hilt 1
    canvas.drawLine(
      Offset(w * 0.68, h * 0.82),
      Offset(w * 0.82, h * 0.68),
      hiltPaint,
    );

    // Sword 2: Top-Right to Bottom-Left
    canvas.drawLine(
      Offset(w * 0.78, h * 0.22),
      Offset(w * 0.22, h * 0.78),
      bladePaint,
    );
    // Hilt 2
    canvas.drawLine(
      Offset(w * 0.18, h * 0.68),
      Offset(w * 0.32, h * 0.82),
      hiltPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CrossedSwordsPainter oldDelegate) => false;
}
