// Halaman Mini-Game Penalty Zone
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../services/blockchain_service.dart';
import '../services/notification_service.dart';
import '../services/supabase_api_service.dart';
import 'game_over_page.dart';

class PenaltyMiniGamePage extends StatefulWidget {
  const PenaltyMiniGamePage({super.key});

  @override
  State<PenaltyMiniGamePage> createState() => _PenaltyMiniGamePageState();
}

class _PenaltyMiniGamePageState extends State<PenaltyMiniGamePage>
    with SingleTickerProviderStateMixin {
  // Konstanta target tantangan penalti
  static const int _targetTaps = 50;
  static const int _totalSeconds = 15;

  // State mini-game
  int _tapCount = 0;
  int _secondsLeft = _totalSeconds;
  Timer? _timer;
  bool _isGameRunning = false;
  bool _isGameOver = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  // Memulai timer dan reset hitungan
  void _startGame() {
    setState(() {
      _tapCount = 0;
      _secondsLeft = _totalSeconds;
      _isGameRunning = true;
      _isGameOver = false;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        _handleTimeUp();
      } else {
        setState(() {
          _secondsLeft--;
        });
      }
    });
  }

  // Menangani ketukan tombol survival
  void _handleTap() {
    if (!_isGameRunning || _isGameOver) return;

    setState(() {
      _tapCount++;
    });

    if (_tapCount >= _targetTaps) {
      _handleVictory();
    }
  }

  // Penanganan saat pengguna berhasil mencapai target 50 tap
  Future<void> _handleVictory() async {
    _timer?.cancel();
    setState(() {
      _isGameRunning = false;
      _isGameOver = true;
    });

    // Pemulihan +10 HP dan penonaktifan status penalti
    final player = SupabaseApiService.getPlayerCache();
    if (player != null) {
      final updatedHp = min(100, player.hp + 10);
      final updatedPlayer = player.copyWith(
        hp: updatedHp,
        isPenaltyActive: false,
      );
      await SupabaseApiService.updateUser(updatedPlayer);

      // Pencatatan ke rantai blok anti-manipulasi
      await BlockchainService.addBlock(
        'PENALTY SURVIVED: Successfully tapped $_targetTaps times in $_totalSeconds s. Restored +10 HP (Total HP: $updatedHp).',
        userId: player.id,
      );
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131B2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF00E5FF), width: 2),
        ),
        title: const Row(
          children: [
            Icon(Icons.verified, color: Color(0xFF00E5FF)),
            SizedBox(width: 8),
            Text(
              'PENALTY SURVIVED!',
              style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.w900),
            ),
          ],
        ),
        content: const Text(
          'Tantangan berhasil diselesaikan!\n\nReward Kelayakan:\n• HP dipulihkan: +10 HP\n• Status Penalti: DINONAKTIFKAN\n• Transaksi dicatat ke Rantai Blok.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E5FF)),
            child: const Text('KEMBALI KE STATUS WINDOW', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  // Penanganan saat batas waktu 15 detik habis
  Future<void> _handleTimeUp() async {
    _timer?.cancel();
    setState(() {
      _isGameRunning = false;
      _isGameOver = true;
    });

    final player = SupabaseApiService.getPlayerCache();
    if (player != null) {
      final updatedHp = max(0, player.hp - 10);
      final updatedPlayer = player.copyWith(hp: updatedHp);
      await SupabaseApiService.updateUser(updatedPlayer);

      if (updatedHp <= 0) {
        // HP habis, diarahkan ke layar Game Over
        await NotificationService.showGameOverNotification();
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const GameOverPage()),
        );
        return;
      }
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131B2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFFF1744), width: 2),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Color(0xFFFF1744)),
            SizedBox(width: 8),
            Text(
              'WAKTU HABIS! PENALTY GAGAL',
              style: TextStyle(color: Color(0xFFFF1744), fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Anda hanya melakukan $_tapCount dari $_targetTaps tap.\nHP Anda berkurang tambahan -10 HP.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('KEMBALI', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _startGame();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF1744)),
            child: const Text('COBA LAGI', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_tapCount / _targetTaps).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: const Color(0xFF0F050B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A0A14),
        title: const Text(
          'PENALTY ZONE: SURVIVAL QUEST',
          style: TextStyle(color: Color(0xFFFF1744), fontWeight: FontWeight.w900),
        ),
        iconTheme: const IconThemeData(color: Color(0xFFFF1744)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Banner peringatan
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF1744).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFF1744)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.dangerous, color: Color(0xFFFF1744), size: 36),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ZONA HUKUMAN SISTEM AKTIF',
                            style: TextStyle(
                              color: Color(0xFFFF1744),
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Lakukan 50x Tap dalam 15 Detik untuk menangkis serangan Monster Penalti dan memulihkan +10 HP!',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Timer dan Progres Tap
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text(
                        'SISA WAKTU',
                        style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_secondsLeft}s',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: _secondsLeft <= 5 ? const Color(0xFFFF1744) : Colors.white,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      const Text(
                        'PROGRES TAP',
                        style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$_tapCount / $_targetTaps',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF00E5FF),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 14,
                  backgroundColor: const Color(0xFF1E293B),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
                ),
              ),
              const SizedBox(height: 32),

              // Area Interaksi GestureDetector
              Center(
                child: GestureDetector(
                  onTap: _isGameRunning ? _handleTap : null,
                  child: ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFFFF1744),
                            const Color(0xFF4A0E17),
                            Colors.black.withValues(alpha: 0.8),
                          ],
                        ),
                        border: Border.all(color: const Color(0xFFFF1744), width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF1744).withValues(alpha: 0.4),
                            blurRadius: 30,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isGameRunning ? Icons.touch_app : Icons.play_arrow,
                            size: 64,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isGameRunning ? 'TAP CEPAT!' : 'MULAI SURVIVAL',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              letterSpacing: 2.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 36),

              // Tombol mulai tantangan
              if (!_isGameRunning) ...[
                ElevatedButton(
                  onPressed: _startGame,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF1744),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'MULAI MINI-GAME PENALTY ZONE',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
