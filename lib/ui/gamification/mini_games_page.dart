// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/ui/gamification/mini_games_page.dart
// Deskripsi: Halaman Utama Mini-Game Hub / Training Ground (Prompt 11)
//            1. Arcade Header & Gold Telemetry (Bind Hive & User Model)
//            2. Daily Cap Tracker (0/1 CLAIMED vs 1/1 CLAIMED)
//            3. Game Selection Card "Mana Core Stabilization" (Gyroscope Game)
//            4. Navigation Modal / Fullscreen ke GyroBalanceGamePage
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../helpers/levmax_theme.dart';
import '../../models/user_model.dart';
import '../../services/minigame_service.dart';
import '../../services/supabase_api_service.dart';
import 'games/gyro_balance_game.dart';

class MiniGamesPage extends StatefulWidget {
  final UserModel? player;
  final VoidCallback? onPlayerUpdated;

  const MiniGamesPage({
    super.key,
    this.player,
    this.onPlayerUpdated,
  });

  @override
  State<MiniGamesPage> createState() => _MiniGamesPageState();
}

class _MiniGamesPageState extends State<MiniGamesPage>
    with SingleTickerProviderStateMixin {
  late UserModel _player;
  bool _isClaimedToday = false;
  late AnimationController _pingController;
  late Animation<double> _pingAnimation;

  @override
  void initState() {
    super.initState();
    _player = widget.player ??
        SupabaseApiService.getPlayerCache() ??
        UserModel.initial(id: 1, username: 'Hunter', email: '');

    _isClaimedToday = MinigameService.isDailyRewardClaimed();

    // Animasi Ping Indicator Kuning
    _pingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pingAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pingController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pingController.dispose();
    super.dispose();
  }

  void _refreshPlayerData() {
    final cached = SupabaseApiService.getPlayerCache();
    if (cached != null && mounted) {
      setState(() {
        _player = cached;
        _isClaimedToday = MinigameService.isDailyRewardClaimed();
      });
    }
    widget.onPlayerUpdated?.call();
  }

  void _openGyroGame() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GyroBalanceGamePage(
          player: _player,
          onPlayerUpdated: _refreshPlayerData,
        ),
      ),
    ).then((_) => _refreshPlayerData());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F131D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F131D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: LevMaxTheme.onSurfaceVariant, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'TRAINING GROUND',
          style: LevMaxTheme.headline(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: LevMaxTheme.amberGold,
            letterSpacing: 1.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: LevMaxTheme.primaryContainer, size: 20),
            onPressed: _refreshPlayerData,
            tooltip: 'Refresh Status',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ==================================================================
            // KOMPONEN 1: ARCADE HEADER & GOLD TELEMETRY
            // ==================================================================
            _buildArcadeHeader(),
            const SizedBox(height: 14),

            // Telemetry Card (Daily Cap Status & Vault Balance)
            _buildTelemetryCard(),
            const SizedBox(height: 20),

            // ==================================================================
            // KOMPONEN 2: GAME SELECTION CAROUSEL / CARDS
            // ==================================================================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'SELECT PROTOCOL',
                  style: LevMaxTheme.mono(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: LevMaxTheme.onSurfaceVariant,
                    letterSpacing: 1.0,
                  ),
                ),
                Text(
                  'SENSORS: ACTIVE',
                  style: LevMaxTheme.mono(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: LevMaxTheme.tertiaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // GAME 1 CARD: "MANA CORE STABILIZATION" (GYROSCOPE GAME)
            _buildGyroGameCard(),
            const SizedBox(height: 16),

            // GAME 2 CARD: "SHADOW AGILITY TRIAL" (PHASE 2 - LOCKED)
            _buildShadowAgilityCard(),
            const SizedBox(height: 24),

            // ==================================================================
            // KOMPONEN 3: ARCADE RULES & SYSTEM GUIDELINES
            // ==================================================================
            _buildSystemGuidelinesCard(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // KOMPONEN 1A: ARCADE HEADER
  // ============================================================================
  Widget _buildArcadeHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Titik Kuning Animasi Ping + Label Tag
        Row(
          children: [
            FadeTransition(
              opacity: _pingAnimation,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFFBBF24),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x88FBBF24),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '[TRAINING GROUND // ARCADE]',
              style: LevMaxTheme.mono(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFFBBF24),
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Judul Utama Space Grotesk 24px Bold
        Text(
          'HUNTER MINI-GAMES',
          style: LevMaxTheme.headline(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: const Color(0xFFDFE2F1),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Latih refleks dan kestabilan sensorik Hunter untuk meraup reward koin emas harian.',
          style: LevMaxTheme.mono(
            fontSize: 11,
            color: const Color(0xFFB9CACB),
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // KOMPONEN 1B: TELEMETRY CARD (DAILY CAP & GOLD BALANCE)
  // ============================================================================
  Widget _buildTelemetryCard() {
    final formattedGold = NumberFormat('#,###', 'id_ID').format(_player.gold);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1F2A),
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          top: BorderSide(color: Color(0xFFFBBF24), width: 1.5),
          left: BorderSide(color: Color(0xFF1E293B)),
          right: BorderSide(color: Color(0xFF1E293B)),
          bottom: BorderSide(color: Color(0xFF1E293B)),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1AFBBF24),
            blurRadius: 16,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Kiri: Ikon Koin Emas + Current Balance
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0F131D),
                  border: Border.all(color: const Color(0xFFFBBF24), width: 1.2),
                ),
                child: const Center(
                  child: Icon(Icons.monetization_on, color: Color(0xFFFBBF24), size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CURRENT BALANCE',
                    style: LevMaxTheme.mono(fontSize: 9, color: LevMaxTheme.outline),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$formattedGold G',
                    style: LevMaxTheme.headline(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFFBBF24),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Kanan: Badge Daily Reward Cap
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _isClaimedToday
                  ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                  : const Color(0xFF65F2B5).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _isClaimedToday ? const Color(0xFFEF4444) : const Color(0xFF65F2B5),
                width: 1.0,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isClaimedToday ? Icons.lock_clock : Icons.check_circle_outline,
                  size: 13,
                  color: _isClaimedToday ? const Color(0xFFEF4444) : const Color(0xFF65F2B5),
                ),
                const SizedBox(width: 6),
                Text(
                  _isClaimedToday ? 'DAILY REWARD: 1/1 CLAIMED' : 'DAILY REWARD: 0/1 CLAIMED',
                  style: LevMaxTheme.mono(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: _isClaimedToday ? const Color(0xFFEF4444) : const Color(0xFF65F2B5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // KOMPONEN 2A: GAME 1 CARD - MANA CORE STABILIZATION (GYROSCOPE GAME)
  // ============================================================================
  Widget _buildGyroGameCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF171B26),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00F0FF).withValues(alpha: 0.4), width: 1.5),
        gradient: const RadialGradient(
          center: Alignment(-0.6, -0.6),
          radius: 1.2,
          colors: [
            Color(0x1A00F0FF),
            Color(0xFF171B26),
          ],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F00F0FF),
            blurRadius: 18,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ikon Gyroscope Besar dengan Cyan Glow
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F131D),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF00F0FF), width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x4D00F0FF),
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.screen_rotation,
                    color: Color(0xFF00F0FF),
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Judul & Badge Sensor
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0x2600F0FF),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0x6600F0FF)),
                          ),
                          child: Text(
                            'GYROSCOPE // SENSOR-BASED',
                            style: LevMaxTheme.mono(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF00F0FF),
                            ),
                          ),
                        ),
                        Text(
                          '15 SECONDS',
                          style: LevMaxTheme.mono(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: LevMaxTheme.tertiaryContainer,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Mana Core Stabilization',
                      style: LevMaxTheme.headline(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Deskripsi
          Text(
            'Seimbangkan Mana Core di titik pusat selama 15 detik menggunakan sensor kemiringan (Gyroscope) perangkatmu.',
            style: LevMaxTheme.mono(
              fontSize: 10.5,
              color: const Color(0xFFB9CACB),
            ),
          ),
          const SizedBox(height: 14),

          // Reward Label (Kuning Emas)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F131D),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFBBF24).withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.stars, color: Color(0xFFFBBF24), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'WIN REWARD: +50 GOLD',
                      style: LevMaxTheme.mono(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFFBBF24),
                      ),
                    ),
                  ],
                ),
                Text(
                  _isClaimedToday ? '(TRAINING MODE)' : '(DAILY DROP READY)',
                  style: LevMaxTheme.mono(
                    fontSize: 9,
                    color: _isClaimedToday ? LevMaxTheme.outline : LevMaxTheme.tertiaryContainer,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tombol CTA: [ INITIALIZE GAME ]
          ElevatedButton(
            onPressed: _openGyroGame,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00F0FF),
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 8,
              shadowColor: const Color(0x6600F0FF),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.play_arrow, color: Colors.black, size: 20),
                const SizedBox(width: 8),
                Text(
                  'INITIALIZE GAME',
                  style: LevMaxTheme.headline(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // KOMPONEN 2B: GAME 2 CARD - SHADOW AGILITY TRIAL (COMING SOON)
  // ============================================================================
  Widget _buildShadowAgilityCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF171B26),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
        gradient: const RadialGradient(
          center: Alignment(-0.6, -0.6),
          radius: 1.2,
          colors: [
            Color(0x1A7C3AED),
            Color(0xFF171B26),
          ],
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F131D),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF6B21A8)),
                ),
                child: const Center(
                  child: Icon(Icons.flash_on, color: Color(0xFFC084FC), size: 24),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0x266B21A8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'REFLEX // TOUCH REACTION',
                        style: LevMaxTheme.mono(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFC084FC),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Shadow Agility Reaction',
                      style: LevMaxTheme.headline(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Uji kecepatan visual neural Hunter dalam mendeteksi anomali bayangan dalam sepersekian detik.',
            style: LevMaxTheme.mono(fontSize: 10.5, color: LevMaxTheme.outline),
          ),
          const SizedBox(height: 14),

          // Tombol Disabled
          OutlinedButton(
            onPressed: null,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF262A35)),
              minimumSize: const Size(double.infinity, 42),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              'LOCKED // COMING SOON',
              style: LevMaxTheme.mono(fontSize: 11, color: Colors.white24),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // KOMPONEN 3: ARCADE RULES & SYSTEM GUIDELINES
  // ============================================================================
  Widget _buildSystemGuidelinesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131826),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: LevMaxTheme.primaryContainer, size: 18),
              const SizedBox(width: 8),
              Text(
                'ARCADE TRAINING PROTOCOL RULES',
                style: LevMaxTheme.mono(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: LevMaxTheme.primaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildRuleBullet('1. Daily Gold Cap:', 'Pemain berhak memperoleh +50 Gold satu kali (1x) dalam setiap 24 jam kalender.'),
          const SizedBox(height: 6),
          _buildRuleBullet('2. Training Mode:', 'Setelah reward harian diklaim, mini-game tetap dapat dimainkan tanpa batas kuota untuk melatih reflek Hunter.'),
          const SizedBox(height: 6),
          _buildRuleBullet('3. Ledger Notarization:', 'Setiap perolehan Gold resmi dicatat dan divalidasi ke dalam Blockchain Ledger lokal.'),
        ],
      ),
    );
  }

  Widget _buildRuleBullet(String boldPrefix, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('• ', style: LevMaxTheme.mono(fontSize: 10, color: LevMaxTheme.primaryContainer)),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: LevMaxTheme.mono(fontSize: 9.5, color: LevMaxTheme.onSurfaceVariant),
              children: [
                TextSpan(
                  text: '$boldPrefix ',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                TextSpan(text: text),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
