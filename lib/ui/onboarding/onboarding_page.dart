// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/ui/onboarding/onboarding_page.dart
// Deskripsi: Redesain Google Stitch - Hunter Calibration: Stats Calibration (Prompt 2 - Bagian 2)
//            Mengusung estetika RPG Character Stat Sheet, Interactive Metric Steppers,
//            Pixel Silhouette & Height Ruler, Dynamic BMI Range Gauge, & Vitals Allocation.
// ==============================================================================

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../helpers/boxes.dart';
import '../../helpers/levmax_theme.dart';
import '../../helpers/user_info.dart';
import '../../models/quest_model.dart';
import '../../models/user_model.dart';
import '../../services/blockchain_service.dart';
import '../../services/supabase_api_service.dart';
import '../main_navigation_page.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> with SingleTickerProviderStateMixin {
  // Stat State (Metric RPG Sheet)
  double _heightCm = 175.0;
  double _weightKg = 68.5;
  int _pushups = 35;
  int _situps = 40;
  final int _squats = 45;
  final int _pullups = 8;
  final double _runKm = 3.0;
  final double _pace = 12.0;

  String _weightUnit = 'kg'; // 'kg' or 'lbs'
  bool _isLoading = false;
  bool _isAwakeningTriggered = false;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ============================================================================
  // KALKULASI DINAMIS BMI, VITALS, & HUNTER RANK
  // ============================================================================
  double get _calculatedBmi {
    final heightMeter = _heightCm / 100.0;
    if (heightMeter <= 0) return 22.4;
    final bmi = _weightKg / (heightMeter * heightMeter);
    return double.parse(bmi.toStringAsFixed(1));
  }

  String get _bmiStatusText {
    final bmi = _calculatedBmi;
    if (bmi < 18.5) return 'UNDERWEIGHT // RECOVERY REQ';
    if (bmi <= 24.9) return 'NORMAL // COMBAT READY';
    if (bmi <= 29.9) return 'HIGH DENSITY // GUARD FOCUS';
    return 'HEAVY TANK // CONDITIONING';
  }

  Color get _bmiStatusColor {
    final bmi = _calculatedBmi;
    if (bmi < 18.5) return const Color(0xFFF59E0B); // Amber Warning
    if (bmi <= 24.9) return LevMaxTheme.tertiaryContainer; // Neon Mint
    if (bmi <= 29.9) return LevMaxTheme.secondary; // Soft Lavender
    return LevMaxTheme.hpRed; // Crimson Heavy Tank
  }

  int get _calculatedBaseHp {
    return (80 + (_pushups * 0.5) + (_situps * 0.3)).round().clamp(50, 200);
  }

  int get _calculatedBaseStamina {
    return (75 + (_situps * 0.6) + (_pushups * 0.2)).round().clamp(50, 200);
  }

  double get _bmiGaugePercentage {
    // Memetakan rentang BMI 15.0 - 32.0 ke persentase 0.05 .. 0.94
    final bmi = _calculatedBmi;
    final percent = ((bmi - 15.0) / (32.0 - 15.0)).clamp(0.04, 0.94);
    return percent;
  }

  String get _calculatedRank {
    if (_pushups >= 55 && _situps >= 60) return 'C';
    if (_pushups >= 40 && _situps >= 45) return 'D';
    return 'E';
  }

  String get _rankTitle {
    final rank = _calculatedRank;
    if (rank == 'C') return 'RANK C - ELITE STRIKER';
    if (rank == 'D') return 'RANK D - EXPERIENCED VESSEL';
    return 'RANK E - RECRUIT HUNTER';
  }

  void _adjustHeight(double delta) {
    setState(() {
      _heightCm = (_heightCm + delta).clamp(120.0, 230.0);
    });
  }

  void _adjustWeight(double delta) {
    setState(() {
      if (_weightUnit == 'kg') {
        _weightKg = double.parse((_weightKg + delta).clamp(30.0, 250.0).toStringAsFixed(1));
      } else {
        // Delta dalam lbs -> konversi ke kg
        final currentLbs = _weightKg * 2.20462;
        final newLbs = (currentLbs + delta).clamp(66.0, 550.0);
        _weightKg = double.parse((newLbs / 2.20462).toStringAsFixed(1));
      }
    });
  }

  void _adjustPushups(int delta) {
    setState(() {
      _pushups = (_pushups + delta).clamp(0, 200);
    });
  }

  void _adjustSitups(int delta) {
    setState(() {
      _situps = (_situps + delta).clamp(0, 200);
    });
  }

  void _toggleWeightUnit(String unit) {
    if (_weightUnit == unit) return;
    setState(() {
      _weightUnit = unit;
    });
  }

  // ============================================================================
  // FINALISASI ONBOARDING & GENERASI DAILY QUEST PERDANA (60% ADAPTIF)
  // ============================================================================
  Future<void> _handleCompleteAwakening() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _isAwakeningTriggered = true;
    });

    await Future.delayed(const Duration(milliseconds: 900));

    final userId = await UserInfo.getUserID() ?? 1;
    final username = await UserInfo.getUsername() ?? 'Hunter';
    final email = await UserInfo.getEmail() ?? '';
    final todayDate = DateTime.now().toIso8601String().substring(0, 10);

    final assignedRank = _calculatedRank;
    final baseHp = _calculatedBaseHp;

    final player = UserModel(
      id: userId,
      username: username,
      email: email,
      isOnboarded: true,
      tbCm: _heightCm,
      bbKg: _weightKg,
      bmi: _calculatedBmi,
      maxPushup: _pushups,
      maxSitup: _situps,
      maxSquat: _squats,
      maxPullup: _pullups,
      maxRunKm: _runKm,
      pace2kmMenit: _pace,
      level: 1,
      rank: assignedRank,
      hp: baseHp,
      exp: 0,
      gold: 50,
      isPenaltyActive: false,
      lastActiveDate: todayDate,
      createdAt: DateTime.now().toIso8601String(),
    );

    // 1. Simpan ke Supabase Cloud DB & Local UserInfo
    try {
      await SupabaseApiService.updateUser(player);
    } catch (e) {
      debugPrint('Supabase update error: $e');
    }
    await UserInfo.setIsOnboarded(true);

    // 2. Rumus Adaptif 60% Kapasitas Maksimal Hunter dengan Pembobotan BMI
    final questBox = Hive.box<QuestModel>(HiveBoxes.questBox);
    await questBox.clear();

    double pushupMultiplier = 0.60;
    double runMultiplier = 0.60;

    // Adaptasi berdasarkan kategori BMI
    if (_calculatedBmi < 18.5) {
      // Underweight: Tingkatkan fokus hypertrophy strength
      pushupMultiplier = 0.65;
      runMultiplier = 0.50;
    } else if (_calculatedBmi >= 25.0) {
      // High Density / Heavy Tank: Tingkatkan fokus endurance cardio
      pushupMultiplier = 0.55;
      runMultiplier = 0.70;
    }

    final targetPushup = (_pushups * pushupMultiplier).round().clamp(5, 500);
    final targetSitup = (_situps * 0.60).round().clamp(5, 500);
    final targetSquat = (_squats * 0.60).round().clamp(5, 500);
    final targetPullup = (_pullups * 0.60).round().clamp(2, 500);
    final targetRun = double.parse((_runKm * runMultiplier).toStringAsFixed(1)).clamp(0.5, 50.0);

    final initialQuests = [
      QuestModel(
        id: 'quest_pushup_${DateTime.now().millisecondsSinceEpoch}',
        title: '[QUEST 01: PUSH-UPS]',
        description: 'Physical Sensor (Accelerometer) - Kalibrasi form push-up sempurna',
        category: 'Workout',
        targetValue: targetPushup,
        currentValue: 0,
        unit: 'Reps',
        expReward: 25,
        goldReward: 50,
        isCompleted: false,
        scheduledDate: todayDate,
      ),
      QuestModel(
        id: 'quest_run_${DateTime.now().millisecondsSinceEpoch + 1}',
        title: '[QUEST 02: 5KM RUNNING]',
        description: 'GPS Dungeon Tracking - Pertahankan Zone 2 cardio endurance',
        category: 'Cardio',
        targetValue: targetRun.round() < 1 ? 1 : targetRun.round(),
        currentValue: 0,
        unit: 'KM',
        expReward: 40,
        goldReward: 80,
        isCompleted: false,
        scheduledDate: todayDate,
      ),
      QuestModel(
        id: 'quest_study_${DateTime.now().millisecondsSinceEpoch + 2}',
        title: '[QUEST 03: STUDY FOCUS]',
        description: 'Gyroscope Posture Guardian - Deep work focus session tanpa distraksi',
        category: 'Study',
        targetValue: 45,
        currentValue: 0,
        unit: 'Mins',
        expReward: 30,
        goldReward: 60,
        isCompleted: false,
        scheduledDate: todayDate,
      ),
      QuestModel(
        id: 'quest_situp_${DateTime.now().millisecondsSinceEpoch + 3}',
        title: '[QUEST 04: SIT-UPS CORE]',
        description: 'Stabilitas lumbar dan penguatan dinding abdomen',
        category: 'Workout',
        targetValue: targetSitup,
        currentValue: 0,
        unit: 'Reps',
        expReward: 25,
        goldReward: 40,
        isCompleted: false,
        scheduledDate: todayDate,
      ),
      QuestModel(
        id: 'quest_skin_${DateTime.now().millisecondsSinceEpoch + 4}',
        title: '[QUEST 05: SKINCARE RESTORATION]',
        description: 'Habit Restoration Protocol - Cuci muka & proteksi barrier kulit',
        category: 'Skincare',
        targetValue: 1,
        currentValue: 0,
        unit: 'Sesi',
        expReward: 20,
        goldReward: 30,
        isCompleted: false,
        scheduledDate: todayDate,
      ),
      QuestModel(
        id: 'quest_squat_${DateTime.now().millisecondsSinceEpoch + 5}',
        title: '[QUEST 06: SQUAT MASTERY]',
        description: 'Kekuatan paha depan dan glutes untuk mobilitas dungeon',
        category: 'Workout',
        targetValue: targetSquat,
        currentValue: 0,
        unit: 'Reps',
        expReward: 20,
        goldReward: 30,
        isCompleted: false,
        scheduledDate: todayDate,
      ),
      QuestModel(
        id: 'quest_pullup_${DateTime.now().millisecondsSinceEpoch + 6}',
        title: '[QUEST 07: PULL-UP LAT]',
        description: 'Tarik tubuh ke atas palang tanpa momentum',
        category: 'Workout',
        targetValue: targetPullup,
        currentValue: 0,
        unit: 'Reps',
        expReward: 25,
        goldReward: 40,
        isCompleted: false,
        scheduledDate: todayDate,
      ),
    ];

    for (final q in initialQuests) {
      await questBox.add(q);
      try {
        await SupabaseApiService.syncQuest(quest: q, userId: userId);
      } catch (e) {
        debugPrint('Sync quest error: $e');
      }
    }

    // 3. Catat ke Blockchain Genesis
    try {
      await BlockchainService.addBlock(
        'ONBOARDING COMPLETED: Hunter Awakened as Rank $assignedRank - Baseline BMI: $_calculatedBmi, HP: $baseHp',
        userId: userId,
      );
    } catch (e) {
      debugPrint('Blockchain genesis error: $e');
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.verified, color: LevMaxTheme.onPrimary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'AWAKENING COMPLETE! ENTERING THE SYSTEM...',
                style: LevMaxTheme.mono(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: LevMaxTheme.onPrimary,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: LevMaxTheme.primaryContainer,
        behavior: SnackBarBehavior.floating,
      ),
    );

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainNavigationPage()),
      (route) => false,
    );
  }

  // ============================================================================
  // KOMPONEN 1: STICKY TOP NAVIGATION BAR (64PX)
  // ============================================================================
  Widget _buildStickyTopNavigationBar() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: LevMaxTheme.surfaceContainerLow.withValues(alpha: 0.85),
            border: const Border(
              bottom: BorderSide(color: Color(0xFF1E293B), width: 1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Sisi Kiri: Tombol Back & Judul Sistem
              Expanded(
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: LevMaxTheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: LevMaxTheme.surfaceContainerHigh),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.arrow_back,
                            color: Color(0xFF00DBE9),
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              AnimatedBuilder(
                                animation: _pulseController,
                                builder: (context, child) {
                                  return Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: LevMaxTheme.primaryContainer.withValues(
                                        alpha: 0.4 + (_pulseController.value * 0.6),
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: LevMaxTheme.primaryContainer,
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '[SYS // ONBOARDING]',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: LevMaxTheme.mono(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF00DBE9),
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'HUNTER CALIBRATION',
                              style: LevMaxTheme.headline(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: LevMaxTheme.onSurface,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Sisi Kanan: SEQ / PHASE 01/02 & Avatar
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'SEQ',
                        style: LevMaxTheme.mono(
                          fontSize: 8.5,
                          color: LevMaxTheme.outline,
                        ),
                      ),
                      Text(
                        'PHASE 01/02',
                        style: LevMaxTheme.mono(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: LevMaxTheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: LevMaxTheme.primary,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.person,
                        size: 18,
                        color: LevMaxTheme.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // KOMPONEN 2: NARRATIVE INTRO & TELEMETRY HEADER
  // ============================================================================
  Widget _buildNarrativeIntroHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Baris 1: Status Phase & Sync Capsule
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF00DBE9).withValues(
                          alpha: 0.4 + (_pulseController.value * 0.6),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0xFF00DBE9),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                Text(
                  'PHASE 02 // VESSEL CALIBRATION',
                  style: LevMaxTheme.mono(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF00DBE9),
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: LevMaxTheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'SYNC: READY',
                style: LevMaxTheme.mono(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF4EDEA3),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Judul Utama Monolith
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            'NEW HUNTER ONBOARDING: STATS CALIBRATION',
            style: LevMaxTheme.headline(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: LevMaxTheme.primary,
              letterSpacing: 0.6,
            ),
          ),
        ),
        const SizedBox(height: 6),

        // Subdeskripsi
        const Text(
          'Enter your physical vessel metrics to calculate your starting Hunter Rank and baseline vitals.',
          style: TextStyle(
            fontSize: 12,
            color: LevMaxTheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // KOMPONEN 3: VESSEL HEIGHT STEPPER CARD (DENGAN SILUET & VERTICAL RULER)
  // ============================================================================
  Widget _buildVesselHeightCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LevMaxTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Card
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.height,
                      color: Color(0xFF00DBE9),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'VESSEL HEIGHT [VERTICAL STAT]',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: LevMaxTheme.mono(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF00DBE9),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: LevMaxTheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'AXIS: Z-HEIGHT',
                  style: LevMaxTheme.mono(
                    fontSize: 9.5,
                    color: LevMaxTheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Grid 2 Kolom: Kiri Kontrol & Kanan Grafis Siluet
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Kiri: Angka & Stepper
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          _heightCm.toInt().toString(),
                          style: LevMaxTheme.headline(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: LevMaxTheme.primary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'CM',
                          style: LevMaxTheme.mono(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF00DBE9),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildStepperButton(
                          icon: Icons.remove,
                          onTap: () => _adjustHeight(-1),
                        ),
                        const SizedBox(width: 8),
                        _buildStepperButton(
                          icon: Icons.add,
                          onTap: () => _adjustHeight(1),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _adjustHeight(5),
                          child: Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: LevMaxTheme.surfaceContainer,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF262A35)),
                            ),
                            child: Center(
                              child: Text(
                                '+5',
                                style: LevMaxTheme.mono(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF00DBE9),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Kanan: Pixel Silhouette & Vertical Ruler Ticks
              Expanded(
                flex: 5,
                child: SizedBox(
                  height: 104,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Animated Pixel Silhouette
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return CustomPaint(
                            size: const Size(44, 96),
                            painter: _PixelSilhouettePainter(
                              heightCm: _heightCm,
                              pulseValue: _pulseController.value,
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 12),

                      // Vertical Height Ruler Ticks
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildRulerTick('200', _heightCm >= 195 && _heightCm <= 205),
                          _buildRulerTick('180', _heightCm >= 178 && _heightCm < 185),
                          _buildRulerTick(
                            _heightCm.toInt().toString(),
                            true,
                            showLine: true,
                          ),
                          _buildRulerTick('160', _heightCm >= 155 && _heightCm < 165),
                          _buildRulerTick('140', _heightCm >= 135 && _heightCm < 145),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRulerTick(String label, bool isActive, {bool showLine = false}) {
    return Row(
      children: [
        if (showLine) ...[
          Container(
            width: 8,
            height: 1.5,
            color: LevMaxTheme.primaryContainer,
          ),
          const SizedBox(width: 4),
        ],
        Text(
          label,
          style: LevMaxTheme.mono(
            fontSize: isActive ? 10 : 8.5,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? LevMaxTheme.primaryContainer : LevMaxTheme.outline,
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // KOMPONEN 4: VESSEL MASS CARD (DENGAN UNIT SWITCHER KG / LBS)
  // ============================================================================
  Widget _buildVesselMassCard() {
    final displayWeight = _weightUnit == 'kg'
        ? _weightKg.toStringAsFixed(1)
        : (_weightKg * 2.20462).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LevMaxTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        children: [
          // Header Card
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.scale,
                      color: Color(0xFF00DBE9),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'VESSEL MASS [GRAVITY RESISTANCE]',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: LevMaxTheme.mono(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF00DBE9),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Unit Switcher Pill (KG / LBS)
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: LevMaxTheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => _toggleWeightUnit('kg'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _weightUnit == 'kg'
                              ? LevMaxTheme.primaryContainer
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'KG',
                          style: LevMaxTheme.mono(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _weightUnit == 'kg'
                                ? LevMaxTheme.onPrimary
                                : LevMaxTheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _toggleWeightUnit('lbs'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _weightUnit == 'lbs'
                              ? LevMaxTheme.primaryContainer
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'LBS',
                          style: LevMaxTheme.mono(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _weightUnit == 'lbs'
                                ? LevMaxTheme.onPrimary
                                : LevMaxTheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Baris Nilai & Stepper
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    displayWeight,
                    style: LevMaxTheme.headline(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: LevMaxTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _weightUnit.toUpperCase(),
                    style: LevMaxTheme.mono(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF00DBE9),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  _buildStepperButton(
                    icon: Icons.remove,
                    onTap: () => _adjustWeight(-0.5),
                  ),
                  const SizedBox(width: 8),
                  _buildStepperButton(
                    icon: Icons.add,
                    onTap: () => _adjustWeight(0.5),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // KOMPONEN 5: UPPER BODY & CORE STRENGTH GRID (2 KOLOM KARTU STEPPER REPETISI)
  // ============================================================================
  Widget _buildStrengthCalibrationGrid() {
    return Row(
      children: [
        // Kartu 1: Max Push-Ups (Upper Strength)
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: LevMaxTheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.fitness_center,
                      color: Color(0xFF00DBE9),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'UPPER STRENGTH',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: LevMaxTheme.mono(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF00DBE9),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'MAX PUSH-UPS',
                  style: LevMaxTheme.mono(
                    fontSize: 9,
                    color: LevMaxTheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _pushups.toString(),
                      style: LevMaxTheme.headline(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: LevMaxTheme.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'REPS',
                      style: LevMaxTheme.mono(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF00DBE9),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildSmallStepper(
                      icon: Icons.remove,
                      onTap: () => _adjustPushups(-1),
                    ),
                    const SizedBox(width: 6),
                    _buildSmallStepper(
                      icon: Icons.add,
                      onTap: () => _adjustPushups(1),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _adjustPushups(5),
                        child: Container(
                          height: 36,
                          decoration: BoxDecoration(
                            color: LevMaxTheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: Text(
                              '+5',
                              style: LevMaxTheme.mono(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF00DBE9),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Kartu 2: Max Sit-Ups (Core Stability)
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: LevMaxTheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.accessibility_new,
                      color: Color(0xFF00DBE9),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'CORE STABILITY',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: LevMaxTheme.mono(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF00DBE9),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'MAX SIT-UPS',
                  style: LevMaxTheme.mono(
                    fontSize: 9,
                    color: LevMaxTheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _situps.toString(),
                      style: LevMaxTheme.headline(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: LevMaxTheme.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'REPS',
                      style: LevMaxTheme.mono(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF00DBE9),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildSmallStepper(
                      icon: Icons.remove,
                      onTap: () => _adjustSitups(-1),
                    ),
                    const SizedBox(width: 6),
                    _buildSmallStepper(
                      icon: Icons.add,
                      onTap: () => _adjustSitups(1),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _adjustSitups(5),
                        child: Container(
                          height: 36,
                          decoration: BoxDecoration(
                            color: LevMaxTheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: Text(
                              '+5',
                              style: LevMaxTheme.mono(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF00DBE9),
                              ),
                            ),
                          ),
                        ),
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
  // KOMPONEN 6: REAL-TIME DYNAMIC BMI & SYSTEM APPRAISAL WINDOW
  // ============================================================================
  Widget _buildSystemAppraisalWindow() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LevMaxTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF262A35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Appraisal Window
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified,
                      color: LevMaxTheme.secondary,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '[ SYSTEM APPRAISAL COMPLETE ]',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: LevMaxTheme.mono(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: LevMaxTheme.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: LevMaxTheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF4EDEA3).withValues(
                              alpha: 0.4 + (_pulseController.value * 0.6),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'LIVE SYNC',
                      style: LevMaxTheme.mono(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF4EDEA3),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // BMI Readout & Status Tag
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CALCULATED VESSEL SCORE',
                    style: LevMaxTheme.mono(
                      fontSize: 9.5,
                      color: LevMaxTheme.onSurfaceVariant,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        _calculatedBmi.toString(),
                        style: LevMaxTheme.headline(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF00DBE9),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'BMI',
                        style: LevMaxTheme.mono(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF00DBE9),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 8),

              // Reaktif Status Tag
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: LevMaxTheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _bmiStatusColor,
                          boxShadow: [
                            BoxShadow(color: _bmiStatusColor, blurRadius: 4),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _bmiStatusText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: LevMaxTheme.mono(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: _bmiStatusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Multi-Segment Visual BMI Range Gauge
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('16.0 SLENDER', style: LevMaxTheme.mono(fontSize: 8.5, color: LevMaxTheme.onSurfaceVariant)),
                  const SizedBox(width: 14),
                  Text('18.5 BALANCED', style: LevMaxTheme.mono(fontSize: 8.5, color: LevMaxTheme.onSurfaceVariant)),
                  const SizedBox(width: 14),
                  Text('25.0 OVER', style: LevMaxTheme.mono(fontSize: 8.5, color: LevMaxTheme.onSurfaceVariant)),
                  const SizedBox(width: 14),
                  Text('30.0+ APEX', style: LevMaxTheme.mono(fontSize: 8.5, color: LevMaxTheme.onSurfaceVariant)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),

          // Bar Track (Height 12px) dengan 4 Segmen Warna & Moving Active Marker
          LayoutBuilder(
            builder: (context, constraints) {
              final totalWidth = constraints.maxWidth;
              final markerPosition = (totalWidth * _bmiGaugePercentage).clamp(0.0, totalWidth - 8);

              return SizedBox(
                height: 14,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    // 4 Segmen Warna Bar Track
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        height: 12,
                        color: LevMaxTheme.surfaceContainerLowest,
                        child: Row(
                          children: [
                            // 1. Underweight / Slender (Grey)
                            Expanded(
                              flex: 22,
                              child: Container(color: LevMaxTheme.surfaceContainerHighest),
                            ),
                            const SizedBox(width: 2),
                            // 2. Normal / Balanced (Mint Green)
                            Expanded(
                              flex: 38,
                              child: Container(color: LevMaxTheme.tertiaryContainer),
                            ),
                            const SizedBox(width: 2),
                            // 3. Overweight / Guard (Violet)
                            Expanded(
                              flex: 25,
                              child: Container(color: LevMaxTheme.secondaryContainer),
                            ),
                            const SizedBox(width: 2),
                            // 4. Heavy Tank / Apex (Dark Crimson)
                            Expanded(
                              flex: 15,
                              child: Container(color: const Color(0xFF93000A)),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Active BMI Needle / Marker
                    Positioned(
                      left: markerPosition,
                      child: Container(
                        width: 8,
                        height: 14,
                        decoration: BoxDecoration(
                          color: LevMaxTheme.primaryContainer,
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: const [
                            BoxShadow(
                              color: LevMaxTheme.primaryContainer,
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Starting Vitals Allocation Readout (2 Kolom)
          Row(
            children: [
              // Kolom 1: Base HP
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: LevMaxTheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.favorite,
                                    color: LevMaxTheme.hpRed,
                                    size: 13,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    'BASE HP',
                                    style: LevMaxTheme.mono(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: LevMaxTheme.hpRedLabel,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$_calculatedBaseHp / $_calculatedBaseHp',
                                style: LevMaxTheme.mono(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: LevMaxTheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: LevMaxTheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: 1.0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: LevMaxTheme.hpRed,
                              borderRadius: BorderRadius.circular(2),
                              boxShadow: const [
                                BoxShadow(
                                  color: LevMaxTheme.hpRed,
                                  blurRadius: 6,
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
              const SizedBox(width: 8),

              // Kolom 2: Base Stamina
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: LevMaxTheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.bolt,
                                    color: LevMaxTheme.tertiaryContainer,
                                    size: 13,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    'BASE STAMINA',
                                    style: LevMaxTheme.mono(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: LevMaxTheme.tertiaryContainer,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$_calculatedBaseStamina / $_calculatedBaseStamina',
                                style: LevMaxTheme.mono(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: LevMaxTheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: LevMaxTheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: 1.0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: LevMaxTheme.tertiaryContainer,
                              borderRadius: BorderRadius.circular(2),
                              boxShadow: const [
                                BoxShadow(
                                  color: LevMaxTheme.tertiaryContainer,
                                  blurRadius: 6,
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
            ],
          ),
          const SizedBox(height: 12),

          // Assigned Starting Hunter Rank Banner
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: LevMaxTheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Row(
              children: [
                // Square Rank Badge 40x40
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: LevMaxTheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF00DBE9),
                      width: 1.2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _calculatedRank,
                      style: LevMaxTheme.headline(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF00DBE9),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Rank Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _rankTitle,
                        style: LevMaxTheme.headline(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: LevMaxTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Vessel ready for Awakening Sequence',
                        style: TextStyle(
                          fontSize: 11,
                          color: LevMaxTheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                const Icon(
                  Icons.military_tech,
                  color: Color(0xFF00DBE9),
                  size: 22,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // KOMPONEN 7: FINAL CTA BUTTON & PROTOCOL DISCLAIMER
  // ============================================================================
  Widget _buildFinalCtaAndDisclaimer() {
    return Column(
      children: [
        // Main CTA Button
        GestureDetector(
          onTap: _isLoading ? null : _handleCompleteAwakening,
          child: Container(
            height: 48,
            width: double.infinity,
            decoration: BoxDecoration(
              color: _isAwakeningTriggered
                  ? LevMaxTheme.tertiaryContainer
                  : LevMaxTheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: LevMaxTheme.primaryContainer.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: _isLoading
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: LevMaxTheme.onPrimary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'AWAKENING PROTOCOL INITIALIZED...',
                          style: LevMaxTheme.mono(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: LevMaxTheme.onPrimary,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'COMPLETE AWAKENING & INITIALIZE SYSTEM',
                          style: LevMaxTheme.mono(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: LevMaxTheme.onPrimary,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward,
                          color: LevMaxTheme.onPrimary,
                          size: 20,
                        ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Protocol Disclaimer
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.sync,
              color: LevMaxTheme.outline,
              size: 14,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'SYSTEM METRICS SYNC WITH GOOGLE FIT & APPLE HEALTH PROTOCOLS',
                textAlign: TextAlign.center,
                style: LevMaxTheme.mono(
                  fontSize: 9,
                  color: LevMaxTheme.outline,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================================
  // REUSABLE STEPPER CONTROLS
  // ============================================================================
  Widget _buildStepperButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: LevMaxTheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF313540)),
        ),
        child: Center(
          child: Icon(
            icon,
            color: LevMaxTheme.primary,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildSmallStepper({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: LevMaxTheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF313540)),
        ),
        child: Center(
          child: Icon(
            icon,
            color: LevMaxTheme.primary,
            size: 18,
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // BUILD METHOD UTAMA
  // ============================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LevMaxTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Komponen 1: Sticky Top Navigation Bar (64px)
            _buildStickyTopNavigationBar(),

            // Main Scrollable Body
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Komponen 2: Narrative Intro & Telemetry Header
                    _buildNarrativeIntroHeader(),
                    const SizedBox(height: 18),

                    // Komponen 3: Vessel Height Stepper Card
                    _buildVesselHeightCard(),
                    const SizedBox(height: 14),

                    // Komponen 4: Vessel Mass Card
                    _buildVesselMassCard(),
                    const SizedBox(height: 14),

                    // Komponen 5: Upper Body & Core Strength Grid
                    _buildStrengthCalibrationGrid(),
                    const SizedBox(height: 16),

                    // Komponen 6: Real-Time Dynamic BMI & System Appraisal Window
                    _buildSystemAppraisalWindow(),
                    const SizedBox(height: 20),

                    // Komponen 7: Final CTA Button & Protocol Disclaimer
                    _buildFinalCtaAndDisclaimer(),
                    const SizedBox(height: 24),
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
// CUSTOM PAINTER: PIXEL SILHOUETTE FOR HEIGHT RULER & GLOWING MANA CORE
// ==============================================================================
class _PixelSilhouettePainter extends CustomPainter {
  final double heightCm;
  final double pulseValue;

  const _PixelSilhouettePainter({
    required this.heightCm,
    required this.pulseValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00DBE9).withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;

    // Scale factor dinamis berdasarkan heightCm (120 - 230 cm)
    final scale = ((heightCm - 120.0) / 110.0).clamp(0.68, 1.05);

    canvas.save();
    canvas.translate(size.width / 2, size.height);
    canvas.scale(scale, scale);

    // 1. Head (Pixel Block)
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-7, -80, 14, 14), const Radius.circular(2)),
      paint,
    );

    // 2. Torso (Pixel Block)
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-10, -64, 20, 32), const Radius.circular(2)),
      paint,
    );

    // 3. Left Arm
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-17, -62, 5, 26), const Radius.circular(2)),
      paint,
    );

    // 4. Right Arm
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(12, -62, 5, 26), const Radius.circular(2)),
      paint,
    );

    // 5. Left Leg
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-9, -30, 8, 30), const Radius.circular(2)),
      paint,
    );

    // 6. Right Leg
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(1, -30, 8, 30), const Radius.circular(2)),
      paint,
    );

    // 7. Glowing Mana Core Pulse Dot di Bagian Dada
    final manaGlowPaint = Paint()
      ..color = LevMaxTheme.primaryContainer.withValues(alpha: 0.3 + (pulseValue * 0.5))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(const Offset(0, -50), 6.0 + (pulseValue * 2.0), manaGlowPaint);

    final manaCorePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(0, -50), 3.0, manaCorePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PixelSilhouettePainter oldDelegate) =>
      oldDelegate.heightCm != heightCm || oldDelegate.pulseValue != pulseValue;
}
