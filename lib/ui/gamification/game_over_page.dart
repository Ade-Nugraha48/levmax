// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/ui/gamification/game_over_page.dart
// Deskripsi: Pixel-Perfect Game Over Screen "ANDA TIDAK LAYAK" (FR-6.2 & Aturan C)
//            Google Stitch HUD, PopScope(canPop: false), Ambient Red Blur,
//            Skull Emblem Pulsing Glow, Penalty Audit Sanctions & Re-Awakening.
// ==============================================================================

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';

import '../../helpers/boxes.dart';
import '../../models/quest_model.dart';
import '../../models/user_model.dart';
import '../../services/blockchain_service.dart';
import '../../services/supabase_api_service.dart';
import '../main_navigation_page.dart';

class GameOverPage extends StatefulWidget {
  final UserModel? player;
  final int? previousLevel;
  final String? previousRank;

  const GameOverPage({
    super.key,
    this.player,
    this.previousLevel,
    this.previousRank,
  });

  @override
  State<GameOverPage> createState() => _GameOverPageState();
}

class _GameOverPageState extends State<GameOverPage> with TickerProviderStateMixin {
  // Palet Warna Eksak Game Over Google Stitch
  static const Color surface = Color(0xFF0F131D);
  static const Color surfaceContainerLowest = Color(0xFF0A0E18);
  static const Color surfaceContainerLow = Color(0xFF171B26);
  static const Color surfaceContainer = Color(0xFF1C1F2A);
  static const Color surfaceContainerHigh = Color(0xFF262A35);
  static const Color surfaceBright = Color(0xFF353944);
  static const Color error = Color(0xFFFFB4AB);
  static const Color errorContainer = Color(0xFF93000A);
  static const Color onSurface = Color(0xFFDFE2F1);
  static const Color onSurfaceVariant = Color(0xFFB9CACB);
  static const Color outline = Color(0xFF849495);
  static const Color cyanAccent = Color(0xFF00F0FF);
  static const Color redGlow = Color(0xFFFF2A54);

  // Animation Controllers
  late AnimationController _pulseController;
  late AnimationController _restartRotateController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotateAnimation;

  bool _isLoading = false;
  bool _isButtonPressed = false;

  late int _displayPrevLevel;
  late String _displayPrevRank;

  @override
  void initState() {
    super.initState();

    final cachedPlayer = widget.player ?? SupabaseApiService.getPlayerCache();
    _displayPrevLevel = widget.previousLevel ?? (cachedPlayer?.level ?? 24);
    if (_displayPrevLevel <= 1) _displayPrevLevel = 24;

    _displayPrevRank = widget.previousRank ?? (cachedPlayer?.rank ?? 'B');
    if (_displayPrevRank == 'F') _displayPrevRank = 'B';

    // 1. Controller Denyut Pendaran Merah
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );

    // 2. Controller Rotasi Tombol Re-Awakening
    _restartRotateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _rotateAnimation = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(
        parent: _restartRotateController,
        curve: Curves.easeInOutCubic,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _restartRotateController.dispose();
    super.dispose();
  }

  // ============================================================================
  // LOGIKA SISTEM RE-AWAKENING (FR-6.3 & ATURAN GAMIFIKASI BALANCING)
  // ============================================================================
  Future<void> _onAcceptPunishment() async {
    if (_isLoading) return;

    HapticFeedback.heavyImpact();
    setState(() {
      _isLoading = true;
    });

    _restartRotateController.forward(from: 0.0);

    try {
      // 1. Reset State Hive (player_cache_box)
      final player = widget.player ?? SupabaseApiService.getPlayerCache();
      final updatedPlayer = (player ?? UserModel(username: 'Hunter', email: '')).copyWith(
        level: 1,
        rank: 'F',
        hp: 100,
        exp: 0,
        gold: 0,
        isPenaltyActive: false,
      );

      await SupabaseApiService.savePlayerCache(updatedPlayer);

      // 2. Catat ke Blockchain Ledger (Anti-Cheat Ledger)
      await BlockchainService.addBlock(
        'PENALTY TRIGGERED: HP 0. VESSEL RE-AWAKENED TO RANK F',
        userId: updatedPlayer.id,
      );

      // 3. Sinkronisasi Cloud Supabase via HTTP PATCH
      try {
        await SupabaseApiService.updateUser(updatedPlayer);
      } catch (e) {
        debugPrint('[GameOverPage] Supabase sync error: $e');
      }

      // 4. Bersihkan status quest di questBox
      if (Hive.isBoxOpen(HiveBoxes.questBox)) {
        final questBox = Hive.box<QuestModel>(HiveBoxes.questBox);
        for (int i = 0; i < questBox.length; i++) {
          final q = questBox.getAt(i);
          if (q != null) {
            q.isCompleted = false;
            q.currentValue = 0;
            await q.save();
          }
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'RE-AWAKENING SUCCESSFUL: Vessel reset to Level 1 (Rank F).',
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

      // 5. Navigasi Paksa: Menghapus seluruh history route dan kembali ke Main Navigation
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const MainNavigationPage(),
        ),
        (route) => false,
      );
    } catch (e) {
      debugPrint('[GameOverPage] Error executing Re-Awakening: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================================
  // KOMPONEN 1: AMBIENT BACKGROUND GLOW & SYSTEM SEVERED HEADER
  // ============================================================================
  Widget _buildAmbientGlowBackground() {
    return Stack(
      children: [
        // Top-Center Maroon Ambient Blur Glow
        Positioned(
          top: -70,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: errorContainer.withValues(alpha: 0.35),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),

        // Right-Center Maroon Ambient Blur Glow
        Positioned(
          top: 300,
          right: -80,
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: errorContainer.withValues(alpha: 0.28),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSystemSeveredHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: surfaceContainerLowest.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: error.withValues(alpha: 0.22), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Sisi Kiri: Ikon Skull Berkedip + Teks SYS // SEVERED
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return _SkullIcon(
                    size: 14,
                    color: Color.lerp(error, redGlow, _pulseAnimation.value) ?? error,
                  );
                },
              ),
              const SizedBox(width: 6),
              Text(
                '[SYS // SEVERED] CONDUIT TERMINATED',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: error,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),

          // Sisi Kanan: Red Ping Dot + ERR_009
          Row(
            mainAxisSize: MainAxisSize.min,
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
                          color: redGlow.withValues(alpha: 0.4 + 0.6 * _pulseAnimation.value),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(width: 5),
              Text(
                'ERR_009',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: outline,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // KOMPONEN 2: SKULL EMBLEM & TYPOGRAPHY DRAMATIS
  // ============================================================================
  Widget _buildSkullAndTypography() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 1. Skull Image dengan Red BoxShadow Glow Animasi Pulse
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Container(
              width: 144,
              height: 144,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: redGlow.withValues(alpha: 0.25 + 0.35 * _pulseAnimation.value),
                    blurRadius: 36,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/images/skull_emblem.png',
                  width: 144,
                  height: 144,
                  fit: BoxFit.contain,
                  errorBuilder: (context, err, stackTrace) {
                    return Container(
                      width: 144,
                      height: 144,
                      decoration: BoxDecoration(
                        color: surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: error.withValues(alpha: 0.4), width: 1.5),
                      ),
                      child: const Center(
                        child: Icon(Icons.dangerous, size: 68, color: error),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 20),

        // 2. Badge: PENALTY PROTOCOL ACTIVATED
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: errorContainer.withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: error.withValues(alpha: 0.40), width: 1),
          ),
          child: Text(
            'PENALTY PROTOCOL ACTIVATED',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: error,
              letterSpacing: 0.8,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 3. Title 1: YOU ARE UNWORTHY (36px Space Grotesk Black)
        Text(
          'YOU ARE\nUNWORTHY',
          textAlign: TextAlign.center,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            color: error,
            height: 1.05,
            letterSpacing: 1.2,
            shadows: const [
              Shadow(
                color: Color(0x99FF2A54),
                blurRadius: 20,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // 4. Title 2: (ANDA TIDAK LAYAK) (16px Space Grotesk Bold)
        Text(
          '(ANDA TIDAK LAYAK)',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: onSurface.withValues(alpha: 0.90),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 12),

        // 5. Lore Description Text
        SizedBox(
          width: 310,
          child: Text(
            'System connection severed. HP reached 0. All accumulated rank privileges have been revoked by The Monarch.',
            textAlign: TextAlign.center,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 13,
              color: outline,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // KOMPONEN 3: PENALTY AUDIT CARD (DETAIL HUKUMAN)
  // ============================================================================
  Widget _buildPenaltyAuditCard() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: error.withValues(alpha: 0.18), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Garis Merah Gradien di Bagian Atas Card
          Container(
            height: 2,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, redGlow, Colors.transparent],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Card: Ikon Palu + PENALTY AUDIT: SANCTIONS & Badge NON-NEGOTIABLE
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.gavel, color: error, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'PENALTY AUDIT: SANCTIONS',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: onSurface,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: errorContainer.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: error.withValues(alpha: 0.40), width: 1),
                      ),
                      child: Text(
                        'NON-NEGOTIABLE',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: error,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Daftar Sanksi 5 Baris
                // Baris 1: Previous Rank
                _buildSanctionRow(
                  icon: Icons.military_tech,
                  iconColor: outline,
                  title: 'Previous Rank',
                  trailingWidget: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Rank $_displayPrevRank',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: outline,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: error,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: errorContainer.withValues(alpha: 0.40),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Stripped',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Baris 2: Current Status
                _buildSanctionRow(
                  icon: Icons.keyboard_double_arrow_down,
                  iconColor: error,
                  title: 'Current Status',
                  trailingWidget: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: errorContainer.withValues(alpha: 0.30),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: error.withValues(alpha: 0.45), width: 1),
                    ),
                    child: Text(
                      'Rank F (Demoted)',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: error,
                      ),
                    ),
                  ),
                ),

                // Baris 3: Hunter Level
                _buildSanctionRow(
                  icon: Icons.trending_down,
                  iconColor: error,
                  title: 'Hunter Level',
                  trailingWidget: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'LV. 1',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: onSurface,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '(Down from $_displayPrevLevel)',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          color: outline,
                        ),
                      ),
                    ],
                  ),
                ),

                // Baris 4: Monarch Tribute
                _buildSanctionRow(
                  icon: Icons.toll,
                  iconColor: error,
                  title: 'Monarch Tribute',
                  trailingWidget: Text(
                    '-1,000 G Confiscated',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: error,
                    ),
                  ),
                ),

                // Baris 5: Awakened Streak
                _buildSanctionRow(
                  icon: Icons.local_fire_department,
                  iconColor: error,
                  title: 'Awakened Streak',
                  trailingWidget: Text(
                    'Purged (0 Days)',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: error,
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

  Widget _buildSanctionRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget trailingWidget,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: surfaceContainerLow, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 16),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  color: onSurfaceVariant,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          trailingWidget,
        ],
      ),
    );
  }

  // ============================================================================
  // KOMPONEN 4: ACTION BUTTON "RE-AWAKENING"
  // ============================================================================
  Widget _buildReAwakeningActionButton() {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isButtonPressed = true),
      onTapUp: (_) => setState(() => _isButtonPressed = false),
      onTapCancel: () => setState(() => _isButtonPressed = false),
      onTap: _onAcceptPunishment,
      child: AnimatedScale(
        scale: _isButtonPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: _isButtonPressed ? surfaceContainerHigh : surfaceBright,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16), width: 1),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: cyanAccent,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Ikon Restart Berputar
                      RotationTransition(
                        turns: _rotateAnimation,
                        child: const Icon(
                          Icons.restart_alt,
                          color: cyanAccent,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Teks Tombol Dua Baris / Terpusat
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'ACCEPT PUNISHMENT & RE-AWAKEN AS',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: onSurface,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'RANK F',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: onSurface,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // KOMPONEN 5: FOOTER DIRECTIVE
  // ============================================================================
  Widget _buildFooterDirective() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2, right: 8),
          child: Icon(Icons.terminal, size: 14, color: outline),
        ),
        SizedBox(
          width: 300,
          child: Text(
            'SOVEREIGN DIRECTIVE 09: THE WEAK CANNOT COMMAND SHADOWS. RE-INITIALIZE VESSEL.',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              color: outline,
              letterSpacing: 0.4,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // BUILD METHOD UTAMA: POPSCOPE (canPop: false) & SCROLLABLE LAYOUT
  // ============================================================================
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          HapticFeedback.vibrate();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'PENALTY LOCK: You must accept punishment to proceed.',
                style: GoogleFonts.jetBrainsMono(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
              backgroundColor: errorContainer,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: surface,
        body: Stack(
          children: [
            // Ambient Red/Maroon Glow Background
            _buildAmbientGlowBackground(),

            // Konten Utama Scrollable
            SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Komponen 1: Header Badge Melayang
                    _buildSystemSeveredHeader(),
                    const SizedBox(height: 18),

                    // Komponen 2: Skull Emblem & Tipografi
                    _buildSkullAndTypography(),
                    const SizedBox(height: 18),

                    // Komponen 3: Penalty Audit Card
                    _buildPenaltyAuditCard(),
                    const SizedBox(height: 18),

                    // Komponen 4: Action Button "Re-Awakening"
                    _buildReAwakeningActionButton(),
                    const SizedBox(height: 14),

                    // Komponen 5: Footer Directive
                    _buildFooterDirective(),
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
// CUSTOM VECTOR SKULL ICON PAINTER (PIXEL-PERFECT GOOGLE STITCH HUD)
// ==============================================================================
class _SkullIcon extends StatelessWidget {
  final Color color;
  final double size;

  const _SkullIcon({
    required this.color,
    this.size = 14,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _SkullPainter(color: color),
    );
  }
}

class _SkullPainter extends CustomPainter {
  final Color color;

  _SkullPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    // Cranium + cheekbones + jaw
    final skullPath = Path();
    skullPath.moveTo(w * 0.28, h * 0.68);
    // Left jaw
    skullPath.lineTo(w * 0.32, h * 0.90);
    // Chin
    skullPath.lineTo(w * 0.68, h * 0.90);
    // Right jaw
    skullPath.lineTo(w * 0.72, h * 0.68);
    // Right temple / cranium curve
    skullPath.cubicTo(w * 0.98, h * 0.60, w * 0.98, h * 0.12, w * 0.50, h * 0.10);
    // Left temple / cranium curve
    skullPath.cubicTo(w * 0.02, h * 0.12, w * 0.02, h * 0.60, w * 0.28, h * 0.68);
    skullPath.close();

    canvas.drawPath(skullPath, strokePaint);

    // Eye sockets
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.38, h * 0.44), width: w * 0.20, height: h * 0.22),
      fillPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.62, h * 0.44), width: w * 0.20, height: h * 0.22),
      fillPaint,
    );

    // Nose notch
    final nosePath = Path()
      ..moveTo(w * 0.50, h * 0.58)
      ..lineTo(w * 0.44, h * 0.68)
      ..lineTo(w * 0.56, h * 0.68)
      ..close();
    canvas.drawPath(nosePath, fillPaint);

    // Vertical teeth lines
    canvas.drawLine(Offset(w * 0.44, h * 0.78), Offset(w * 0.44, h * 0.90), strokePaint);
    canvas.drawLine(Offset(w * 0.56, h * 0.78), Offset(w * 0.56, h * 0.90), strokePaint);
  }

  @override
  bool shouldRepaint(covariant _SkullPainter oldDelegate) => oldDelegate.color != color;
}
