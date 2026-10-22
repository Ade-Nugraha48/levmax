// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/ui/qa_debug_panel.dart
// Deskripsi: Monarch's God Mode (QA Debug & UAS Presentation Override Panel)
//            Fitur Eksklusif Penguji/Auditor untuk Menguji Seluruh Logika Game
//            secara Real-Time tanpa Menunggu Jam 21:00 atau Siklus Reset 24 Jam.
// ==============================================================================

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../helpers/boxes.dart';
import '../helpers/debug_config.dart';
import '../helpers/game_rules.dart';
import '../helpers/levmax_theme.dart';
import '../models/quest_model.dart';
import '../models/user_model.dart';
import '../services/blockchain_service.dart';
import '../services/minigame_service.dart';
import '../services/supabase_api_service.dart';
import 'gamification/penalty_game_page.dart';

class QaDebugPanel extends StatefulWidget {
  final UserModel? player;
  final VoidCallback? onUpdated;

  const QaDebugPanel({super.key, this.player, this.onUpdated});

  @override
  State<QaDebugPanel> createState() => _QaDebugPanelState();
}

class _QaDebugPanelState extends State<QaDebugPanel> {
  late UserModel _player;
  bool _isLoading = false;
  final List<String> _consoleLogs = [];
  final ScrollController _logScrollController = ScrollController();

  // Warna Palet Hazard Admin Terminal
  static const Color hazardBg = Color(0xFF0A0E17);
  static const Color hazardSurface = Color(0xFF111827);
  static const Color hazardCard = Color(0xFF161F30);
  static const Color hazardRed = Color(0xFFEF4444);
  static const Color hazardYellow = Color(0xFFFBBF24);
  static const Color hazardGreen = Color(0xFF10B981);
  static const Color hazardCyan = Color(0xFF00E5FF);
  static const Color hazardBorder = Color(0xFF2E3B52);

  @override
  void initState() {
    super.initState();
    _loadInitialPlayer();
    _addLog('SYS_INIT: Monarch QA God Mode Console initialized.');
    _addLog(
      'SECURITY: Operator credentials verified (Ade Nugraha - UAS Demo).',
    );
    _addLog(
      'TARGET_TIME: System time is ${DateFormat('HH:mm:ss').format(DateTime.now())}.',
    );
  }

  @override
  void dispose() {
    _logScrollController.dispose();
    super.dispose();
  }

  void _loadInitialPlayer() {
    if (widget.player != null) {
      _player = widget.player!;
    } else {
      _player =
          SupabaseApiService.getPlayerCache() ??
          UserModel.initial(
            id: 'qa_monarch_01',
            username: 'Sung Jin-Woo',
            email: 'monarch@shadow.realm',
          );
    }
  }

  void _addLog(String message) {
    final timestamp = DateFormat('HH:mm:ss').format(DateTime.now());
    setState(() {
      _consoleLogs.add('[$timestamp] $message');
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollController.hasClients) {
        _logScrollController.animateTo(
          _logScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ============================================================================
  // 1. INJECT 10,000 GOLD
  // ============================================================================
  Future<void> _injectGold() async {
    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();
    _addLog('OVERRIDE_EXEC: Injecting +10,000 Gold...');

    try {
      final newGold = _player.gold + 10000;
      final updated = _player.copyWith(gold: newGold);

      await SupabaseApiService.savePlayerCache(updated);
      try {
        await SupabaseApiService.updateUser(updated);
      } catch (e) {
        _addLog('CLOUD_WARN: Supabase sync warning: $e');
      }

      await BlockchainService.addBlock(
        'QA_OVERRIDE: Injected +10,000 Gold into Player Treasury. Total: $newGold Gold.',
        userId: updated.id,
      );

      setState(() {
        _player = updated;
      });
      widget.onUpdated?.call();

      _addLog(
        'SUCCESS: +10,000 Gold injected! New Gold Balance: $newGold Gold.',
      );
      _showSnackbar('SUKSES: +10,000 Gold berhasil diinjeksikan!', hazardGreen);
    } catch (err) {
      _addLog('ERROR: Inject gold failed: $err');
      _showSnackbar('Gagal inject gold: $err', hazardRed);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ============================================================================
  // 2. TRIGGER PENALTY MODE
  // ============================================================================
  Future<void> _triggerPenaltyMode() async {
    setState(() => _isLoading = true);
    HapticFeedback.heavyImpact();
    _addLog('OVERRIDE_EXEC: Forcing is_penalty_active = true...');

    try {
      final updated = _player.copyWith(isPenaltyActive: true);
      await SupabaseApiService.savePlayerCache(updated);

      try {
        await SupabaseApiService.updateUser(updated);
      } catch (_) {}

      await BlockchainService.addBlock(
        'QA_OVERRIDE: Force Triggered System Penalty Zone.',
        userId: updated.id,
      );

      setState(() {
        _player = updated;
      });
      widget.onUpdated?.call();

      _addLog(
        'ALERT: Penalty Zone activated! Redirecting to Penalty Mini-Game...',
      );
      _showSnackbar('PENALTY DIAKTIFKAN! Membuka Penalty Zone...', hazardRed);

      await Future.delayed(const Duration(milliseconds: 600));

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PenaltyGamePage()),
      ).then((_) {
        // Refresh status saat kembali dari game
        _refreshPlayerFromCache();
      });
    } catch (err) {
      _addLog('ERROR: Trigger penalty failed: $err');
      _showSnackbar('Gagal aktifkan penalti: $err', hazardRed);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ============================================================================
  // 3. BYPASS TIME: FORCE 21:00
  // ============================================================================
  void _toggleTimeBypass() {
    HapticFeedback.selectionClick();
    setState(() {
      DebugConfig.forceHour21 = !DebugConfig.forceHour21;
    });

    if (DebugConfig.forceHour21) {
      _addLog('TIME_BYPASS: ON. System time mocked to >= 21:00 Server Time.');
      _showSnackbar(
        'BYPASS WAKTU AKTIF: Jam sistem dipaksa 21:00!',
        hazardYellow,
      );
    } else {
      _addLog(
        'TIME_BYPASS: OFF. Restored to actual device time (${DateTime.now().hour}:00).',
      );
      _showSnackbar(
        'BYPASS WAKTU NONAKTIF: Mengikuti jam asli perangkat.',
        hazardCyan,
      );
    }
  }

  // ============================================================================
  // 4. RESET DAILY LIMITS
  // ============================================================================
  Future<void> _resetDailyLimits() async {
    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();
    _addLog(
      'OVERRIDE_EXEC: Resetting daily mini-game reward and quest states...',
    );

    try {
      // 1. Reset flag daily reward mini-game di Hive playerBox
      try {
        final box = Hive.box(HiveBoxes.playerBox);
        await box.put(MinigameService.keyDailyRewardClaimed, false);
        await box.put(MinigameService.keyDailyRewardDate, '');
        _addLog(
          'RESET_HIVE: Cleared minigame_gyro_reward_claimed in playerBox.',
        );
      } catch (e) {
        _addLog('RESET_WARN: Hive playerBox reset note: $e');
      }

      // 2. Reset status quest harian di questBox
      try {
        final questBox = Hive.box<QuestModel>(HiveBoxes.questBox);
        int resetCount = 0;
        for (int i = 0; i < questBox.length; i++) {
          final q = questBox.getAt(i);
          if (q != null && (q.isCompleted || q.currentValue > 0)) {
            final resetQuest = q.copyWith(isCompleted: false, currentValue: 0);
            await questBox.putAt(i, resetQuest);
            resetCount++;
          }
        }
        _addLog(
          'RESET_QUESTS: Restored $resetCount daily quests to pending state.',
        );
      } catch (e) {
        _addLog('RESET_WARN: Hive questBox reset note: $e');
      }

      _showSnackbar(
        'SUKSES: Limit harian mini-game dan quest direset!',
        hazardGreen,
      );
    } catch (err) {
      _addLog('ERROR: Reset daily limits failed: $err');
      _showSnackbar('Gagal reset daily limits: $err', hazardRed);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ============================================================================
  // 5. FORCE LEVEL UP
  // ============================================================================
  Future<void> _forceLevelUp() async {
    setState(() => _isLoading = true);
    HapticFeedback.heavyImpact();
    _addLog('OVERRIDE_EXEC: Executing Force Level Up protocol...');

    try {
      final currentRank = _player.rank.toUpperCase();
      final rankCfg = RankConfig.getConfig(currentRank);
      final nextRank = rankCfg.targetRank
          .split(' ')
          .first; // e.g. "D", "C", "B", "A", "S"

      final newLevel = _player.level + 1;
      final newRank = (rankCfg.targetRank != 'S (Uncapped)') ? nextRank : 'S';
      final newExp = max(0, RankConfig.getRequiredExp(newRank));

      final updated = _player.copyWith(
        level: newLevel,
        rank: newRank,
        exp: newExp,
        str: _player.str + 5,
        agi: _player.agi + 5,
        intStat: _player.intStat + 5,
        cha: _player.cha + 5,
        hp: min(100, _player.hp + 20),
      );

      await SupabaseApiService.savePlayerCache(updated);
      try {
        await SupabaseApiService.updateUser(updated);
      } catch (_) {}

      await BlockchainService.addBlock(
        'QA_OVERRIDE: Force Promoted Hunter to Rank $newRank (Level $newLevel)',
        userId: updated.id,
      );

      setState(() {
        _player = updated;
      });
      widget.onUpdated?.call();

      _addLog(
        'PROMOTION: Hunter successfully promoted to Rank $newRank (Level $newLevel)!',
      );
      _showLevelUpDialog(newRank, newLevel);
    } catch (err) {
      _addLog('ERROR: Force level up failed: $err');
      _showSnackbar('Gagal force level up: $err', hazardRed);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _refreshPlayerFromCache() {
    final cached = SupabaseApiService.getPlayerCache();
    if (cached != null) {
      setState(() {
        _player = cached;
      });
      _addLog('CACHE_REFRESH: Player stats reloaded from local Hive.');
    }
  }

  void _showSnackbar(String text, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: hazardSurface,
        content: Row(
          children: [
            Icon(Icons.terminal, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: LevMaxTheme.mono(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showLevelUpDialog(String newRank, int newLevel) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: hazardSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: hazardYellow, width: 2),
        ),
        title: const Row(
          children: [
            Icon(Icons.military_tech, color: hazardYellow, size: 28),
            SizedBox(width: 8),
            Text(
              'RANK PROMOTION!',
              style: TextStyle(
                fontFamily: 'Courier',
                fontWeight: FontWeight.w900,
                color: hazardYellow,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'HUNTER AWAKENING ASCENSION',
              style: LevMaxTheme.mono(fontSize: 11, color: Colors.white70),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: hazardCard,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: hazardBorder),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'LEVEL:',
                        style: LevMaxTheme.mono(
                          fontSize: 12,
                          color: Colors.white60,
                        ),
                      ),
                      Text(
                        '$newLevel',
                        style: LevMaxTheme.mono(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: hazardCyan,
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: hazardBorder, height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'NEW RANK:',
                        style: LevMaxTheme.mono(
                          fontSize: 12,
                          color: Colors.white60,
                        ),
                      ),
                      Text(
                        'RANK $newRank',
                        style: LevMaxTheme.mono(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: hazardYellow,
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: hazardBorder, height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ALL STATS:',
                        style: LevMaxTheme.mono(
                          fontSize: 12,
                          color: Colors.white60,
                        ),
                      ),
                      Text(
                        '+5 POINTS',
                        style: LevMaxTheme.mono(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: hazardGreen,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'ACKNOWLEDGE',
              style: LevMaxTheme.mono(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: hazardYellow,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isGyroClaimed = MinigameService.isDailyRewardClaimed();

    return Scaffold(
      backgroundColor: hazardBg,
      appBar: AppBar(
        backgroundColor: hazardSurface,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: hazardYellow),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: hazardRed.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: hazardRed, width: 1),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield, color: hazardRed, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'GOD MODE',
                    style: TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: hazardRed,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'QA AUDIT OVERRIDE',
                style: LevMaxTheme.headline(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 1.0,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Status',
            icon: const Icon(Icons.refresh, color: hazardCyan),
            onPressed: _refreshPlayerFromCache,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Konten Utama Bisa di-Scroll
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // HAZARD WARNING BANNER
                    _buildHazardWarningBanner(),
                    const SizedBox(height: 16),

                    // LIVE TELEMETRY DASHBOARD
                    _buildTelemetryCard(isGyroClaimed),
                    const SizedBox(height: 18),

                    // SECTION TITLE: OVERRIDE CONTROLS
                    Row(
                      children: [
                        const Icon(Icons.bolt, color: hazardYellow, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'SYSTEM OVERRIDE CONTROLS',
                          style: LevMaxTheme.headline(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: hazardYellow,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // TOMBOL 1: INJECT 10,000 GOLD
                    _buildOverrideButton(
                      title: 'INJECT 10,000 GOLD',
                      subtitle: 'Tambahkan 10.000 Gold instan untuk demo Blockchain Shop',
                      icon: Icons.monetization_on,
                      accentColor: hazardYellow,
                      isLoading: _isLoading,
                      onPressed: _injectGold,
                    ),
                    const SizedBox(height: 10),

                    // TOMBOL 2: TRIGGER PENALTY MODE
                    _buildOverrideButton(
                      title: 'TRIGGER PENALTY MODE',
                      subtitle: 'Set is_penalty_active = true dan lempar ke Poison Centipede',
                      icon: Icons.warning_amber_rounded,
                      accentColor: hazardRed,
                      isLoading: _isLoading,
                      onPressed: _triggerPenaltyMode,
                    ),
                    const SizedBox(height: 10),

                    // TOMBOL 3: BYPASS TIME FORCE 21:00
                    _buildOverrideButton(
                      title: DebugConfig.forceHour21
                          ? 'TIME BYPASS: ACTIVE [21:00 LOCKED]'
                          : 'BYPASS TIME: FORCE 21:00',
                      subtitle: 'Buka paksa submit Skincare Appearance Quest di siang hari',
                      icon: Icons.access_time_filled,
                      accentColor: DebugConfig.forceHour21
                          ? hazardGreen
                          : hazardCyan,
                      badgeText: DebugConfig.forceHour21 ? 'FORCED ON' : 'OFF',
                      badgeColor: DebugConfig.forceHour21
                          ? hazardGreen
                          : Colors.white38,
                      isLoading: false,
                      onPressed: _toggleTimeBypass,
                    ),
                    const SizedBox(height: 10),

                    // TOMBOL 4: RESET DAILY LIMITS
                    _buildOverrideButton(
                      title: 'RESET DAILY LIMITS',
                      subtitle: 'Reset reward mini-game 1x/hari dan reset pool quest hari ini',
                      icon: Icons.restore,
                      accentColor: const Color(0xFFA78BFA),
                      isLoading: _isLoading,
                      onPressed: _resetDailyLimits,
                    ),
                    const SizedBox(height: 10),

                    // TOMBOL 5: FORCE LEVEL UP
                    _buildOverrideButton(
                      title: 'FORCE LEVEL UP',
                      subtitle: 'Manipulasi EXP, promosikan Rank (+1) dan picu efek naik rank',
                      icon: Icons.military_tech,
                      accentColor: hazardGreen,
                      isLoading: _isLoading,
                      onPressed: _forceLevelUp,
                    ),
                  ],
                ),
              ),
            ),

            // LIVE CONSOLE TERMINAL OUTPUT (Bawah Layar)
            _buildLiveConsoleWindow(),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // WIDGET HELPER: HAZARD WARNING STRIPE BANNER
  // ============================================================================
  Widget _buildHazardWarningBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: hazardRed.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: hazardRed.withValues(alpha: 0.8), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.dangerous, color: hazardRed, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CONFIDENTIAL // UAS PRESENTATION TERMINAL',
                  style: TextStyle(
                    fontFamily: 'Courier',
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: hazardRed,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Menu ini disediakan eksklusif untuk demonstrasi di hadapan Dosen Penguji. '
                  'Perubahan state akan merefleksikan Hive lokal, Supabase Cloud, dan Blockchain Ledger secara simultan.',
                  style: LevMaxTheme.mono(fontSize: 10, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // WIDGET HELPER: LIVE TELEMETRY MONITOR CARD
  // ============================================================================
  Widget _buildTelemetryCard(bool isGyroClaimed) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hazardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: hazardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'LIVE TELEMETRY MONITOR',
                style: LevMaxTheme.mono(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: hazardCyan,
                  letterSpacing: 1.0,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: hazardGreen.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: hazardGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'ONLINE',
                      style: LevMaxTheme.mono(
                        fontSize: 9,
                        color: hazardGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(color: hazardBorder, height: 16),
          // Grid Telemetri
          Row(
            children: [
              Expanded(
                child: _buildTelemetryItem(
                  'HUNTER',
                  _player.username,
                  hazardCyan,
                ),
              ),
              Expanded(
                child: _buildTelemetryItem(
                  'RANK / LVL',
                  'Rank ${_player.rank} (Lv ${_player.level})',
                  hazardYellow,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildTelemetryItem(
                  'GOLD TREASURY',
                  '${_player.gold} G',
                  hazardYellow,
                ),
              ),
              Expanded(
                child: _buildTelemetryItem(
                  'HP / ATTRIBUTES',
                  '${_player.hp}% HP (STR:${_player.str} AGI:${_player.agi})',
                  hazardRed,
                ),
              ),
            ],
          ),
          const Divider(color: hazardBorder, height: 16),
          // Status Flags
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildStatusPill(
                label: 'PENALTY',
                isActive: _player.isPenaltyActive,
                activeText: 'ACTIVE (PUNISHED)',
                inactiveText: 'SAFE (CLEAR)',
                activeColor: hazardRed,
                inactiveColor: hazardGreen,
              ),
              _buildStatusPill(
                label: 'TIME LOCK',
                isActive: DebugConfig.isAppearanceUnlocked,
                activeText: 'UNLOCKED (>=21:00)',
                inactiveText: 'LOCKED (<21:00)',
                activeColor: hazardGreen,
                inactiveColor: hazardYellow,
              ),
              _buildStatusPill(
                label: 'MINI-GAME GOLD',
                isActive: isGyroClaimed,
                activeText: 'CLAIMED (LIMIT)',
                inactiveText: 'READY TO CLAIM',
                activeColor: Colors.white54,
                inactiveColor: hazardGreen,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryItem(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: LevMaxTheme.mono(fontSize: 9, color: Colors.white54),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: LevMaxTheme.mono(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildStatusPill({
    required String label,
    required bool isActive,
    required String activeText,
    required String inactiveText,
    required Color activeColor,
    required Color inactiveColor,
  }) {
    final color = isActive ? activeColor : inactiveColor;
    final text = isActive ? activeText : inactiveText;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1),
      ),
      child: Text(
        '$label: $text',
        style: TextStyle(
          fontFamily: 'Courier',
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  // ============================================================================
  // WIDGET HELPER: CUSTOM OVERRIDE BUTTON
  // ============================================================================
  Widget _buildOverrideButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required bool isLoading,
    required VoidCallback onPressed,
    String? badgeText,
    Color? badgeColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: hazardCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.4), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: isLoading ? null : onPressed,
          splashColor: accentColor.withValues(alpha: 0.2),
          highlightColor: accentColor.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.4),
                    ),
                  ),
                  child: isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: accentColor,
                          ),
                        )
                      : Icon(icon, color: accentColor, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontFamily: 'Courier',
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          if (badgeText != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: (badgeColor ?? accentColor).withValues(
                                  alpha: 0.2,
                                ),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: badgeColor ?? accentColor,
                                ),
                              ),
                              child: Text(
                                badgeText,
                                style: TextStyle(
                                  fontFamily: 'Courier',
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: badgeColor ?? accentColor,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: LevMaxTheme.mono(
                          fontSize: 10,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: Colors.white30,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // WIDGET HELPER: LIVE CONSOLE TERMINAL OUTPUT
  // ============================================================================
  Widget _buildLiveConsoleWindow() {
    return Container(
      height: 140,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF070A10),
        border: Border(top: BorderSide(color: hazardBorder, width: 1.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Console Header Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: const Color(0xFF0D121D),
            child: Row(
              children: [
                const Icon(Icons.code, color: hazardGreen, size: 14),
                const SizedBox(width: 6),
                const Text(
                  'TERMINAL LOG STREAM (REAL-TIME)',
                  style: TextStyle(
                    fontFamily: 'Courier',
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: hazardGreen,
                    letterSpacing: 1.0,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _consoleLogs.clear();
                      _addLog('SYS_RESET: Terminal log buffer cleared.');
                    });
                  },
                  child: const Text(
                    'CLEAR',
                    style: TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.white38,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Scrollable Log Content
          Expanded(
            child: ListView.builder(
              controller: _logScrollController,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _consoleLogs.length,
              itemBuilder: (context, index) {
                final log = _consoleLogs[index];
                Color logColor = hazardGreen;
                if (log.contains('ERROR:')) {
                  logColor = hazardRed;
                } else if (log.contains('ALERT:') || log.contains('OVERRIDE_EXEC:')) {
                  logColor = hazardYellow;
                } else if (log.contains('TIME_BYPASS:')) {
                  logColor = hazardCyan;
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    '> $log',
                    style: TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 10,
                      color: logColor,
                      height: 1.2,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
