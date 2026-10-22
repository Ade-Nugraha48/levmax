// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/main.dart
// Deskripsi: Titik Masuk Utama Aplikasi (Tahap 1) - Inisialisasi Hive NoSQL,
//            TypeAdapter, Notification Service, Validasi Sesi 1 Jam, & Tema Solo Leveling.
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers/boxes.dart';
import 'helpers/user_info.dart';
import 'models/quest_model.dart';
import 'models/block_model.dart';
import 'models/feedback_model.dart';
import 'services/notification_service.dart';
import 'services/blockchain_service.dart';
import 'services/supabase_api_service.dart';
import 'ui/auth/login_page.dart';
import 'ui/auth/register_page.dart';
import 'ui/onboarding/onboarding_page.dart';
import 'ui/main_navigation_page.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'ui/gamification/penalty_game_page.dart';
import 'ui/gamification/mini_games_page.dart';
import 'ui/shop/shop_page.dart';
import 'ui/penalty/game_over_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi Environment Variables (.env)
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('[main] Warning: .env file not found or failed to load: $e');
  }

  // Kunci orientasi layar ke Portrait agar UI stabil
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Atur warna status bar transparan dengan ikon terang
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0A0E1A),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Inisialisasi Lapisan 3 DB: Supabase Cloud Database (Backend Online)
  try {
    await Supabase.initialize(
      url: SupabaseApiService.supabaseUrl,
      publishableKey: SupabaseApiService.supabaseAnonKey,
    );
  } catch (e) {
    debugPrint('Supabase initialization error: $e');
  }

  // 1. Inisialisasi Lapisan 2 DB: Hive NoSQL
  await Hive.initFlutter();

  // 2. Registrasi TypeAdapter Manual (Bekerja langsung tanpa build_runner)
  Hive.registerAdapter(QuestAdapter());
  Hive.registerAdapter(BlockAdapter());
  Hive.registerAdapter(FeedbackAdapter());

  // 3. Membuka Box Hive (Arsitektur Baru: authBox, questCacheBox, alarmBox, aiChatBox)
  await HiveBoxes.openAllBoxes();
  if (!Hive.isBoxOpen(HiveBoxes.questBox)) {
    await Hive.openBox<QuestModel>(HiveBoxes.questBox);
  }
  if (!Hive.isBoxOpen(HiveBoxes.blockchainBox)) {
    await Hive.openBox<BlockModel>(HiveBoxes.blockchainBox);
  }
  if (!Hive.isBoxOpen(HiveBoxes.feedbackBox)) {
    await Hive.openBox<FeedbackModel>(HiveBoxes.feedbackBox);
  }

  // 4. Inisialisasi Genesis Block Blockchain jika belum ada
  await BlockchainService.ensureGenesisBlock();

  // 5. Inisialisasi Notifikasi Lokal (FR-6.2)
  await NotificationService.initialize();

  // 6. Validasi Sesi SharedPreferences (Auto-Logout jika inaktif > 60 menit)
  final isSessionExpired = await UserInfo.checkSessionTimeout();
  if (isSessionExpired) {
    await UserInfo.logout();
  }

  runApp(const LevMaxApp());
}

class LevMaxApp extends StatelessWidget {
  const LevMaxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LevMax: Solo Leveling Lifestyle RPG',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0E1A),
        primaryColor: const Color(0xFF00E5FF),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFF7B1FA2),
          surface: Color(0xFF131B2E),
          error: Color(0xFFFF1744),
          onPrimary: Colors.black,
          onSecondary: Colors.white,
          onSurface: Colors.white,
        ),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0A0E1A),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Color(0xFF00E5FF),
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
          iconTheme: IconThemeData(color: Color(0xFF00E5FF)),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF131B2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF1E293B), width: 1),
          ),
          elevation: 4,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00E5FF),
            foregroundColor: Colors.black,
            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        ),
      ),
      home: const SplashScreen(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/onboarding': (context) => const OnboardingPage(),
        '/main': (context) => const MainNavigationPage(),
        '/register': (context) => const RegisterPage(),
        '/game_over': (context) => const GameOverPage(),
        '/penalty': (context) => const PenaltyGamePage(),
        '/mini_games': (context) => const MiniGamesPage(),
        '/mini-games': (context) => const MiniGamesPage(),
        '/shop': (context) => const ShopPage(),
      },
    );
  }
}

/// ==============================================================================
/// SPLASH SCREEN & AUTH GATEWAY (TAHAP 1)
/// Memvalidasi status autentikasi, sesi aktif, dan biometrik
/// ==============================================================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _glowAnimation;
  final String _statusMessage = 'MENGINISIALISASI SISTEM...';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    _checkAuthAndNavigate();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _checkAuthAndNavigate() async {
    await Future.delayed(const Duration(milliseconds: 1500));

    // Periksa apakah sesi kedaluwarsa (> 60 menit) atau proteksi biometrik aktif
    final isExpired = await UserInfo.checkSessionTimeout();
    final isLoggedIn = await UserInfo.getLoginStatus();
    final isBiometricEnabled = await UserInfo.getBiometricEnabled();

    if (!mounted) return;

    // Jika belum login, sesi kedaluwarsa, atau proteksi biometrik aktif:
    // Arahkan ke Menu Autentikasi (LoginPage) yang ramah & fleksibel.
    // Pengguna memiliki kebebasan penuh: login password, klik Face ID, atau klik Fingerprint.
    if (!isLoggedIn || isExpired || isBiometricEnabled) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
      return;
    }

    // Periksa status onboarding
    final isOnboarded = await UserInfo.getIsOnboarded();
    if (!mounted) return;

    if (!isOnboarded) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingPage()),
      );
    } else {
      // Periksa apakah HP <= 0
      final player = SupabaseApiService.getPlayerCache();
      if (player != null && player.hp <= 0) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const GameOverPage()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigationPage()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo & Aura Animasi Solo Leveling
                AnimatedBuilder(
                  animation: _glowAnimation,
                  builder: (context, child) {
                    return Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF131B2E),
                        border: Border.all(
                          color: const Color(0xFF00E5FF)
                              .withValues(alpha: _glowAnimation.value),
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00E5FF)
                                .withValues(alpha: _glowAnimation.value * 0.6),
                            blurRadius: 30,
                            spreadRadius: 8,
                          ),
                          BoxShadow(
                            color: const Color(0xFF7B1FA2)
                                .withValues(alpha: _glowAnimation.value * 0.4),
                            blurRadius: 40,
                            spreadRadius: 12,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.bolt,
                        size: 72,
                        color: Color(0xFF00E5FF),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 36),

                // Judul Aplikasi
                const Text(
                  'LEVMAX',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 6.0,
                    color: Color(0xFF00E5FF),
                  ),
                ),
                const SizedBox(height: 8),

                // Subtitle Solo Leveling
                Text(
                  'SOLO LEVELING LIFESTYLE RPG',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.5,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 48),

                // Indikator Progres Sistem
                const SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
                  ),
                ),
                const SizedBox(height: 24),

                // Pesan Status Sistem
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131B2E),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                  child: Text(
                    _statusMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.0,
                      color: Color(0xFF00E5FF),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
