// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/ui/onboarding/onboarding_page.dart
// Deskripsi: Layanan Onboarding Fisik, Kalkulasi BMI Real-time, &
//            Generasi Daily Quest Perdana dengan Rumus Adaptif 60% (FR-1.4 & Bab 5)
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

class _OnboardingPageState extends State<OnboardingPage> {
  final _formKey = GlobalKey<FormState>();

  final _tbController = TextEditingController(text: '170');
  final _bbController = TextEditingController(text: '65');
  final _pushupController = TextEditingController(text: '15');
  final _situpController = TextEditingController(text: '20');
  final _squatController = TextEditingController(text: '25');
  final _pullupController = TextEditingController(text: '5');
  final _runKmController = TextEditingController(text: '2.0');
  final _paceController = TextEditingController(text: '14.0');

  double _calculatedBmi = 22.49;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _recalculateBmi();
  }

  @override
  void dispose() {
    _tbController.dispose();
    _bbController.dispose();
    _pushupController.dispose();
    _situpController.dispose();
    _squatController.dispose();
    _pullupController.dispose();
    _runKmController.dispose();
    _paceController.dispose();
    super.dispose();
  }

  void _recalculateBmi() {
    final tb = double.tryParse(_tbController.text) ?? 170.0;
    final bb = double.tryParse(_bbController.text) ?? 65.0;
    if (tb > 0) {
      final heightMeter = tb / 100.0;
      final bmi = bb / (heightMeter * heightMeter);
      setState(() {
        _calculatedBmi = double.parse(bmi.toStringAsFixed(2));
      });
    }
  }

  String get _bmiCategory {
    if (_calculatedBmi < 18.5) return 'Underweight (Kurang BB)';
    if (_calculatedBmi <= 24.9) return 'Normal (Ideal)';
    if (_calculatedBmi <= 29.9) return 'Overweight (Kelebihan BB)';
    return 'Obese (Obesitas)';
  }

  Color get _bmiColor {
    if (_calculatedBmi < 18.5) return Colors.amber;
    if (_calculatedBmi <= 24.9) return const Color(0xFF00E5FF);
    if (_calculatedBmi <= 29.9) return Colors.orange;
    return const Color(0xFFFF1744);
  }

  String get _bmiRecommendation {
    if (_calculatedBmi < 18.5) {
      return 'Fokus: Peningkatan massa otot melalui Strength Workout & asupan surplus kalori tinggi protein.';
    } else if (_calculatedBmi <= 24.9) {
      return 'Fokus: Program seimbang (Workout, Cardio, Skincare Looksmaxxing, & Disiplin Belajar).';
    } else {
      return 'Fokus: Defisit kalori aerobik via Cardio (Jogging/Lari) dan endurance latihan tubuh.';
    }
  }

  Future<void> _handleSubmitOnboarding() async {
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final tb = double.tryParse(_tbController.text) ?? 170.0;
    final bb = double.tryParse(_bbController.text) ?? 65.0;
    final pushup = int.tryParse(_pushupController.text) ?? 15;
    final situp = int.tryParse(_situpController.text) ?? 20;
    final squat = int.tryParse(_squatController.text) ?? 25;
    final pullup = int.tryParse(_pullupController.text) ?? 5;
    final runKm = double.tryParse(_runKmController.text) ?? 2.0;
    final pace = double.tryParse(_paceController.text) ?? 14.0;

    final userId = await UserInfo.getUserID() ?? 1;
    final username = await UserInfo.getUsername() ?? 'Hunter';
    final email = await UserInfo.getEmail() ?? '';

    // Buat objek player terkini
    final player = UserModel(
      id: userId,
      username: username,
      email: email,
      isOnboarded: true,
      tbCm: tb,
      bbKg: bb,
      bmi: _calculatedBmi,
      maxPushup: pushup,
      maxSitup: situp,
      maxSquat: squat,
      maxPullup: pullup,
      maxRunKm: runKm,
      pace2kmMenit: pace,
      level: 1,
      rank: 'F',
      hp: 100,
      exp: 0,
      gold: 0,
      isPenaltyActive: false,
      lastActiveDate: DateTime.now().toIso8601String().substring(0, 10),
      createdAt: DateTime.now().toIso8601String(),
    );

    // Simpan ke Hive Cache & Supabase
    await SupabaseApiService.updateUser(player);
    await UserInfo.setIsOnboarded(true);

    // Generasi Daily Quest Perdana dengan Rumus Adaptif 60% (Bab 5 Rules):
    // targetHariIni = (kapasitasMaks * 0.60).round()
    final todayDate = DateTime.now().toIso8601String().substring(0, 10);
    final questBox = Hive.box<QuestModel>(HiveBoxes.questBox);
    await questBox.clear(); // Bersihkan quest lama jika ada

    final targetPushup = (pushup * 0.60).round().clamp(5, 1000);
    final targetSitup = (situp * 0.60).round().clamp(5, 1000);
    final targetSquat = (squat * 0.60).round().clamp(5, 1000);
    final targetPullup = (pullup * 0.60).round().clamp(2, 1000);
    final targetRun = double.parse((runKm * 0.60).toStringAsFixed(1)).clamp(0.5, 50.0);

    final initialQuests = [
      QuestModel(
        id: 'quest_pushup_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Push-up Endurance',
        description: 'Lakukan form push-up sempurna untuk dada & core',
        category: 'Workout',
        targetValue: targetPushup,
        currentValue: 0,
        unit: 'Reps',
        expReward: 25,
        goldReward: 10,
        isCompleted: false,
        scheduledDate: todayDate,
      ),
      QuestModel(
        id: 'quest_situp_${DateTime.now().millisecondsSinceEpoch + 1}',
        title: 'Sit-up Core Discipline',
        description: 'Kencangkan otot perut dan stabilitas lumbar',
        category: 'Workout',
        targetValue: targetSitup,
        currentValue: 0,
        unit: 'Reps',
        expReward: 25,
        goldReward: 10,
        isCompleted: false,
        scheduledDate: todayDate,
      ),
      QuestModel(
        id: 'quest_squat_${DateTime.now().millisecondsSinceEpoch + 2}',
        title: 'Squat Leg Mastery',
        description: 'Kekuatan paha depan dan glutes untuk mobilitas',
        category: 'Workout',
        targetValue: targetSquat,
        currentValue: 0,
        unit: 'Reps',
        expReward: 25,
        goldReward: 10,
        isCompleted: false,
        scheduledDate: todayDate,
      ),
      QuestModel(
        id: 'quest_pullup_${DateTime.now().millisecondsSinceEpoch + 3}',
        title: 'Pull-up Lat Activation',
        description: 'Tarik tubuh ke atas palang tanpa momentum',
        category: 'Workout',
        targetValue: targetPullup,
        currentValue: 0,
        unit: 'Reps',
        expReward: 25,
        goldReward: 10,
        isCompleted: false,
        scheduledDate: todayDate,
      ),
      QuestModel(
        id: 'quest_run_${DateTime.now().millisecondsSinceEpoch + 4}',
        title: 'Cardio Jogging Pagi/Sore',
        description: 'Pertahankan Zone 2 cardio untuk stamina dungeon',
        category: 'Cardio',
        targetValue: targetRun.round() < 1 ? 1 : targetRun.round(),
        currentValue: 0,
        unit: 'Km',
        expReward: 30,
        goldReward: 15,
        isCompleted: false,
        scheduledDate: todayDate,
      ),
      QuestModel(
        id: 'quest_skin_${DateTime.now().millisecondsSinceEpoch + 5}',
        title: 'Looksmaxxing Skincare & Mewing',
        description: 'Cuci muka, aplikasikan sunscreen, & jaga postur tegap',
        category: 'Skincare',
        targetValue: 1,
        currentValue: 0,
        unit: 'Checklist',
        expReward: 15,
        goldReward: 5,
        isCompleted: false,
        scheduledDate: todayDate,
      ),
      QuestModel(
        id: 'quest_study_${DateTime.now().millisecondsSinceEpoch + 6}',
        title: 'Deep Work & Disiplin Belajar',
        description: 'Fokus 1 jam belajar/kuliah tanpa gangguan distraksi layar',
        category: 'Study',
        targetValue: 1,
        currentValue: 0,
        unit: 'Jam',
        expReward: 20,
        goldReward: 10,
        isCompleted: false,
        scheduledDate: todayDate,
      ),
    ];

    for (final q in initialQuests) {
      await questBox.add(q);
      await SupabaseApiService.syncQuest(quest: q, userId: userId);
    }

    // Catat ke Blockchain
    await BlockchainService.addBlock(
      'ONBOARDING COMPLETED: Hunter Awakened as Level 1 (Rank F) - BMI: $_calculatedBmi',
      userId: userId,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Penilaian Fisik Selesai! Daily Quest Perdana Telah Diterbitkan.'),
        backgroundColor: Color(0xFF00E5FF),
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
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        title: const Text('PENILAIAN FISIK AWAL (ONBOARDING)'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Info Box Solo Leveling
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131B2E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.6)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.fitness_center, color: Color(0xFF00E5FF), size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'SISTEM PENENTUAN BEBAN QUEST',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF00E5FF),
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Sistem akan menetapkan beban awal 60% dari kapasitas maksimal Anda',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: Color(0xFF1E293B), height: 24),

                      // Card Tampilan BMI Real-time
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SKOR BMI HUNTER',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                  color: Colors.white.withValues(alpha: 0.6),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$_calculatedBmi',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: _bmiColor,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _bmiColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _bmiColor),
                            ),
                            child: Text(
                              _bmiCategory,
                              style: TextStyle(
                                color: _bmiColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _bmiRecommendation,
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Bagian 1: Antropometri
                const Text(
                  '1. ANTROPOMETRI (TB & BB)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF00E5FF)),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _tbController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Tinggi Badan (cm)',
                          suffixText: 'cm',
                          filled: true,
                          fillColor: const Color(0xFF131B2E),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onChanged: (_) => _recalculateBmi(),
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Wajib diisi';
                          if (double.tryParse(val) == null) return 'Angka';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _bbController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Berat Badan (kg)',
                          suffixText: 'kg',
                          filled: true,
                          fillColor: const Color(0xFF131B2E),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onChanged: (_) => _recalculateBmi(),
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Wajib diisi';
                          if (double.tryParse(val) == null) return 'Angka';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Bagian 2: Repetisi Maksimal (Calisthenics)
                const Text(
                  '2. KAPASITAS REPETISI MAKSIMAL',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF00E5FF)),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _pushupController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Maks Push-up',
                          suffixText: 'reps',
                          filled: true,
                          fillColor: const Color(0xFF131B2E),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _situpController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Maks Sit-up',
                          suffixText: 'reps',
                          filled: true,
                          fillColor: const Color(0xFF131B2E),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _squatController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Maks Squat',
                          suffixText: 'reps',
                          filled: true,
                          fillColor: const Color(0xFF131B2E),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _pullupController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Maks Pull-up',
                          suffixText: 'reps',
                          filled: true,
                          fillColor: const Color(0xFF131B2E),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Bagian 3: Cardio / Jogging
                const Text(
                  '3. KAPASITAS CARDIO & ENDURANCE',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF00E5FF)),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _runKmController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Jarak Lari Maks',
                          suffixText: 'km',
                          filled: true,
                          fillColor: const Color(0xFF131B2E),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _paceController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Pace 2 Km',
                          suffixText: 'menit',
                          filled: true,
                          fillColor: const Color(0xFF131B2E),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 36),

                // Tombol Submit Selesaikan Onboarding
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleSubmitOnboarding,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5FF),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 6,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                        )
                      : const Text(
                          'BANGKITKAN HUNTER & TERIMA DAILY QUEST',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                        ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
