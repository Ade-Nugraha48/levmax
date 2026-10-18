// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/ui/tabs/profile_tab.dart
// Deskripsi: Tab 4 Bottom Navigation Bar: Profil Player, Dynamic Rank Frame (F-S),
//            Statistik Antropometri BMI, Toggle Biometrik, & Logout (FR-3.4 & FR-1.5)
// ==============================================================================

import 'package:flutter/material.dart';
import '../../helpers/user_info.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_api_service.dart';
import '../auth/login_page.dart';

class ProfileTab extends StatefulWidget {
  final UserModel player;
  final VoidCallback onPlayerUpdated;

  const ProfileTab({
    super.key,
    required this.player,
    required this.onPlayerUpdated,
  });

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadBiometricState();
  }

  Future<void> _loadBiometricState() async {
    final enabled = await UserInfo.getBiometricEnabled();
    if (mounted) {
      setState(() {
        _biometricEnabled = enabled;
      });
    }
  }

  Future<void> _toggleBiometrics(bool val) async {
    setState(() {
      _biometricEnabled = val;
    });
    await UserInfo.setBiometricEnabled(val);

    final updated = widget.player.copyWith(biometricEnabled: val);
    await SupabaseApiService.updateUser(updated);
    widget.onPlayerUpdated();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(val
              ? 'Autentikasi Biometrik Diaktifkan.'
              : 'Autentikasi Biometrik Dinonaktifkan.'),
          backgroundColor: const Color(0xFF00E5FF),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131B2E),
        title: const Text('LOGOUT DARI SISTEM', style: TextStyle(color: Color(0xFF00E5FF))),
        content: const Text(
          'Apakah Anda yakin ingin keluar dari Status Window?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('BATAL', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF1744)),
            child: const Text('LOGOUT', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService.logout();
      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Profil & Dynamic Rank Frame
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF131B2E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: widget.player.rankColor, width: 2),
              boxShadow: [
                BoxShadow(
                  color: widget.player.rankColor.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Column(
              children: [
                // Avatar Frame Solo Leveling Sesuai Rank
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: widget.player.rankColor, width: 3.5),
                        boxShadow: [
                          BoxShadow(
                            color: widget.player.rankColor.withValues(alpha: 0.5),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        backgroundColor: const Color(0xFF0A0E1A),
                        child: Text(
                          widget.player.rank,
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: widget.player.rankColor,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: widget.player.rankColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'RANK ${widget.player.rank}',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                Text(
                  widget.player.username.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.player.rankTitle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: widget.player.rankColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.player.email,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Detail Statistik Antropometri & BMI
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
                const Text(
                  'STATISTIK FISIK & BMI HUNTER',
                  style: TextStyle(
                    color: Color(0xFF00E5FF),
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatItem('TB', '${widget.player.tbCm.toInt()} cm'),
                    _buildStatItem('BB', '${widget.player.bbKg.toInt()} kg'),
                    _buildStatItem('BMI', widget.player.bmi.toStringAsFixed(1)),
                    _buildStatItem('STATUS', widget.player.bmiCategory.split(' ').first),
                  ],
                ),
                const Divider(color: Color(0xFF1E293B), height: 24),
                const Text(
                  'Kapasitas Repetisi Awal:',
                  style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '• Push-up: ${widget.player.maxPushup} reps   • Sit-up: ${widget.player.maxSitup} reps\n• Squat: ${widget.player.maxSquat} reps       • Pull-up: ${widget.player.maxPullup} reps\n• Jarak Lari: ${widget.player.maxRunKm} km   • Pace: ${widget.player.pace2kmMenit} min/2km',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Pengaturan Biometrik
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF131B2E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.fingerprint, color: Color(0xFF00E5FF), size: 28),
              title: const Text(
                'Autentikasi Biometrik',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: const Text(
                'Masuk lebih cepat menggunakan Sidik Jari / Face ID',
                style: TextStyle(color: Colors.grey, fontSize: 11),
              ),
              activeThumbColor: const Color(0xFF00E5FF),
              value: _biometricEnabled,
              onChanged: _toggleBiometrics,
            ),
          ),
          const SizedBox(height: 24),

          // Tombol Logout
          OutlinedButton.icon(
            onPressed: _handleLogout,
            icon: const Icon(Icons.logout, color: Color(0xFFFF1744)),
            label: const Text(
              'LOGOUT DARI SISTEM',
              style: TextStyle(color: Color(0xFFFF1744), fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFFF1744)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 14, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}
