// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/ui/tabs/status_quest_tab.dart
// Deskripsi: Pixel-Perfect Main Dashboard HUD (Solo Leveling Dark HUD)
//            Aturan Mutlak:
//            1. Penalty Guard: Jika user.isPenaltyActive == true, redirect ke /penalty
//            2. Kunci Appearance: Checkbox Skincare hanya bisa disubmit >= 21:00
//            3. Kunci Mystery Quest: Terkunci hingga 2 WO, 1 Cardio, 1 Appearance, 1 Study selesai
//            4. Sensor Navigation: WO -> SensorWorkoutPage, Cardio -> GPS Track, Study -> SensorStudyPage
//            5. Zero Lag Architecture: Server Reset Countdown menggunakan ValueNotifier
// ==============================================================================

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../../helpers/boxes.dart';
import '../../helpers/game_rules.dart';
import '../../helpers/levmax_theme.dart';
import '../../helpers/user_info.dart';
import '../../models/quest_model.dart';
import '../../models/user_model.dart';
import '../../services/blockchain_service.dart';
import '../../services/notification_service.dart';
import '../../services/supabase_api_service.dart';
import '../chat/system_ai_chat_modal.dart';
import '../quests/sensor_study_page.dart';
import '../quests/sensor_workout_page.dart';

class StatusQuestTab extends StatefulWidget {
  final UserModel player;
  final VoidCallback onPlayerUpdated;

  const StatusQuestTab({
    super.key,
    required this.player,
    required this.onPlayerUpdated,
  });

  @override
  State<StatusQuestTab> createState() => _StatusQuestTabState();
}

class _StatusQuestTabState extends State<StatusQuestTab> {
  // Search & Filter State
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Workout',
    'Cardio',
    'Appearance',
    'Study',
  ];

  // Zero-Lag Countdown Timer & Multi-Timezone Strip State (ValueNotifier)
  Timer? _countdownTimer;
  final ValueNotifier<String> _resetCountdownNotifier =
      ValueNotifier<String>('00:00:00');
  final ValueNotifier<String> _timezoneStripNotifier =
      ValueNotifier<String>('WIB --:-- | WITA --:-- | WIT --:-- | LND --:--');

  @override
  void initState() {
    super.initState();

    // 1. ATURAN 1: PENALTY GUARD (Cek Status Penalti Pengguna)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPenaltyGuard();
    });

    // 2. Inisialisasi Seeding Quests Harian
    _seedDefaultQuestsIfEmpty();

    // 3. Inisialisasi Timer Countdown Server Reset (00:00 WIB) & Zona Waktu
    _startServerResetTimer();

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _resetCountdownNotifier.dispose();
    _timezoneStripNotifier.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================================
  // ATURAN 1: PENALTY GUARD LOGIC
  // ============================================================================
  void _checkPenaltyGuard() {
    if (widget.player.isPenaltyActive) {
      debugPrint('[PENALTY GUARD] User is penalized! Redirecting to /penalty...');
      Navigator.pushReplacementNamed(context, '/penalty');
    }
  }

  // ============================================================================
  // KOMPONEN 2: LOGIKA SERVER RESET COUNTDOWN & MULTI-TIMEZONE STRIP
  // ============================================================================
  void _startServerResetTimer() {
    _updateCountdownAndTimezones();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateCountdownAndTimezones();
    });
  }

  void _updateCountdownAndTimezones() {
    final nowUtc = DateTime.now().toUtc();

    // 1. Hitung Mundur ke Pukul 00:00 WIB (UTC+7)
    final nowWib = nowUtc.add(const Duration(hours: 7));
    final nextMidnightWib = DateTime.utc(
      nowWib.year,
      nowWib.month,
      nowWib.day + 1,
      0,
      0,
      0,
    );
    final durationRemaining = nextMidnightWib.difference(nowWib);

    final hours = durationRemaining.inHours.toString().padLeft(2, '0');
    final minutes =
        (durationRemaining.inMinutes % 60).toString().padLeft(2, '0');
    final seconds =
        (durationRemaining.inSeconds % 60).toString().padLeft(2, '0');

    _resetCountdownNotifier.value = '$hours:$minutes:$seconds';

    // 2. Format 4 Zona Waktu: WIB (UTC+7), WITA (UTC+8), WIT (UTC+9), LND (UTC+0/1)
    final nowWita = nowUtc.add(const Duration(hours: 8));
    final nowWit = nowUtc.add(const Duration(hours: 9));
    final nowLnd = nowUtc; // London GMT / UTC

    final timeFormat = DateFormat('HH:mm');
    _timezoneStripNotifier.value =
        'WIB ${timeFormat.format(nowWib)} | WITA ${timeFormat.format(nowWita)} | WIT ${timeFormat.format(nowWit)} | LND ${timeFormat.format(nowLnd)}';
  }

  // ============================================================================
  // SEED DEFAULT QUESTS HARIAN SESUAI STANDAR GAME RULES
  // ============================================================================
  Future<void> _seedDefaultQuestsIfEmpty() async {
    final box = Hive.box<QuestModel>(HiveBoxes.questBox);
    if (box.isEmpty) {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final rankTargets = WorkoutScaling.targets[widget.player.rank] ??
          WorkoutScaling.targets['F']!;

      final initialQuests = [
        QuestModel(
          id: 'quest_wo_pushup_${widget.player.rank}',
          title: 'PUSH-UPS PROTOCOL',
          description: 'Ujian kekuatan sensor fisik otot dada & trisep',
          category: 'Workout',
          targetValue: rankTargets.pushUp,
          currentValue: 0,
          unit: 'Reps',
          expReward: 35,
          goldReward: 50,
          isCompleted: false,
          scheduledDate: today,
        ),
        QuestModel(
          id: 'quest_wo_squat_${widget.player.rank}',
          title: 'SQUAT REPETITION TRIAL',
          description: 'Kalibrasi lower body quadriceps & glutes',
          category: 'Workout',
          targetValue: rankTargets.squat,
          currentValue: 0,
          unit: 'Reps',
          expReward: 35,
          goldReward: 50,
          isCompleted: false,
          scheduledDate: today,
        ),
        QuestModel(
          id: 'quest_cardio_gps_${widget.player.rank}',
          title: 'GPS SPRINT PERIMETER',
          description: 'Lari taktis tracking GPS untuk meningkatkan AGI',
          category: 'Cardio',
          targetValue: max(1, rankTargets.runningKm.toInt()),
          currentValue: 0,
          unit: 'KM',
          expReward: 45,
          goldReward: 70,
          isCompleted: false,
          scheduledDate: today,
        ),
        QuestModel(
          id: 'quest_appearance_skincare',
          title: 'DAILY LOOKSMAXXING PROTOCOL',
          description: '7 Tahap Perawatan Kulit & Regenerasi Sel Hunter',
          category: 'Appearance',
          targetValue: 7,
          currentValue: 0,
          unit: 'Checklist',
          expReward: 25,
          goldReward: 30,
          isCompleted: false,
          scheduledDate: today,
        ),
        QuestModel(
          id: 'quest_study_trivia',
          title: 'COGNITIVE FOCUS & TRIVIA',
          description: 'Sensor Gyroscope Deep Work & Trivia Uji Kecerdasan',
          category: 'Study',
          targetValue: 45,
          currentValue: 0,
          unit: 'Mins',
          expReward: 30,
          goldReward: 60,
          isCompleted: false,
          scheduledDate: today,
        ),
      ];

      for (final q in initialQuests) {
        await box.add(q);
      }
      if (mounted) setState(() {});
    }
  }

  // ============================================================================
  // ATURAN 3: KUNCI MYSTERY QUEST CHECKER
  // ============================================================================
  bool _isMysteryQuestUnlocked(List<QuestModel> quests) {
    // Syarat: Minimal 2 Workout, 1 Cardio, 1 Appearance, 1 Study harus COMPLETED
    final workoutCompleted = quests
        .where((q) =>
            q.category.toLowerCase() == 'workout' && q.isCompleted)
        .length;
    final cardioCompleted = quests
        .where((q) =>
            q.category.toLowerCase() == 'cardio' && q.isCompleted)
        .length;
    final appearanceCompleted = quests
        .where((q) =>
            (q.category.toLowerCase() == 'appearance' ||
                q.category.toLowerCase() == 'skincare') &&
            q.isCompleted)
        .length;
    final studyCompleted = quests
        .where((q) =>
            (q.category.toLowerCase() == 'study' ||
                q.category.toLowerCase() == 'work') &&
            q.isCompleted)
        .length;

    return workoutCompleted >= 2 &&
        cardioCompleted >= 1 &&
        appearanceCompleted >= 1 &&
        studyCompleted >= 1;
  }

  // ============================================================================
  // PENYELESAIAN QUEST & LEVEL UP PROGRESSION
  // ============================================================================
  Future<void> _completeQuest(QuestModel quest) async {
    if (quest.isCompleted) return;

    quest.isCompleted = true;
    quest.currentValue = quest.targetValue;
    await quest.save();

    // Reward Atribut Sesuai Kategori
    String targetStat = 'STR';
    final cat = quest.category.toLowerCase();
    if (cat.contains('workout')) {
      targetStat = 'STR';
    } else if (cat.contains('cardio')) {
      targetStat = 'AGI';
    } else if (cat.contains('study')) {
      targetStat = 'INT';
    } else if (cat.contains('appearance') || cat.contains('skincare')) {
      targetStat = 'CHA';
    }

    await SupabaseApiService.applyQuestStatReward(
      user: widget.player,
      targetStat: targetStat,
      statBonus: 2,
      expBonus: quest.expReward,
      goldBonus: quest.goldReward,
    );

    // Notarisasi ke Blockchain Ledger lokal
    await BlockchainService.addBlock(
      'QUEST COMPLETED: ${quest.title} (+${quest.expReward} EXP, +$targetStat)',
      userId: widget.player.id,
    );

    // Sync status ke Supabase tabel daily_user_quests
    await SupabaseApiService.syncQuest(
      quest: quest,
      userId: widget.player.id,
    );

    widget.onPlayerUpdated();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF131826),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: LevMaxTheme.primaryContainer, width: 1.5),
          ),
          content: Row(
            children: [
              const Icon(Icons.bolt, color: LevMaxTheme.primaryContainer, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'SYSTEM: ${quest.title} SELESAI!\n+${quest.expReward} EXP • +${quest.goldReward}G • +2 $targetStat',
                  style: LevMaxTheme.mono(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // ============================================================================
  // ATURAN 2: MODAL BOTTOM SHEET SKINCARE (VALIDASI PUKUL 21:00)
  // ============================================================================
  void _openAppearanceBottomSheet(QuestModel quest) {
    final List<Map<String, dynamic>> skincareSteps = [
      {'title': 'Cuci Muka Pagi', 'desc': 'Gentle Cleanser menghilangkan sebum tidur', 'checked': true},
      {'title': 'Moisturizer Pagi', 'desc': 'Hydration Shield pelindung barier kulit', 'checked': true},
      {'title': 'Sunscreen Pagi', 'desc': 'UV Barrier SPF 50+ PA++++ tahan radiasi', 'checked': true},
      {'title': 'Re-apply Sunscreen', 'desc': 'Midday Refresh perlindungan matahari siang', 'checked': true},
      {'title': 'Cuci Muka Malam', 'desc': 'Deep Pore Cleanse mengangkat polusi & kotoran', 'checked': false},
      {'title': 'Eksfoliasi / Serum Malam', 'desc': 'Active Recovery regenerasi sel kulit mati', 'checked': false},
      {'title': 'Moisturizer Malam', 'desc': 'Night Regeneration kunci kelembapan tidur', 'checked': false},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1F2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final int currentHour = DateTime.now().hour;
            final bool isEligible = currentHour >= 21;

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle Bar
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF313540),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header Bottom Sheet
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF472B6).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.spa, color: Color(0xFFF472B6), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'DAILY LOOKSMAXXING PROTOCOL',
                              style: LevMaxTheme.headline(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: LevMaxTheme.primaryContainer,
                                letterSpacing: 1.0,
                              ),
                            ),
                            Text(
                              'Protokol Kebersihan Kulit & Regenerasi Sel Hunter',
                              style: LevMaxTheme.mono(
                                fontSize: 10,
                                color: LevMaxTheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFF262A35)),
                  const SizedBox(height: 8),

                  // 7 Checkbox Langkah Skincare
                  ...List.generate(skincareSteps.length, (index) {
                    final step = skincareSteps[index];
                    final isChecked = step['checked'] as bool;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F131D),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isChecked
                              ? LevMaxTheme.primaryContainer.withValues(alpha: 0.6)
                              : const Color(0xFF262A35),
                        ),
                      ),
                      child: CheckboxListTile(
                        value: isChecked,
                        activeColor: LevMaxTheme.primaryContainer,
                        checkColor: Colors.black,
                        checkboxShape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        onChanged: (val) {
                          setSheetState(() {
                            step['checked'] = val ?? false;
                          });
                        },
                        title: Text(
                          step['title'] as String,
                          style: LevMaxTheme.mono(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        subtitle: Text(
                          step['desc'] as String,
                          style: LevMaxTheme.mono(
                            fontSize: 10,
                            color: LevMaxTheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 14),

                  // KUNCI VALIDASI: Jam >= 21:00
                  if (!isEligible)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFEF4444)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lock_clock, color: Color(0xFFEF4444), size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Protokol malam hanya dapat divalidasi setelah pukul 21:00 Server Time.',
                              style: LevMaxTheme.mono(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFFFB4AB),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Tombol Submit
                  ElevatedButton(
                    onPressed: isEligible
                        ? () {
                            Navigator.pop(ctx);
                            _completeQuest(quest);
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isEligible
                          ? LevMaxTheme.primaryContainer
                          : const Color(0xFF262A35),
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: const Color(0xFF262A35),
                      disabledForegroundColor: Colors.white30,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      isEligible ? 'SUBMIT (+25 EXP & +2 CHA)' : 'SUBMIT (TERKUNCI < 21:00)',
                      style: LevMaxTheme.headline(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                        color: isEligible ? Colors.black : Colors.white30,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================================
  // ATURAN 3: MODAL MYSTERY QUEST (2.5x EXP MULTIPLIER)
  // ============================================================================
  void _openMysteryQuestModal() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF131826),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF8B5CF6), width: 2),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF6001D1).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.help_outline, color: Color(0xFFD2BBFF)),
              ),
              const SizedBox(width: 10),
              Text(
                'RED GATE: MYSTERY QUEST',
                style: LevMaxTheme.headline(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFD2BBFF),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'THE SHADOW MONARCH AWAKENING TRIAL',
                style: LevMaxTheme.headline(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Anda telah menaklukkan seluruh misi harian standar! Gerbang misterius terbuka dengan tantangan kejutan ekstrem.',
                style: LevMaxTheme.mono(
                  fontSize: 11,
                  color: LevMaxTheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F131D),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF6001D1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BONUS MULTIPLIER',
                          style: LevMaxTheme.mono(
                            fontSize: 9,
                            color: LevMaxTheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          '2.5x EXP MULTIPLIER',
                          style: LevMaxTheme.headline(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: LevMaxTheme.tertiaryFixed,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '+125 EXP',
                      style: LevMaxTheme.headline(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFD2BBFF),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('TUTUP', style: LevMaxTheme.mono(color: LevMaxTheme.outline)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await SupabaseApiService.applyQuestStatReward(
                  user: widget.player,
                  targetStat: 'STR',
                  statBonus: 5,
                  expBonus: (50 * QuestMultiplier.mysteryQuest).round(),
                  goldBonus: 100,
                );
                await BlockchainService.addBlock(
                  'RED GATE MYSTERY QUEST CLEARED (+125 EXP, +5 ALL STATS)',
                  userId: widget.player.id,
                );
                widget.onPlayerUpdated();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFF6001D1),
                      content: Text(
                        'MYSTERY QUEST CLEARED! +125 EXP & +100 GOLD TERCATAT DI BLOCKCHAIN!',
                        style: LevMaxTheme.mono(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6001D1)),
              child: Text(
                'ACCEPT & CLAIM',
                style: LevMaxTheme.headline(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================================
  // DIALOG CARDIO / GPS TRACK
  // ============================================================================
  void _openCardioGpsModal(QuestModel quest) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF131826),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF65F2B5), width: 1.5),
          ),
          title: Row(
            children: [
              const Icon(Icons.directions_run, color: Color(0xFF65F2B5)),
              const SizedBox(width: 8),
              Text(
                'GPS CARDIO TRACKER',
                style: LevMaxTheme.headline(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF65F2B5),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TARGET SPRINT: ${quest.targetValue} KM',
                style: LevMaxTheme.mono(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sistem mengaktifkan sensor LBS dan Pedometer dengan batas Anti-Cheat Kecepatan (Max ${PenaltyRules.maxCardioSpeedKmh} km/h).',
                style: LevMaxTheme.mono(
                  fontSize: 11,
                  color: LevMaxTheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F131D),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'STATUS SENSOR',
                      style: LevMaxTheme.mono(fontSize: 10, color: LevMaxTheme.onSurfaceVariant),
                    ),
                    Text(
                      'SATELLITE LOCKED',
                      style: LevMaxTheme.mono(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: LevMaxTheme.tertiaryFixed,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('BATAL', style: LevMaxTheme.mono(color: LevMaxTheme.outline)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _completeQuest(quest);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF65F2B5)),
              child: Text(
                'COMPLETE RUN',
                style: LevMaxTheme.headline(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================================
  // FLOATING BUTTON 1: ALARM / REMINDER PICKER
  // ============================================================================
  Future<void> _openAlarmDialog() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: LevMaxTheme.amberGold,
              onPrimary: Colors.black,
              surface: Color(0xFF1C1F2A),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      final timeStr =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';

      final alarmBox = Hive.box<AlarmModel>(HiveBoxes.alarmBox);
      final newAlarm = AlarmModel(
        id: DateTime.now().millisecondsSinceEpoch % 100000,
        time: timeStr,
        label: 'Hunter Daily Wakeup Call',
        isActive: true,
      );
      await alarmBox.add(newAlarm);

      await NotificationService.showCustomNotification(
        id: newAlarm.id,
        title: '⏰ [ALARM HUNTER DIAKTIFKAN: $timeStr]',
        body: 'Sistem akan mengingatkan Anda untuk menuntaskan seluruh Quest harian!',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF131826),
          content: Text(
            'PENGINGAT SISTEM DIAKTIFKAN UNTUK PUKUL $timeStr',
            style: LevMaxTheme.mono(color: LevMaxTheme.amberGold, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
  }

  // ============================================================================
  // LOGOUT CONFIRMATION
  // ============================================================================
  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131826),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFEF4444)),
        ),
        title: Row(
          children: [
            const Icon(Icons.power_settings_new, color: Color(0xFFEF4444)),
            const SizedBox(width: 8),
            Text(
              'DISCONNECT HUNTER',
              style: LevMaxTheme.headline(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFEF4444),
              ),
            ),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin memutuskan koneksi sesi Hunter dan keluar dari Sistem?',
          style: LevMaxTheme.mono(fontSize: 11, color: LevMaxTheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('BATAL', style: LevMaxTheme.mono(color: LevMaxTheme.outline)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await UserInfo.logout();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: Text(
              'LOGOUT',
              style: LevMaxTheme.mono(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // BUILD UTAMA (SCAFFOLD HUD SOLO LEVELING)
  // ============================================================================
  @override
  Widget build(BuildContext context) {
    // ATURAN 1: PENALTY GUARD CHECK
    if (widget.player.isPenaltyActive) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F131D),
        body: Center(
          child: CircularProgressIndicator(color: LevMaxTheme.hpRed),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F131D),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // KOMPONEN 1: ADVANCED STATUS WINDOW (ATRIBUT RPG)
              _buildAdvancedStatusWindow(),
              const SizedBox(height: 14),

              // KOMPONEN 2: SERVER RESET COUNTDOWN & MULTI-TIMEZONE STRIP
              _buildServerResetAndMultiTimezoneStrip(),
              const SizedBox(height: 16),

              // KOMPONEN 3: SEARCH, FILTER CHIPS, & MYSTERY KEY
              _buildSearchFilterAndMysteryRow(),
              const SizedBox(height: 14),

              // KOMPONEN 4: REACTIVE QUEST FEED (VALUELISTENABLEBUILDER)
              _buildReactiveQuestFeed(),
              const SizedBox(height: 80), // Padding untuk Floating Action Buttons
            ],
          ),
        ),
      ),
      // KOMPONEN 6: FLOATING ACTION BUTTONS GANDA (ALARM & SYSTEM AI CHAT)
      floatingActionButton: _buildDualFloatingActionButtons(),
    );
  }

  // ============================================================================
  // KOMPONEN 1: ADVANCED STATUS WINDOW
  // ============================================================================
  Widget _buildAdvancedStatusWindow() {
    final player = widget.player;
    final double hpRatio = (player.hp / 100.0).clamp(0.0, 1.0);
    final double expRatio = (player.exp / 100.0).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1F2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00F0FF).withValues(alpha: 0.3),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00F0FF).withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Profile: Avatar, Nama, Level, Logout
          Row(
            children: [
              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F131D),
                  shape: BoxShape.circle,
                  border: Border.all(color: LevMaxTheme.primaryContainer, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    player.username.isNotEmpty ? player.username[0].toUpperCase() : 'H',
                    style: LevMaxTheme.headline(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: LevMaxTheme.primaryContainer,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Nama & Level
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            player.username.toUpperCase(),
                            style: LevMaxTheme.headline(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 1.0,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: LevMaxTheme.primaryContainer.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'RANK ${player.rank}',
                            style: LevMaxTheme.mono(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: LevMaxTheme.primaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'HUNTER LEVEL ${player.level} • ${player.rankTitle}',
                      style: LevMaxTheme.mono(
                        fontSize: 10,
                        color: LevMaxTheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              // Tombol Logout Power Merah
              IconButton(
                icon: const Icon(Icons.power_settings_new, color: Color(0xFFEF4444), size: 22),
                tooltip: 'Disconnect Hunter',
                onPressed: _confirmLogout,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Vitals Bar: HP & EXP
          // HP Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'HP (HEALTH POINTS)',
                style: LevMaxTheme.mono(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFEF4444),
                ),
              ),
              Text(
                '${player.hp}/100',
                style: LevMaxTheme.mono(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFEF4444),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: hpRatio,
              minHeight: 6,
              backgroundColor: const Color(0xFF0F131D),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFEF4444)),
            ),
          ),
          const SizedBox(height: 10),

          // EXP Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'EXP (EXPERIENCE)',
                style: LevMaxTheme.mono(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: LevMaxTheme.primaryContainer,
                ),
              ),
              Text(
                '${player.exp}/100',
                style: LevMaxTheme.mono(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: LevMaxTheme.primaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: expRatio,
              minHeight: 6,
              backgroundColor: const Color(0xFF0F131D),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00F0FF)),
            ),
          ),
          const SizedBox(height: 14),

          // Attributes Grid (STR, AGI, INT, CHA)
          Row(
            children: [
              _buildAttributeBox('STR', player.str, const Color(0xFFEF4444)),
              const SizedBox(width: 8),
              _buildAttributeBox('AGI', player.agi, const Color(0xFF65F2B5)),
              const SizedBox(width: 8),
              _buildAttributeBox('INT', player.intStat, const Color(0xFF00F0FF)),
              const SizedBox(width: 8),
              _buildAttributeBox('CHA', player.cha, const Color(0xFFC084FC)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttributeBox(String label, int value, Color glowColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0F131D),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: glowColor.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: glowColor.withValues(alpha: 0.15),
              blurRadius: 6,
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              label,
              style: LevMaxTheme.mono(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: glowColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$value',
              style: LevMaxTheme.headline(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // KOMPONEN 2: SERVER RESET COUNTDOWN & MULTI-TIMEZONE STRIP
  // ============================================================================
  Widget _buildServerResetAndMultiTimezoneStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF171B26),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E2638)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Atas: SYSTEM RESET IN & Jam Besar (Zero Lag)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFB4AB),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'SYSTEM RESET IN:',
                    style: LevMaxTheme.mono(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF849495),
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              ValueListenableBuilder<String>(
                valueListenable: _resetCountdownNotifier,
                builder: (context, countdown, _) {
                  return Text(
                    countdown,
                    style: LevMaxTheme.mono(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFFFB4AB),
                      letterSpacing: 1.5,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(color: Color(0xFF1E2638), height: 1),
          const SizedBox(height: 6),

          // Bawah: 4 Zona Waktu (WIB | WITA | WIT | LND)
          ValueListenableBuilder<String>(
            valueListenable: _timezoneStripNotifier,
            builder: (context, timezones, _) {
              return Text(
                timezones,
                style: LevMaxTheme.mono(
                  fontSize: 10,
                  color: const Color(0xFF849495),
                  letterSpacing: 0.8,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // KOMPONEN 3: SEARCH, FILTER CHIPS, & MYSTERY KEY
  // ============================================================================
  Widget _buildSearchFilterAndMysteryRow() {
    final questBox = Hive.box<QuestModel>(HiveBoxes.questBox);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Input Kustom
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF0A0E18),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF1E2638)),
          ),
          child: TextField(
            controller: _searchController,
            style: LevMaxTheme.mono(fontSize: 12, color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search quest directives...',
              hintStyle: LevMaxTheme.mono(fontSize: 12, color: LevMaxTheme.outline),
              prefixIcon: const Icon(Icons.search, color: LevMaxTheme.outline, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Filter Chips Row + Mystery Key Button
        ValueListenableBuilder<Box<QuestModel>>(
          valueListenable: questBox.listenable(),
          builder: (context, box, _) {
            final allQuests = box.values.toList();
            final bool isMysteryUnlocked = _isMysteryQuestUnlocked(allQuests);

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ..._categories.map((cat) {
                    final bool isSelected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(cat),
                        selected: isSelected,
                        labelStyle: LevMaxTheme.mono(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.black : LevMaxTheme.onSurfaceVariant,
                        ),
                        backgroundColor: const Color(0xFF171B26),
                        selectedColor: LevMaxTheme.primaryContainer,
                        side: BorderSide(
                          color: isSelected
                              ? LevMaxTheme.primaryContainer
                              : const Color(0xFF1E2638),
                        ),
                        onSelected: (_) {
                          setState(() {
                            _selectedCategory = cat;
                          });
                        },
                      ),
                    );
                  }),

                  // Tombol Mystery Quest di ujung kanan
                  const SizedBox(width: 4),
                  Opacity(
                    opacity: isMysteryUnlocked ? 1.0 : 0.4,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (!isMysteryUnlocked) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: const Color(0xFF131826),
                              content: Text(
                                'Selesaikan misi harian terlebih dahulu!',
                                style: LevMaxTheme.mono(
                                  color: const Color(0xFFFFB4AB),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        } else {
                          _openMysteryQuestModal();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6001D1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: isMysteryUnlocked
                                ? const Color(0xFFD2BBFF)
                                : Colors.transparent,
                            width: 1.2,
                          ),
                        ),
                        elevation: isMysteryUnlocked ? 6 : 0,
                      ),
                      icon: const Icon(Icons.help_outline, size: 16),
                      label: Text(
                        'MYSTERY',
                        style: LevMaxTheme.mono(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // ============================================================================
  // KOMPONEN 4: REACTIVE QUEST FEED (VALUELISTENABLEBUILDER)
  // ============================================================================
  Widget _buildReactiveQuestFeed() {
    final questBox = Hive.box<QuestModel>(HiveBoxes.questBox);

    return ValueListenableBuilder<Box<QuestModel>>(
      valueListenable: questBox.listenable(),
      builder: (context, box, _) {
        var quests = box.values.toList();

        // Filter berdasarkan kategori
        if (_selectedCategory != 'All') {
          quests = quests
              .where((q) =>
                  q.category.toLowerCase() == _selectedCategory.toLowerCase())
              .toList();
        }

        // Filter berdasarkan pencarian
        if (_searchQuery.isNotEmpty) {
          quests = quests
              .where((q) =>
                  q.title.toLowerCase().contains(_searchQuery) ||
                  q.description.toLowerCase().contains(_searchQuery))
              .toList();
        }

        if (quests.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 40),
            alignment: Alignment.center,
            child: Column(
              children: [
                const Icon(Icons.shield_moon, color: LevMaxTheme.outline, size: 40),
                const SizedBox(height: 10),
                Text(
                  'NO QUEST DIRECTIVES FOUND',
                  style: LevMaxTheme.mono(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: LevMaxTheme.outline,
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: quests.map((quest) => _buildQuestCard(quest)).toList(),
        );
      },
    );
  }

  Widget _buildQuestCard(QuestModel quest) {
    Color accentColor;
    String actionLabel;
    IconData actionIcon;
    final cat = quest.category.toLowerCase();

    if (cat.contains('workout')) {
      accentColor = const Color(0xFF00F0FF); // Cyan
      actionLabel = quest.isCompleted ? 'COMPLETED' : 'CAMERA TRIAL';
      actionIcon = quest.isCompleted ? Icons.check_circle : Icons.camera_alt;
    } else if (cat.contains('cardio')) {
      accentColor = const Color(0xFF65F2B5); // Mint
      actionLabel = quest.isCompleted ? 'COMPLETED' : 'GPS TRACK';
      actionIcon = quest.isCompleted ? Icons.check_circle : Icons.navigation;
    } else if (cat.contains('study') || cat.contains('work')) {
      accentColor = const Color(0xFFC084FC); // Lavender
      actionLabel = quest.isCompleted ? 'COMPLETED' : 'INITIATE TRIVIA';
      actionIcon = quest.isCompleted ? Icons.check_circle : Icons.psychology;
    } else {
      accentColor = const Color(0xFFF472B6); // Pink Appearance
      actionLabel = quest.isCompleted ? 'COMPLETED' : 'ROUTINE CHECK';
      actionIcon = quest.isCompleted ? Icons.check_circle : Icons.spa;
    }

    final double progress = quest.targetValue > 0
        ? (quest.currentValue / quest.targetValue).clamp(0.0, 1.0)
        : (quest.isCompleted ? 1.0 : 0.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1F2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: quest.isCompleted
              ? const Color(0xFF262A35)
              : accentColor.withValues(alpha: 0.3),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Garis Aksen Neon Kiri
              Container(
                width: 4,
                color: quest.isCompleted ? LevMaxTheme.outline : accentColor,
              ),

              // Konten Kartu
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Kategori & Reward
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              quest.category.toUpperCase(),
                              style: LevMaxTheme.mono(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: accentColor,
                              ),
                            ),
                          ),
                          Text(
                            '+${quest.expReward} EXP • +${quest.goldReward}G',
                            style: LevMaxTheme.mono(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: LevMaxTheme.tertiaryFixed,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Judul Quest
                      Text(
                        quest.title,
                        style: LevMaxTheme.headline(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: quest.isCompleted
                              ? LevMaxTheme.onSurfaceVariant
                              : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),

                      // Deskripsi
                      Text(
                        quest.description,
                        style: LevMaxTheme.mono(
                          fontSize: 10,
                          color: LevMaxTheme.outline,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Progress Bar & Tombol Action
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${quest.currentValue}/${quest.targetValue} ${quest.unit}',
                                  style: LevMaxTheme.mono(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 4,
                                    backgroundColor: const Color(0xFF0F131D),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      quest.isCompleted
                                          ? LevMaxTheme.outline
                                          : accentColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Tombol Action Sesuai Kategori
                          ElevatedButton.icon(
                            onPressed: quest.isCompleted
                                ? null
                                : () => _handleQuestAction(quest),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentColor,
                              foregroundColor: Colors.black,
                              disabledBackgroundColor: const Color(0xFF262A35),
                              disabledForegroundColor: LevMaxTheme.outline,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: quest.isCompleted ? 0 : 4,
                            ),
                            icon: Icon(actionIcon, size: 14),
                            label: Text(
                              actionLabel,
                              style: LevMaxTheme.mono(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
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
        ),
      ),
    );
  }

  // ============================================================================
  // ATURAN 4: ROUTING SENSOR SESUAI KATEGORI
  // ============================================================================
  void _handleQuestAction(QuestModel quest) {
    final cat = quest.category.toLowerCase();

    if (cat.contains('workout')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SensorWorkoutPage(
            quest: quest,
            player: widget.player,
            onQuestCompleted: () => _completeQuest(quest),
          ),
        ),
      );
    } else if (cat.contains('cardio')) {
      _openCardioGpsModal(quest);
    } else if (cat.contains('study') || cat.contains('work')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SensorStudyPage(
            quest: quest,
            player: widget.player,
            onQuestCompleted: () => _completeQuest(quest),
          ),
        ),
      );
    } else if (cat.contains('appearance') || cat.contains('skincare')) {
      _openAppearanceBottomSheet(quest);
    }
  }

  // ============================================================================
  // KOMPONEN 6: FLOATING ACTION BUTTONS GANDA (ALARM & AI SYSTEM CHAT)
  // ============================================================================
  Widget _buildDualFloatingActionButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // 1. Tombol Alarm / Pengingat (Kuning Emas, Mini)
        FloatingActionButton.small(
          heroTag: 'fab_alarm',
          backgroundColor: LevMaxTheme.amberGold,
          onPressed: _openAlarmDialog,
          tooltip: 'Set Alarm / Reminder',
          child: const Icon(Icons.alarm, color: Colors.black, size: 20),
        ),
        const SizedBox(height: 10),

        // 2. Tombol Chat AI "The System" (Cyan, Besar, Glowing)
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: LevMaxTheme.primaryContainer.withValues(alpha: 0.4),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: FloatingActionButton(
            heroTag: 'fab_ai_system',
            backgroundColor: LevMaxTheme.primaryContainer,
            onPressed: () {
              SystemAiChatModal.show(context, player: widget.player);
            },
            tooltip: 'The System AI Directive',
            child: const Icon(Icons.smart_toy, color: Colors.black, size: 26),
          ),
        ),
      ],
    );
  }
}
