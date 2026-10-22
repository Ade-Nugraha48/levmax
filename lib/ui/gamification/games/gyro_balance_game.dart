// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/ui/gamification/games/gyro_balance_game.dart
// Deskripsi: Game 1 Gyroscope / Accelerometer "Mana Core Stabilization" (Prompt 11)
//            Mekanik: Seimbangkan Mana Core di dalam Target Ring selama 15 detik.
//            Fisika: Sensor kemiringan perangkat (sensors_plus) real-time.
//            Kondisi: Jarak Euclidean ke pusat melebihi batas = Kalah (Failed).
//                     Bertahan 15 detik = Menang (Stabilized) + Daily Reward (+50G).
// ==============================================================================

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../../helpers/levmax_theme.dart';
import '../../../models/user_model.dart';
import '../../../services/minigame_service.dart';

class GyroBalanceGamePage extends StatefulWidget {
  final UserModel player;
  final VoidCallback onPlayerUpdated;

  const GyroBalanceGamePage({
    super.key,
    required this.player,
    required this.onPlayerUpdated,
  });

  @override
  State<GyroBalanceGamePage> createState() => _GyroBalanceGamePageState();
}

enum GameState {
  ready,
  playing,
  failed,
  won,
}

class _GyroBalanceGamePageState extends State<GyroBalanceGamePage>
    with TickerProviderStateMixin {
  // Sensor Stream & Physics State
  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  Timer? _gameLoopTimer;

  // Koordinat Bola (Piksel relatif terhadap pusat arena)
  double _ballX = 0.0;
  double _ballY = 0.0;
  double _velX = 0.0;
  double _velY = 0.0;

  // Sensor Raw Data untuk Telemetry HUD
  double _rawSensorX = 0.0;
  double _rawSensorY = 0.0;

  // Parameter Fisika & Arena
  static const double _targetRingRadius = 110.0; // Radius Cincin Target
  static const double _coreRadius = 18.0; // Radius Bola Mana Core
  static const double _maxSafeDistance = _targetRingRadius - _coreRadius; // ~92px
  static const double _sensorSensitivity = 0.85;
  static const double _dampingFriction = 0.92;

  // Timer & Game State
  GameState _gameState = GameState.ready;
  double _remainingSeconds = 15.0;
  static const double _totalGameDuration = 15.0;

  // Reward State
  bool _isClaimSuccess = false;
  bool _isAlreadyClaimedToday = false;

  // Animasi Efek Visual
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _winCoinController;

  @override
  void initState() {
    super.initState();

    // Inisialisasi Animasi Pulse Radar Ring
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Animasi Pop-up Koin Emas Kemenangan
    _winCoinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _isAlreadyClaimedToday = MinigameService.isDailyRewardClaimed();

    // Mulai game secara otomatis setelah frame pertama dirender
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startGame();
    });
  }

  @override
  void dispose() {
    _accelSubscription?.cancel();
    _gameLoopTimer?.cancel();
    _pulseController.dispose();
    _winCoinController.dispose();
    super.dispose();
  }

  // ============================================================================
  // INISIALISASI & GAME LOOP FISIKA GYROSCOPE / ACCELEROMETER
  // ============================================================================
  void _startGame() {
    setState(() {
      _ballX = 0.0;
      _ballY = 0.0;
      _velX = 0.0;
      _velY = 0.0;
      _remainingSeconds = _totalGameDuration;
      _gameState = GameState.playing;
    });

    // 1. Pasang Stream Accelerometer untuk input kemiringan perangkat
    _accelSubscription?.cancel();
    try {
      _accelSubscription = accelerometerEventStream(
        samplingPeriod: SensorInterval.gameInterval,
      ).listen(
        (AccelerometerEvent event) {
          if (_gameState != GameState.playing) return;
          _rawSensorX = event.x;
          _rawSensorY = event.y;

          // Dalam orientasi portrait:
          // Miring ke kanan: event.x negatif -> gaya gerak ke kanan (+ax)
          // Miring ke depan: event.y negatif -> gaya gerak ke atas (-ay)
          final ax = -event.x * _sensorSensitivity;
          final ay = event.y * _sensorSensitivity;

          _velX = (_velX + ax) * _dampingFriction;
          _velY = (_velY + ay) * _dampingFriction;
        },
        onError: (e) {
          debugPrint('[GyroGame] Accelerometer stream error: $e');
        },
      );
    } catch (e) {
      debugPrint('[GyroGame] Failed to listen to accelerometer: $e');
    }

    // 2. Game Loop Timer (Interval 20ms ~ 50 FPS)
    _gameLoopTimer?.cancel();
    const tickDuration = Duration(milliseconds: 20);
    _gameLoopTimer = Timer.periodic(tickDuration, (timer) {
      if (!mounted || _gameState != GameState.playing) return;

      setState(() {
        // Update Posisi Bola berdasarkan Kecepatan
        _ballX += _velX;
        _ballY += _velY;

        // Hitung Jarak Euclidean dari Pusat (0, 0)
        final distance = math.sqrt((_ballX * _ballX) + (_ballY * _ballY));

        // KONDISI KALAH (OUT OF BOUNDS): Bola menyentuh batas luar lingkaran
        if (distance > _maxSafeDistance) {
          _triggerGameOver();
          return;
        }

        // Hitung Mundur Timer 15 Detik
        _remainingSeconds -= 0.02;
        if (_remainingSeconds <= 0.0) {
          _remainingSeconds = 0.0;
          _triggerVictory();
        }
      });
    });
  }

  // ============================================================================
  // KONDISI KALAH (SYNCHRONIZATION FAILED)
  // ============================================================================
  void _triggerGameOver() {
    _gameLoopTimer?.cancel();
    _accelSubscription?.cancel();

    HapticFeedback.heavyImpact();

    setState(() {
      _gameState = GameState.failed;
    });
  }

  // ============================================================================
  // KONDISI MENANG (MANA CORE STABILIZED) & DAILY REWARD VALIDASI
  // ============================================================================
  Future<void> _triggerVictory() async {
    _gameLoopTimer?.cancel();
    _accelSubscription?.cancel();

    HapticFeedback.lightImpact();
    _winCoinController.forward(from: 0.0);

    // Eksekusi Logika Reward Harian Sesuai Aturan Game
    final claimSuccess = await MinigameService.claimDailyReward(
      player: widget.player,
      rewardGold: 50,
    );

    widget.onPlayerUpdated();

    setState(() {
      _gameState = GameState.won;
      _isClaimSuccess = claimSuccess;
      _isAlreadyClaimedToday = MinigameService.isDailyRewardClaimed();
    });
  }

  // ============================================================================
  // BUILD UTAMA (ARENA GAME & TACTICAL HUD)
  // ============================================================================
  @override
  Widget build(BuildContext context) {
    final distance = math.sqrt((_ballX * _ballX) + (_ballY * _ballY));
    final stabilityRatio = (1.0 - (distance / _maxSafeDistance)).clamp(0.0, 1.0);
    final isNearEdge = distance > (_maxSafeDistance * 0.72);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E18),
      body: SafeArea(
        child: Stack(
          children: [
            // 1. Grid Garis-garis Vektor Cyberpunk Background
            CustomPaint(
              size: Size.infinite,
              painter: _CyberArenaGridPainter(
                isCritical: isNearEdge && _gameState == GameState.playing,
              ),
            ),

            // 2. Telemetry Top Bar (Timer, Stabilitas & Header)
            _buildTopTelemetryBar(stabilityRatio),

            // 3. Central Arena: Target Ring & Mana Core
            Center(
              child: SizedBox(
                width: _targetRingRadius * 2 + 40,
                height: _targetRingRadius * 2 + 40,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // A. Tactical Rings & Crosshairs
                    _buildTacticalTargetRing(isNearEdge),

                    // B. The Mana Core (Bola Pemain)
                    _buildTheManaCore(isNearEdge),
                  ],
                ),
              ),
            ),

            // 4. Live Sensor Tilt Readout di Bagian Bawah
            _buildBottomTiltReadout(distance),

            // 5. Fallback Gesture Detector untuk Pengujian Tanpa Sensor Fisik (Simulator/Desktop)
            if (_gameState == GameState.playing)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onPanUpdate: (details) {
                    setState(() {
                      _velX += details.delta.dx * 0.15;
                      _velY += details.delta.dy * 0.15;
                    });
                  },
                ),
              ),

            // 6. Overlay Kalah (Synchronization Failed)
            if (_gameState == GameState.failed) _buildFailedOverlay(),

            // 7. Overlay Menang (Mana Core Stabilized)
            if (_gameState == GameState.won) _buildVictoryOverlay(),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // WIDGET KOMPONEN: TOP TELEMETRY BAR
  // ============================================================================
  Widget _buildTopTelemetryBar(double stabilityRatio) {
    final Color timerColor = _remainingSeconds <= 3.0
        ? LevMaxTheme.amberGold
        : LevMaxTheme.primaryContainer;

    return Positioned(
      top: 14,
      left: 16,
      right: 16,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Tombol Kembali / Exit
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: LevMaxTheme.onSurfaceVariant, size: 20),
                onPressed: () => Navigator.pop(context),
                tooltip: 'Exit Game',
              ),

              // Mode Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF171B26),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isAlreadyClaimedToday
                            ? LevMaxTheme.amberGold
                            : LevMaxTheme.tertiaryContainer,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isAlreadyClaimedToday
                          ? 'GYROSCOPE PROTOCOL // TRAINING ONLY'
                          : 'GYROSCOPE PROTOCOL // REWARD READY',
                      style: LevMaxTheme.mono(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: _isAlreadyClaimedToday
                            ? LevMaxTheme.amberGold
                            : LevMaxTheme.tertiaryContainer,
                      ),
                    ),
                  ],
                ),
              ),

              // Tombol Reset / Re-center
              IconButton(
                icon: const Icon(Icons.refresh, color: LevMaxTheme.primaryContainer, size: 22),
                onPressed: _startGame,
                tooltip: 'Restart',
              ),
            ],
          ),
          const SizedBox(height: 12),

          // COUNTDOWN TIMER UTAMA
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _remainingSeconds.toStringAsFixed(1),
                style: LevMaxTheme.headline(
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                  color: timerColor,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'S',
                style: LevMaxTheme.mono(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: timerColor.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // BAR INDIKATOR STABILITAS
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'CORE STABILITY THRESHOLD',
                      style: LevMaxTheme.mono(fontSize: 9, color: LevMaxTheme.outline),
                    ),
                    Text(
                      '${(stabilityRatio * 100).toInt()}%',
                      style: LevMaxTheme.mono(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: stabilityRatio > 0.4
                            ? LevMaxTheme.tertiaryContainer
                            : LevMaxTheme.hpRed,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: stabilityRatio,
                    backgroundColor: const Color(0xFF171B26),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      stabilityRatio > 0.4
                          ? LevMaxTheme.tertiaryContainer
                          : LevMaxTheme.hpRed,
                    ),
                    minHeight: 6,
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
  // WIDGET KOMPONEN: TACTICAL TARGET RING
  // ============================================================================
  Widget _buildTacticalTargetRing(bool isNearEdge) {
    final ringColor = _gameState == GameState.failed
        ? LevMaxTheme.hpRed
        : (isNearEdge ? LevMaxTheme.amberGold : LevMaxTheme.tertiaryContainer);

    return ScaleTransition(
      scale: _pulseAnimation,
      child: Container(
        width: _targetRingRadius * 2,
        height: _targetRingRadius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ringColor.withValues(alpha: 0.04),
          border: Border.all(
            color: ringColor.withValues(alpha: 0.8),
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: ringColor.withValues(alpha: 0.25),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Lingkaran Konsentris Dalam (Safe Zone)
            Container(
              width: _targetRingRadius * 1.2,
              height: _targetRingRadius * 1.2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: ringColor.withValues(alpha: 0.2),
                  width: 1.0,
                ),
              ),
            ),

            // Crosshair Tengah
            Container(
              width: 14,
              height: 1,
              color: ringColor.withValues(alpha: 0.4),
            ),
            Container(
              width: 1,
              height: 14,
              color: ringColor.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // WIDGET KOMPONEN: THE MANA CORE (BOLA CYBERPUNK)
  // ============================================================================
  Widget _buildTheManaCore(bool isNearEdge) {
    Color ballColor;
    if (_gameState == GameState.failed) {
      ballColor = LevMaxTheme.hpRed;
    } else if (_gameState == GameState.won) {
      ballColor = LevMaxTheme.amberGold;
    } else {
      ballColor = LevMaxTheme.primaryContainer;
    }

    return Transform.translate(
      offset: Offset(_ballX, _ballY),
      child: Container(
        width: _coreRadius * 2,
        height: _coreRadius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              Colors.white,
              ballColor,
              ballColor.withValues(alpha: 0.8),
            ],
            stops: const [0.1, 0.6, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: ballColor.withValues(alpha: 0.7),
              blurRadius: 18,
              spreadRadius: 4,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // WIDGET KOMPONEN: LIVE TILT READOUT TELEMETRY
  // ============================================================================
  Widget _buildBottomTiltReadout(double distance) {
    return Positioned(
      bottom: 24,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF171B26),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF1E293B)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildReadoutColumn(
              label: 'PITCH (X-TILT)',
              value: '${_rawSensorX >= 0 ? "+" : ""}${_rawSensorX.toStringAsFixed(2)}',
              color: LevMaxTheme.primaryContainer,
            ),
            Container(width: 1, height: 26, color: const Color(0xFF262A35)),
            _buildReadoutColumn(
              label: 'ROLL (Y-TILT)',
              value: '${_rawSensorY >= 0 ? "+" : ""}${_rawSensorY.toStringAsFixed(2)}',
              color: LevMaxTheme.primaryContainer,
            ),
            Container(width: 1, height: 26, color: const Color(0xFF262A35)),
            _buildReadoutColumn(
              label: 'OFFSET RADIUS',
              value: '${distance.toInt()} PX',
              color: distance < (_maxSafeDistance * 0.7)
                  ? LevMaxTheme.tertiaryContainer
                  : LevMaxTheme.hpRed,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadoutColumn({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: LevMaxTheme.mono(fontSize: 8.5, color: LevMaxTheme.outline),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: LevMaxTheme.mono(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // OVERLAY KALAH (SYNCHRONIZATION FAILED)
  // ============================================================================
  Widget _buildFailedOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF171B26),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: LevMaxTheme.hpRed, width: 2),
          boxShadow: [
            BoxShadow(
              color: LevMaxTheme.hpRed.withValues(alpha: 0.3),
              blurRadius: 24,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: LevMaxTheme.hpRed.withValues(alpha: 0.15),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: LevMaxTheme.hpRed, size: 42),
            ),
            const SizedBox(height: 14),
            Text(
              'SYNCHRONIZATION FAILED',
              style: LevMaxTheme.headline(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: LevMaxTheme.hpRed,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Mana Core keluar dari batas radius penahanan. Kestabilan energi dimensi terputus!',
              textAlign: TextAlign.center,
              style: LevMaxTheme.mono(fontSize: 11, color: LevMaxTheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F131D),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'WAKTU BERTAHAN: ${(15.0 - _remainingSeconds).toStringAsFixed(1)}s / 15.0s',
                style: LevMaxTheme.mono(fontSize: 10, color: Colors.white70),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: LevMaxTheme.outline,
                      side: const BorderSide(color: Color(0xFF313540)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text('EXIT TO HUB', style: LevMaxTheme.mono(fontSize: 11)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _startGame,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LevMaxTheme.hpRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'TRY AGAIN',
                      style: LevMaxTheme.headline(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // OVERLAY MENANG (MANA CORE STABILIZED & REWARD CLAIM)
  // ============================================================================
  Widget _buildVictoryOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.88),
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF171B26),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: LevMaxTheme.tertiaryContainer, width: 2),
          boxShadow: [
            BoxShadow(
              color: LevMaxTheme.tertiaryContainer.withValues(alpha: 0.25),
              blurRadius: 28,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ikon Mahkota / Piala Kemenangan
            ScaleTransition(
              scale: _winCoinController,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: LevMaxTheme.tertiaryContainer.withValues(alpha: 0.15),
                  border: Border.all(color: LevMaxTheme.tertiaryContainer, width: 1.5),
                ),
                child: const Icon(Icons.verified, color: LevMaxTheme.tertiaryContainer, size: 46),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'MANA CORE STABILIZED!',
              style: LevMaxTheme.headline(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: LevMaxTheme.tertiaryContainer,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sinkronisasi 100% Sempurna! Anda berhasil menahan energi Mana Core selama 15 detik penuh.',
              textAlign: TextAlign.center,
              style: LevMaxTheme.mono(fontSize: 11, color: LevMaxTheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),

            // BANNER REWARD GOLD ATAU DAILY CAP REACHED
            if (_isClaimSuccess) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F131D),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: LevMaxTheme.amberGold, width: 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.monetization_on, color: LevMaxTheme.amberGold, size: 24),
                    const SizedBox(width: 10),
                    Text(
                      '+50 GOLD GAINED!',
                      style: LevMaxTheme.headline(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: LevMaxTheme.amberGold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tercatat resmi di Blockchain Ledger & Saldo Vault Anda.',
                style: LevMaxTheme.mono(fontSize: 9.5, color: LevMaxTheme.outline),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F131D),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF313540)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: LevMaxTheme.outline, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Training Completed!\n(Daily Gold limit already reached - Playing for Training Only)',
                        style: LevMaxTheme.mono(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: LevMaxTheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: LevMaxTheme.outline,
                      side: const BorderSide(color: Color(0xFF313540)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text('RETURN TO HUB', style: LevMaxTheme.mono(fontSize: 11)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _startGame,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LevMaxTheme.tertiaryContainer,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'PLAY AGAIN',
                      style: LevMaxTheme.headline(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ==============================================================================
// CUSTOM PAINTER: CYBER ARENA GRID LINES
// ==============================================================================
class _CyberArenaGridPainter extends CustomPainter {
  final bool isCritical;

  const _CyberArenaGridPainter({required this.isCritical});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = isCritical
          ? const Color(0xFFEF4444).withValues(alpha: 0.12)
          : const Color(0xFF00F0FF).withValues(alpha: 0.05)
      ..strokeWidth = 1.0;

    const spacing = 36.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CyberArenaGridPainter oldDelegate) =>
      oldDelegate.isCritical != isCritical;
}
