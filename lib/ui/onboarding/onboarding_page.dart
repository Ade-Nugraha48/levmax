// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/ui/onboarding/onboarding_page.dart
// Deskripsi: Redesain Google Stitch - Hunter Calibration: Stats Calibration (Prompt 2 - Bagian 2)
//            Mengusung estetika RPG Character Stat Sheet, Interactive Metric Steppers,
//            Pixel Silhouette & Height Ruler, Dynamic BMI Range Gauge, & Vitals Allocation.
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../helpers/boxes.dart';
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
  // KALKULASI DINAMIS BMI & VITALS
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
    if (bmi < 18.5) return const Color(0xFFF59E0B); // Amber
    if (bmi <= 24.9) return const Color(0xFF65F2B5); // Mint Emerald
    if (bmi <= 29.9) return const Color(0xFFD2BBFF); // Violet
    return const Color(0xFFFF2A54); // Crimson
  }

  int get _calculatedBaseHp {
    return (80 + (_pushups * 0.5) + (_situps * 0.3)).round().clamp(50, 200);
  }

  int get _calculatedBaseStamina {
    return (75 + (_situps * 0.6) + (_pushups * 0.2)).round().clamp(50, 200);
  }

  double get _bmiGaugePercentage {
    // Clamps between 15 and 32 BMI, mapped to 0.05 .. 0.92
    final bmi = _calculatedBmi;
    final percent = ((bmi - 15.0) / (32.0 - 15.0)).clamp(0.05, 0.92);
    return percent;
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
        // Delta in lbs -> convert to kg
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
      rank: 'E',
      hp: 100,
      exp: 0,
      gold: 50,
      isPenaltyActive: false,
      lastActiveDate: todayDate,
      createdAt: DateTime.now().toIso8601String(),
    );

    // Simpan ke Hive Cache & Supabase
    await SupabaseApiService.updateUser(player);
    await UserInfo.setIsOnboarded(true);

    // Rumus Adaptif 60% Kapasitas Maksimal Hunter
    final questBox = Hive.box<QuestModel>(HiveBoxes.questBox);
    await questBox.clear();

    final targetPushup = (_pushups * 0.60).round().clamp(5, 500);
    final targetSitup = (_situps * 0.60).round().clamp(5, 500);
    final targetSquat = (_squats * 0.60).round().clamp(5, 500);
    final targetPullup = (_pullups * 0.60).round().clamp(2, 500);
    final targetRun = double.parse((_runKm * 0.60).toStringAsFixed(1)).clamp(0.5, 50.0);

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
      await SupabaseApiService.syncQuest(quest: q, userId: userId);
    }

    // Catat ke Blockchain Genesis
    await BlockchainService.addBlock(
      'ONBOARDING COMPLETED: Hunter Awakened as Rank E Recruit - Baseline BMI: $_calculatedBmi, HP: $_calculatedBaseHp',
      userId: userId,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.verified, color: Colors.black),
            SizedBox(width: 8),
            Text(
              'AWAKENING COMPLETE! ENTERING THE SYSTEM...',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 12),
            ),
          ],
        ),
        backgroundColor: Color(0xFF00F0FF),
        behavior: SnackBarBehavior.floating,
      ),
    );

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainNavigationPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayWeight = _weightUnit == 'kg'
        ? _weightKg.toStringAsFixed(1)
        : (_weightKg * 2.20462).toStringAsFixed(1);

    return Scaffold(
      backgroundColor: const Color(0xFF0F131D),
      body: SafeArea(
        child: Column(
          children: [
            // ==============================================================
            // 1. TOP HEADER BAR
            // ==============================================================
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(
                color: Color(0xFF0A0E18),
                border: Border(bottom: BorderSide(color: Color(0xFF1C1F2A), width: 1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Color(0xFF00DBE9), size: 20),
                        onPressed: () {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          }
                        },
                      ),
                      const SizedBox(width: 4),
                      Column(
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
                                      color: const Color(0xFF00F0FF).withValues(
                                        alpha: 0.4 + (_pulseController.value * 0.6),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                '[SYS // ONBOARDING]',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  color: Color(0xFF00DBE9),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                          const Text(
                            'Hunter Calibration',
                            style: TextStyle(
                              color: Color(0xFFDFE2F1),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'SEQ',
                            style: TextStyle(fontFamily: 'monospace', color: Color(0xFF849495), fontSize: 9),
                          ),
                          Text(
                            'PHASE 01/02',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: Color(0xFF00F0FF),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFDBFCFF),
                        ),
                        child: const Icon(Icons.person, color: Color(0xFF00363A), size: 18),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ==============================================================
            // MAIN SCROLLABLE ONBOARDING FORM
            // ==============================================================
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Step Telemetry & Narrative Intro
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF00F0FF),
                                boxShadow: [
                                  BoxShadow(color: Color(0xFF00F0FF), blurRadius: 4),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'PHASE 02 // VESSEL CALIBRATION',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: Color(0xFF00DBE9),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF262A35),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'SYNC: READY',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: Color(0xFF6FFBBE),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'NEW HUNTER ONBOARDING: STATS CALIBRATION',
                      style: TextStyle(
                        color: Color(0xFF00F0FF),
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Enter your physical vessel metrics to calculate your starting Hunter Rank and baseline vitals.',
                      style: TextStyle(
                        color: Color(0xFFB9CACB),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // ==============================================================
                    // 2. HEIGHT STEPPER CARD (WITH PIXEL SILHOUETTE & RULER)
                    // ==============================================================
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF171B26),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF1C1F2A)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Row(
                                  children: [
                                    Icon(Icons.height, color: Color(0xFF7DF4FF), size: 15),
                                    SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        'VESSEL HEIGHT [VERTICAL STAT]',
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          color: Color(0xFF7DF4FF),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.4,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0A0E18),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'AXIS: Z-HEIGHT',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    color: Color(0xFF849495),
                                    fontSize: 9,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Left Controls
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
                                          style: const TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 32,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF00F0FF),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Text(
                                          'CM',
                                          style: TextStyle(
                                            fontFamily: 'monospace',
                                            color: Color(0xFF00DBE9),
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
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
                                            height: 38,
                                            padding: const EdgeInsets.symmetric(horizontal: 10),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF1C1F2A),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: const Color(0xFF313540)),
                                            ),
                                            child: const Center(
                                              child: Text(
                                                '+5',
                                                style: TextStyle(
                                                  fontFamily: 'monospace',
                                                  color: Color(0xFF00DBE9),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
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

                              // Right Graphic: Pixel Silhouette + Height Ruler
                              Expanded(
                                flex: 5,
                                child: SizedBox(
                                  height: 96,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      // Pixel silhouette
                                      CustomPaint(
                                        size: const Size(42, 84),
                                        painter: _PixelSilhouettePainter(heightCm: _heightCm),
                                      ),
                                      const SizedBox(width: 10),
                                      // Height ruler ticks
                                      const Column(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('200', style: TextStyle(fontFamily: 'monospace', color: Color(0xFF849495), fontSize: 9)),
                                          Text('180', style: TextStyle(fontFamily: 'monospace', color: Color(0xFF849495), fontSize: 9)),
                                          Text('175', style: TextStyle(fontFamily: 'monospace', color: Color(0xFF00F0FF), fontSize: 9, fontWeight: FontWeight.bold)),
                                          Text('160', style: TextStyle(fontFamily: 'monospace', color: Color(0xFF849495), fontSize: 9)),
                                          Text('140', style: TextStyle(fontFamily: 'monospace', color: Color(0xFF849495), fontSize: 9)),
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
                    ),
                    const SizedBox(height: 12),

                    // ==============================================================
                    // 3. WEIGHT STEPPER CARD WITH UNIT SWITCHER
                    // ==============================================================
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF171B26),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF1C1F2A)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Row(
                                  children: [
                                    Icon(Icons.scale, color: Color(0xFF7DF4FF), size: 15),
                                    SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        'VESSEL MASS [GRAVITY RESISTANCE]',
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          color: Color(0xFF7DF4FF),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.4,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Unit Switcher KG / LBS
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0A0E18),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () => _toggleWeightUnit('kg'),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: _weightUnit == 'kg' ? const Color(0xFF00F0FF) : Colors.transparent,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'KG',
                                          style: TextStyle(
                                            fontFamily: 'monospace',
                                            color: _weightUnit == 'kg' ? const Color(0xFF002022) : const Color(0xFF849495),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => _toggleWeightUnit('lbs'),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: _weightUnit == 'lbs' ? const Color(0xFF00F0FF) : Colors.transparent,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'LBS',
                                          style: TextStyle(
                                            fontFamily: 'monospace',
                                            color: _weightUnit == 'lbs' ? const Color(0xFF002022) : const Color(0xFF849495),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    displayWeight,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF00F0FF),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _weightUnit.toUpperCase(),
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      color: Color(0xFF00DBE9),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
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
                    ),
                    const SizedBox(height: 12),

                    // ==============================================================
                    // 4. UPPER BODY & CORE STRENGTH GRID (2 COLUMNS)
                    // ==============================================================
                    Row(
                      children: [
                        // Column 1: Max Push-Ups
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF171B26),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF1C1F2A)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.fitness_center, color: Color(0xFF00F0FF), size: 16),
                                    SizedBox(width: 6),
                                    Text(
                                      'UPPER STRENGTH',
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        color: Color(0xFF7DF4FF),
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'MAX PUSH-UPS',
                                  style: TextStyle(fontFamily: 'monospace', color: Color(0xFF849495), fontSize: 9),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      _pushups.toString(),
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF00F0FF),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'REPS',
                                      style: TextStyle(fontFamily: 'monospace', color: Color(0xFF00DBE9), fontSize: 10),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    _buildSmallStepper(icon: Icons.remove, onTap: () => _adjustPushups(-1)),
                                    const SizedBox(width: 6),
                                    _buildSmallStepper(icon: Icons.add, onTap: () => _adjustPushups(1)),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => _adjustPushups(5),
                                        child: Container(
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF313540),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Center(
                                            child: Text(
                                              '+5',
                                              style: TextStyle(
                                                fontFamily: 'monospace',
                                                color: Color(0xFF7DF4FF),
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
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

                        // Column 2: Max Sit-Ups
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF171B26),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF1C1F2A)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.accessibility_new, color: Color(0xFF00F0FF), size: 16),
                                    SizedBox(width: 6),
                                    Text(
                                      'CORE STABILITY',
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        color: Color(0xFF7DF4FF),
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'MAX SIT-UPS',
                                  style: TextStyle(fontFamily: 'monospace', color: Color(0xFF849495), fontSize: 9),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      _situps.toString(),
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF00F0FF),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'REPS',
                                      style: TextStyle(fontFamily: 'monospace', color: Color(0xFF00DBE9), fontSize: 10),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    _buildSmallStepper(icon: Icons.remove, onTap: () => _adjustSitups(-1)),
                                    const SizedBox(width: 6),
                                    _buildSmallStepper(icon: Icons.add, onTap: () => _adjustSitups(1)),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => _adjustSitups(5),
                                        child: Container(
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF313540),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Center(
                                            child: Text(
                                              '+5',
                                              style: TextStyle(
                                                fontFamily: 'monospace',
                                                color: Color(0xFF7DF4FF),
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
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
                    ),
                    const SizedBox(height: 16),

                    // ==============================================================
                    // 5. REAL-TIME DYNAMIC BMI & SYSTEM APPRAISAL WINDOW
                    // ==============================================================
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1F2A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF262A35)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header appraisal
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.verified, color: Color(0xFFD2BBFF), size: 16),
                                  SizedBox(width: 6),
                                  Text(
                                    '[ SYSTEM APPRAISAL COMPLETE ]',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      color: Color(0xFFEADDFF),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF262A35),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.circle, color: Color(0xFF6FFBBE), size: 6),
                                    SizedBox(width: 4),
                                    Text(
                                      'LIVE SYNC',
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        color: Color(0xFF6FFBBE),
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Score and Badge
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'CALCULATED VESSEL SCORE',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      color: Color(0xFF849495),
                                      fontSize: 9,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                        _calculatedBmi.toString(),
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 30,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF7DF4FF),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Text(
                                        'BMI',
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          color: Color(0xFF00DBE9),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF313540),
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
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Flexible(
                                        child: Text(
                                          _bmiStatusText,
                                          style: TextStyle(
                                            fontFamily: 'monospace',
                                            color: _bmiStatusColor,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
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
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('16.0 SLENDER', style: TextStyle(fontFamily: 'monospace', color: Color(0xFF849495), fontSize: 7.5)),
                              Text('18.5 BALANCED', style: TextStyle(fontFamily: 'monospace', color: Color(0xFF849495), fontSize: 7.5)),
                              Text('25.0 OVER', style: TextStyle(fontFamily: 'monospace', color: Color(0xFF849495), fontSize: 7.5)),
                              Text('30.0+ APEX', style: TextStyle(fontFamily: 'monospace', color: Color(0xFF849495), fontSize: 7.5)),
                            ],
                          ),
                          const SizedBox(height: 4),

                          // Gauge Bar
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final totalWidth = constraints.maxWidth;
                              final markerPosition = (totalWidth * _bmiGaugePercentage).clamp(0.0, totalWidth - 8);

                              return SizedBox(
                                height: 14,
                                child: Stack(
                                  alignment: Alignment.centerLeft,
                                  children: [
                                    // 4 Segment track
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Row(
                                        children: [
                                          Expanded(flex: 22, child: Container(color: const Color(0xFF313540))),
                                          const SizedBox(width: 2),
                                          Expanded(flex: 38, child: Container(color: const Color(0xFF65F2B5))),
                                          const SizedBox(width: 2),
                                          Expanded(flex: 25, child: Container(color: const Color(0xFF6001D1))),
                                          const SizedBox(width: 2),
                                          Expanded(flex: 15, child: Container(color: const Color(0xFF93000A))),
                                        ],
                                      ),
                                    ),

                                    // Moving Active Needle / Marker
                                    Positioned(
                                      left: markerPosition,
                                      child: Container(
                                        width: 8,
                                        height: 14,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF00F0FF),
                                          borderRadius: BorderRadius.circular(3),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Color(0xFF00F0FF),
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

                          // Starting Vitals Allocation Readout
                          Row(
                            children: [
                              // HP Gauge
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0A0E18),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Row(
                                            children: [
                                              Icon(Icons.favorite, color: Color(0xFFFFB4AB), size: 12),
                                              SizedBox(width: 4),
                                              Text(
                                                'BASE HP',
                                                style: TextStyle(
                                                  fontFamily: 'monospace',
                                                  color: Color(0xFFFFB4AB),
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            '$_calculatedBaseHp / $_calculatedBaseHp',
                                            style: const TextStyle(
                                              fontFamily: 'monospace',
                                              color: Color(0xFFFFB4AB),
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF262A35),
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                        child: FractionallySizedBox(
                                          alignment: Alignment.centerLeft,
                                          widthFactor: 1.0,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFF2A54),
                                              borderRadius: BorderRadius.circular(2),
                                              boxShadow: const [
                                                BoxShadow(color: Color(0xFFFF2A54), blurRadius: 4),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Stamina Gauge
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0A0E18),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Row(
                                            children: [
                                              Icon(Icons.bolt, color: Color(0xFF4EDEA3), size: 11),
                                              SizedBox(width: 3),
                                              Text(
                                                'BASE STAMINA',
                                                style: TextStyle(
                                                  fontFamily: 'monospace',
                                                  color: Color(0xFF4EDEA3),
                                                  fontSize: 8.5,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            '$_calculatedBaseStamina / $_calculatedBaseStamina',
                                            style: const TextStyle(
                                              fontFamily: 'monospace',
                                              color: Color(0xFF4EDEA3),
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF262A35),
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                        child: FractionallySizedBox(
                                          alignment: Alignment.centerLeft,
                                          widthFactor: 1.0,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF65F2B5),
                                              borderRadius: BorderRadius.circular(2),
                                              boxShadow: const [
                                                BoxShadow(color: Color(0xFF65F2B5), blurRadius: 4),
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
                              color: const Color(0xFF0A0E18),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF262A35),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFF00F0FF)),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'E',
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        color: Color(0xFF00F0FF),
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'RANK E - RECRUIT HUNTER',
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          color: Color(0xFF00F0FF),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'Vessel ready for Awakening Sequence',
                                        style: TextStyle(color: Color(0xFF849495), fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.military_tech, color: Color(0xFF00F0FF), size: 22),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ==============================================================
                    // 6. FINAL CTA & DISCLAIMER
                    // ==============================================================
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleCompleteAwakening,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isAwakeningTriggered ? const Color(0xFF65F2B5) : const Color(0xFF00F0FF),
                        foregroundColor: const Color(0xFF002022),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 8,
                        shadowColor: const Color(0xFF00F0FF).withValues(alpha: 0.4),
                      ),
                      child: _isAwakeningTriggered
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.done_all, color: Colors.black, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'AWAKENING COMPLETE! ENTERING GATE',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'COMPLETE AWAKENING & INITIALIZE SYSTEM',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                SizedBox(width: 6),
                                Icon(Icons.arrow_forward, size: 18),
                              ],
                            ),
                    ),
                    const SizedBox(height: 12),

                    // Protocol disclaimer
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sync, color: Color(0xFF849495), size: 14),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'SYSTEM METRICS SYNC WITH GOOGLE FIT & APPLE HEALTH PROTOCOLS',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: Color(0xFF849495),
                              fontSize: 9,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepperButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFF262A35),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF313540)),
        ),
        child: Center(
          child: Icon(icon, color: const Color(0xFF00F0FF), size: 18),
        ),
      ),
    );
  }

  Widget _buildSmallStepper({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFF262A35),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFF313540)),
        ),
        child: Center(
          child: Icon(icon, color: const Color(0xFF00F0FF), size: 16),
        ),
      ),
    );
  }
}

// ==============================================================================
// CUSTOM PAINTER: PIXEL SILHOUETTE FOR HEIGHT RULER
// ==============================================================================
class _PixelSilhouettePainter extends CustomPainter {
  final double heightCm;
  const _PixelSilhouettePainter({required this.heightCm});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00DBE9).withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;

    // Scale factor based on heightCm (140 to 200 cm mapped to 0.7 .. 1.0)
    final scale = ((heightCm - 120.0) / 100.0).clamp(0.65, 1.05);

    canvas.save();
    canvas.translate(size.width / 2, size.height);
    canvas.scale(scale, scale);

    // Pixelated hunter humanoid body
    // Head
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-6, -74, 12, 12), const Radius.circular(2)), paint);
    // Torso
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-9, -60, 18, 30), const Radius.circular(2)), paint);
    // Left Arm
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-16, -58, 5, 24), const Radius.circular(2)), paint);
    // Right Arm
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(11, -58, 5, 24), const Radius.circular(2)), paint);
    // Left Leg
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-8, -28, 7, 28), const Radius.circular(2)), paint);
    // Right Leg
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(1, -28, 7, 28), const Radius.circular(2)), paint);

    // Mana Core Pulse Dot
    final corePaint = Paint()
      ..color = const Color(0xFF00F0FF)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(0, -46), 3.5, corePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PixelSilhouettePainter oldDelegate) =>
      oldDelegate.heightCm != heightCm;
}
