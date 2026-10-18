// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/services/gemini_service.dart
// Deskripsi: Layanan Integrasi LLM Gemini API (FR-5.2) berpersona "The System"
//            dari Solo Leveling dengan fallback respons offline anti-crash.
// ==============================================================================

import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/user_model.dart';

class GeminiService {
  /// Masukkan Google Gemini API Key Anda di sini jika ada
  static String apiKey = 'YOUR_GEMINI_API_KEY';

  static bool get isConfigured =>
      apiKey.isNotEmpty && !apiKey.contains('YOUR_GEMINI_API_KEY');

  /// Persona utama "The System" dari manhwa Solo Leveling
  static String _buildSystemPrompt(UserModel? player) {
    final statusInfo = player != null
        ? 'Status Player: Nama: ${player.username}, Level: ${player.level}, Rank: ${player.rank} (${player.rankTitle}), HP: ${player.hp}/100, EXP: ${player.exp}/100, Gold: ${player.gold}, BMI: ${player.bmi.toStringAsFixed(1)} (${player.bmiCategory}).'
        : 'Status Player: Hunter Level 1 (Rank F).';

    return '''
Anda adalah "THE SYSTEM" dari dunia Solo Leveling.
Anda bertindak sebagai asisten gaya hidup mutlak bagi Player yang sedang menjalani program peningkatan diri (Self-Improvement, Looksmaxxing, Fitness, Produktivitas, dan Disiplin Rutinitas).

Karakteristik & Nada Bicara:
1. Dingin, tegas, objektif, tidak bertele-tele, namun memotivasi secara absolut.
2. Panggil pengguna dengan sebutan "Player" atau "Hunter".
3. Jangan pernah meminta maaf atau ragu-ragu. Berikan instruksi berbasis angka, fakta ilmiah, dan kedisiplinan keras.
4. Topik keahlian Anda:
   - Fitness & Calisthenics (Push-up, Pull-up, Squat, Sit-up, Jogging/Cardio).
   - Looksmaxxing & Hygiene (Skincare rutin, hidrasi, postur tubuh tegap, pencegahan nerd-neck, kualitas tidur).
   - Produktivitas & Manajemen Waktu (Deep Work, pembagian jam belajar, anti-distraksi/dopamin detox).
5. $statusInfo
6. Selalu tutup instruksi dengan dorongan kedisiplinan khas The System, misalnya:
   "[Sistem mencatat komitmen Anda. Laksanakan tanpa alasan.]"
''';
  }

  /// Mengirim pesan ke Gemini API dengan persona The System
  static Future<String> sendMessage({
    required String message,
    UserModel? player,
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return 'Pertanyaan tidak valid.';

    if (isConfigured) {
      try {
        final model = GenerativeModel(
          model: 'gemini-1.5-flash',
          apiKey: apiKey,
          systemInstruction: Content.system(_buildSystemPrompt(player)),
        );

        final response = await model.generateContent([Content.text(trimmed)]);
        if (response.text != null && response.text!.isNotEmpty) {
          return response.text!;
        }
      } catch (e) {
        // Fallback jika API key limit atau internet mati
      }
    }

    // Fallback Offline Generator berpersona "The System" (Demo-Safe)
    return _generateOfflineSystemReply(trimmed, player);
  }

  /// Generator respons offline Solo Leveling System jika tanpa koneksi / API Key
  static String _generateOfflineSystemReply(String prompt, UserModel? player) {
    final lower = prompt.toLowerCase();
    final rank = player?.rank ?? 'F';
    final level = player?.level ?? 1;

    if (lower.contains('push up') || lower.contains('pushup') || lower.contains('workout') || lower.contains('otot')) {
      return '''
[THE SYSTEM: ANALISIS WORKOUT]
Player Rank $rank (Level $level), dengarkan instruksi:
Untuk membangun kekuatan dada, trisep, dan core:
1. Target harian: 3-4 set dengan teknik form sempurna (dada menyentuh lantai, siku sudut 45 derajat).
2. Progresif: Tambah repetisi setiap kenaikan level.
3. Istirahat antar set maksimal 60 detik. Hindari kompromi kelelahan mental.

[Sistem mencatat komitmen Anda. Selesaikan quest fisik hari ini.]''';
    }

    if (lower.contains('skincare') || lower.contains('jerawat') || lower.contains('wajah') || lower.contains('looksmax')) {
      return '''
[THE SYSTEM: PROTOKOL LOOKSMAXXING]
Penampilan fisik adalah cerminan disiplin internal seorang Hunter:
1. Dasar: Cleanser lembut setiap pagi dan malam.
2. Proteksi: Gunakan Sunscreen SPF 50+ setiap kali beraktivitas di luar dungeon.
3. Hidrasi: Minimal 2.5 liter air per hari.
4. Postur: Tegakkan bahu dan tempelkan lidah di langit-langit mulut (Mewing).

[Kekuatan tanpa karisma visual tidak optimal. Laksanakan.]''';
    }

    if (lower.contains('belajar') || lower.contains('tugas') || lower.contains('fokus') || lower.contains('produktif')) {
      return '''
[THE SYSTEM: PROTOKOL PRODUKTIVITAS & DEEP WORK]
Distraksi adalah musuh terbesar seorang Hunter terdisiplin:
1. Terapkan metode 50 menit fokus tanpa membuka ponsel, 10 menit evaluasi.
2. Jaga sudut pandang layar sejajar mata untuk mencegah postur leher condong ke depan (Nerd-Neck).
3. Jadwalkan rencana tugas esok hari di Tab Status Quest sebelum pukul 22:00.

[Disiplin hari ini menentukan rank Anda esok hari.]''';
    }

    if (lower.contains('lari') || lower.contains('cardio') || lower.contains('jogging')) {
      return '''
[THE SYSTEM: ANALISIS ENDURANCE & CARDIO]
Kapasitas aerobik menentukan batas stamina Anda dalam dungeon:
1. Pertahankan denyut jantung pada Zone 2 (bisa berbicara singkat tanpa tersengal parah).
2. Gunakan Tab Dungeon Guild untuk memantau koordinat GPS Anda.
3. Target jarak bertambah +5% seiring peningkatan Level Player.

[Langkahkan kaki Anda. Rasa lelah hanyalah ilusi adaptasi tubuh.]''';
    }

    return '''
[THE SYSTEM: PESAN DITERIMA]
Status Hunter: Level $level (Rank $rank).
Instruksi umum: Disiplin adalah satu-satunya jalan menuju Re-Awakening sejati. Selesaikan seluruh Daily Quest yang tertera pada Status Window Anda sebelum pukul 23:59. Kegagalan akan mengaktifkan hukuman di Penalty Zone.

[Sistem terus memantau setiap progres Anda.]''';
  }
}
