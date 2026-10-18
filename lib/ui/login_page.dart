// Halaman Login Kredensial dan Biometrik
import 'package:flutter/material.dart';
import '../helpers/user_info.dart';
import '../services/auth_service.dart';
import '../services/supabase_api_service.dart';
import 'onboarding_page.dart';
import 'main_navigation_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Controller input form
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  // State tampilan form
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _canUseBiometrics = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Pengecekan ketersediaan sensor biometrik
    _checkBiometricsSupport();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Memeriksa status biometrik di perangkat dan SharedPreferences
  Future<void> _checkBiometricsSupport() async {
    final canAuth = await AuthService.canAuthenticateWithBiometrics();
    final hasBiometricPref = await UserInfo.getBiometricEnabled();
    if (mounted) {
      setState(() {
        _canUseBiometrics = canAuth && hasBiometricPref;
      });
    }
  }

  // Validasi form dan proses login kredensial SHA-256
  Future<void> _handleLogin() async {
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Otentikasi username dan password
    final res = await AuthService.login(
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (res['success'] == true) {
      final user = res['user'];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Otorisasi berhasil diterima sistem.'),
          backgroundColor: const Color(0xFF00E5FF),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Routing berdasarkan status onboarding fisik
      if (user != null && user.isOnboarded) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigationPage()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const OnboardingPage()),
        );
      }
    } else {
      setState(() {
        _errorMessage = res['message'] ?? 'Gagal masuk ke sistem.';
      });
    }
  }

  // Verifikasi biometrik sidik jari atau Face ID
  Future<void> _handleBiometricLogin() async {
    final authOk = await AuthService.authenticateWithBiometrics(
      reason: 'Pindai sidik jari atau wajah untuk membuka Status Window Hunter',
    );

    if (!authOk || !mounted) return;

    // Ambil data profil dari cache lokal
    final cachedUser = SupabaseApiService.getPlayerCache();
    if (cachedUser != null) {
      await UserInfo.setLoginStatus(true);
      await UserInfo.updateLastActive();

      if (!mounted) return;

      if (cachedUser.isOnboarded) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigationPage()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const OnboardingPage()),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data profil belum tersimpan di perangkat. Masuk secara manual terlebih dahulu.'),
          backgroundColor: Colors.amber,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Ikon lambang Hunter
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF131B2E),
                      border: Border.all(color: const Color(0xFF00E5FF), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      size: 44,
                      color: Color(0xFF00E5FF),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Judul aplikasi
                const Text(
                  'LEVMAX SYSTEM',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4.0,
                    color: Color(0xFF00E5FF),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Verifikasi Otorisasi Hunter Solo Leveling',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 32),

                // Notifikasi pesan error
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF1744).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFF1744)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Color(0xFFFF1744), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Color(0xFFFF1744), fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Form validasi kredensial
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Input Username
                      TextFormField(
                        controller: _usernameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Nama Hunter / Username',
                          labelStyle: const TextStyle(color: Color(0xFF00E5FF)),
                          prefixIcon: const Icon(Icons.person, color: Color(0xFF00E5FF)),
                          filled: true,
                          fillColor: const Color(0xFF131B2E),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF1E293B)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF1E293B)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF00E5FF), width: 2),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Harap masukkan nama Hunter Anda.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Input Password
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Password Akses (SHA-256)',
                          labelStyle: const TextStyle(color: Color(0xFF00E5FF)),
                          prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF00E5FF)),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          filled: true,
                          fillColor: const Color(0xFF131B2E),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF1E293B)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF1E293B)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF00E5FF), width: 2),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Harap masukkan password.';
                          }
                          if (value.length < 6) {
                            return 'Password minimal 6 karakter.';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Tombol Submit Form Login
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5FF),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 6,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                        )
                      : const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'ENTER THE SYSTEM (LOGIN)',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                          ),
                        ),
                ),
                const SizedBox(height: 16),

                // Tombol login biometrik jika aktif
                if (_canUseBiometrics) ...[
                  OutlinedButton.icon(
                    onPressed: _handleBiometricLogin,
                    icon: const Icon(Icons.fingerprint, color: Color(0xFF00E5FF), size: 28),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'BUKA DENGAN BIOMETRIK / SIDIK JARI',
                        style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF00E5FF)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Navigasi ke pendaftaran akun
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Belum memiliki otorisasi Hunter? ',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const RegisterPage()),
                        );
                      },
                      child: const Text(
                        'DAFTAR SEKARANG',
                        style: TextStyle(
                          color: Color(0xFF00E5FF),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
