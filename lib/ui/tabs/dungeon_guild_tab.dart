// Tab Dungeon dan Guild Exchange
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../../helpers/boxes.dart';
import '../../models/quest_model.dart';
import '../../models/user_model.dart';
import '../../services/blockchain_service.dart';
import '../../services/supabase_api_service.dart';

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

class _DungeonGuildTabState extends State<DungeonGuildTab> {
  // Controller peta dan lokasi GPS
  final MapController _mapController = MapController();
  LatLng _currentLocation = const LatLng(-6.200000, 106.816666); // Koordinat default Jakarta
  bool _isLoadingLocation = true;
  bool _isTrackingRun = false;
  double _totalDistanceRunKm = 0.0;
  LatLng? _lastTrackedPosition;
  StreamSubscription<Position>? _positionStream;

  // Controller jam real-time multi-zona
  Timer? _clockTimer;
  DateTime _nowUtc = DateTime.now().toUtc();

  // Controller kalkulator Guild Exchange
  final _exchangeController = TextEditingController();
  double _calculatedIdr = 0.0;
  double _calculatedUsd = 0.0;
  double _calculatedEur = 0.0;

  // State sinkronisasi Blockchain
  bool _isSyncingBlockchain = false;

  @override
  void initState() {
    super.initState();
    // Memuat posisi GPS dan memulai timer waktu
    _initUserLocation();
    _startClockTimer();
    _exchangeController.text = widget.player.gold.toString();
    _calculateExchange(widget.player.gold.toDouble());
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _clockTimer?.cancel();
    _exchangeController.dispose();
    super.dispose();
  }

  // Timer pembaruan waktu real-time
  void _startClockTimer() {
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _nowUtc = DateTime.now().toUtc();
      });
    });
  }

  // Inisialisasi koordinat GPS menggunakan Geolocator
  Future<void> _initUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _isLoadingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) setState(() => _isLoadingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _isLoadingLocation = false);
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          _currentLocation = LatLng(pos.latitude, pos.longitude);
          _isLoadingLocation = false;
        });
        _mapController.move(_currentLocation, 15.0);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  // Mulai atau hentikan pelacakan jarak lari GPS
  void _toggleRunTracking() {
    if (_isTrackingRun) {
      _positionStream?.cancel();
      setState(() {
        _isTrackingRun = false;
      });
    } else {
      setState(() {
        _isTrackingRun = true;
        _totalDistanceRunKm = 0.0;
        _lastTrackedPosition = _currentLocation;
      });

      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      );

      _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen((pos) {
        if (!mounted) return;
        final newLatLng = LatLng(pos.latitude, pos.longitude);

        if (_lastTrackedPosition != null) {
          final distanceMeters = Geolocator.distanceBetween(
            _lastTrackedPosition!.latitude,
            _lastTrackedPosition!.longitude,
            newLatLng.latitude,
            newLatLng.longitude,
          );

          setState(() {
            _totalDistanceRunKm += (distanceMeters / 1000.0);
            _lastTrackedPosition = newLatLng;
            _currentLocation = newLatLng;
          });
          _mapController.move(newLatLng, 16.0);
        } else {
          _lastTrackedPosition = newLatLng;
        }
      });
    }
  }

  // Menyimpan hasil jarak lari ke Daily Quest Cardio
  Future<void> _saveRunToCardioQuest() async {
    if (_totalDistanceRunKm <= 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jarak lari belum tercatat.')),
      );
      return;
    }

    final box = Hive.box<QuestModel>(HiveBoxes.questBox);
    QuestModel? cardioQuest;

    for (final q in box.values) {
      if (q.category == 'Cardio') {
        cardioQuest = q;
        break;
      }
    }

    if (cardioQuest != null) {
      final addedKm = _totalDistanceRunKm.round();
      cardioQuest.currentValue += addedKm > 0 ? addedKm : 1;
      if (cardioQuest.currentValue >= cardioQuest.targetValue) {
        cardioQuest.isCompleted = true;
      }
      await cardioQuest.save();
      await SupabaseApiService.syncQuest(quest: cardioQuest, userId: widget.player.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_totalDistanceRunKm.toStringAsFixed(2)} Km ditambahkan ke Quest Cardio!'),
            backgroundColor: const Color(0xFF00E5FF),
          ),
        );
      }
    }
  }

  // Perhitungan kurs pertukaran mata uang Guild Exchange
  void _calculateExchange(double goldAmount) {
    // Formula kurs: 1 Gold = Rp 1.000, 1 USD = Rp 16.200, 1 EUR = Rp 17.500
    final idr = goldAmount * 1000.0;
    final usd = idr / 16200.0;
    final eur = idr / 17500.0;

    setState(() {
      _calculatedIdr = idr;
      _calculatedUsd = usd;
      _calculatedEur = eur;
    });
  }

  // Sinkronisasi data Blockchain ke Supabase
  Future<void> _syncBlockchain() async {
    setState(() {
      _isSyncingBlockchain = true;
    });

    final syncedCount = await BlockchainService.syncAllToSupabase();

    if (!mounted) return;

    setState(() {
      _isSyncingBlockchain = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$syncedCount blok riwayat berhasil disinkronkan ke Supabase.'),
        backgroundColor: const Color(0xFF00E5FF),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Format waktu untuk 4 zona: WIB, WITA, WIT, London
    final wibTime = _nowUtc.add(const Duration(hours: 7));
    final witaTime = _nowUtc.add(const Duration(hours: 8));
    final witTime = _nowUtc.add(const Duration(hours: 9));
    final londonTime = _nowUtc.add(const Duration(hours: 1)); // BST UTC+1

    final timeFormatter = DateFormat('HH:mm:ss');
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    // Hitung sisa waktu sebelum reset quest 23:59:59 WIB
    final resetToday = DateTime(wibTime.year, wibTime.month, wibTime.day, 23, 59, 59);
    final remainingDiff = resetToday.difference(wibTime);
    final countdownStr = remainingDiff.isNegative
        ? '00:00:00'
        : '${remainingDiff.inHours.toString().padLeft(2, '0')}:${(remainingDiff.inMinutes % 60).toString().padLeft(2, '0')}:${(remainingDiff.inSeconds % 60).toString().padLeft(2, '0')}';

    // Daftar marker lokasi Gym dan Barbershop terdekat
    final markers = <Marker>[
      // Marker Hunter Saat Ini
      Marker(
        point: _currentLocation,
        width: 44,
        height: 44,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF00E5FF),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.6),
                blurRadius: 16,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Icon(Icons.person_pin_circle, color: Colors.black, size: 28),
        ),
      ),
      // Marker Lokasi Gym 1
      Marker(
        point: LatLng(_currentLocation.latitude + 0.003, _currentLocation.longitude + 0.004),
        width: 36,
        height: 36,
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.orange,
          ),
          child: const Icon(Icons.fitness_center, color: Colors.black, size: 20),
        ),
      ),
      // Marker Lokasi Gym 2
      Marker(
        point: LatLng(_currentLocation.latitude - 0.002, _currentLocation.longitude + 0.003),
        width: 36,
        height: 36,
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.orange,
          ),
          child: const Icon(Icons.fitness_center, color: Colors.black, size: 20),
        ),
      ),
      // Marker Lokasi Barbershop / Looksmax 1
      Marker(
        point: LatLng(_currentLocation.latitude + 0.002, _currentLocation.longitude - 0.003),
        width: 36,
        height: 36,
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF7B1FA2),
          ),
          child: const Icon(Icons.content_cut, color: Colors.white, size: 20),
        ),
      ),
      // Marker Lokasi Barbershop / Looksmax 2
      Marker(
        point: LatLng(_currentLocation.latitude - 0.003, _currentLocation.longitude - 0.002),
        width: 36,
        height: 36,
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF7B1FA2),
          ),
          child: const Icon(Icons.spa, color: Colors.white, size: 20),
        ),
      ),
    ];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ==================================================================
          // BAGIAN 1: PETA DUNGEON LBS (FR-4.1)
          // ==================================================================
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF131B2E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF00E5FF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.explore, color: Color(0xFF00E5FF), size: 22),
                        SizedBox(width: 8),
                        Text(
                          'PETA DUNGEON & LOKASI LBS',
                          style: TextStyle(
                            color: Color(0xFF00E5FF),
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.my_location, color: Color(0xFF00E5FF), size: 20),
                      onPressed: _initUserLocation,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Koordinat GPS Lari & Titik Dungeon Gym / Barbershop Looksmaxxing',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
                ),
                const SizedBox(height: 12),

                // Container Widget Peta OpenStreetMap
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 240,
                    child: _isLoadingLocation
                        ? const Center(
                            child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
                          )
                        : FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: _currentLocation,
                              initialZoom: 15.0,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.levmax.app',
                              ),
                              MarkerLayer(markers: markers),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 12),

                // Legenda Marker
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildLegendItem(const Color(0xFF00E5FF), 'Hunter'),
                    _buildLegendItem(Colors.orange, 'Gym Guild'),
                    _buildLegendItem(const Color(0xFF7B1FA2), 'Barbershop/Spa'),
                  ],
                ),
                const Divider(color: Color(0xFF1E293B), height: 20),

                // Baris Tombol Pelacakan Lari
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'JARAK LARI TERCATAT',
                            style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${_totalDistanceRunKm.toStringAsFixed(2)} Km',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF00E5FF),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _toggleRunTracking,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isTrackingRun ? const Color(0xFFFF1744) : const Color(0xFF00E5FF),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      child: Text(
                        _isTrackingRun ? 'STOP TRACKING' : 'MULAI LARI',
                        style: TextStyle(
                          color: _isTrackingRun ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.save, color: Color(0xFF00E5FF)),
                      onPressed: _saveRunToCardioQuest,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ==================================================================
          // BAGIAN 2: KONVERSI WAKTU SERVER MULTI-ZONA (FR-4.2)
          // ==================================================================
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF131B2E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.access_time, color: Color(0xFF00E5FF), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'SERVER QUEST RESET TIMER (23:59)',
                          style: TextStyle(
                            color: Color(0xFF00E5FF),
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF1744).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFF1744)),
                      ),
                      child: Text(
                        countdownStr,
                        style: const TextStyle(
                          color: Color(0xFFFF1744),
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 4 Kartu Zona Waktu
                Row(
                  children: [
                    Expanded(child: _buildZoneCard('WIB (UTC+7)', timeFormatter.format(wibTime))),
                    const SizedBox(width: 8),
                    Expanded(child: _buildZoneCard('WITA (UTC+8)', timeFormatter.format(witaTime))),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildZoneCard('WIT (UTC+9)', timeFormatter.format(witTime))),
                    const SizedBox(width: 8),
                    Expanded(child: _buildZoneCard('London (UTC+1)', timeFormatter.format(londonTime))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ==================================================================
          // BAGIAN 3: GUILD EXCHANGE KONVERSI MATA UANG (FR-4.3)
          // ==================================================================
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF131B2E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.currency_exchange, color: Colors.amber, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'GUILD EXCHANGE (KURS GOLD)',
                          style: TextStyle(
                            color: Colors.amber,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Saldo: ${widget.player.gold} Gold',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Formula Standar: 1 Gold = Rp 1.000 | 1 USD = Rp 16.200 | 1 EUR = Rp 17.500',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 10.5),
                ),
                const SizedBox(height: 12),

                // Input Simulasi Gold
                TextField(
                  controller: _exchangeController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Jumlah Koin Gold yang Dikonversi',
                    labelStyle: const TextStyle(color: Colors.amber, fontSize: 11),
                    suffixText: 'Gold',
                    filled: true,
                    fillColor: const Color(0xFF0A0E1A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onChanged: (val) {
                    final amount = double.tryParse(val) ?? 0.0;
                    _calculateExchange(amount);
                  },
                ),
                const SizedBox(height: 14),

                // Hasil Konversi 3 Mata Uang
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0E1A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                  child: Column(
                    children: [
                      _buildCurrencyRow('Rupiah Indonesia (IDR)', currencyFormatter.format(_calculatedIdr)),
                      const Divider(color: Color(0xFF1E293B), height: 16),
                      _buildCurrencyRow('Dolar Amerika (USD)', '\$ ${_calculatedUsd.toStringAsFixed(2)}'),
                      const Divider(color: Color(0xFF1E293B), height: 16),
                      _buildCurrencyRow('Euro Eropa (EUR)', '€ ${_calculatedEur.toStringAsFixed(2)}'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ==================================================================
          // BAGIAN 4: BLOCKCHAIN LEDGER ANTI-CHEAT (FR-6.3)
          // ==================================================================
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF131B2E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.link, color: Color(0xFF00E5FF), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'BLOCKCHAIN LEDGER (ANTI-CHEAT)',
                          style: TextStyle(
                            color: Color(0xFF00E5FF),
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: _isSyncingBlockchain ? null : _syncBlockchain,
                      icon: _isSyncingBlockchain
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : const Icon(Icons.cloud_sync, size: 14, color: Colors.black),
                      label: const Text('SYNC', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E5FF),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Status Integritas Rantai Blok
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: BlockchainService.isChainValid()
                        ? Colors.green.withValues(alpha: 0.15)
                        : Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: BlockchainService.isChainValid() ? Colors.green : Colors.red,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        BlockchainService.isChainValid() ? Icons.check_circle : Icons.error,
                        color: BlockchainService.isChainValid() ? Colors.greenAccent : Colors.redAccent,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          BlockchainService.isChainValid()
                              ? 'Integritas Rantai Blok Valid (SHA-256 Terverifikasi)'
                              : 'Peringatan: Hash Blok Terindikasi Manipulasi!',
                          style: TextStyle(
                            color: BlockchainService.isChainValid() ? Colors.greenAccent : Colors.redAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Daftar Blok Tersimpan di Hive
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: BlockchainService.getBlocks().length,
                  itemBuilder: (context, index) {
                    final blocks = BlockchainService.getBlocks();
                    final block = blocks[blocks.length - 1 - index]; // Urutkan terbaru ke terlama

                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A0E1A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF1E293B)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Blok #${block.index}',
                                style: const TextStyle(
                                  color: Color(0xFF00E5FF),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                              Text(
                                block.timestamp.length >= 19 ? block.timestamp.substring(0, 19) : block.timestamp,
                                style: const TextStyle(color: Colors.grey, fontSize: 10),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            block.action,
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Hash: ${block.currentHash.substring(0, 24)}...',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 9.5),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
      ],
    );
  }

  Widget _buildZoneCard(String zoneName, String timeStr) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0E1A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(zoneName, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(timeStr, style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 14, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildCurrencyRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );
  }
}
