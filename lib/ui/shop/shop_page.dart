// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/ui/shop/shop_page.dart
// Deskripsi: Halaman Utama System Shop / Monarch's Treasury (Prompt 12)
//            1. The Treasury Header & Gold Balance Box
//            2. Shop Category Switcher (Consumables, Collectibles Pride, Top-Up & Exchange)
//            3. Grid Consumables (Elixir of Life +25 HP, Mystery Key, etc.)
//            4. Luxury List Collectibles dengan Notarisasi Minting SHA-256 Blockchain
//            5. Top-Up Mockup (Google Play / App Store) & Live Currency Exchange Calculator
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../helpers/levmax_theme.dart';
import '../../models/quest_models.dart';
import '../../models/user_model.dart';
import '../../services/shop_service.dart';
import '../../services/supabase_api_service.dart';

class ShopPage extends StatefulWidget {
  final UserModel? player;
  final VoidCallback? onPlayerUpdated;

  const ShopPage({super.key, this.player, this.onPlayerUpdated});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage>
    with SingleTickerProviderStateMixin {
  late UserModel _player;

  // Tab Kategori: 'consumables' | 'collectibles' | 'exchange'
  String _activeTab = 'consumables';

  // Animasi Ping Indicator Emas
  late AnimationController _pingController;
  late Animation<double> _pingAnimation;

  // State Kalkulator Kurs Kustom
  late TextEditingController _customGoldController;
  int _calculatorGoldInput = 1000;

  // Daftar Katalog Item
  List<ItemShopModel> _items = [];
  bool _isProcessingTransaction = false;

  @override
  void initState() {
    super.initState();
    _player =
        widget.player ??
        SupabaseApiService.getPlayerCache() ??
        UserModel.initial(id: 1, username: 'Hunter', email: '');

    _items = ShopService.getDefaultShopItems();
    _customGoldController = TextEditingController(text: '1000');

    _pingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pingAnimation = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _pingController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pingController.dispose();
    _customGoldController.dispose();
    super.dispose();
  }

  void _refreshPlayerData() {
    final cached = SupabaseApiService.getPlayerCache();
    if (cached != null && mounted) {
      setState(() {
        _player = cached;
      });
    }
    widget.onPlayerUpdated?.call();
  }

  // ============================================================================
  // EKSEKUSI PEMBELIAN CONSUMABLE
  // ============================================================================
  Future<void> _handlePurchaseConsumable(ItemShopModel item) async {
    if (_player.gold < item.priceGold) {
      _showErrorSnackBar(
        'INSUFFICIENT GOLD! Butuh ${item.priceGold} Gold untuk item ini.',
      );
      return;
    }

    setState(() => _isProcessingTransaction = true);
    try {
      final updated = await ShopService.purchaseConsumable(
        player: _player,
        item: item,
      );

      _player = updated;
      _refreshPlayerData();

      if (!mounted) return;
      HapticFeedback.lightImpact();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF131826),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xFF00F0FF), width: 1.5),
          ),
          content: Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: Color(0xFF00F0FF),
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'TRANSAKSI BERHASIL: ${item.name} (-${item.priceGold} G)',
                  style: LevMaxTheme.mono(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isProcessingTransaction = false);
    }
  }

  // ============================================================================
  // EKSEKUSI MINTING COLLECTIBLE (PRIDE ITEM) KE BLOCKCHAIN
  // ============================================================================
  Future<void> _handleMintCollectible(ItemShopModel item) async {
    if (_player.gold < item.priceGold) {
      _showErrorSnackBar(
        'INSUFFICIENT GOLD! Saldo tidak mencukupi untuk mem-mint item ini.',
      );
      return;
    }

    setState(() => _isProcessingTransaction = true);
    try {
      final logModel = await ShopService.mintCollectibleItem(
        player: _player,
        item: item,
      );

      _refreshPlayerData();

      if (!mounted) return;
      HapticFeedback.heavyImpact();

      // Tampilkan Dialog Sukses Minting ke Blockchain SHA-256
      _showBlockchainMintDialog(item: item, log: logModel);
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isProcessingTransaction = false);
    }
  }

  // ============================================================================
  // EKSEKUSI TOP-UP MOCKUP (GOOGLE PLAY / APP STORE)
  // ============================================================================
  Future<void> _handleTopUp({
    required int goldAmount,
    required String idrPriceFormatted,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF171B26),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFFBBF24), width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.shopping_bag, color: Color(0xFFFBBF24)),
            const SizedBox(width: 8),
            Text(
              'KONFIRMASI TOP-UP',
              style: LevMaxTheme.headline(
                fontSize: 14,
                color: const Color(0xFFFBBF24),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Beli paket $goldAmount Gold seharga $idrPriceFormatted melalui Google Play Store / App Store?',
              style: LevMaxTheme.mono(
                fontSize: 11,
                color: LevMaxTheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F131D),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TOTAL GOLD DIDAPAT:',
                    style: LevMaxTheme.mono(
                      fontSize: 9.5,
                      color: LevMaxTheme.outline,
                    ),
                  ),
                  Text(
                    '+$goldAmount G',
                    style: LevMaxTheme.headline(
                      fontSize: 14,
                      color: const Color(0xFFFBBF24),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
              backgroundColor: const Color(0xFFFBBF24),
              foregroundColor: Colors.black,
            ),
            child: Text(
              'BAYAR VIA STORE',
              style: LevMaxTheme.headline(fontSize: 11, color: Colors.black),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isProcessingTransaction = true);
      try {
        final updated = await ShopService.processTopUp(
          player: _player,
          goldAmount: goldAmount,
          idrPriceFormatted: idrPriceFormatted,
        );

        _player = updated;
        _refreshPlayerData();

        if (!mounted) return;
        HapticFeedback.lightImpact();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF131826),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: Color(0xFFFBBF24), width: 1.5),
            ),
            content: Row(
              children: [
                const Icon(
                  Icons.monetization_on,
                  color: Color(0xFFFBBF24),
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'TOP-UP SUKSES: +$goldAmount GOLD TELAH MASUK KE SALDO VAULT!',
                    style: LevMaxTheme.mono(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } catch (e) {
        if (mounted) _showErrorSnackBar(e.toString());
      } finally {
        if (mounted) setState(() => _isProcessingTransaction = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF131826),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: LevMaxTheme.mono(fontSize: 11, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // DIALOG HASIL MINTING KE BLOCKCHAIN LEDGER
  // ============================================================================
  void _showBlockchainMintDialog({
    required ItemShopModel item,
    required BlockchainInventoryLogModel log,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F131D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF6001D1), width: 2),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF6001D1).withValues(alpha: 0.25),
              ),
              child: const Icon(
                Icons.security,
                color: Color(0xFF00F0FF),
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'ITEM MINTED TO BLOCKCHAIN!',
                style: LevMaxTheme.headline(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFD2BBFF),
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Item ${item.name} berhasil ditransaksikan dan diverifikasi ke dalam Rantai Blok SHA-256.',
              style: LevMaxTheme.mono(
                fontSize: 11,
                color: LevMaxTheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),

            // Telemetry Box Hash
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF171B26),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHashTelemetryRow(
                    'ITEM NAME:',
                    item.name,
                    const Color(0xFFFBBF24),
                  ),
                  const SizedBox(height: 6),
                  _buildHashTelemetryRow(
                    'PREV HASH:',
                    log.previousHash.length > 20
                        ? '${log.previousHash.substring(0, 16)}...'
                        : log.previousHash,
                    LevMaxTheme.outline,
                  ),
                  const SizedBox(height: 6),
                  _buildHashTelemetryRow(
                    'CURRENT HASH:',
                    '${log.currentHash.substring(0, 24)}...',
                    const Color(0xFF00F0FF),
                  ),
                  const SizedBox(height: 6),
                  _buildHashTelemetryRow(
                    'TIMESTAMP:',
                    log.timestamp.substring(0, 19).replaceAll('T', ' '),
                    LevMaxTheme.tertiaryContainer,
                  ),
                  const SizedBox(height: 6),
                  _buildHashTelemetryRow(
                    'LEDGER STATUS:',
                    'IMMUTABLE // ON-CHAIN',
                    const Color(0xFF65F2B5),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6001D1),
              foregroundColor: Colors.white,
            ),
            child: Text(
              'CONFIRM & CLOSE',
              style: LevMaxTheme.headline(fontSize: 11, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHashTelemetryRow(String label, String value, Color valColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 95,
          child: Text(
            label,
            style: LevMaxTheme.mono(fontSize: 9, color: LevMaxTheme.outline),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: LevMaxTheme.mono(
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              color: valColor,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // BUILD UTAMA (SCAFFOLD SHOP HUD)
  // ============================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F131D),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // KOMPONEN 1: THE TREASURY HEADER & BALANCE
                  _buildTreasuryHeader(),
                  const SizedBox(height: 16),

                  // KOMPONEN 2: SHOP CATEGORY TAB SWITCHER
                  _buildCategoryTabSwitcher(),
                  const SizedBox(height: 16),

                  // KONTEN DINAMIS BERDASARKAN TAB AKTIF
                  if (_activeTab == 'consumables') _buildConsumablesGrid(),
                  if (_activeTab == 'collectibles') _buildCollectiblesList(),
                  if (_activeTab == 'exchange') _buildTopUpAndExchangeSection(),

                  const SizedBox(height: 40),
                ],
              ),
            ),

            // Loading Overlay saat Transaksi Berlangsung
            if (_isProcessingTransaction)
              Container(
                color: Colors.black.withValues(alpha: 0.6),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Color(0xFF00F0FF)),
                      SizedBox(height: 16),
                      Text(
                        'NOTARIZING TRANSACTION ON-CHAIN...',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // KOMPONEN 1: THE TREASURY HEADER & GOLD BALANCE BOX
  // ============================================================================
  Widget _buildTreasuryHeader() {
    final formattedGold = NumberFormat('#,###', 'id_ID').format(_player.gold);
    final canPop = Navigator.canPop(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF171B26), Color(0xFF0A0E18)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Kiri: Tag Ping Emas + Judul Besar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (canPop) ...[
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(
                            Icons.arrow_back_ios_new,
                            color: LevMaxTheme.onSurfaceVariant,
                            size: 16,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 8),
                      ],
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
                                color: Color(0x99FBBF24),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "[MONARCH'S TREASURY]",
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
                  Text(
                    'SYSTEM SHOP',
                    style: LevMaxTheme.headline(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFDFE2F1),
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),

              // Kanan: Box Saldo Aktual Pengguna
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1F2A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFFBBF24).withValues(alpha: 0.6),
                    width: 1.0,
                  ),
                  boxShadow: const [
                    BoxShadow(color: Color(0x1AFBBF24), blurRadius: 10),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.monetization_on,
                      color: Color(0xFFFBBF24),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$formattedGold G',
                      style: LevMaxTheme.mono(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFFBBF24),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Pasar resmi Guild & Sistem Solo Leveling. Tukarkan Gold dengan buff penawar penalti dan koleksi bernilai blockchain.',
            style: LevMaxTheme.mono(
              fontSize: 10.5,
              color: const Color(0xFFB9CACB),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // KOMPONEN 2: SHOP CATEGORY TAB SWITCHER (3 PILL BUTTONS)
  // ============================================================================
  Widget _buildCategoryTabSwitcher() {
    final tabs = [
      {'id': 'consumables', 'label': 'Consumables'},
      {'id': 'collectibles', 'label': 'Collectibles (Pride)'},
      {'id': 'exchange', 'label': 'Top-Up & Exchange'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.map((tab) {
          final isSelected = _activeTab == tab['id'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () {
                setState(() {
                  _activeTab = tab['id']!;
                });
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFFBBF24)
                      : const Color(0xFF262A35),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFFFBBF24)
                        : const Color(0xFF313540),
                  ),
                ),
                child: Text(
                  tab['label']!,
                  style: LevMaxTheme.headline(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                    color: isSelected
                        ? const Color(0xFF002022)
                        : const Color(0xFFB9CACB),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ============================================================================
  // KOMPONEN 3: TAB CONSUMABLES (ITEM HABIS PAKAI - GRID 2 KOLOM)
  // ============================================================================
  Widget _buildConsumablesGrid() {
    final consumables = _items
        .where((i) => i.category == 'Consumable')
        .toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: consumables.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.74,
      ),
      itemBuilder: (context, index) {
        final item = consumables[index];
        final isHpPotion = item.id.contains('hp_potion');
        final isMysteryKey = item.id.contains('mystery_key');

        final Color accentColor = isHpPotion
            ? const Color(0xFFEF4444)
            : (isMysteryKey
                  ? const Color(0xFFD2BBFF)
                  : const Color(0xFF00F0FF));

        final IconData icon = isHpPotion
            ? Icons.favorite
            : (isMysteryKey ? Icons.vpn_key : Icons.bolt);

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1F2A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.35),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.1),
                blurRadius: 12,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Icon Container
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F131D),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Center(
                    child: Icon(icon, color: accentColor, size: 24),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Title
              Text(
                item.name,
                style: LevMaxTheme.headline(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),

              // Description
              Expanded(
                child: Text(
                  item.description,
                  style: LevMaxTheme.mono(
                    fontSize: 9.5,
                    color: const Color(0xFFB9CACB),
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 8),

              // Harga Gold (Kuning)
              Row(
                children: [
                  const Icon(
                    Icons.monetization_on,
                    color: Color(0xFFFBBF24),
                    size: 15,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${item.priceGold} G',
                    style: LevMaxTheme.headline(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFFBBF24),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Tombol [ PURCHASE ] (Cyan)
              ElevatedButton(
                onPressed: () => _handlePurchaseConsumable(item),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00F0FF),
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 36),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 2,
                ),
                child: Text(
                  'PURCHASE',
                  style: LevMaxTheme.headline(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================================
  // KOMPONEN 4: TAB COLLECTIBLES (PRIDE ITEMS / LEADERBOARD)
  // ============================================================================
  Widget _buildCollectiblesList() {
    final collectibles = _items
        .where((i) => i.category == 'PrideItem')
        .toList();

    return Column(
      children: collectibles.map((item) {
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0E18),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF6001D1), width: 2.0),
            boxShadow: const [
              BoxShadow(
                color: Color(0x336001D1),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Kiri: Placeholder Ikon Pixel Art / Mahkota Emas-Ungu
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFF171B26),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFFBBF24),
                    width: 1.2,
                  ),
                  boxShadow: const [
                    BoxShadow(color: Color(0x22FBBF24), blurRadius: 10),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.military_tech,
                    color: Color(0xFFFBBF24),
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Tengah: Judul Emas, Badge Blockchain Secured, Deskripsi
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: LevMaxTheme.headline(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFFBBF24),
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Badge [BLOCKCHAIN SECURED]
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF313540),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: const Color(0xFF00F0FF).withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.security,
                            color: Color(0xFF00F0FF),
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'BLOCKCHAIN SECURED',
                            style: LevMaxTheme.mono(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF00F0FF),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),

                    Text(
                      item.description,
                      style: LevMaxTheme.mono(
                        fontSize: 10,
                        color: const Color(0xFFB9CACB),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Kanan: Harga & Tombol [ MINT ITEM ]
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.monetization_on,
                        color: Color(0xFFFBBF24),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${NumberFormat('#,###').format(item.priceGold)} G',
                        style: LevMaxTheme.headline(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFFBBF24),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  ElevatedButton(
                    onPressed: () => _handleMintCollectible(item),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6001D1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 4,
                    ),
                    child: Text(
                      'MINT ITEM',
                      style: LevMaxTheme.headline(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ============================================================================
  // KOMPONEN 5: TAB TOP-UP & EXCHANGE (FIAT TO GOLD & CURRENCY CALCULATOR)
  // ============================================================================
  Widget _buildTopUpAndExchangeSection() {
    final currencyInfo = ShopService.calculateCurrencyExchange(_player.gold);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // A. TOP-UP PACKAGES (MOCKUP VIA GOOGLE PLAY / APP STORE)
        Row(
          children: [
            const Icon(Icons.add_card, color: Color(0xFFFBBF24), size: 18),
            const SizedBox(width: 8),
            Text(
              'TOP-UP GOLD (STORE PACKAGES)',
              style: LevMaxTheme.mono(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFFBBF24),
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        _buildTopUpPackageCard(
          goldAmount: 1000,
          idrPrice: 'Rp 10.000',
          badgeText: 'STARTER PACK',
          badgeColor: LevMaxTheme.primaryContainer,
        ),
        const SizedBox(height: 10),

        _buildTopUpPackageCard(
          goldAmount: 5000,
          idrPrice: 'Rp 45.000',
          badgeText: 'POPULAR // SAVE 10%',
          badgeColor: const Color(0xFFFBBF24),
        ),
        const SizedBox(height: 10),

        _buildTopUpPackageCard(
          goldAmount: 10000,
          idrPrice: 'Rp 80.000',
          badgeText: 'BEST VALUE // SAVE 20%',
          badgeColor: const Color(0xFF65F2B5),
        ),
        const SizedBox(height: 24),

        // B. CURRENCY EXCHANGE CALCULATOR
        Row(
          children: [
            const Icon(
              Icons.currency_exchange,
              color: Color(0xFF00F0FF),
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              'CURRENCY EXCHANGE CALCULATOR (ASSET VALUE)',
              style: LevMaxTheme.mono(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF00F0FF),
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF171B26),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'YOUR ${_player.gold} GOLD IS CURRENTLY WORTH:',
                style: LevMaxTheme.mono(
                  fontSize: 10,
                  color: LevMaxTheme.outline,
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  _buildExchangeRateBox(
                    'IDR',
                    currencyInfo['idr']!,
                    const Color(0xFFFBBF24),
                  ),
                  const SizedBox(width: 10),
                  _buildExchangeRateBox(
                    'USD',
                    currencyInfo['usd']!,
                    const Color(0xFF65F2B5),
                  ),
                  const SizedBox(width: 10),
                  _buildExchangeRateBox(
                    'EUR',
                    currencyInfo['eur']!,
                    const Color(0xFF00F0FF),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Interactive Custom Calculator Field
              Text(
                'CUSTOM GOLD CONVERTER:',
                style: LevMaxTheme.mono(
                  fontSize: 9.5,
                  color: LevMaxTheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F131D),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF1E2638)),
                      ),
                      child: TextField(
                        controller: _customGoldController,
                        keyboardType: TextInputType.number,
                        style: LevMaxTheme.mono(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter gold amount...',
                          hintStyle: LevMaxTheme.mono(
                            fontSize: 11,
                            color: LevMaxTheme.outline,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          border: InputBorder.none,
                          suffixText: 'G',
                          suffixStyle: LevMaxTheme.mono(
                            fontSize: 11,
                            color: const Color(0xFFFBBF24),
                          ),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _calculatorGoldInput = int.tryParse(val) ?? 0;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Hasil Konversi Kustom
              Builder(
                builder: (context) {
                  final customRates = ShopService.calculateCurrencyExchange(
                    _calculatorGoldInput,
                  );
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A0E18),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF262A35)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'EQUIVALENT VALUE:',
                          style: LevMaxTheme.mono(
                            fontSize: 9.5,
                            color: LevMaxTheme.outline,
                          ),
                        ),
                        Text(
                          '${customRates['idr']}  |  ${customRates['usd']}  |  ${customRates['eur']}',
                          style: LevMaxTheme.mono(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopUpPackageCard({
    required int goldAmount,
    required String idrPrice,
    required String badgeText,
    required Color badgeColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF171B26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F131D),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFBBF24)),
                ),
                child: const Center(
                  child: Icon(
                    Icons.monetization_on,
                    color: Color(0xFFFBBF24),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      badgeText,
                      style: LevMaxTheme.mono(
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        color: badgeColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${NumberFormat('#,###').format(goldAmount)} Gold',
                    style: LevMaxTheme.headline(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),

          ElevatedButton(
            onPressed: () => _handleTopUp(
              goldAmount: goldAmount,
              idrPriceFormatted: idrPrice,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1C1F2A),
              foregroundColor: const Color(0xFFFBBF24),
              side: const BorderSide(color: Color(0xFFFBBF24), width: 1.0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Column(
              children: [
                Text(
                  idrPrice,
                  style: LevMaxTheme.headline(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFFBBF24),
                  ),
                ),
                Text(
                  'STORE CHECKOUT',
                  style: LevMaxTheme.mono(
                    fontSize: 7.5,
                    color: LevMaxTheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExchangeRateBox(
    String currencyLabel,
    String formattedValue,
    Color valColor,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF0F131D),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF1E293B)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              currencyLabel,
              style: LevMaxTheme.mono(fontSize: 9, color: LevMaxTheme.outline),
            ),
            const SizedBox(height: 3),
            Text(
              formattedValue,
              style: LevMaxTheme.headline(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: valColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
