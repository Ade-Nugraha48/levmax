// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/ui/tabs/profile_tab.dart
// Deskripsi: Pixel-Perfect Hunter Profile, Full RPG Stats, Course Evaluation Terminal,
//            dan Danger Zone Logout (Prompt 13 - Google Stitch Solo Leveling Window).
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

import '../../helpers/boxes.dart';
import '../../helpers/levmax_theme.dart';
import '../../helpers/user_info.dart';
import '../../models/feedback_model.dart';
import '../../models/user_model.dart';
import '../../services/blockchain_service.dart';
import '../../services/supabase_api_service.dart';
import '../auth/login_page.dart';

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

class _ProfileTabState extends State<ProfileTab> with SingleTickerProviderStateMixin {
  // Token Warna Eksak Tema LevMax & Solo Leveling HUD
  static const Color surface = Color(0xFF0F131D);
  static const Color surfaceContainerLowest = Color(0xFF0A0E18);
  static const Color surfaceContainerLow = Color(0xFF171B26);
  static const Color surfaceContainer = Color(0xFF1C1F2A);
  static const Color primaryCyan = Color(0xFF00F0FF);
  static const Color tertiaryMint = Color(0xFF65F2B5);
  static const Color secondaryPurple = Color(0xFFD2BBFF);
  static const Color epicViolet = Color(0xFF6001D1);
  static const Color goldAmber = Color(0xFFFBBF24);
  static const Color errorCrimson = Color(0xFFEF4444);
  static const Color dangerDark = Color(0xFF93000A);
  static const Color onSurfaceVariant = Color(0xFFB9CACB);
  static const Color outline = Color(0xFF849495);

  late UserModel _player;

  // Controllers untuk Evaluasi Mata Kuliah
  final TextEditingController _nimController = TextEditingController(text: '123220000');
  final TextEditingController _kesanController = TextEditingController();
  final TextEditingController _saranController = TextEditingController();
  bool _isSubmittingEvaluation = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _player = widget.player;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(covariant ProfileTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.player != widget.player) {
      _player = widget.player;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _nimController.dispose();
    _kesanController.dispose();
    _saranController.dispose();
    super.dispose();
  }

  void _syncCachedPlayer() {
    final cached = SupabaseApiService.getPlayerCache();
    if (cached != null && mounted) {
      setState(() {
        _player = cached;
      });
    }
  }

  Color _getRankColor(String rank) {
    switch (rank.toUpperCase()) {
      case 'S':
        return epicViolet;
      case 'A':
        return goldAmber;
      case 'B':
        return primaryCyan;
      case 'C':
        return tertiaryMint;
      case 'D':
        return const Color(0xFFFB923C);
      case 'E':
      case 'F':
      default:
        return const Color(0xFF38BDF8);
    }
  }

  // ============================================================================
  // LOGIKA SUBMIT EVALUASI MATA KULIAH MOBILE KE SUPABASE & HIVE
  // ============================================================================
  Future<void> _handleSubmitEvaluation() async {
    final kesan = _kesanController.text.trim();
    final saran = _saranController.text.trim();
    final nim = _nimController.text.trim().isEmpty ? '123220000' : _nimController.text.trim();

    if (kesan.isEmpty || saran.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: surfaceContainer,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: errorCrimson, width: 1.2),
          ),
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: errorCrimson, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Harap isi kolom Kesan dan Saran sebelum mengirim ke Guild!',
                  style: LevMaxTheme.mono(fontSize: 10.5, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    setState(() => _isSubmittingEvaluation = true);

    try {
      // 1. POST ke Supabase tabel saran_kesan
      final success = await SupabaseApiService.submitFeedback(
        userId: _player.id,
        namaMahasiswa: _player.username,
        nim: nim,
        kesan: kesan,
        saran: saran,
      );
      debugPrint('[ProfileTab] Supabase submit feedback status: $success');

      // 2. Simpan juga ke Box Hive feedbackBox sebagai backup offline
      try {
        final box = Hive.box<FeedbackModel>(HiveBoxes.feedbackBox);
        await box.add(
          FeedbackModel(
            id: DateTime.now().millisecondsSinceEpoch % 1000000,
            userId: _player.id,
            namaMahasiswa: _player.username,
            nim: nim,
            kesan: kesan,
            saran: saran,
            createdAt: DateTime.now().toIso8601String(),
          ),
        );
      } catch (hiveErr) {
        debugPrint('[ProfileTab] Local Hive feedback save note: $hiveErr');
      }

      // 3. Tambahkan Reward +450 EXP ke Player
      final updatedPlayer = _player.copyWith(
        exp: _player.exp + 450,
      );
      await SupabaseApiService.updateUser(updatedPlayer);

      // 4. Catat ke Blockchain Ledger
      await BlockchainService.addBlock(
        'COURSE EVALUATION ARCHIVED: Mobile Programming Feedback (+450 EXP)',
        userId: _player.id,
      );

      _player = updatedPlayer;
      widget.onPlayerUpdated();

      if (!mounted) return;
      HapticFeedback.lightImpact();

      // Reset Text Field
      _kesanController.clear();
      _saranController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: surfaceContainer,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: primaryCyan, width: 1.5),
          ),
          content: Row(
            children: [
              const Icon(Icons.verified, color: primaryCyan, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Evaluation Archived Successfully! +450 EXP Gained.',
                  style: LevMaxTheme.mono(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: surfaceContainer,
            content: Text('Submission notice: $e', style: LevMaxTheme.mono(color: Colors.white)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmittingEvaluation = false);
    }
  }

  // ============================================================================
  // LOGIKA LOGOUT
  // ============================================================================
  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: errorCrimson, width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning, color: errorCrimson, size: 22),
            const SizedBox(width: 8),
            Text(
              'TERMINATE SYSTEM SESSION',
              style: LevMaxTheme.headline(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: errorCrimson,
              ),
            ),
          ],
        ),
        content: Text(
          'Anda yakin ingin keluar dari The System?\nSesi token autentikasi Hunter Anda akan dinonaktifkan.',
          style: LevMaxTheme.mono(fontSize: 11, color: onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('BATAL', style: LevMaxTheme.mono(color: outline)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await UserInfo.logout();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: errorCrimson,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'TERMINATE & LOGOUT',
              style: LevMaxTheme.headline(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _syncCachedPlayer();

    return Scaffold(
      backgroundColor: surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Breadcrumb Hunter
              _buildTopBreadcrumb(),
              const SizedBox(height: 12),

              // ================================================================
              // KOMPONEN 1: HERO IDENTITY CARD (AVATAR & RANK)
              // ================================================================
              _buildHeroIdentityCard(),
              const SizedBox(height: 18),

              // ================================================================
              // KOMPONEN 2: FULL RPG STATISTICS GRID
              // ================================================================
              _buildRpgStatisticsSection(),
              const SizedBox(height: 20),

              // ================================================================
              // KOMPONEN 3: COURSE EVALUATION TERMINAL (KESAN & SARAN MATKUL)
              // ================================================================
              _buildCourseEvaluationTerminal(),
              const SizedBox(height: 24),

              // ================================================================
              // KOMPONEN 4: DANGER ZONE (LOGOUT)
              // ================================================================
              _buildDangerZone(),
              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // HEADER BREADCRUMB
  // ============================================================================
  Widget _buildTopBreadcrumb() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            FadeTransition(
              opacity: _pulseAnimation,
              child: Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryCyan,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x8800F0FF),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '[HUNTER PROFILE // SYSTEM CONDUIT]',
              style: LevMaxTheme.mono(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: primaryCyan,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        Text(
          'STATUS: AUTHENTICATED',
          style: LevMaxTheme.mono(
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            color: tertiaryMint,
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // KOMPONEN 1: HERO IDENTITY CARD (AVATAR & RANK)
  // ============================================================================
  Widget _buildHeroIdentityCard() {
    final rankColor = _getRankColor(_player.rank);
    final shortUserId = _player.id.length > 6 ? _player.id.substring(0, 6) : _player.id;

    // Hitung persentase EXP ke level berikutnya (Level Cap tiap 1000 EXP)
    final int expProgress = _player.exp % 1000;
    final double expRatio = (expProgress / 1000.0).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: primaryCyan.withValues(alpha: 0.35),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryCyan.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Baris Atas: Kotak Avatar 80x80 & Informasi Pengguna
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Kotak 80x80 Avatar dengan Border Warna Rank
              Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: rankColor, width: 2.0),
                      boxShadow: [
                        BoxShadow(
                          color: rankColor.withValues(alpha: 0.3),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons.person,
                            size: 48,
                            color: rankColor.withValues(alpha: 0.35),
                          ),
                          Text(
                            _player.username.isNotEmpty ? _player.username[0].toUpperCase() : 'H',
                            style: LevMaxTheme.headline(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: rankColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Badge Tebal RANK Dinamis
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: rankColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: rankColor, width: 1.0),
                    ),
                    child: Text(
                      'RANK ${_player.rank.toUpperCase()}',
                      style: LevMaxTheme.mono(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: rankColor,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),

              // Kanan: Nama, ID, Class, Guild
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _player.username.toUpperCase(),
                      style: LevMaxTheme.headline(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.8,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),

                    Text(
                      '#$shortUserId',
                      style: LevMaxTheme.mono(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: primaryCyan,
                      ),
                    ),
                    const SizedBox(height: 8),

                    _buildInfoBadgeRow(Icons.shield, 'Class: Shadow Monarch', secondaryPurple),
                    const SizedBox(height: 4),
                    _buildInfoBadgeRow(Icons.fort, 'Guild: Citadel Apex', goldAmber),
                    const SizedBox(height: 4),
                    _buildInfoBadgeRow(
                      Icons.favorite,
                      'HP: ${_player.hp}/100 • ${_player.rankTitle}',
                      _player.hp > 30 ? tertiaryMint : errorCrimson,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Progress EXP Besar (Tinggi 8px, Warna Mint)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'LEVEL ${_player.level}',
                style: LevMaxTheme.headline(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: primaryCyan,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                'EXP: $expProgress/1000',
                style: LevMaxTheme.mono(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: tertiaryMint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: expRatio,
              minHeight: 8,
              backgroundColor: surfaceContainerLowest,
              valueColor: const AlwaysStoppedAnimation<Color>(tertiaryMint),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBadgeRow(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: LevMaxTheme.mono(fontSize: 10, color: onSurfaceVariant),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // KOMPONEN 2: FULL RPG STATISTICS GRID
  // ============================================================================
  Widget _buildRpgStatisticsSection() {
    final formattedGold = NumberFormat('#,###', 'id_ID').format(_player.gold);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label Header
        Row(
          children: [
            const Icon(Icons.bar_chart, color: primaryCyan, size: 18),
            const SizedBox(width: 8),
            Text(
              '[DETAILED VESSEL STATISTICS]',
              style: LevMaxTheme.mono(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: primaryCyan,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Grid Kartu-Kartu Statistik
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.2,
          children: [
            // 1. GOLD
            _buildStatCard(
              icon: Icons.monetization_on,
              label: 'VAULT GOLD',
              value: '$formattedGold G',
              color: goldAmber,
            ),

            // 2. STR (Strength) - Merah
            _buildStatCard(
              icon: Icons.fitness_center,
              label: 'STR (STRENGTH)',
              value: '${_player.str}',
              color: errorCrimson,
            ),

            // 3. AGI (Agility) - Mint
            _buildStatCard(
              icon: Icons.directions_run,
              label: 'AGI (AGILITY)',
              value: '${_player.agi}',
              color: tertiaryMint,
            ),

            // 4. INT (Intelligence) - Cyan
            _buildStatCard(
              icon: Icons.psychology,
              label: 'INT (INTELLIGENCE)',
              value: '${_player.intStat}',
              color: primaryCyan,
            ),

            // 5. CHA (Charisma) - Ungu
            _buildStatCard(
              icon: Icons.auto_awesome,
              label: 'CHA (CHARISMA)',
              value: '${_player.cha}',
              color: secondaryPurple,
            ),

            // 6. BMI Score
            _buildStatCard(
              icon: Icons.monitor_weight,
              label: 'BMI SCORE',
              value: '${_player.bmiScore.toStringAsFixed(1)} (${_player.bmiCategory})',
              color: goldAmber,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: surfaceContainerLowest,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: LevMaxTheme.mono(fontSize: 8.5, color: outline),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: LevMaxTheme.headline(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // KOMPONEN 3: COURSE EVALUATION TERMINAL (KESAN & SARAN MATKUL MOBILE)
  // ============================================================================
  Widget _buildCourseEvaluationTerminal() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label Header
        Row(
          children: [
            const Icon(Icons.terminal, color: secondaryPurple, size: 18),
            const SizedBox(width: 8),
            Text(
              '[GUILD ARCHIVE: COURSE EVALUATION]',
              style: LevMaxTheme.mono(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: secondaryPurple,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surfaceContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF313540)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Submit your impressions and directives for Mobile App Programming Course.',
                style: LevMaxTheme.mono(fontSize: 10.5, color: onSurfaceVariant),
              ),
              const SizedBox(height: 14),

              // Baris NIM & Nama Mahasiswa
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: _buildInputWrapper(
                      label: 'Student NIM',
                      child: TextField(
                        controller: _nimController,
                        style: LevMaxTheme.mono(fontSize: 11, color: Colors.white),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          border: InputBorder.none,
                          hintText: 'NIM...',
                          hintStyle: LevMaxTheme.mono(fontSize: 11, color: outline),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 6,
                    child: _buildInputWrapper(
                      label: 'Student Name',
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        child: Text(
                          _player.username,
                          style: LevMaxTheme.mono(fontSize: 11, fontWeight: FontWeight.bold, color: goldAmber),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Field Kesan: Max 3 baris
              _buildInputWrapper(
                label: 'Hunter Impression [Kesan]',
                child: TextField(
                  controller: _kesanController,
                  maxLines: 3,
                  style: LevMaxTheme.mono(fontSize: 11.5, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Tuliskan kesan perkuliahan Pemrograman Aplikasi Mobile di sini...',
                    hintStyle: LevMaxTheme.mono(fontSize: 10.5, color: outline),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Field Saran: Max 3 baris
              _buildInputWrapper(
                label: 'Strategic Directives [Saran]',
                child: TextField(
                  controller: _saranController,
                  maxLines: 3,
                  style: LevMaxTheme.mono(fontSize: 11.5, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Tuliskan saran untuk pengembangan materi perkuliahan...',
                    hintStyle: LevMaxTheme.mono(fontSize: 10.5, color: outline),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Tombol Submit: Tinggi 48px, Latar Cyan, Teks Bold Hitam
              ElevatedButton(
                onPressed: _isSubmittingEvaluation ? null : _handleSubmitEvaluation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryCyan,
                  foregroundColor: const Color(0xFF002022),
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 4,
                ),
                child: _isSubmittingEvaluation
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.send, size: 16, color: Color(0xFF002022)),
                          const SizedBox(width: 8),
                          Text(
                            'SUBMIT EVALUATION TO GUILD',
                            style: LevMaxTheme.headline(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                              color: const Color(0xFF002022),
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

  Widget _buildInputWrapper({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: LevMaxTheme.mono(
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            color: secondaryPurple,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: surfaceContainerLowest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF1E2638)),
          ),
          child: child,
        ),
      ],
    );
  }

  // ============================================================================
  // KOMPONEN 4: DANGER ZONE (LOGOUT)
  // ============================================================================
  Widget _buildDangerZone() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label Header Merah
        Row(
          children: [
            const Icon(Icons.warning, color: errorCrimson, size: 18),
            const SizedBox(width: 8),
            Text(
              '[SYSTEM CONDUIT OVERRIDE]',
              style: LevMaxTheme.mono(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: errorCrimson,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Tombol Logout: Tinggi 48px, Latar Merah Gelap 20%, Teks #FFB4AB
        InkWell(
          onTap: _confirmLogout,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: dangerDark.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: errorCrimson.withValues(alpha: 0.4), width: 1.0),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.power_settings_new, color: Color(0xFFFFB4AB), size: 18),
                const SizedBox(width: 8),
                Text(
                  'TERMINATE SESSION [LOGOUT]',
                  style: LevMaxTheme.headline(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFFFB4AB),
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
