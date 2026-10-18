// Tab Profil Hunter dan Pengaturan Sesi
import 'package:flutter/material.dart';
import '../../helpers/user_info.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_api_service.dart';
import '../login_page.dart';

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
  // State pengaturan biometrik
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    // Memuat preferensi biometrik lokal
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

  // Mengubah preferensi biometrik dan sinkronisasi ke Supabase
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
              ? 'Autentikasi biometrik diaktifkan.'
              : 'Autentikasi biometrik dinonaktifkan.'),
          backgroundColor: const Color(0xFF00E5FF),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // Proses keluar sesi dan pembersihan SharedPreferences
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

      // Navigasi kembali ke LoginPage dan bersihkan stack navigasi
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
          // Kartu Header Profil & Bingkai Dinamis Sesuai Rank
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF131B2E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: widget.player.rankColor, width: 2),
              boxShadow: [
                BoxShadow(
                  color: widget.player.rankColor.withValues(alpha: 0.35),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
                if (widget.player.rank == 'S')
                  BoxShadow(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                    blurRadius: 30,
                    spreadRadius: 6,
                  ),
              ],
            ),
            child: Column(
              children: [
                // Avatar Frame Dinamis Solo Leveling
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.player.rankColor,
                          width: widget.player.rank == 'S' ? 4.0 : 3.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: widget.player.rankColor.withValues(alpha: 0.5),
                            blurRadius: 18,
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        backgroundColor: const Color(0xFF0A0E1A),
                        child: Text(
                          widget.player.rank,
                          style: TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            color: widget.player.rankColor,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: widget.player.rankColor,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Text(
                          'RANK ${widget.player.rank}',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
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

          // Detail Statistik Fisik dan Skor BMI
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
                const Row(
                  children: [
                    Icon(Icons.monitor_weight_outlined, color: Color(0xFF00E5FF), size: 18),
                    SizedBox(width: 8),
                    Text(
                      'STATISTIK FISIK & BMI HUNTER',
                      style: TextStyle(
                        color: Color(0xFF00E5FF),
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

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
                  'Kapasitas Repetisi & Cardio Awal:',
                  style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '• Push-up: ${widget.player.maxPushup} reps   • Sit-up: ${widget.player.maxSitup} reps\n• Squat: ${widget.player.maxSquat} reps       • Pull-up: ${widget.player.maxPullup} reps\n• Jarak Lari: ${widget.player.maxRunKm} km   • Pace: ${widget.player.pace2kmMenit} min/2km',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 11.5,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.player.bmiRecommendation,
                  style: const TextStyle(
                    color: Color(0xFF00E5FF),
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Pengaturan Biometrik Sidik Jari / Face ID
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
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              subtitle: const Text(
                'Buka Status Window cepat via sensor sidik jari atau wajah',
                style: TextStyle(color: Colors.grey, fontSize: 11),
              ),
              activeThumbColor: const Color(0xFF00E5FF),
              value: _biometricEnabled,
              onChanged: _toggleBiometrics,
            ),
          ),
          const SizedBox(height: 24),

          // Tombol Logout Sesi
          OutlinedButton.icon(
            onPressed: _handleLogout,
            icon: const Icon(Icons.logout, color: Color(0xFFFF1744)),
            label: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'LOGOUT DARI SISTEM',
                style: TextStyle(color: Color(0xFFFF1744), fontWeight: FontWeight.bold),
              ),
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
