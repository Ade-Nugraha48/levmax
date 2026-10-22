// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/ui/tabs/dungeon_map_view.dart
// Deskripsi: Sub-View Peta Taktis LBS Dungeon & Mystery Gate Mingguan (Prompt 10)
//            1. Menggunakan FlutterMap & TileLayer CartoDB Dark Matter
//            2. Player Pin Real-time dari GPS Geolocator Stream + Animasi Radar Pulse
//            3. 7 Mystery Gates Mingguan (Radius 1-3km, Reset Senin 00:00)
//            4. Validasi Jarak < 50m untuk Tombol [ EXPLORE GATE ]
//            5. Algoritma RNG Drop Loot (Zonk, Gold, Consumable, Collectible, Quest)
// ==============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../helpers/levmax_theme.dart';
import '../../models/user_model.dart';
import '../../services/dungeon_map_service.dart';

class DungeonMapView extends StatefulWidget {
  final UserModel player;
  final VoidCallback onPlayerUpdated;

  const DungeonMapView({
    super.key,
    required this.player,
    required this.onPlayerUpdated,
  });

  @override
  State<DungeonMapView> createState() => _DungeonMapViewState();
}

class _DungeonMapViewState extends State<DungeonMapView>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();

  // GPS State
  double _currentLat = -6.2088;
  double _currentLng = 106.8456;
  double _gpsAccuracy = 3.2;
  final int _satCount = 18;
  bool _isGpsActive = false;

  StreamSubscription<Position>? _positionStream;

  // Mystery Gates State
  List<MysteryGateModel> _gates = [];
  MysteryGateModel? _selectedGate;
  bool _isLoadingGates = true;
  String _filterMode = 'All Gates';

  // Radar Pulse Animation
  late AnimationController _pulseController;
  late Animation<double> _pulseScaleAnimation;
  late Animation<double> _pulseFadeAnimation;

  @override
  void initState() {
    super.initState();

    // Inisialisasi Kontroler Animasi Radar Pulse
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _pulseScaleAnimation = Tween<double>(begin: 0.6, end: 1.8).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOutQuad),
    );
    _pulseFadeAnimation = Tween<double>(begin: 0.7, end: 0.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOutQuad),
    );

    // Ambil Posisi GPS & Muat 7 Mystery Gate Mingguan
    _initializeGpsAndGates();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  // ============================================================================
  // INISIALISASI GPS REAL-TIME & 7 MYSTERY GATE MINGGUAN
  // ============================================================================
  Future<void> _initializeGpsAndGates() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[DungeonMap] Location service is disabled');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        _currentLat = position.latitude;
        _currentLng = position.longitude;
        _gpsAccuracy = position.accuracy > 0 ? position.accuracy : 3.2;
        _isGpsActive = true;
      }
    } catch (e) {
      debugPrint('[DungeonMap] GPS init fallback to default coordinates: $e');
    }

    // Muat 7 titik Mystery Gate Mingguan (Reset Senin)
    final loadedGates = await DungeonMapService.getOrGenerateWeeklyGates(
      userLat: _currentLat,
      userLng: _currentLng,
    );

    if (mounted) {
      setState(() {
        _gates = loadedGates;
        if (_gates.isNotEmpty) {
          _selectedGate = _gates.first;
        }
        _isLoadingGates = false;
      });

      // Pindahkan peta ke koordinat awal pemain
      _mapController.move(LatLng(_currentLat, _currentLng), 14.5);
    }

    // Pasang Stream GPS Real-Time untuk memperbarui posisi Hunter saat bergerak
    _startPositionStream();
  }

  void _startPositionStream() {
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3, // Update setiap perpindahan 3 meter
      ),
    ).listen(
      (Position position) {
        if (!mounted) return;
        setState(() {
          _currentLat = position.latitude;
          _currentLng = position.longitude;
          _gpsAccuracy = position.accuracy;
          _isGpsActive = true;
        });
      },
      onError: (e) {
        debugPrint('[DungeonMap] Position stream error: $e');
      },
    );
  }

  void _recenterMapOnPlayer() {
    _mapController.move(LatLng(_currentLat, _currentLng), 15.0);
  }

  void _recenterMapOnGate(MysteryGateModel gate) {
    setState(() {
      _selectedGate = gate;
    });
    _mapController.move(LatLng(gate.latitude, gate.longitude), 15.5);
  }

  // ============================================================================
  // EKSEKUSI EXPLORE GATE & RNG DROPS
  // ============================================================================
  Future<void> _exploreGate(MysteryGateModel gate) async {
    try {
      final result = await DungeonMapService.exploreGate(
        gate: gate,
        player: widget.player,
        currentLat: _currentLat,
        currentLng: _currentLng,
      );

      // Simpan perubahan ke Hive Cache
      await DungeonMapService.saveGatesToCache(_gates);

      // Trigger pembaruan data player di tab utama
      widget.onPlayerUpdated();

      if (!mounted) return;

      setState(() {});

      // Tampilkan Dialog Hasil Loot RNG Solo Leveling
      _showLootResultDialog(result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF131826),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0xFFEF4444)),
          ),
          content: Row(
            children: [
              const Icon(Icons.warning, color: Color(0xFFEF4444), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  e.toString().replaceAll('Exception: ', ''),
                  style: LevMaxTheme.mono(fontSize: 11, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _showLootResultDialog(LootResult result) {
    Color themeColor;
    IconData icon;

    switch (result.type) {
      case LootType.zonk:
        themeColor = LevMaxTheme.outline;
        icon = Icons.cancel_outlined;
        break;
      case LootType.gold:
        themeColor = LevMaxTheme.amberGold;
        icon = Icons.monetization_on;
        break;
      case LootType.consumable:
        themeColor = LevMaxTheme.tertiaryFixed;
        icon = Icons.science;
        break;
      case LootType.collectible:
        themeColor = const Color(0xFFC084FC); // Purple Artifact
        icon = Icons.auto_awesome;
        break;
      case LootType.quest:
        themeColor = LevMaxTheme.primaryContainer; // Cyan Secret Quest
        icon = Icons.bolt;
        break;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131826),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: themeColor, width: 2),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: themeColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: themeColor, size: 24),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                result.title,
                style: LevMaxTheme.headline(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: themeColor,
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
              result.description,
              style: LevMaxTheme.mono(
                fontSize: 11,
                color: LevMaxTheme.onSurfaceVariant,
              ),
            ),
            if (result.goldAmount > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F131D),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: LevMaxTheme.amberGold),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'GOLD ACQUIRED',
                      style: LevMaxTheme.mono(fontSize: 10, color: LevMaxTheme.onSurfaceVariant),
                    ),
                    Text(
                      '+${result.goldAmount} GOLD',
                      style: LevMaxTheme.headline(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: LevMaxTheme.amberGold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (result.itemName != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F131D),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: themeColor),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        result.itemName!,
                        style: LevMaxTheme.headline(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: themeColor,
              foregroundColor: Colors.black,
            ),
            child: Text(
              'CLAIM & CLOSE',
              style: LevMaxTheme.mono(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: result.type == LootType.collectible ? Colors.white : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // BUILD UTAMA
  // ============================================================================
  @override
  Widget build(BuildContext context) {
    if (_isLoadingGates) {
      return Container(
        height: 380,
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: LevMaxTheme.primaryContainer),
            SizedBox(height: 16),
            Text('SCANNING DIMENSIONAL RIFTS VIA GPS...', style: TextStyle(color: Colors.white70)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Telemetry Strip Bar GPS
        _buildTelemetryBar(),
        const SizedBox(height: 8),

        // 2. ChoiceChips Filter Row
        _buildFilterChipsRow(),
        const SizedBox(height: 12),

        // 3. FLUTTER MAP LBS INTERACTIVE CONTAINER (400px)
        _buildInteractiveFlutterMap(),
        const SizedBox(height: 12),

        // 4. Interactive Bottom Sheet: Selected Target Gate Card
        if (_selectedGate != null) _buildSelectedGateCard(_selectedGate!),
        const SizedBox(height: 14),

        // 5. Weekly Mystery Gates Radar List (7 Titik)
        _buildWeeklyGatesList(),
      ],
    );
  }

  // ============================================================================
  // 1. TELEMETRY BAR
  // ============================================================================
  Widget _buildTelemetryBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: LevMaxTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.satellite_alt,
                color: _isGpsActive ? LevMaxTheme.primaryContainer : Colors.amber,
                size: 15,
              ),
              const SizedBox(width: 8),
              Text(
                'GPS FIX: ${_gpsAccuracy.toStringAsFixed(1)}M // SATELLITE: $_satCount LOCKED',
                style: LevMaxTheme.mono(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: _isGpsActive ? LevMaxTheme.primaryContainer : Colors.amber,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          Text(
            'WEEK: ${DungeonMapService.getCurrentWeekId()}',
            style: LevMaxTheme.mono(
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              color: LevMaxTheme.tertiaryFixed,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // 2. FILTER CHIPS
  // ============================================================================
  Widget _buildFilterChipsRow() {
    final filters = [
      'All Gates',
      'Unclaimed',
      'Claimed',
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: filters.map((label) {
          final isSelected = _filterMode == label;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(label),
              selected: isSelected,
              labelStyle: LevMaxTheme.mono(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.black : LevMaxTheme.onSurfaceVariant,
              ),
              backgroundColor: const Color(0xFF131826),
              selectedColor: LevMaxTheme.primaryContainer,
              side: BorderSide(
                color: isSelected ? LevMaxTheme.primaryContainer : const Color(0xFF1E2638),
              ),
              onSelected: (_) {
                setState(() {
                  _filterMode = label;
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  // ============================================================================
  // 3. FLUTTER MAP LBS DENGAN CARTODB DARK MATTER & PLAYER RADAR
  // ============================================================================
  Widget _buildInteractiveFlutterMap() {
    // Filter gate sesuai filter chip
    List<MysteryGateModel> displayedGates = _gates;
    if (_filterMode == 'Unclaimed') {
      displayedGates = _gates.where((g) => !g.isClaimed).toList();
    } else if (_filterMode == 'Claimed') {
      displayedGates = _gates.where((g) => g.isClaimed).toList();
    }

    return Container(
      height: 380,
      decoration: BoxDecoration(
        color: const Color(0xFF070B12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // FlutterMap Widget dengan TileLayer CartoDB Dark Matter
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(_currentLat, _currentLng),
              initialZoom: 14.5,
              minZoom: 11.0,
              maxZoom: 18.0,
            ),
            children: [
              // 1. TileLayer Peta Gelap CartoDB
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.example.levmax',
              ),

              // 2. Lingkaran Radius Interaksi 50 Meter di Sekitar Pemain
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: LatLng(_currentLat, _currentLng),
                    radius: 50.0,
                    useRadiusInMeter: true,
                    color: const Color(0x2200F0FF),
                    borderColor: const Color(0x6600F0FF),
                    borderStrokeWidth: 1.5,
                  ),
                ],
              ),

              // 3. MarkerLayer: Pin Pemain & 7 Mystery Gate
              MarkerLayer(
                markers: [
                  // A. Pin Pemain dengan Animasi Radar Pulse
                  Marker(
                    point: LatLng(_currentLat, _currentLng),
                    width: 60,
                    height: 60,
                    child: _buildAnimatedPlayerMarker(),
                  ),

                  // B. 7 Pin Mystery Gates Mingguan
                  ...displayedGates.map((gate) {
                    final isSelected = _selectedGate?.id == gate.id;
                    return Marker(
                      point: LatLng(gate.latitude, gate.longitude),
                      width: 52,
                      height: 52,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedGate = gate;
                          });
                        },
                        child: _buildGateMarkerWidget(gate, isSelected: isSelected),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),

          // Watermark Koordinat GPS di Pojok Kiri Atas
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF1E2638)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LAT: ${_currentLat.toStringAsFixed(5)}',
                    style: LevMaxTheme.mono(fontSize: 9, color: LevMaxTheme.primaryContainer),
                  ),
                  Text(
                    'LNG: ${_currentLng.toStringAsFixed(5)}',
                    style: LevMaxTheme.mono(fontSize: 9, color: LevMaxTheme.primaryContainer),
                  ),
                ],
              ),
            ),
          ),

          // Badge RADAR ACTIVE di Pojok Kanan Atas
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: LevMaxTheme.tertiaryFixed.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: LevMaxTheme.tertiaryFixed,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'LBS ACTIVE',
                    style: LevMaxTheme.mono(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: LevMaxTheme.tertiaryFixed,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Tombol Recenter GPS Pemain di Pojok Kanan Bawah
          Positioned(
            bottom: 12,
            right: 12,
            child: FloatingActionButton.small(
              heroTag: 'map_recenter_fab',
              backgroundColor: const Color(0xFF131826),
              onPressed: _recenterMapOnPlayer,
              tooltip: 'Center on Hunter',
              child: const Icon(Icons.my_location, color: LevMaxTheme.primaryContainer, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  // Widget Marker Pemain dengan Animasi Gelombang Radar Pulse
  Widget _buildAnimatedPlayerMarker() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Gelombang Radar Luar
            Transform.scale(
              scale: _pulseScaleAnimation.value,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: LevMaxTheme.primaryContainer.withValues(
                    alpha: _pulseFadeAnimation.value * 0.35,
                  ),
                  border: Border.all(
                    color: LevMaxTheme.primaryContainer.withValues(
                      alpha: _pulseFadeAnimation.value * 0.8,
                    ),
                    width: 1.2,
                  ),
                ),
              ),
            ),

            // Titik Inti Hunter Cyan
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: LevMaxTheme.primaryContainer,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: LevMaxTheme.primaryContainer.withValues(alpha: 0.7),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // Widget Marker Gate di Peta
  Widget _buildGateMarkerWidget(MysteryGateModel gate, {required bool isSelected}) {
    Color accentColor;
    IconData icon;

    if (gate.isClaimed) {
      accentColor = const Color(0xFF313540); // Abu-abu redup setelah di-klaim
      icon = Icons.check_circle_outline;
    } else {
      accentColor = LevMaxTheme.amberGold; // Kuning Emas menyala
      icon = Icons.help_center;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF0F131D),
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? Colors.white : accentColor,
              width: isSelected ? 2.5 : 1.5,
            ),
            boxShadow: [
              if (!gate.isClaimed)
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.4),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
            ],
          ),
          child: Icon(icon, color: accentColor, size: 20),
        ),
      ],
    );
  }

  // ============================================================================
  // 4. BOTTOM SHEET INFO CARD DENGAN VALIDASI JARAK < 50 METER
  // ============================================================================
  Widget _buildSelectedGateCard(MysteryGateModel gate) {
    final double distanceInMeters = DungeonMapService.calculateDistanceInMeters(
      startLat: _currentLat,
      startLng: _currentLng,
      endLat: gate.latitude,
      endLng: gate.longitude,
    );

    final bool isWithinRange = distanceInMeters <= 50.0;
    final String formattedDistance = distanceInMeters < 1000.0
        ? '${distanceInMeters.toInt()}m'
        : '${(distanceInMeters / 1000.0).toStringAsFixed(1)}km';

    final Color statusColor = gate.isClaimed
        ? const Color(0xFF313540)
        : (isWithinRange ? LevMaxTheme.tertiaryFixed : Colors.amber);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1F2A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: gate.isClaimed
              ? const Color(0xFF262A35)
              : (isWithinRange ? LevMaxTheme.primaryContainer : const Color(0xFF1E293B)),
          width: isWithinRange ? 1.5 : 1.0,
        ),
        boxShadow: [
          if (isWithinRange && !gate.isClaimed)
            BoxShadow(
              color: LevMaxTheme.primaryContainer.withValues(alpha: 0.15),
              blurRadius: 16,
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Baris: Badge Rank, Status, & Jarak
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      '[${gate.rank}-RANK GATE]',
                      style: LevMaxTheme.mono(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    gate.isClaimed ? 'CLEARED' : (isWithinRange ? 'TARGET IN RANGE' : 'OUT OF RANGE'),
                    style: LevMaxTheme.mono(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
              Text(
                'JARAK: $formattedDistance',
                style: LevMaxTheme.mono(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isWithinRange ? LevMaxTheme.tertiaryFixed : Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Judul Gate & Deskripsi
          Text(
            gate.name,
            style: LevMaxTheme.headline(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            gate.description,
            style: LevMaxTheme.mono(
              fontSize: 10.5,
              color: LevMaxTheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),

          // TOMBOL EXPLORE GATE DENGAN VALIDASI JARAK < 50 METER
          if (gate.isClaimed) ...[
            Container(
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF262A35),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'GATE TELAH DI-CLEAR // REWARD CLAIMED: ${gate.lootReward ?? "CLEARED"}',
                style: LevMaxTheme.mono(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: LevMaxTheme.outline,
                ),
              ),
            ),
          ] else ...[
            ElevatedButton(
              onPressed: isWithinRange ? () => _exploreGate(gate) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: isWithinRange
                    ? LevMaxTheme.primaryContainer
                    : const Color(0xFF262A35),
                foregroundColor: Colors.black,
                disabledBackgroundColor: const Color(0xFF1E2638),
                disabledForegroundColor: Colors.white30,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: isWithinRange ? 8 : 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isWithinRange ? Icons.explore : Icons.lock_outline,
                    size: 18,
                    color: isWithinRange ? Colors.black : Colors.white30,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isWithinRange
                        ? 'EXPLORE GATE [ENGAGE LOOT]'
                        : 'TARGET TERLALU JAUH: $formattedDistance',
                    style: LevMaxTheme.headline(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      color: isWithinRange ? Colors.black : Colors.white30,
                    ),
                  ),
                ],
              ),
            ),
            if (!isWithinRange) ...[
              const SizedBox(height: 6),
              Text(
                'Dekati lokasi dalam radius 50m dari posisi Hunter Anda untuk membuka gate ini.',
                textAlign: TextAlign.center,
                style: LevMaxTheme.mono(fontSize: 9.5, color: const Color(0xFFFFB4AB)),
              ),
            ],
          ],
        ],
      ),
    );
  }

  // ============================================================================
  // 5. RADAR LIST 7 MYSTERY GATE MINGGUAN
  // ============================================================================
  Widget _buildWeeklyGatesList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'WEEKLY MYSTERY GATES (7 PER MINGGU)',
              style: LevMaxTheme.mono(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: LevMaxTheme.onSurfaceVariant,
              ),
            ),
            Text(
              'RESET SENIN 00:00',
              style: LevMaxTheme.mono(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                color: LevMaxTheme.tertiaryFixed,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        ..._gates.map((gate) {
          final isSelected = _selectedGate?.id == gate.id;
          final double distance = DungeonMapService.calculateDistanceInMeters(
            startLat: _currentLat,
            startLng: _currentLng,
            endLat: gate.latitude,
            endLng: gate.longitude,
          );

          final formattedDist = distance < 1000.0
              ? '${distance.toInt()}m'
              : '${(distance / 1000.0).toStringAsFixed(1)}km';

          final color = gate.isClaimed
              ? const Color(0xFF313540)
              : (distance <= 50.0 ? LevMaxTheme.primaryContainer : LevMaxTheme.amberGold);

          return GestureDetector(
            onTap: () => _recenterMapOnGate(gate),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF131826),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? LevMaxTheme.primaryContainer : const Color(0xFF1E2638),
                  width: isSelected ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F131D),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      gate.isClaimed ? Icons.check : Icons.help_center,
                      color: color,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          gate.name,
                          style: LevMaxTheme.headline(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${gate.rank}-Rank • $formattedDist away • ${gate.isClaimed ? "Cleared" : "Available"}',
                          style: LevMaxTheme.mono(
                            fontSize: 9.5,
                            color: LevMaxTheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? LevMaxTheme.primaryContainer
                          : const Color(0xFF262A35),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'FOCUS',
                      style: LevMaxTheme.mono(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.black : Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
