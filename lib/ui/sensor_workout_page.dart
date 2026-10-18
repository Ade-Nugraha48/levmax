// Halaman Integrasi Sensor Accelerometer dan Gyroscope
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../helpers/boxes.dart';
import '../models/quest_model.dart';
import '../models/user_model.dart';
import '../services/supabase_api_service.dart';

class SensorWorkoutPage extends StatefulWidget {
  final UserModel player;

  const SensorWorkoutPage({super.key, required this.player});

  @override
  State<SensorWorkoutPage> createState() => _SensorWorkoutPageState();
}

class _SensorWorkoutPageState extends State<SensorWorkoutPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Stream Subscription Sensor
  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;

  // State Mode 1: Penghitung Repetisi Accelerometer
  int _repsCount = 0;
  bool _isWorkoutTracking = false;
  String _selectedWorkoutType = 'Push-up';
  bool _isDownPosition = false;
  double _lastAccZ = 0.0;

  // State Mode 2: Detektor Postur Gyroscope
  bool _isStudyTimerActive = false;
  int _studySeconds = 3000; // 50 Menit Deep Work
  Timer? _studyTimer;
  bool _isBadPostureDetected = false;
  double _currentPitch = 0.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _accelSubscription?.cancel();
    _gyroSubscription?.cancel();
    _studyTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  // ==========================================================================
  // MODE 1: ACCELEROMETER PENGHITUNG REPETISI PUSH-UP / SQUAT
  // ==========================================================================
  void _toggleWorkoutTracking() {
    if (_isWorkoutTracking) {
      _accelSubscription?.cancel();
      setState(() {
        _isWorkoutTracking = false;
      });
    } else {
      setState(() {
        _isWorkoutTracking = true;
        _repsCount = 0;
        _isDownPosition = false;
      });

      _accelSubscription = accelerometerEventStream().listen((event) {
        if (!mounted) return;

        final z = event.z;
        final deltaZ = (z - _lastAccZ).abs();
        _lastAccZ = z;

        // Deteksi gerakan turun dan naik pada sumbu Z
        if (!_isDownPosition && z < 4.0 && deltaZ > 1.5) {
          _isDownPosition = true;
        } else if (_isDownPosition && z > 8.0) {
          _isDownPosition = false;
          setState(() {
            _repsCount++;
          });
        }
      });
    }
  }

  // Menyimpan hasil repetisi sensor ke Daily Quest
  Future<void> _saveRepsToDailyQuest() async {
    if (_repsCount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum ada repetisi yang terhitung.')),
      );
      return;
    }

    final box = Hive.box<QuestModel>(HiveBoxes.questBox);
    QuestModel? targetQuest;

    for (final q in box.values) {
      if (q.category == 'Workout' && q.title.toLowerCase().contains(_selectedWorkoutType.toLowerCase())) {
        targetQuest = q;
        break;
      }
    }

    if (targetQuest != null) {
      targetQuest.currentValue = min(targetQuest.targetValue, targetQuest.currentValue + _repsCount);
      if (targetQuest.currentValue >= targetQuest.targetValue) {
        targetQuest.isCompleted = true;
      }
      await targetQuest.save();
      await SupabaseApiService.syncQuest(quest: targetQuest, userId: widget.player.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$_repsCount repetisi $_selectedWorkoutType ditambahkan ke Daily Quest!'),
            backgroundColor: const Color(0xFF00E5FF),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Daily Quest untuk $_selectedWorkoutType tidak ditemukan.')),
      );
    }
  }

  // ==========================================================================
  // MODE 2: GYROSCOPE PENDETEKSI POSTUR (NERD NECK DETECTOR)
  // ==========================================================================
  void _toggleStudyTimer() {
    if (_isStudyTimerActive) {
      _gyroSubscription?.cancel();
      _studyTimer?.cancel();
      setState(() {
        _isStudyTimerActive = false;
      });
    } else {
      setState(() {
        _isStudyTimerActive = true;
        _isBadPostureDetected = false;
      });

      // Timer countdown belajar 50 menit
      _studyTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        if (_studySeconds <= 1) {
          _studyTimer?.cancel();
          setState(() {
            _isStudyTimerActive = false;
          });
        } else {
          setState(() {
            _studySeconds--;
          });
        }
      });

      // Pemantauan sudut rotasi leher / kemiringan HP via Gyroscope
      _gyroSubscription = gyroscopeEventStream().listen((event) {
        if (!mounted) return;
        final x = event.x;
        _currentPitch = x;

        // Jika rotasi sumbu X menunjukkan kemiringan menunduk > 1.2 rad/s
        if (x.abs() > 1.2) {
          if (!_isBadPostureDetected) {
            setState(() {
              _isBadPostureDetected = true;
            });
          }
        } else {
          if (_isBadPostureDetected) {
            setState(() {
              _isBadPostureDetected = false;
            });
          }
        }
      });
    }
  }

  String _formatTimer(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        title: const Text('SENSOR DETECTOR (FR-5.1)'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF00E5FF),
          labelColor: const Color(0xFF00E5FF),
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.fitness_center), text: 'Accelerometer Reps'),
            Tab(icon: Icon(Icons.timer), text: 'Gyroscope Posture'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Accelerometer Repetisi
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131B2E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF00E5FF)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'PENGHITUNG OTOMATIS GERAKAN TUBUH',
                        style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Letakkan HP di lengan atau saku celana saat melakukan latihan. Sensor akan menghitung repetisi saat tubuh turun dan naik.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Pilihan Jenis Workout
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: ['Push-up', 'Squat'].map((type) {
                    final isSel = _selectedWorkoutType == type;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: ChoiceChip(
                        label: Text(type),
                        selected: isSel,
                        selectedColor: const Color(0xFF00E5FF),
                        onSelected: (val) {
                          if (val) {
                            setState(() {
                              _selectedWorkoutType = type;
                            });
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 30),

                // Counter Display
                Center(
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF131B2E),
                      border: Border.all(
                        color: _isWorkoutTracking ? const Color(0xFF00E5FF) : Colors.grey,
                        width: 3,
                      ),
                      boxShadow: [
                        if (_isWorkoutTracking)
                          BoxShadow(
                            color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                            blurRadius: 24,
                            spreadRadius: 6,
                          ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$_repsCount',
                          style: const TextStyle(
                            fontSize: 54,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF00E5FF),
                          ),
                        ),
                        Text(
                          'REPS $_selectedWorkoutType',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 36),

                // Tombol Mulai / Berhenti Tracking
                ElevatedButton(
                  onPressed: _toggleWorkoutTracking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isWorkoutTracking ? const Color(0xFFFF1744) : const Color(0xFF00E5FF),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    _isWorkoutTracking ? 'HENTIKAN PELACAKAN SENSOR' : 'MULAI PENGHITUNG SENSOR',
                    style: TextStyle(
                      color: _isWorkoutTracking ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Tombol Simpan ke Daily Quest
                OutlinedButton.icon(
                  onPressed: _repsCount > 0 ? _saveRepsToDailyQuest : null,
                  icon: const Icon(Icons.check_circle_outline, color: Color(0xFF00E5FF)),
                  label: const Text(
                    'SIMPAN KE DAILY QUEST',
                    style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF00E5FF)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ],
            ),
          ),

          // Tab 2: Gyroscope Postur (Nerd-Neck Detector)
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131B2E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF7B1FA2)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'PEMANTAU POSTUR LEHER (NERD-NECK)',
                        style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Sensor Gyroscope mendeteksi sudut kemiringan HP saat Anda fokus belajar atau bekerja untuk menjaga postur tubuh tetap tegap.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Peringatan Postur Menunduk
                if (_isBadPostureDetected) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF1744).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFF1744)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning, color: Color(0xFFFF1744), size: 28),
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PERINGATAN POSTUR MENUNDUK!',
                                style: TextStyle(
                                  color: Color(0xFFFF1744),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                'Tegakkan leher dan posisikan layar sejajar dengan mata Anda.',
                                style: TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Timer Display Deep Work
                Center(
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF131B2E),
                      border: Border.all(
                        color: _isBadPostureDetected ? const Color(0xFFFF1744) : const Color(0xFF00E5FF),
                        width: 3,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _formatTimer(_studySeconds),
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            color: _isBadPostureDetected ? const Color(0xFFFF1744) : Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'DEEP WORK FOCUS',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                        if (_isStudyTimerActive) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Kemiringan: ${_currentPitch.toStringAsFixed(2)} rad/s',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _isBadPostureDetected ? const Color(0xFFFF1744) : Colors.greenAccent,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 36),

                // Tombol Kontrol Timer
                ElevatedButton(
                  onPressed: _toggleStudyTimer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isStudyTimerActive ? const Color(0xFFFF1744) : const Color(0xFF00E5FF),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    _isStudyTimerActive ? 'HENTIKAN SESI FOKUS' : 'MULAI SESI FOKUS & POSTUR',
                    style: TextStyle(
                      color: _isStudyTimerActive ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
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
}
