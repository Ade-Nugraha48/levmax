// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/ui/tabs/profile_biometric_widget.dart
// Deskripsi: Widget Modular Pengaturan Face ID & Fingerprint Terpisah (Alur 4)
//            untuk Tab Profil Player Sesuai Standar Industri Keamanan Perbankan.
// ==============================================================================

import 'package:flutter/material.dart';
import '../../helpers/user_info.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/biometric_service.dart';
import '../auth/face_scan_camera_page.dart';
import '../auth/fingerprint_scan_page.dart';

class ProfileBiometricWidget extends StatefulWidget {
  final UserModel player;
  final VoidCallback onPlayerUpdated;

  const ProfileBiometricWidget({
    super.key,
    required this.player,
    required this.onPlayerUpdated,
  });

  @override
  State<ProfileBiometricWidget> createState() => _ProfileBiometricWidgetState();
}

class _ProfileBiometricWidgetState extends State<ProfileBiometricWidget> {
  bool _faceIdEnabled = false;
  bool _fingerprintEnabled = false;
  bool _hasEnrolledFace = false;
  bool _hasEnrolledFingerprint = false;
  bool _isProcessingFace = false;
  bool _isProcessingFingerprint = false;
  BiometricCapability? _capability;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  @override
  void didUpdateWidget(covariant ProfileBiometricWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.player.biometricEnabled != widget.player.biometricEnabled) {
      _loadState();
    }
  }

  Future<void> _loadState() async {
    final cap = await BiometricService.checkCapability();
    final facePref = await UserInfo.getFaceIdEnabled();
    final fpPref = await UserInfo.getFingerprintEnabled();
    final anyPref = await UserInfo.getBiometricEnabled();
    final hasEnrolled = await UserInfo.getHasEnrolledFace();
    final hasEnrolledFp = await UserInfo.getHasEnrolledFingerprint();

    // Jika di database user sudah aktif tetapi lokal belum di-set spesifik:
    bool effectiveFace = facePref;
    bool effectiveFp = fpPref;
    if (widget.player.biometricEnabled && !facePref && !fpPref) {
      effectiveFace = true;
      effectiveFp = true;
      await UserInfo.setFaceIdEnabled(true);
      await UserInfo.setFingerprintEnabled(true);
    } else if (anyPref && !facePref && !fpPref) {
      effectiveFace = true;
      effectiveFp = true;
      await UserInfo.setFaceIdEnabled(true);
      await UserInfo.setFingerprintEnabled(true);
    }

    if (mounted) {
      setState(() {
        _capability = cap;
        _faceIdEnabled = effectiveFace;
        _fingerprintEnabled = effectiveFp;
        _hasEnrolledFace = hasEnrolled;
        _hasEnrolledFingerprint = hasEnrolledFp;
      });
    }
  }

  // ============================================================================
  // LOGIKA SETOR / PERBARUI WAJAH PATOKAN SEKURITAS (ENROLLMENT)
  // ============================================================================
  Future<void> _handleEnrollOrUpdateFace() async {
    if (_isProcessingFace || _isProcessingFingerprint) return;

    setState(() {
      _isProcessingFace = true;
    });

    final scanSuccess = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => FaceScanCameraPage(
          mode: FaceScanMode.enroll,
          title: _hasEnrolledFace ? 'PERBARUI WAJAH PATOKAN' : 'SETOR WAJAH PATOKAN',
          subtitle: 'Posisikan wajah Anda tegak lurus di lingkaran pemindai untuk merekam patokan',
        ),
      ),
    );

    if (!mounted) return;

    setState(() {
      _isProcessingFace = false;
    });

    if (scanSuccess == true) {
      await _loadState();
      widget.onPlayerUpdated();
      _showFeedbackSnackBar(
        'Wajah patokan sekuritas berhasil disimpan ke Sistem LevMax!',
        isSuccess: true,
      );
    } else {
      _showFeedbackSnackBar(
        'Perekaman wajah patokan dibatalkan.',
        isSuccess: false,
      );
    }
  }

  // ============================================================================
  // LOGIKA SETOR / PERBARUI SIDIK JARI PATOKAN SEKURITAS (ENROLLMENT)
  // ============================================================================
  Future<void> _handleEnrollOrUpdateFingerprint() async {
    if (_isProcessingFace || _isProcessingFingerprint) return;

    setState(() {
      _isProcessingFingerprint = true;
    });

    final scanSuccess = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => FingerprintScanPage(
          mode: FingerprintScanMode.enroll,
          title: _hasEnrolledFingerprint ? 'PERBARUI SIDIK JARI PATOKAN' : 'SETOR SIDIK JARI PATOKAN',
          subtitle: 'Lakukan 3 sentuhan bertahap untuk merekam patokan sidik jari sekuritas',
        ),
      ),
    );

    if (!mounted) return;

    setState(() {
      _isProcessingFingerprint = false;
    });

    if (scanSuccess == true) {
      await _loadState();
      widget.onPlayerUpdated();
      _showFeedbackSnackBar(
        'Sidik jari patokan sekuritas berhasil disimpan ke Sistem LevMax!',
        isSuccess: true,
      );
    } else {
      _showFeedbackSnackBar(
        'Perekaman sidik jari patokan dibatalkan.',
        isSuccess: false,
      );
    }
  }

  // ============================================================================
  // LOGIKA TOGGLE FACE SCAN KAMERA (VERIFIKASI FISIK KAMERA DEPAN)
  // ============================================================================
  Future<void> _handleFaceIdToggle(bool val) async {
    if (_isProcessingFace || _isProcessingFingerprint) return;

    // Jika ingin MENGAKTIFKAN tapi BELUM PERNAH SETOR WAJAH:
    // Wajib setor wajah terlebih dahulu!
    if (val && !_hasEnrolledFace) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF131B2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF00E5FF), width: 1.5),
          ),
          title: const Row(
            children: [
              Icon(Icons.face_unlock_outlined, color: Color(0xFF00E5FF)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Setor Wajah Patokan',
                  style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          content: const Text(
            'Untuk mengaktifkan Face ID, Anda harus menyetor wajah Anda terlebih dahulu agar sistem memiliki patokan biometrik untuk memverifikasi identitas Anda.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('BATAL', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: Colors.black,
              ),
              child: const Text('SETOR WAJAH SEKARANG', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (proceed != true) {
        setState(() {
          _faceIdEnabled = false;
        });
        return;
      }

      await _handleEnrollOrUpdateFace();
      return;
    }

    setState(() {
      _isProcessingFace = true;
    });

    // Buka Layar Kamera Depan Fisik untuk Verifikasi Face Scan
    final scanSuccess = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => FaceScanCameraPage(
          mode: FaceScanMode.toggle,
          title: val ? 'KONFIRMASI AKTIFKAN FACE ID' : 'KONFIRMASI NONAKTIFKAN FACE ID',
          subtitle: val
              ? 'Verifikasi wajah Anda untuk mengaktifkan Face ID Hunter'
              : 'Verifikasi wajah Anda untuk menonaktifkan fitur ini',
        ),
      ),
    );

    if (!mounted) return;

    if (scanSuccess == true) {
      final res = await AuthService.setFaceIdStatusForUser(
        userId: widget.player.id,
        enable: val,
      );

      setState(() {
        _isProcessingFace = false;
        _faceIdEnabled = val;
      });
      widget.onPlayerUpdated();
      _showFeedbackSnackBar(
        res['message'] ?? 'Pengaturan Face Scan Diperbarui.',
        isSuccess: true,
      );
    } else {
      // Revert switch ke nilai semula
      setState(() {
        _isProcessingFace = false;
        _faceIdEnabled = !val;
      });
      _showFeedbackSnackBar(
        'Verifikasi pemindaian wajah kamera dibatalkan.',
        isSuccess: false,
      );
    }
  }

  // ============================================================================
  // LOGIKA TOGGLE FINGERPRINT (VERIFIKASI SENSOR WAJIB & PATOKAN)
  // ============================================================================
  Future<void> _handleFingerprintToggle(bool val) async {
    if (_isProcessingFace || _isProcessingFingerprint) return;

    // Jika ingin MENGAKTIFKAN tapi BELUM PERNAH SETOR SIDIK JARI:
    // Wajib setor sidik jari terlebih dahulu!
    if (val && !_hasEnrolledFingerprint) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF131B2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF00E5FF), width: 1.5),
          ),
          title: const Row(
            children: [
              Icon(Icons.fingerprint, color: Color(0xFF00E5FF)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Setor Sidik Jari Patokan',
                  style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          content: const Text(
            'Untuk mengaktifkan Fingerprint, Anda harus menyetor sidik jari Anda terlebih dahulu agar sistem memiliki patokan biometrik yang sah.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('BATAL', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: Colors.black,
              ),
              child: const Text('SETOR SIDIK JARI SEKARANG', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (proceed != true) {
        setState(() {
          _fingerprintEnabled = false;
        });
        return;
      }

      await _handleEnrollOrUpdateFingerprint();
      return;
    }

    setState(() {
      _isProcessingFingerprint = true;
    });

    // Buka Layar Verifikasi Sidik Jari Asli
    final scanSuccess = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => FingerprintScanPage(
          mode: FingerprintScanMode.toggle,
          title: val ? 'KONFIRMASI AKTIFKAN FINGERPRINT' : 'KONFIRMASI NONAKTIFKAN FINGERPRINT',
          subtitle: val
              ? 'Verifikasi sidik jari Anda untuk mengaktifkan akses cepat'
              : 'Konfirmasi sidik jari Anda untuk menonaktifkan fitur ini',
        ),
      ),
    );

    if (!mounted) return;

    if (scanSuccess == true) {
      final res = await AuthService.toggleFingerprintForUser(
        userId: widget.player.id,
        enable: val,
      );

      setState(() {
        _isProcessingFingerprint = false;
        _fingerprintEnabled = val;
      });
      widget.onPlayerUpdated();
      _showFeedbackSnackBar(
        res['message'] ?? 'Pengaturan Fingerprint Diperbarui.',
        isSuccess: true,
      );
    } else {
      // Revert switch ke nilai semula
      setState(() {
        _isProcessingFingerprint = false;
        _fingerprintEnabled = !val;
      });
      _showFeedbackSnackBar(
        'Verifikasi sidik jari dibatalkan.',
        isSuccess: false,
      );
    }
  }

  void _showFeedbackSnackBar(String message, {required bool isSuccess}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle_outline : Icons.warning_amber_rounded,
              color: isSuccess ? Colors.black : Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: isSuccess ? Colors.black : Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isSuccess ? const Color(0xFF00E5FF) : const Color(0xFFFFA000),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cap = _capability;
    final hasFaceHardware = cap?.hasFace ?? true;
    final hasFpHardware = cap?.hasFingerprint ?? true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header Bagian Pengaturan Biometrik
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'KEAMANAN BIOMETRIK HUNTER',
              style: TextStyle(
                color: Color(0xFF00E5FF),
                fontWeight: FontWeight.w900,
                fontSize: 13,
                letterSpacing: 1.0,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF7B1FA2).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF7B1FA2)),
              ),
              child: const Text(
                'STANDAR INDUSTRI',
                style: TextStyle(
                  color: Color(0xFF00E5FF),
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // OPSI 1: FACE ID / BIOMETRIK WAJAH
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF131B2E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _faceIdEnabled
                  ? const Color(0xFF00E5FF).withValues(alpha: 0.6)
                  : const Color(0xFF1E293B),
              width: 1.2,
            ),
          ),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _faceIdEnabled
                    ? const Color(0xFF00E5FF).withValues(alpha: 0.15)
                    : const Color(0xFF0A0E1A),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _faceIdEnabled ? const Color(0xFF00E5FF) : const Color(0xFF1E293B),
                ),
              ),
              child: _isProcessingFace
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E5FF)),
                    )
                  : Icon(
                      Icons.face_unlock_outlined,
                      color: _faceIdEnabled ? const Color(0xFF00E5FF) : Colors.grey,
                      size: 24,
                    ),
            ),
            title: const Text(
              'Face ID / Biometrik Wajah',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.white,
              ),
            ),
            subtitle: Text(
              !hasFaceHardware
                  ? 'Sensor tidak terdeteksi pada perangkat'
                  : _faceIdEnabled
                      ? 'Status: Aktif (Otorisasi instan via kamera depan 2D M31)'
                      : 'Status: Nonaktif (Arahkan wajah untuk Quick Login)',
              style: TextStyle(
                color: _faceIdEnabled ? const Color(0xFF00E5FF).withValues(alpha: 0.8) : Colors.grey,
                fontSize: 11,
              ),
            ),
            activeThumbColor: const Color(0xFF00E5FF),
            value: _faceIdEnabled,
            onChanged: _isProcessingFace || _isProcessingFingerprint
                ? null
                : (val) => _handleFaceIdToggle(val),
          ),
        ),

        // KARTU STATUS PATOKAN WAJAH SEKURITAS (SETOR WAJAH)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hasEnrolledFace
                  ? const Color(0xFF00E5FF).withValues(alpha: 0.4)
                  : const Color(0xFFFFB300).withValues(alpha: 0.5),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    _hasEnrolledFace ? Icons.verified_user : Icons.warning_amber_rounded,
                    color: _hasEnrolledFace ? const Color(0xFF00E5FF) : const Color(0xFFFFB300),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _hasEnrolledFace ? 'PATOKAN WAJAH SEKURITAS TERDAFTAR' : 'WAJAH PATOKAN BELUM DISETOR',
                      style: TextStyle(
                        color: _hasEnrolledFace ? const Color(0xFF00E5FF) : const Color(0xFFFFB300),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _hasEnrolledFace
                    ? 'Struktur biometrik wajah Anda telah tersimpan sebagai patokan verifikasi Face ID.'
                    : 'Setor wajah Anda ke sistem agar sensor Face ID dapat mengidentifikasi Anda dengan akurat.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _isProcessingFace ? null : _handleEnrollOrUpdateFace,
                icon: Icon(
                  _hasEnrolledFace ? Icons.refresh : Icons.add_a_photo_outlined,
                  color: const Color(0xFF00E5FF),
                  size: 16,
                ),
                label: Text(
                  _hasEnrolledFace ? 'PERBARUI WAJAH PATOKAN' : 'SETOR WAJAH SEKARANG',
                  style: const TextStyle(
                    color: Color(0xFF00E5FF),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF00E5FF)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),

        // OPSI 2: FINGERPRINT / SENSOR SIDIK JARI
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF131B2E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _fingerprintEnabled
                  ? const Color(0xFF00E5FF).withValues(alpha: 0.6)
                  : const Color(0xFF1E293B),
              width: 1.2,
            ),
          ),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _fingerprintEnabled
                    ? const Color(0xFF00E5FF).withValues(alpha: 0.15)
                    : const Color(0xFF0A0E1A),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _fingerprintEnabled ? const Color(0xFF00E5FF) : const Color(0xFF1E293B),
                ),
              ),
              child: _isProcessingFingerprint
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E5FF)),
                    )
                  : Icon(
                      Icons.fingerprint,
                      color: _fingerprintEnabled ? const Color(0xFF00E5FF) : Colors.grey,
                      size: 24,
                    ),
            ),
            title: const Text(
              'Fingerprint / Sidik Jari',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.white,
              ),
            ),
            subtitle: Text(
              !hasFpHardware
                  ? 'Sensor sidik jari tidak terdeteksi pada perangkat'
                  : _fingerprintEnabled
                      ? 'Status: Aktif (Otorisasi instan via sensor sidik jari)'
                      : 'Status: Nonaktif (Tempelkan jari untuk Quick Login)',
              style: TextStyle(
                color: _fingerprintEnabled ? const Color(0xFF00E5FF).withValues(alpha: 0.8) : Colors.grey,
                fontSize: 11,
              ),
            ),
            activeThumbColor: const Color(0xFF00E5FF),
            value: _fingerprintEnabled,
            onChanged: _isProcessingFace || _isProcessingFingerprint
                ? null
                : (val) => _handleFingerprintToggle(val),
          ),
        ),

        // KARTU STATUS PATOKAN SIDIK JARI SEKURITAS (SETOR SIDIK JARI)
        Container(
          margin: const EdgeInsets.only(top: 8, bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hasEnrolledFingerprint
                  ? const Color(0xFF00E5FF).withValues(alpha: 0.4)
                  : const Color(0xFFFFB300).withValues(alpha: 0.5),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    _hasEnrolledFingerprint ? Icons.verified_user : Icons.warning_amber_rounded,
                    color: _hasEnrolledFingerprint ? const Color(0xFF00E5FF) : const Color(0xFFFFB300),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _hasEnrolledFingerprint ? 'PATOKAN SIDIK JARI TERDAFTAR' : 'SIDIK JARI PATOKAN BELUM DISETOR',
                      style: TextStyle(
                        color: _hasEnrolledFingerprint ? const Color(0xFF00E5FF) : const Color(0xFFFFB300),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _hasEnrolledFingerprint
                    ? 'Patokan sidik jari Anda telah tervalidasi dan siap digunakan untuk otorisasi instan.'
                    : 'Setor sidik jari Anda ke sistem (3 sentuhan kalibrasi) agar dapat digunakan untuk login cepat.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _isProcessingFingerprint ? null : _handleEnrollOrUpdateFingerprint,
                icon: Icon(
                  _hasEnrolledFingerprint ? Icons.refresh : Icons.fingerprint,
                  color: const Color(0xFF00E5FF),
                  size: 16,
                ),
                label: Text(
                  _hasEnrolledFingerprint ? 'PERBARUI SIDIK JARI' : 'SETOR SIDIK JARI SEKARANG',
                  style: const TextStyle(
                    color: Color(0xFF00E5FF),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF00E5FF)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Catatan Kebijakan Keamanan Perangkat
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0E1A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.security, color: Color(0xFF00E5FF), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Kedua opsi dapat diaktifkan bersamaan atau salah satu saja. Pengaktifan dan penonaktifan mewajibkan verifikasi sensor demi keamanan akun.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
