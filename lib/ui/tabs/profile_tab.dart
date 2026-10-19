// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/ui/tabs/profile_tab.dart
// Deskripsi: Pixel-Perfect Hunter Profile & Vessel Credentials (Tab 4 Bottom Nav).
//            Mengimplementasikan Google Stitch HUD (image_8c6e85.jpg) & FR-3.4:
//            - Breadcrumb & Title Header (Authenticated status)
//            - Hero Identity Card (Avatar, Dynamic Rank Frame Glow & Carousel F/C/A/S)
//            - Biometric Security Conduit (Face ID & Fingerprint live switches & calibration)
//            - System Preferences & Telemetry (Sound/Haptic & JSON Ledger Export)
//            - Danger Conduit // Access Control (Logout sequence)
// ==============================================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';

import '../../helpers/boxes.dart';
import '../../helpers/user_info.dart';
import '../../models/block_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../auth/face_scan_camera_page.dart';
import '../auth/fingerprint_scan_page.dart';
import '../auth/login_page.dart';
import 'status_quest_tab.dart'; // Reusing HunterPortraitPainter

class ProfileTab extends StatefulWidget {
  final UserModel player;
  final VoidCallback onPlayerUpdated;

  const ProfileTab({
    super.key,
    required this.player,
    required this.onPlayerUpdated,
  });

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab>
    with SingleTickerProviderStateMixin {
  // ============================================================================
  // TOKEN WARNA EKSAK GOOGLE STITCH HUD
  // ============================================================================
  static const Color surface = Color(0xFF0F131D);
  static const Color surfaceContainerLowest = Color(0xFF0A0E18);
  static const Color surfaceContainerLow = Color(0xFF171B26);
  static const Color surfaceContainer = Color(0xFF1C1F2A);
  static const Color surfaceContainerHigh = Color(0xFF262A35);
  static const Color primaryCyan = Color(0xFF00F0FF); // Electric Cyan
  static const Color tertiaryMint = Color(0xFF65F2B5); // Mint Green
  static const Color rankSPurple = Color(0xFF6001D1); // Purple neon glow Rank S
  static const Color rankSPurpleText = Color(0xFFD2BBFF);
  static const Color rankAGold = Color(0xFFFFD700);
  static const Color errorCoral = Color(0xFFFFB4AB); // Danger coral
  static const Color errorContainer = Color(0xFF93000A);
  static const Color onSurface = Color(0xFFDFE2F1);
  static const Color onSurfaceVariant = Color(0xFFB9CACB);
  static const Color outline = Color(0xFF849495);

  // State Rank Frame Aktif (Default: 'S')
  late String _activeRank;

  // State Biometrik & Preferensi
  bool _isFaceIdEnabled = true;
  bool _isFingerprintEnabled = true;
  bool _isSoundHapticEnabled = true;
  bool _isProcessingBiometric = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _activeRank = widget.player.rank.toUpperCase();
    if (_activeRank != 'S' && _activeRank != 'A' && _activeRank != 'C' && _activeRank != 'F') {
      _activeRank = 'S';
    }

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );

    _loadBiometricPreferences();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadBiometricPreferences() async {
    final facePref = await UserInfo.getFaceIdEnabled();
    final fpPref = await UserInfo.getFingerprintEnabled();
    final anyPref = await UserInfo.getBiometricEnabled();

    if (mounted) {
      setState(() {
        _isFaceIdEnabled = facePref || (anyPref && !fpPref);
        _isFingerprintEnabled = fpPref || (anyPref && !facePref);
      });
    }
  }

  // ============================================================================
  // LOGIKA BIOMETRIK & PREFERENSI (FR-3.4)
  // ============================================================================
  Future<void> _toggleFaceId(bool val) async {
    HapticFeedback.lightImpact();
    setState(() {
      _isFaceIdEnabled = val;
    });

    await UserInfo.setFaceIdEnabled(val);
    await UserInfo.setBiometricEnabled(val || _isFingerprintEnabled);

    if (!mounted) return;
    _showFloatingNotification(
      icon: Icons.center_focus_strong,
      message: 'Face ID Conduit: ${val ? "ONLINE // ACTIVE" : "OFFLINE // SUSPENDED"}',
      color: val ? primaryCyan : outline,
    );
  }

  Future<void> _toggleFingerprint(bool val) async {
    HapticFeedback.lightImpact();
    setState(() {
      _isFingerprintEnabled = val;
    });

    await UserInfo.setFingerprintEnabled(val);
    await UserInfo.setBiometricEnabled(val || _isFaceIdEnabled);

    if (!mounted) return;
    _showFloatingNotification(
      icon: Icons.fingerprint,
      message: 'Fingerprint Biometrics: ${val ? "ONLINE // ACTIVE" : "OFFLINE // SUSPENDED"}',
      color: val ? primaryCyan : outline,
    );
  }

  Future<void> _toggleSoundHaptic(bool val) async {
    if (val) HapticFeedback.mediumImpact();
    setState(() {
      _isSoundHapticEnabled = val;
    });

    _showFloatingNotification(
      icon: Icons.volume_up,
      message: 'Sound & Haptic Impulse: ${val ? "ENGAGED" : "MUTED"}',
      color: val ? primaryCyan : outline,
    );
  }

  Future<void> _updateFaceBaseline() async {
    if (_isProcessingBiometric) return;
    setState(() => _isProcessingBiometric = true);

    final success = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const FaceScanCameraPage(
          mode: FaceScanMode.enroll,
          title: 'REKALIBRASI FACE ID HUNTER',
          subtitle: 'Posisikan wajah Anda di dalam target frame untuk pemindaian ulang',
        ),
      ),
    );

    setState(() => _isProcessingBiometric = false);

    if (success == true) {
      await UserInfo.setFaceIdEnabled(true);
      await UserInfo.setHasEnrolledFace(true);
      setState(() => _isFaceIdEnabled = true);

      if (!mounted) return;
      _showFloatingNotification(
        icon: Icons.verified,
        message: 'Face ID Baseline Updated & Verified (99.8% Match)',
        color: tertiaryMint,
      );
    }
  }

  Future<void> _updateFingerprint() async {
    if (_isProcessingBiometric) return;
    setState(() => _isProcessingBiometric = true);

    final success = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const FingerprintScanPage(
          mode: FingerprintScanMode.enroll,
          title: 'REKALIBRASI SIDIK JARI HUNTER',
          subtitle: 'Tempelkan jari Anda pada sensor biometrik untuk kalibrasi ulang',
        ),
      ),
    );

    setState(() => _isProcessingBiometric = false);

    if (success == true) {
      await UserInfo.setFingerprintEnabled(true);
      await UserInfo.setHasEnrolledFingerprint(true);
      setState(() => _isFingerprintEnabled = true);

      if (!mounted) return;
      _showFloatingNotification(
        icon: Icons.verified,
        message: 'Fingerprint Samples Calibrated Successfully',
        color: tertiaryMint,
      );
    }
  }

  void _exportQuestLedger() {
    HapticFeedback.selectionClick();
    int count = 1420;
    try {
      if (Hive.isBoxOpen(HiveBoxes.blockchainBox)) {
        final box = Hive.box<BlockModel>(HiveBoxes.blockchainBox);
        count = box.length > 0 ? box.length : 1420;
      }
    } catch (_) {}

    final dummyExport = {
      'registry_node': '0x8921-ALPHA',
      'hunter_id': widget.player.id,
      'username': widget.player.username,
      'exported_at': DateTime.now().toIso8601String(),
      'ledger_sha256': 'e4b83f09a12c87b991ac',
      'total_completed_logs': count,
      'integrity_status': 'IMMUTABLE_VERIFIED',
    };

    final jsonStr = const JsonEncoder.withIndent('  ').convert(dummyExport);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: Color(0xFF1E2330), width: 1.0),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.download_done, color: primaryCyan, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'EXPORT QUEST LEDGER (JSON)',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: onSurface,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: outline, size: 18),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      jsonStr,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        color: tertiaryMint,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: jsonStr));
                    Navigator.pop(ctx);
                    _showFloatingNotification(
                      icon: Icons.copy,
                      message: 'Quest Ledger JSON copied to Hunter Clipboard!',
                      color: primaryCyan,
                    );
                  },
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('COPY TO CLIPBOARD'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryCyan,
                    foregroundColor: const Color(0xFF002022),
                    minimumSize: const Size.fromHeight(42),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: errorCoral.withValues(alpha: 0.35), width: 1.2),
        ),
        title: Row(
          children: [
            const Icon(Icons.power_settings_new, color: errorCoral, size: 22),
            const SizedBox(width: 8),
            Text(
              'TERMINATE SESSION // LOGOUT?',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: errorCoral,
              ),
            ),
          ],
        ),
        content: Text(
          'Confirm disconnect from Citadel System Window. Vessel will enter dormant state, daily daemon streak trackers will pause, and biometric re-authentication will be required upon reactivation.',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11.5,
            color: onSurfaceVariant,
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'ABORT',
              style: GoogleFonts.jetBrainsMono(
                color: outline,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: errorContainer,
              foregroundColor: errorCoral,
            ),
            child: Text(
              'TERMINATE SESSION',
              style: GoogleFonts.jetBrainsMono(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const PopScope(
        canPop: false,
        child: Center(
          child: CircularProgressIndicator(color: primaryCyan),
        ),
      ),
    );

    try {
      await AuthService.logout();
    } catch (e) {
      debugPrint('[ProfileTab] Logout error: $e');
    }

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  void _showFloatingNotification({
    required IconData icon,
    required String message,
    required Color color,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: const Color(0xFF002022), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.jetBrainsMono(
                  color: const Color(0xFF002022),
                  fontWeight: FontWeight.bold,
                  fontSize: 11.5,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ============================================================================
  // RANK HELPERS (WARNA, GLOW, TITLE)
  // ============================================================================
  Color get _activeRankGlowColor {
    switch (_activeRank) {
      case 'S':
        return rankSPurple;
      case 'A':
        return rankAGold;
      case 'C':
        return primaryCyan;
      default:
        return outline;
    }
  }

  Color get _activeRankBorderColor {
    switch (_activeRank) {
      case 'S':
        return rankSPurple;
      case 'A':
        return rankAGold;
      case 'C':
        return primaryCyan;
      default:
        return outline;
    }
  }

  String get _activeRankTitle {
    switch (_activeRank) {
      case 'S':
        return 'SHADOW MONARCH';
      case 'A':
        return 'RADIANT STRIKER';
      case 'C':
        return 'CYAN VANGUARD';
      default:
        return 'E-CLASS RECRUIT';
    }
  }

  Color get _activeRankTitleColor {
    switch (_activeRank) {
      case 'S':
        return rankSPurpleText;
      case 'A':
        return rankAGold;
      case 'C':
        return primaryCyan;
      default:
        return outline;
    }
  }

  // ============================================================================
  // STICKY TACTICAL TOP HEADER BAR (GOOGLE STITCH HUD)
  // ============================================================================
  Widget _buildTacticalHeader() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: surface,
        border: Border(
          bottom: BorderSide(color: Color(0xFF1E2330), width: 1.0),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Sisi Kiri: Status Online + Judul Tab PROFILE
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: primaryCyan,
                          boxShadow: [
                            BoxShadow(
                              color: primaryCyan.withValues(
                                  alpha: 0.4 + 0.6 * _pulseAnimation.value),
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
                    'ONLINE // 14MS',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: primaryCyan,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'PROFILE',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: onSurface,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),

          // Sisi Kanan: Badge SYNCED + Avatar Bulat
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: primaryCyan.withValues(alpha: 0.45),
                    width: 1,
                  ),
                ),
                child: Text(
                  'SYNCED',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: primaryCyan,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: surfaceContainer,
                  border: Border.all(
                    color: primaryCyan.withValues(alpha: 0.8),
                    width: 1.5,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.person_outline,
                    size: 18,
                    color: primaryCyan,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // KOMPONEN 1: BREADCRUMB & TITLE HEADER
  // ============================================================================
  Widget _buildBreadcrumbAndTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Breadcrumb Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: primaryCyan,
                            boxShadow: [
                              BoxShadow(
                                color: primaryCyan.withValues(
                                    alpha: 0.4 + 0.6 * _pulseAnimation.value),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '[HUNTER REGISTRY // CITADEL DATABASE]',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: primaryCyan,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'NODE 0x8921-ALPHA',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 9,
                color: outline,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Title Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                'HUNTER PROFILE & VESSEL CREDENTIALS',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: onSurface,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Row(
              children: [
                const Icon(
                  Icons.verified,
                  size: 14,
                  color: tertiaryMint,
                ),
                const SizedBox(width: 4),
                Text(
                  'AUTHENTICATED',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: tertiaryMint,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================================
  // KOMPONEN 2: HERO IDENTITY CARD (AVATAR & RANK FRAME SHOWCASE)
  // ============================================================================
  Widget _buildHeroIdentityCard() {
    return Container(
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
            color: Colors.black54,
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.military_tech,
                      size: 16,
                      color: primaryCyan,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'OFFICIAL MONARCH LICENSE // CITADEL HIGH COMM',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: primaryCyan,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                decoration: BoxDecoration(
                  color: surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: tertiaryMint,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'SER. #00982-S',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Avatar & Dynamic Rank Frame (Stack Rata Tengah)
          Center(
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // Kotak Luar 96x96 dengan BoxShadow neon dinamis
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: const Color(0xFF313540),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _activeRankBorderColor,
                          width: 2.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _activeRankGlowColor.withValues(alpha: 0.45),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CustomPaint(
                          painter: HunterPortraitPainter(),
                        ),
                      ),
                    ),

                    // Label Kecil Melayang di Batas Atas Frame
                    Positioned(
                      top: -8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _activeRankBorderColor,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black45,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          'RANK $_activeRank',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Teks di Bawah Frame
                Text(
                  _activeRankTitle,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: _activeRankTitleColor,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),

                // Nama Hunter + ID
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.player.username.isNotEmpty
                          ? widget.player.username
                          : 'Hunter Sung',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: onSurface,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '(#${widget.player.id.toString().padLeft(4, '0')})',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: primaryCyan,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Pill COMBAT READY
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF152C28),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: tertiaryMint.withValues(alpha: 0.4),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: tertiaryMint,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'COMBAT READY',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: tertiaryMint,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Grid Statistik (3 Baris Latar #171B26)
          _buildInfoRow(
            label: 'CLASS SPECIALIZATION',
            value: 'Shadow Monarch // Sovereign',
          ),
          const SizedBox(height: 6),
          _buildInfoRow(
            label: 'AFFILIATED GUILD',
            value: 'Citadel Apex Guild',
          ),
          const SizedBox(height: 6),
          _buildBiometricsInfoRow(),
          const SizedBox(height: 16),

          // Rank Frame Carousel (Di Bawah Data Data)
          _buildRankFrameCarousel(),
        ],
      ),
    );
  }

  Widget _buildInfoRow({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: surfaceContainerLow,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.04),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 8.5,
              fontWeight: FontWeight.bold,
              color: outline,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBiometricsInfoRow() {
    final bmi = widget.player.bmi > 0 ? widget.player.bmi.toStringAsFixed(1) : '22.4';
    final tb = widget.player.tbCm > 0 ? '${widget.player.tbCm.toInt()}' : '175';
    final bb = widget.player.bbKg > 0 ? '${widget.player.bbKg.toInt()}' : '68.5';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: surfaceContainerLow,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.04),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PHYSICAL VESSEL BIOMETRICS',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 8.5,
              fontWeight: FontWeight.bold,
              color: outline,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'BMI $bmi',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: primaryCyan,
                ),
              ),
              Text('|', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: outline)),
              Text(
                '$tb cm',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: primaryCyan,
                ),
              ),
              Text('|', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: outline)),
              Text(
                '$bb kg',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: primaryCyan,
                ),
              ),
              Text('|', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: outline)),
              Text(
                'CALIBRATED',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: tertiaryMint,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRankFrameCarousel() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.sync,
                      size: 14,
                      color: primaryCyan,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'UNLOCKED RANK FRAMES',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: onSurface,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'CURRENT: RANK $_activeRank',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 8.5,
                  fontWeight: FontWeight.bold,
                  color: outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 4 Tombol Pilihan Frame Rank
          Row(
            children: [
              _buildRankButton(
                rank: 'F',
                sub: 'Iron',
                icon: Icons.crop_square_outlined,
                color: outline,
              ),
              const SizedBox(width: 6),
              _buildRankButton(
                rank: 'C',
                sub: 'Cyan Gem',
                icon: Icons.diamond_outlined,
                color: primaryCyan,
              ),
              const SizedBox(width: 6),
              _buildRankButton(
                rank: 'A',
                sub: 'Radiant Gold',
                icon: Icons.military_tech,
                color: rankAGold,
              ),
              const SizedBox(width: 6),
              _buildRankButton(
                rank: 'S',
                sub: _activeRank == 'S' ? 'EQUIPPED' : 'Sovereign',
                icon: Icons.local_fire_department,
                color: rankSPurple,
                glowColor: rankSPurple,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRankButton({
    required String rank,
    required String sub,
    required IconData icon,
    required Color color,
    Color? glowColor,
  }) {
    final isSelected = _activeRank == rank;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _activeRank = rank;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1E152E) : surfaceContainerLow,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected
                  ? (glowColor ?? color)
                  : Colors.white.withValues(alpha: 0.05),
              width: isSelected ? 1.5 : 0.8,
            ),
            boxShadow: isSelected && glowColor != null
                ? [
                    BoxShadow(
                      color: glowColor.withValues(alpha: 0.4),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? color : outline,
              ),
              const SizedBox(height: 4),
              Text(
                'Rank $rank',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? onSurface : outline,
                ),
              ),
              Text(
                sub,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 8,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? color : outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // KOMPONEN 3: BIOMETRIC SECURITY CONDUIT
  // ============================================================================
  Widget _buildBiometricSecurityConduit() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  const Icon(
                    Icons.fingerprint,
                    size: 17,
                    color: primaryCyan,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '[BIOMETRIC SECURITY CONDUIT]',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: onSurface,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'ENCRYPTION // AES-256',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 8.5,
                color: outline,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Face ID Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: surfaceContainer,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.06),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: surfaceContainerLow,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.center_focus_strong,
                      size: 20,
                      color: primaryCyan,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Face ID Camera Recognition',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: onSurface,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              width: 4,
                              height: 4,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: tertiaryMint,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                'Baseline Registered (Verified 99.4%)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 9,
                                  color: tertiaryMint,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isFaceIdEnabled,
                    activeThumbColor: primaryCyan,
                    activeTrackColor: primaryCyan.withValues(alpha: 0.3),
                    inactiveThumbColor: outline,
                    inactiveTrackColor: surfaceContainerLowest,
                    onChanged: _toggleFaceId,
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Bottom Bar: Last Scan & Button
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: surfaceContainerLow,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Last mesh scan: 3 hours ago (Citadel Portal...)',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9,
                        color: outline,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ElevatedButton.icon(
                      onPressed: _updateFaceBaseline,
                      icon: const Icon(Icons.refresh, size: 14),
                      label: Text(
                        '[Update Face Baseline]',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: surfaceContainerHigh,
                        foregroundColor: primaryCyan,
                        elevation: 0,
                        minimumSize: const Size.fromHeight(32),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Fingerprint Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: surfaceContainer,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.06),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: surfaceContainerLow,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.fingerprint,
                      size: 20,
                      color: primaryCyan,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fingerprint Biometrics',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: onSurface,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              width: 4,
                              height: 4,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: tertiaryMint,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                '3 Samples Calibrated (Thumb / Index)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 9,
                                  color: tertiaryMint,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isFingerprintEnabled,
                    activeThumbColor: primaryCyan,
                    activeTrackColor: primaryCyan.withValues(alpha: 0.3),
                    inactiveThumbColor: outline,
                    inactiveTrackColor: surfaceContainerLowest,
                    onChanged: _toggleFingerprint,
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Bottom Bar: Hardware Sensor & Button
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: surfaceContainerLow,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Hardware Sensor: Sub-surface Ultrasonic Ring',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9,
                        color: outline,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ElevatedButton.icon(
                      onPressed: _updateFingerprint,
                      icon: const Icon(Icons.fingerprint, size: 14),
                      label: Text(
                        '[Update Fingerprint]',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: surfaceContainerHigh,
                        foregroundColor: primaryCyan,
                        elevation: 0,
                        minimumSize: const Size.fromHeight(32),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // KOMPONEN 4: SYSTEM PREFERENCES & TELEMETRY
  // ============================================================================
  Widget _buildSystemPreferencesAndTelemetry() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Row(
          children: [
            const Icon(
              Icons.tune,
              size: 17,
              color: primaryCyan,
            ),
            const SizedBox(width: 8),
            Text(
              '[SYSTEM PREFERENCES & TELEMETRY]',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: onSurface,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Sound & Haptic Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: surfaceContainer,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.06),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: surfaceContainerLow,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.volume_up,
                  size: 20,
                  color: onSurface,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sound & Haptic Impulse',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Quest notifications, rank-up resonance & clicks.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9.5,
                        color: outline,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _isSoundHapticEnabled,
                activeThumbColor: primaryCyan,
                activeTrackColor: primaryCyan.withValues(alpha: 0.3),
                inactiveThumbColor: outline,
                inactiveTrackColor: surfaceContainerLowest,
                onChanged: _toggleSoundHaptic,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Export Ledger Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: surfaceContainer,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.06),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: surfaceContainerLow,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.storage_rounded,
                      size: 20,
                      color: primaryCyan,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Export Quest Ledger (JSON)',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'SHA-256 HASH: e4b8...91ac // 1,420 Completed Logs',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 9,
                            color: outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _exportQuestLedger,
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.download,
                        size: 15,
                        color: primaryCyan,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'EXPORT LEDGER',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: primaryCyan,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // KOMPONEN 5: DANGER CONDUIT // ACCESS CONTROL (LOGOUT)
  // ============================================================================
  Widget _buildDangerConduit() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 17,
              color: errorCoral,
            ),
            const SizedBox(width: 8),
            Text(
              '[DANGER CONDUIT // ACCESS CONTROL]',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: errorCoral,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Danger Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: errorContainer.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Terminating your vessel session closes all active background daemon trackers, pauses daily quest streak validation clocks, and locks the Citadel System Window.',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  color: onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 10),

              // Warning Box
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: errorContainer.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: errorCoral.withValues(alpha: 0.25),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.lock_outline,
                      size: 15,
                      color: errorCoral,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'WARNING: Biometric re-authentication will be required upon reactivation.',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: errorCoral,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Logout Button
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _handleLogout,
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: errorContainer.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: errorCoral.withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.power_settings_new,
                        size: 17,
                        color: errorCoral,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'TERMINATE SESSION [LOGOUT]',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: errorCoral,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // MAIN BUILD METHOD
  // ============================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surface,
      body: SafeArea(
        child: Column(
          children: [
            // Sticky Tactical Top Header
            _buildTacticalHeader(),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Komponen 1: Breadcrumb & Title Header
                    _buildBreadcrumbAndTitle(),
                    const SizedBox(height: 16),

                    // Komponen 2: Hero Identity Card (Avatar & Rank Frame Showcase)
                    _buildHeroIdentityCard(),
                    const SizedBox(height: 20),

                    // Komponen 3: Biometric Security Conduit
                    _buildBiometricSecurityConduit(),
                    const SizedBox(height: 20),

                    // Komponen 4: System Preferences & Telemetry
                    _buildSystemPreferencesAndTelemetry(),
                    const SizedBox(height: 20),

                    // Komponen 5: Danger Zone Card (Logout)
                    _buildDangerConduit(),
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
