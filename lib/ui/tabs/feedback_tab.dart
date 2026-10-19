// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/ui/tabs/feedback_tab.dart
// Deskripsi: Pixel-Perfect System Archive & Lecture Feedback (Tab 3 Bottom Nav).
//            Mengimplementasikan Google Stitch HUD (image_82811d.png) & FR-3.3:
//            - Breadcrumb & Header Title (Restricted Access)
//            - Guild Evaluation Quota Grid (Synapse Clearance & Evaluation EXP)
//            - System Evaluation Terminal (Dropdown, Runic Dagger Rating, Textareas)
//            - Immutable Archive Log (Hive & Supabase dynamic history)
//            - Monarch Telemetry Inspection modal
//            - Footer Cryptographic Vault Seal
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../helpers/boxes.dart';
import '../../models/feedback_model.dart';
import '../../models/user_model.dart';
import '../../services/blockchain_service.dart';
import '../../services/supabase_api_service.dart';

class FeedbackTab extends StatefulWidget {
  final UserModel player;
  final VoidCallback? onPlayerUpdated;

  const FeedbackTab({
    super.key,
    required this.player,
    this.onPlayerUpdated,
  });

  @override
  State<FeedbackTab> createState() => _FeedbackTabState();
}

class _FeedbackTabState extends State<FeedbackTab>
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
  static const Color mintAccent = Color(0xFF65F2B5); // Mint Green (EXP Yield & Rank S)
  static const Color outline = Color(0xFF849495);
  static const Color onSurface = Color(0xFFDFE2F1);
  static const Color onSurfaceVariant = Color(0xFFB9CACB);

  // Daftar Pilihan Disiplin / Mata Kuliah Aktif
  static const List<String> _availableDisciplines = [
    'Semester 5 - Mobile Programming Theory',
    'Semester 5 - Mobile Programming Practicum',
    'Semester 5 - Advanced Software Engineering',
    'Semester 5 - Cloud & Distributed Systems',
    'Semester 4 - Algoritma & Struktur Data',
    'Semester 4 - Basis Data Terdistribusi',
    'Semester 3 - Rekayasa Perangkat Lunak',
  ];

  late String _selectedDiscipline;
  int _currentRating = 5;
  final TextEditingController _kesanController = TextEditingController();
  final TextEditingController _saranController = TextEditingController();

  bool _isLoading = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late Box<FeedbackModel> _feedbackBox;

  @override
  void initState() {
    super.initState();
    _selectedDiscipline = _availableDisciplines[0];

    // Animasi Pulse Denyut Breadcrumb & Status Dot
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );

    // Buka Box Hive Feedback dan Inisialisasi Data Dummy jika Masih Kosong
    _feedbackBox = Hive.box<FeedbackModel>(HiveBoxes.feedbackBox);
    _seedInitialArchiveIfEmpty();

    // Listener counter karakter
    _kesanController.addListener(() => setState(() {}));
    _saranController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _kesanController.dispose();
    _saranController.dispose();
    super.dispose();
  }

  /// Inisialisasi Riwayat Arsip Awal agar 100% Sesuai Screenshot Desain Google Stitch
  void _seedInitialArchiveIfEmpty() {
    if (_feedbackBox.isEmpty) {
      final initialLogs = [
        FeedbackModel(
          userId: widget.player.id,
          namaMahasiswa: 'Semester 4 - Algoritma & Struktur Data',
          nim: 'RATING:5|RANK:S|SECTOR:Semester 4 - Algoritma & Struktur Data',
          kesan:
              'Fondasi logika dan kompleksitas waktu O(n) terasah dengan intensif melalui coding sprint.',
          saran:
              'Perbanyak studi kasus visualisasi tree & dynamic programming.',
          createdAt: 'JUN 24, 2024',
        ),
        FeedbackModel(
          userId: widget.player.id,
          namaMahasiswa: 'Semester 4 - Basis Data Terdistribusi',
          nim: 'RATING:4|RANK:A|SECTOR:Semester 4 - Basis Data Terdistribusi',
          kesan:
              'Pemahaman replikasi multi-node dan sharding sangat relevan dengan kebutuhan backend game modern.',
          saran:
              'Integrasi benchmark cluster langsung dengan containerized pods (Kubernetes) pada lab praktik berikutnya.',
          createdAt: 'MAY 18, 2024',
        ),
        FeedbackModel(
          userId: widget.player.id,
          namaMahasiswa: 'Semester 3 - Rekayasa Perangkat Lunak',
          nim: 'RATING:5|RANK:S|SECTOR:Semester 3 - Rekayasa Perangkat Lunak',
          kesan:
              'Metodologi Scrum and sprint planning nyata membantu menyelaraskan kolaborasi lintas divisi guild.',
          saran:
              'Fokuskan simulasi automasi CI/CD pipeline & arsitektur testing production.',
          createdAt: 'DEC 12, 2023',
        ),
      ];

      for (final log in initialLogs) {
        _feedbackBox.add(log);
      }
    }
  }

  String get _ratingDescriptor {
    switch (_currentRating) {
      case 5:
        return 'APEX EXCELLENCE';
      case 4:
        return 'SUPERIOR';
      case 3:
        return 'COMPETENT';
      case 2:
        return 'SUBPAR';
      default:
        return 'CRITICAL FLAW';
    }
  }

  // ============================================================================
  // LOGIKA BISNIS: SUBMIT FEEDBACK & EXP YIELD (FR-3.3)
  // ============================================================================
  Future<void> _submitFeedback() async {
    final kesan = _kesanController.text.trim();
    final saran = _saranController.text.trim();

    if (kesan.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'DIRECTIVE REJECTED: Hunter Impression cannot be empty!',
            style: GoogleFonts.jetBrainsMono(
              color: surface,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          backgroundColor: const Color(0xFFFFB4AB),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    HapticFeedback.mediumImpact();

    try {
      final rankStr = _currentRating >= 5 ? 'S' : (_currentRating >= 4 ? 'A' : 'B');
      final nowFormatted = _formatCurrentDate();

      final newFeedback = FeedbackModel(
        userId: widget.player.id,
        namaMahasiswa: _selectedDiscipline,
        nim: 'RATING:$_currentRating|RANK:$rankStr|SECTOR:$_selectedDiscipline',
        kesan: kesan,
        saran: saran.isNotEmpty ? saran : 'No additional directives provided.',
        createdAt: nowFormatted,
      );

      // 1. Simpan ke Hive (Lapisan 2 Offline-First)
      await _feedbackBox.add(newFeedback);

      // 2. Berikan Hadiah +450 EXP ke Player
      final currentExp = widget.player.exp + 450;
      final newLevel = widget.player.level + (currentExp ~/ 100);
      final remainingExp = currentExp % 100;

      final updatedPlayer = widget.player.copyWith(
        level: newLevel,
        exp: remainingExp,
      );

      await SupabaseApiService.savePlayerCache(updatedPlayer);

      // 3. Catat Transaksi Kriptografis ke Blockchain Audit Log
      await BlockchainService.addBlock(
        'EVALUATION ARCHIVED: [$_selectedDiscipline] RATING: $_currentRating/5 (+$rankStr-TIER) // EXP YIELD: +450',
        userId: widget.player.id,
      );

      // 4. Sinkronisasi ke Cloud Supabase (Lapisan 3)
      try {
        await SupabaseApiService.createFeedback(newFeedback);
        await SupabaseApiService.updateUser(updatedPlayer);
      } catch (e) {
        debugPrint('[FeedbackTab] Supabase sync error: $e');
      }

      widget.onPlayerUpdated?.call();

      _kesanController.clear();
      _saranController.clear();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.verified, color: surface, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '+450 EXP GAINED // Testimonial Encrypted into Guild Archive!',
                  style: GoogleFonts.jetBrainsMono(
                    color: surface,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: primaryCyan,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('[FeedbackTab] Submit error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatCurrentDate() {
    final now = DateTime.now();
    const months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
    ];
    return '${months[now.month - 1]} ${now.day.toString().padLeft(2, '0')}, ${now.year}';
  }

  // ============================================================================
  // KOMPONEN: STICKY TACTICAL TOP HEADER BAR (GOOGLE STITCH HUD)
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
          // Sisi Kiri: Status Online + Judul Tab ARCHIVE
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
                'ARCHIVE',
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
  // KOMPONEN 1: BREADCRUMB & HEADER TITLE
  // ============================================================================
  Widget _buildBreadcrumbAndTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Breadcrumb Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
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
                      '[GUILD ARCHIVE // LECTURE EVALUATION]',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: primaryCyan,
                        letterSpacing: 0.5,
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
                color: surfaceContainerHigh,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 0.8,
                ),
              ),
              child: Text(
                'RESTRICTED_ACCESS',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  color: onSurfaceVariant,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Judul Utama Raksasa Space Grotesk
        Text(
          '[ARCHIVE: SYSTEM TESTIMONIALS & LECTURE FEEDBACK]',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: onSurface,
            letterSpacing: 0.5,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),

        // Sub-judul Deskripsi
        Text(
          'Submit course impressions, evaluations, and constructive insights to the Central Guild.',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 12.5,
            color: onSurfaceVariant,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // KOMPONEN 2: GUILD EVALUATION QUOTA GRID
  // ============================================================================
  Widget _buildQuotaGrid() {
    return Row(
      children: [
        // Kartu 1: Synapse Clearance (Kiri)
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.06),
                width: 1,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Circular Glow Corner Accent
                Positioned(
                  right: -20,
                  bottom: -20,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primaryCyan.withValues(alpha: 0.05),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'SYNAPSE_CLEARANCE',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: outline,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const Icon(
                          Icons.shield_outlined,
                          size: 16,
                          color: primaryCyan,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'LEVEL 5',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: onSurface,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF152C28),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: mintAccent.withValues(alpha: 0.4),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            'S-TIER',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: mintAccent,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Guild Hunter ID: #774-K',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9.5,
                        color: outline,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Kartu 2: Evaluation EXP (Kanan)
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.06),
                width: 1,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Circular Glow Corner Accent
                Positioned(
                  right: -20,
                  bottom: -20,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: mintAccent.withValues(alpha: 0.05),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'EVALUATION_EXP',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: outline,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const Icon(
                          Icons.military_tech,
                          size: 18,
                          color: mintAccent,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '+450',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: mintAccent,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'EXP YIELD',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: outline,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Per Submitted Log',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9.5,
                        color: outline,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // KOMPONEN 3: SYSTEM EVALUATION TERMINAL (FORM INPUT)
  // ============================================================================
  Widget _buildSystemEvaluationTerminal() {
    return Container(
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // 4 Corner Accents Ticks (3x3 px Cyan)
            Positioned(
              top: 0,
              left: 0,
              child: Container(width: 4, height: 4, color: primaryCyan),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: Container(width: 4, height: 4, color: primaryCyan),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              child: Container(width: 4, height: 4, color: primaryCyan),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(width: 4, height: 4, color: primaryCyan),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Terminal Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(
                              Icons.terminal,
                              color: primaryCyan,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'SYSTEM EVALUATION TERMINAL',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: onSurface,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: primaryCyan.withValues(alpha: 0.4),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'STATUS // ACTIVE',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                            color: primaryCyan,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Field 1: Target Discipline // Sector (Dropdown)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TARGET DISCIPLINE // SECTOR',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: outline,
                          letterSpacing: 0.4,
                        ),
                      ),
                      Text(
                        '[ACTIVE_SEMESTER]',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: primaryCyan,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _buildDisciplineDropdown(),
                  const SizedBox(height: 16),

                  // Field 2: Runic Ranking Rating
                  _buildRunicRatingField(),
                  const SizedBox(height: 16),

                  // Field 3: Hunter Impression (Kesan Matkul)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 4,
                            color: primaryCyan,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'HUNTER IMPRESSION [KESAN MATKUL]',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'CHAR ${_kesanController.text.length}/500',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9.5,
                          color: outline,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _buildCustomTextArea(
                    controller: _kesanController,
                    hintText:
                        'Materi Mobile Programming sangat aplikatif. Integrasi sensor hardware (akselerometer & giroskop) langsung membuka wawasan arsitektur sistem responsif...',
                  ),
                  const SizedBox(height: 16),

                  // Field 4: Strategic Directives & Suggestions (Saran Matkul)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 4,
                            color: mintAccent,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'STRATEGIC DIRECTIVES & SUGGESTIONS [SARAN MATKUL]',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'CHAR ${_saranController.text.length}/500',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9.5,
                          color: outline,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _buildCustomTextArea(
                    controller: _saranController,
                    hintText:
                        'Saran untuk kurikulum semester mendatang: Tambahkan sesi hands-on optimasi performa memory profiling dan arsitektur offline-first state machine...',
                  ),
                  const SizedBox(height: 18),

                  // Submit CTA Button
                  _buildSubmitButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisciplineDropdown() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _showDisciplinePickerModal,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: surfaceContainerLowest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.view_in_ar,
              size: 18,
              color: primaryCyan,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _selectedDiscipline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: onSurface,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const Icon(
              Icons.expand_more,
              size: 20,
              color: outline,
            ),
          ],
        ),
      ),
    );
  }

  void _showDisciplinePickerModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: Color(0xFF1E2330), width: 1.0),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'SELECT TARGET DISCIPLINE',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: primaryCyan,
                        letterSpacing: 0.6,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: outline, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...List.generate(_availableDisciplines.length, (idx) {
                  final disc = _availableDisciplines[idx];
                  final isSelected = disc == _selectedDiscipline;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedDiscipline = disc;
                      });
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 10),
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? primaryCyan.withValues(alpha: 0.12)
                            : surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected
                              ? primaryCyan.withValues(alpha: 0.5)
                              : Colors.white.withValues(alpha: 0.05),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.view_in_ar,
                            size: 16,
                            color: isSelected ? primaryCyan : outline,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              disc,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected ? primaryCyan : onSurface,
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check, size: 18, color: primaryCyan),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRunicRatingField() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Header Baris Rating
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'EVALUATION RATING [RUNIC RANKING]',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    color: outline,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$_currentRating.0 / 5.0 ($_ratingDescriptor)',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: primaryCyan,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Baris 5 Runic Daggers
          Row(
            children: List.generate(5, (index) {
              final daggerIndex = index + 1;
              final isSelected = daggerIndex <= _currentRating;

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _currentRating = daggerIndex;
                    });
                  },
                  child: Container(
                    height: 44,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? surfaceContainer
                          : surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected
                            ? primaryCyan.withValues(alpha: 0.6)
                            : Colors.white.withValues(alpha: 0.05),
                        width: isSelected ? 1.2 : 0.8,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: primaryCyan.withValues(alpha: 0.2),
                                blurRadius: 8,
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.colorize,
                        size: 20,
                        color: isSelected ? primaryCyan : outline,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),

          // Label Batas Bawah Rating
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'E-RANK (POOR)',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: outline,
                  letterSpacing: 0.4,
                ),
              ),
              Text(
                'S-RANK (PEAK)',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: outline,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomTextArea({
    required TextEditingController controller,
    required String hintText,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: TextField(
        controller: controller,
        maxLines: 3,
        maxLength: 500,
        buildCounter: (context,
                {required currentLength,
                required isFocused,
                required maxLength}) =>
            null,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 11.5,
          color: onSurface,
          height: 1.45,
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
          hintText: hintText,
          hintStyle: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            color: outline.withValues(alpha: 0.45),
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _submitFeedback,
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryCyan,
        foregroundColor: const Color(0xFF002022),
        elevation: 0,
        shadowColor: Colors.transparent,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF002022),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.send,
                  size: 17,
                  color: Color(0xFF002022),
                ),
                const SizedBox(width: 8),
                Text(
                  'SUBMIT TESTIMONIAL TO GUILD [SAVE]',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF002022),
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
    );
  }

  // ============================================================================
  // KOMPONEN 4: IMMUTABLE ARCHIVE LOG (PAST SUBMISSIONS HISTORY)
  // ============================================================================
  Widget _buildImmutableArchiveLog() {
    return ValueListenableBuilder<Box<FeedbackModel>>(
      valueListenable: _feedbackBox.listenable(),
      builder: (context, box, child) {
        final logs = box.values.toList().reversed.toList();
        final count = logs.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Riwayat Arsip
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.history_edu,
                      size: 18,
                      color: onSurface,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '[IMMUTABLE ARCHIVE LOG: PAST SUBMISSIONS]',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: onSurface,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    '$count RECORDED',
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
            const SizedBox(height: 12),

            // Daftar Item History
            if (logs.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'NO ARCHIVED TESTIMONIALS FOUND',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      color: outline,
                    ),
                  ),
                ),
              )
            else
              ...List.generate(logs.length, (idx) {
                return _buildArchiveLogCard(logs[idx]);
              }),
          ],
        );
      },
    );
  }

  Widget _buildArchiveLogCard(FeedbackModel item) {
    final rating = item.rating;
    final rank = item.rank;
    final isRankS = rank == 'S';
    final rankColor = isRankS ? mintAccent : primaryCyan;
    final rankBg = isRankS ? const Color(0xFF152C28) : const Color(0xFF152C33);
    final ratingDesc = rating >= 5 ? 'APEX' : (rating >= 4 ? 'SUPERIOR' : 'COMPETENT');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Baris Atas: Judul Mata Kuliah & Badge Rank
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.discipline,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: onSurface,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: rankBg,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: rankColor.withValues(alpha: 0.4),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  'RANK $rank',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: rankColor,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Subtitle: Tanggal Arsip Terverifikasi
          Text(
            '${item.createdAt} // VERIFIED ARCHIVE',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9.5,
              color: outline,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),

          // Baris Rating Daggers
          Row(
            children: [
              ...List.generate(5, (dIdx) {
                final isDaggerActive = (dIdx + 1) <= rating;
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    Icons.colorize,
                    size: 13,
                    color: isDaggerActive
                        ? primaryCyan
                        : outline.withValues(alpha: 0.4),
                  ),
                );
              }),
              const SizedBox(width: 4),
              Text(
                '($rating/5 $ratingDesc)',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  color: outline,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Blok Excerpt Kesan
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: surfaceContainerLowest,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.04),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'KESAN [CHRONICLE]:',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: primaryCyan,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.kesan,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: onSurface,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Blok Excerpt Saran
          if (item.saran.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: surfaceContainerLowest,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.04),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SARAN [DIRECTIVE]:',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: mintAccent,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.saran,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      color: onSurface,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Tombol Bawah: Inspect Monarch Telemetry
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _showTelemetryModal(item),
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: surfaceContainer,
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
                    Icons.visibility_outlined,
                    size: 15,
                    color: onSurface,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'INSPECT MONARCH TELEMETRY',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: onSurface,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTelemetryModal(FeedbackModel item) {
    showModalBottomSheet(
      context: context,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.security, color: mintAccent, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'MONARCH TELEMETRY VERIFICATION',
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
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SECTOR: ${item.discipline}',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: primaryCyan,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'CRYPTOGRAPHIC HASH: 994E-F29A-${item.hashCode.toRadixString(16).toUpperCase()}',
                        style: GoogleFonts.jetBrainsMono(fontSize: 10, color: outline),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ARCHIVED TIMESTAMP: ${item.createdAt}',
                        style: GoogleFonts.jetBrainsMono(fontSize: 10, color: outline),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'LEDGER INTEGRITY: 100% IMMUTABLE (SHA-256 SIGNED)',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: mintAccent,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================================
  // KOMPONEN 5: FOOTER SEAL
  // ============================================================================
  Widget _buildFooterSeal() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(
                Icons.verified_user_outlined,
                size: 16,
                color: mintAccent,
              ),
              const SizedBox(width: 8),
              Text(
                'CENTRAL GUILD CRYPTOGRAPHIC VAULT',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          Text(
            'HASH: 994E-F29A',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              color: outline,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
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
                    // Komponen 1: Breadcrumb & Header Title
                    _buildBreadcrumbAndTitle(),
                    const SizedBox(height: 16),

                    // Komponen 2: Guild Evaluation Quota Grid
                    _buildQuotaGrid(),
                    const SizedBox(height: 16),

                    // Komponen 3: System Evaluation Terminal (Form Input)
                    _buildSystemEvaluationTerminal(),
                    const SizedBox(height: 24),

                    // Komponen 4: Immutable Archive Log (History List)
                    _buildImmutableArchiveLog(),
                    const SizedBox(height: 20),

                    // Komponen 5: Footer Seal
                    _buildFooterSeal(),
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
