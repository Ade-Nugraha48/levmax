// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/ui/tabs/dungeon_guild_tab.dart
// Deskripsi: Tab 2: Dungeon Map LBS, Guild Exchange & Blockchain Ledger (Prompt 3)
//            Fitur: Sub-Tab Switcher (Map, Guild & Time, Audit Log),
//            LBS Tactical Map, Multi-Currency Exchange, Multi-Timezone Clocks, & SHA-256 Ledger.
// ==============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../helpers/levmax_theme.dart';
import '../../models/block_model.dart';
import '../../models/user_model.dart';
import '../../services/blockchain_service.dart';
import '../../services/supabase_api_service.dart';
import 'dungeon_map_view.dart';

class DungeonGuildTab extends StatefulWidget {
  final UserModel player;
  final VoidCallback onPlayerUpdated;

  const DungeonGuildTab({
    super.key,
    required this.player,
    required this.onPlayerUpdated,
  });

  @override
  State<DungeonGuildTab> createState() => _DungeonGuildTabState();
}

class _DungeonGuildTabState extends State<DungeonGuildTab>
    with SingleTickerProviderStateMixin {
  // Sub-Tab Aktif: 'map' | 'guild' | 'audit'
  String _activeSubView = 'map';

  // Sub-View 2: Guild Exchange State
  late TextEditingController _goldInputController;
  int _selectedGoldAmount = 12500;

  // Sub-View 3: Real-Time Timer untuk Clocks & Radar Animation
  late AnimationController _pulseController;
  Timer? _clockTimer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _goldInputController = TextEditingController(
      text: widget.player.gold.toString(),
    );
    _selectedGoldAmount = widget.player.gold;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    // Timer Detak Jam Real-time (1 detik)
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _clockTimer?.cancel();
    _goldInputController.dispose();
    super.dispose();
  }

  // ============================================================================
  // TRANSAKSI GUILD CASHOUT & BLOCKCHAIN NOTARISASI
  // ============================================================================
  Future<void> _handleGuildCashout() async {
    final amount = int.tryParse(_goldInputController.text) ?? 0;
    if (amount <= 0 || amount > widget.player.gold) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: LevMaxTheme.surfaceContainer,
          behavior: SnackBarBehavior.floating,
          content: Text(
            'JUMLAH GOLD TIDAK VALID ATAU MELEBIHI SALDO VAULT',
            style: LevMaxTheme.mono(fontSize: 11, color: LevMaxTheme.hpRed),
          ),
        ),
      );
      return;
    }

    final idrValue = amount * 10;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LevMaxTheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: LevMaxTheme.amberGold, width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.monetization_on, color: LevMaxTheme.amberGold),
            const SizedBox(width: 8),
            Text(
              'KONFIRMASI CASHOUT',
              style: LevMaxTheme.headline(
                fontSize: 14,
                color: LevMaxTheme.amberGold,
              ),
            ),
          ],
        ),
        content: Text(
          'Cairkan $amount Gold menjadi Rp ${NumberFormat('#,###', 'id_ID').format(idrValue)} via Instant QRIS System?\n\nTransaksi akan dicatat permanen ke Blockchain Ledger.',
          style: LevMaxTheme.mono(
            fontSize: 11,
            color: LevMaxTheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'BATAL',
              style: LevMaxTheme.mono(color: LevMaxTheme.outline),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: LevMaxTheme.amberGold,
            ),
            child: Text(
              'EKSEKUSI CASHOUT',
              style: LevMaxTheme.mono(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: LevMaxTheme.onPrimaryFixed,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final updatedGold = widget.player.gold - amount;
      final updatedPlayer = widget.player.copyWith(gold: updatedGold);

      await SupabaseApiService.updateUser(updatedPlayer);
      await BlockchainService.addBlock(
        'GUILD CASHOUT: Redeemed $amount Gold for Rp ${NumberFormat('#,###', 'id_ID').format(idrValue)} via Instant QRIS.',
        userId: widget.player.id,
      );

      widget.onPlayerUpdated();

      if (mounted) {
        setState(() {
          _selectedGoldAmount = updatedGold;
          _goldInputController.text = updatedGold.toString();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: LevMaxTheme.surfaceContainer,
            behavior: SnackBarBehavior.floating,
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: LevMaxTheme.tertiaryContainer,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'CASHOUT BERHASIL: RP ${NumberFormat('#,###', 'id_ID').format(idrValue)} TERNOTARISASI DI LEDGER',
                    style: LevMaxTheme.mono(
                      fontSize: 10.5,
                      color: LevMaxTheme.tertiaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
  }

  // ============================================================================
  // KOMPONEN 1: STICKY TACTICAL HEADER BAR (IDENTIK DENGAN TAB 1)
  // ============================================================================
  Widget _buildStickyTacticalHeader() {
    final now = DateTime.now();
    final dateStr = DateFormat('MMM dd').format(now).toUpperCase();

    return Container(
      color: LevMaxTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // Sisi Kiri: Emblem & Monolith Info
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: LevMaxTheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: LevMaxTheme.primaryContainer.withValues(alpha: 0.6),
                ),
                boxShadow: [
                  BoxShadow(
                    color: LevMaxTheme.primaryContainer.withValues(alpha: 0.2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.shield,
                  color: LevMaxTheme.primaryContainer,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                            color: LevMaxTheme.primaryContainer,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: LevMaxTheme.primaryContainer.withValues(
                                  alpha: 0.4 + (_pulseController.value * 0.6),
                                ),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '[SYSTEM ALERT]',
                      style: LevMaxTheme.mono(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: LevMaxTheme.primaryContainer,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'DAILY QUESTS',
                  style: LevMaxTheme.headline(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: LevMaxTheme.onSurface,
                  ),
                ),
              ],
            ),
            const Spacer(),

            // Sisi Kanan: Status Baris & Profil Avatar Mini
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  dateStr,
                  style: LevMaxTheme.mono(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: LevMaxTheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: LevMaxTheme.tertiaryFixedDim,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'ONLINE • 24ms',
                      style: LevMaxTheme.mono(
                        fontSize: 10,
                        color: LevMaxTheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(width: 10),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: LevMaxTheme.surfaceContainerLowest,
                border: Border.all(
                  color: LevMaxTheme.primaryContainer.withValues(alpha: 0.6),
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.person,
                  color: LevMaxTheme.primaryContainer,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // KOMPONEN 2: TOP STICKY SEGMENTED CONTROL BAR (3 SUB-TABS)
  // ============================================================================
  Widget _buildSegmentedControlBar() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: LevMaxTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Row(
        children: [
          _buildSegmentButton(
            id: 'map',
            label: 'MAP (LBS)',
            icon: Icons.explore,
          ),
          const SizedBox(width: 4),
          _buildSegmentButton(
            id: 'guild',
            label: 'GUILD & TIME',
            icon: Icons.account_balance,
          ),
          const SizedBox(width: 4),
          _buildSegmentButton(
            id: 'audit',
            label: 'AUDIT LOG',
            icon: Icons.token,
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton({
    required String id,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _activeSubView == id;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            _activeSubView = id;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? LevMaxTheme.surfaceContainerHigh
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: isSelected
                ? Border.all(
                    color: LevMaxTheme.primaryContainer.withValues(alpha: 0.4),
                  )
                : null,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: LevMaxTheme.primaryContainer.withValues(
                        alpha: 0.15,
                      ),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected
                    ? LevMaxTheme.primaryContainer
                    : LevMaxTheme.outline,
              ),
              const SizedBox(width: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: LevMaxTheme.mono(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? LevMaxTheme.primaryContainer
                        : LevMaxTheme.outline,
                    letterSpacing: 0.5,
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
  // SUB-VIEW 1: DUNGEON MAP (LBS) - INTERACTIVE FLUTTER_MAP & MYSTERY GATES
  // ============================================================================
  Widget _buildMapView() {
    return DungeonMapView(
      player: widget.player,
      onPlayerUpdated: widget.onPlayerUpdated,
    );
  }

  // ============================================================================
  // SUB-VIEW 2: GUILD EXCHANGE & SERVER TIME
  // ============================================================================
  Widget _buildGuildView() {
    final goldAmount = _selectedGoldAmount;
    final idrValue = goldAmount * 10;
    final usdValue = (idrValue / 16200).toStringAsFixed(2);
    final eurValue = (idrValue / 17500).toStringAsFixed(2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Guild Treasury Hero Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF262A35), Color(0xFF171B26)],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: LevMaxTheme.amberGold.withValues(alpha: 0.6),
            ),
            boxShadow: [
              BoxShadow(
                color: LevMaxTheme.amberGold.withValues(alpha: 0.15),
                blurRadius: 16,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: LevMaxTheme.amberGold,
                          boxShadow: [
                            BoxShadow(
                              color: LevMaxTheme.amberGold,
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'MONARCH GUILD VAULT // BALANCE',
                        style: LevMaxTheme.mono(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: LevMaxTheme.amberGold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  const Icon(
                    Icons.account_balance_wallet,
                    color: LevMaxTheme.amberGold,
                    size: 18,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  const Icon(
                    Icons.monetization_on,
                    color: LevMaxTheme.amberGold,
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    NumberFormat('#,###', 'id_ID').format(widget.player.gold),
                    style: LevMaxTheme.headline(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: LevMaxTheme.amberGold,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'GOLD',
                    style: LevMaxTheme.mono(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: LevMaxTheme.amberGold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Unclaimed Raid Bounty: +850 G (Pending Sync)',
                style: LevMaxTheme.mono(
                  fontSize: 10,
                  color: LevMaxTheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Currency Exchange Calculator Terminal
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: LevMaxTheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'CURRENCY EXCHANGE CALCULATOR [1 G = RP 10 IDR]',
                style: LevMaxTheme.mono(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: LevMaxTheme.primaryContainer,
                ),
              ),
              const SizedBox(height: 10),

              // Input Amount
              TextField(
                controller: _goldInputController,
                keyboardType: TextInputType.number,
                style: LevMaxTheme.mono(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: LevMaxTheme.amberGold,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: LevMaxTheme.surfaceContainerLowest,
                  labelText: 'JUMLAH GOLD DICAIRKAN',
                  labelStyle: LevMaxTheme.mono(
                    fontSize: 10,
                    color: LevMaxTheme.outline,
                  ),
                  prefixIcon: const Icon(
                    Icons.toll,
                    color: LevMaxTheme.amberGold,
                    size: 18,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF1E293B)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: LevMaxTheme.amberGold,
                      width: 1.5,
                    ),
                  ),
                ),
                onChanged: (val) {
                  final parsed = int.tryParse(val) ?? 0;
                  setState(() {
                    _selectedGoldAmount = parsed.clamp(0, widget.player.gold);
                  });
                },
              ),
              const SizedBox(height: 10),

              // Quick Ratio Buttons (25%, 50%, 75%, MAX)
              Row(
                children: [
                  _buildRatioButton('25%', 0.25),
                  const SizedBox(width: 6),
                  _buildRatioButton('50%', 0.50),
                  const SizedBox(width: 6),
                  _buildRatioButton('75%', 0.75),
                  const SizedBox(width: 6),
                  _buildRatioButton('MAX', 1.0),
                ],
              ),
              const SizedBox(height: 14),

              // Multi-Currency Output Matrix (3 Columns)
              Row(
                children: [
                  Expanded(
                    child: _buildCurrencyMatrixCard(
                      label: 'IDR (LOCAL)',
                      value:
                          'Rp ${NumberFormat('#,###', 'id_ID').format(idrValue)}',
                      sublabel: 'Instant QRIS',
                      color: LevMaxTheme.tertiaryContainer,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildCurrencyMatrixCard(
                      label: 'USD',
                      value: '\$ $usdValue',
                      sublabel: 'Wire / PayPal',
                      color: LevMaxTheme.primaryContainer,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildCurrencyMatrixCard(
                      label: 'EUR',
                      value: '€ $eurValue',
                      sublabel: 'SEPA Swift',
                      color: LevMaxTheme.secondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Tombol Request Cashout
              GestureDetector(
                onTap: _handleGuildCashout,
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: LevMaxTheme.amberGold,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33FBBF24),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.payments,
                        size: 18,
                        color: Color(0xFF002022),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'REQUEST GUILD CASHOUT',
                        style: LevMaxTheme.mono(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF002022),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 3. Multi-Timezone Server Reset Clocks (2x2 Grid)
        Text(
          'SERVER TIMEZONE RESET RADAR [DAILY QUEST CYCLE 00:00]',
          style: LevMaxTheme.mono(
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            color: LevMaxTheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              child: _buildTimezoneClockCard(
                'WIB (JAKARTA)',
                7,
                isActive: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: _buildTimezoneClockCard('WITA (BALI)', 8)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildTimezoneClockCard('WIT (JAYAPURA)', 9)),
            const SizedBox(width: 8),
            Expanded(child: _buildTimezoneClockCard('LONDON (GMT)', 0)),
          ],
        ),
      ],
    );
  }

  Widget _buildRatioButton(String label, double ratio) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          final newAmount = (widget.player.gold * ratio).round();
          setState(() {
            _selectedGoldAmount = newAmount;
            _goldInputController.text = newAmount.toString();
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: LevMaxTheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: Center(
            child: Text(
              label,
              style: LevMaxTheme.mono(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                color: LevMaxTheme.amberGold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrencyMatrixCard({
    required String label,
    required String value,
    required String sublabel,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: LevMaxTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: LevMaxTheme.mono(fontSize: 8.5, color: LevMaxTheme.outline),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: LevMaxTheme.headline(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sublabel,
            style: LevMaxTheme.mono(fontSize: 8, color: LevMaxTheme.outline),
          ),
        ],
      ),
    );
  }

  Widget _buildTimezoneClockCard(
    String zoneName,
    int utcOffset, {
    bool isActive = false,
  }) {
    // Hitung jam di zona waktu yang bersangkutan
    final utc = _currentTime.toUtc();
    final zoneTime = utc.add(Duration(hours: utcOffset));
    final timeStr = DateFormat('HH:mm:ss').format(zoneTime);

    // Hitung sisa waktu hingga 00:00 hari berikutnya di zona itu
    final midnight = DateTime.utc(
      zoneTime.year,
      zoneTime.month,
      zoneTime.day + 1,
    );
    final remaining = midnight.difference(zoneTime);
    final remainingStr =
        '${remaining.inHours.toString().padLeft(2, '0')}h ${(remaining.inMinutes % 60).toString().padLeft(2, '0')}m ${(remaining.inSeconds % 60).toString().padLeft(2, '0')}s';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: LevMaxTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive
              ? LevMaxTheme.primaryContainer
              : const Color(0xFF1E293B),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                zoneName,
                style: LevMaxTheme.mono(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: isActive
                      ? LevMaxTheme.primaryContainer
                      : LevMaxTheme.onSurfaceVariant,
                ),
              ),
              if (isActive)
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: LevMaxTheme.tertiaryFixed,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              timeStr,
              style: LevMaxTheme.headline(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: LevMaxTheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'Reset in $remainingStr',
              style: LevMaxTheme.mono(
                fontSize: 8.5,
                color: LevMaxTheme.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // SUB-VIEW 3: BLOCKCHAIN AUDIT LOG
  // ============================================================================
  Widget _buildAuditView() {
    final blocks = BlockchainService.getBlocks().reversed.toList();
    final isChainValid = BlockchainService.isChainValid();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Audit Header & Telemetry Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: LevMaxTheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF262A35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: LevMaxTheme.secondaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: LevMaxTheme.secondary.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  'SHA-256 ZERO-KNOWLEDGE PROOF',
                  style: LevMaxTheme.mono(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: LevMaxTheme.secondary,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              Text(
                'Anti-Cheat Verification Ledger',
                style: LevMaxTheme.headline(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: LevMaxTheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Every physical quest completion is sealed onto the tamper-proof ledger with cryptographic hardware sensor payloads.',
                style: TextStyle(
                  fontSize: 11,
                  color: LevMaxTheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),

              // 3-Column Telemetry Strip
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: LevMaxTheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Blocks: ${blocks.length}',
                          style: LevMaxTheme.mono(
                            fontSize: 9.5,
                            color: LevMaxTheme.primaryContainer,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: Text(
                          'Validator: Solana VM',
                          style: LevMaxTheme.mono(
                            fontSize: 9.5,
                            color: LevMaxTheme.tertiaryFixedDim,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Gas Fee: 0 G (FREE)',
                          style: LevMaxTheme.mono(
                            fontSize: 9.5,
                            color: LevMaxTheme.outline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Status Keamanan Rantai Blok
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isChainValid
                ? LevMaxTheme.tertiaryContainer.withValues(alpha: 0.1)
                : LevMaxTheme.hpRed.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isChainValid
                  ? LevMaxTheme.tertiaryContainer
                  : LevMaxTheme.hpRed,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isChainValid ? Icons.verified_user : Icons.warning_amber,
                color: isChainValid
                    ? LevMaxTheme.tertiaryContainer
                    : LevMaxTheme.hpRed,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isChainValid
                      ? 'RANTAI BLOK VALID: 100% INTEGRITAS KRIPTOGRAFIS LOLOS AUDIT'
                      : 'PERINGATAN: KETIDAKSESUAIAN HASH TERDETEKSI',
                  style: LevMaxTheme.mono(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: isChainValid
                        ? LevMaxTheme.tertiaryContainer
                        : LevMaxTheme.hpRed,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Node & Link Blockchain Visual Feed
        if (blocks.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                'Belum ada transaksi blok tercatat.',
                style: LevMaxTheme.mono(
                  fontSize: 11,
                  color: LevMaxTheme.outline,
                ),
              ),
            ),
          )
        else
          ...List.generate(blocks.length, (idx) {
            final block = blocks[idx];
            final isLatest = idx == 0;
            return _buildBlockNodeItem(block: block, isLatest: isLatest);
          }),

        const SizedBox(height: 12),

        // Tombol Onchain Explorer Verification
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: LevMaxTheme.surfaceContainer,
                title: Text(
                  'ONCHAIN VERIFIER',
                  style: LevMaxTheme.headline(
                    color: LevMaxTheme.primaryContainer,
                  ),
                ),
                content: Text(
                  'Genesis & Sensor Proof Payload disinkronkan secara kontinu ke Lapisan 3 Cloud Database Supabase & Solscan Virtual Machine Node.',
                  style: LevMaxTheme.mono(
                    fontSize: 11,
                    color: LevMaxTheme.onSurfaceVariant,
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      'TUTUP',
                      style: LevMaxTheme.mono(
                        color: LevMaxTheme.primaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: LevMaxTheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.open_in_new,
                  size: 16,
                  color: LevMaxTheme.primaryContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  'VERIFY BLOCK ONCHAIN (SOLSCAN / ETHERSCAN)',
                  style: LevMaxTheme.mono(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: LevMaxTheme.primaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBlockNodeItem({
    required BlockModel block,
    required bool isLatest,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sisi Kiri: Sirkuit Node Vertikal
        Column(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isLatest
                    ? LevMaxTheme.primaryContainer
                    : LevMaxTheme.surfaceContainerHighest,
                border: Border.all(
                  color: isLatest
                      ? LevMaxTheme.primaryContainer
                      : LevMaxTheme.outline,
                  width: 2,
                ),
                boxShadow: isLatest
                    ? [
                        const BoxShadow(
                          color: Color(0xFF00F0FF),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
            ),
            Container(
              width: 2,
              height: 130,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    isLatest
                        ? LevMaxTheme.primaryContainer
                        : LevMaxTheme.outline,
                    LevMaxTheme.secondary,
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),

        // Sisi Kanan: Kartu Blok Kriptografis
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isLatest
                  ? LevMaxTheme.surfaceContainerHigh
                  : LevMaxTheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isLatest
                    ? LevMaxTheme.primaryContainer.withValues(alpha: 0.5)
                    : const Color(0xFF1E293B),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'BLOCK #${block.index.toString().padLeft(5, '0')} // ${isLatest ? 'LATEST' : 'VALIDATED'}',
                      style: LevMaxTheme.mono(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isLatest
                            ? LevMaxTheme.primaryContainer
                            : LevMaxTheme.onSurface,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: LevMaxTheme.tertiaryFixed,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'MINED',
                          style: LevMaxTheme.mono(
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                            color: LevMaxTheme.tertiaryFixed,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${block.timestamp.length >= 19 ? block.timestamp.substring(0, 19).replaceAll('T', ' ') : block.timestamp} • RepProof-V3',
                  style: LevMaxTheme.mono(
                    fontSize: 8.5,
                    color: LevMaxTheme.outline,
                  ),
                ),
                const SizedBox(height: 8),

                // Hash & Prev Hash Container
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: LevMaxTheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'HASH: ${block.currentHash}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: LevMaxTheme.mono(
                          fontSize: 8.5,
                          color: LevMaxTheme.primaryContainer,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'PREV: ${block.prevHash}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: LevMaxTheme.mono(
                          fontSize: 8.5,
                          color: LevMaxTheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),

                Text(
                  block.action,
                  style: const TextStyle(
                    fontSize: 11,
                    color: LevMaxTheme.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // BUILD UTAMA
  // ============================================================================
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Sticky Tactical Header Bar
        _buildStickyTacticalHeader(),

        // Komponen 1: Top Sticky Segmented Control Bar (Sub-Tab Switcher)
        Container(
          color: LevMaxTheme.surface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: _buildSegmentedControlBar(),
        ),

        // Konten Scrollable Tab
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Tampilan Sub-View Sesuai State
                if (_activeSubView == 'map') ...[
                  _buildMapView(),
                ] else if (_activeSubView == 'guild') ...[
                  _buildGuildView(),
                ] else ...[
                  _buildAuditView(),
                ],

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
