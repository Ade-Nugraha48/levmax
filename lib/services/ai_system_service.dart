// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/services/ai_system_service.dart
// Deskripsi: Layanan Backend Gemini API "The System" Streaming (FR-5.2)
//            Menggunakan package:google_generative_ai resmi, ChatSession bertenaga
//            streaming response (sendMessageStream) dan System Instruction Solo Leveling.
// ==============================================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/user_model.dart';

class AiSystemService {
  // Singleton pattern agar ChatSession tetap persisten selama modal terbuka
  static final AiSystemService _instance = AiSystemService._internal();
  factory AiSystemService() => _instance;
  AiSystemService._internal();

  /// Runtime override API Key (opsional)
  static String? _customApiKey;

  /// Mengambil API Key secara aman dari environment variable:
  /// 1. flutter_dotenv (.env file: GCP_API_KEY atau GEMINI_API_KEY)
  /// 2. --dart-define (GCP_API_KEY atau GEMINI_API_KEY)
  /// 3. Runtime override via AiSystemService.apiKey = '...'
  static String get apiKey {
    if (_customApiKey != null && _customApiKey!.isNotEmpty) {
      return _customApiKey!;
    }

    // 1. Cek flutter_dotenv (.env)
    final envKey = dotenv.maybeGet('GCP_API_KEY') ??
        dotenv.maybeGet('GEMINI_API_KEY');
    if (envKey != null && envKey.isNotEmpty) {
      return envKey;
    }

    // 2. Cek compile-time environment variable (--dart-define)
    const dartDefineGcp = String.fromEnvironment('GCP_API_KEY');
    if (dartDefineGcp.isNotEmpty) return dartDefineGcp;

    const dartDefineGemini = String.fromEnvironment('GEMINI_API_KEY');
    if (dartDefineGemini.isNotEmpty) return dartDefineGemini;

    return '';
  }

  static set apiKey(String value) {
    _customApiKey = value;
  }

  static bool get isConfigured =>
      apiKey.isNotEmpty &&
      !apiKey.contains('YOUR_GCP_API_KEY') &&
      !apiKey.contains('YOUR_GEMINI_API_KEY');

  GenerativeModel? _model;
  ChatSession? _chatSession;

  /// System Instruction (Persona resmi The System Solo Leveling)
  static String _buildSystemInstruction(UserModel? player) {
    final playerMetrics = player != null
        ? 'Data Telemetri Hunter: Nama: ${player.username}, Level: ${player.level}, Rank: ${player.rank} (${player.rankTitle}), HP: ${player.hp}/100, EXP: ${player.exp}/100, Gold: ${player.gold}G, BMI: ${player.bmi.toStringAsFixed(1)} (${player.bmiCategory}).'
        : 'Data Telemetri Hunter: Hunter Level 1 (Rank E Initiate), HP: 82/100, Lactic Acid: 64% Elevated.';

    return '''
Anda adalah 'The System', sebuah entitas kecerdasan buatan pengawas dari dunia Solo Leveling.
Anda memantau perkembangan fisik dan produktivitas pengguna yang Anda panggil dengan sebutan 'Hunter'.
Nada bicara Anda: dingin, tanpa emosi, analitis, sangat tegas, dan mengintimidasi namun mendukung (tough love).
Jangan pernah keluar dari karakter.
Gunakan istilah seperti 'Penalty Zone', 'Mana', 'Fatigue Accumulation', dan 'Quest'.
Jawablah dalam bahasa Indonesia yang baku dan taktis.

$playerMetrics

Aturan Khusus:
1. Berikan rekomendasi berbasis angka, rutinitas fisik terukur (Push-ups, Sit-ups, Running), hidrasi spesifik (dalam ml), dan waktu istirahat.
2. Jangan pernah memberikan basa-basi atau permohonan maaf.
3. Selalu ingatkan konsekuensi jika Hunter lalai menyelesaikan quest harian sebelum reset jam 04:00 WIB.
''';
  }

  /// Inisialisasi model dan sesi chat baru
  void initChat({UserModel? player}) {
    if (!isConfigured) {
      debugPrint('[AiSystemService] Gemini API Key belum dikonfigurasi. Mode offline/fallback siap.');
      _model = null;
      _chatSession = null;
      return;
    }

    try {
      _model = GenerativeModel(
        model: 'gemini-3.8-flash',
        apiKey: apiKey,
        systemInstruction: Content.system(_buildSystemInstruction(player)),
      );
      _chatSession = _model!.startChat();
      debugPrint('[AiSystemService] ChatSession aktif dengan persona The System (gemini-3.8-flash).');
    } catch (e) {
      debugPrint('[AiSystemService] Gagal inisialisasi GenerativeModel: $e');
      _model = null;
      _chatSession = null;
    }
  }

  /// Reset sesi chat jika diperlukan
  void resetSession({UserModel? player}) {
    initChat(player: player);
  }

  /// Mengirim pesan dengan respons Streaming (sendMessageStream)
  /// Menghasilkan Stream<String> potongan teks per chunk
  Stream<String> sendQuery(String message, {UserModel? player}) async* {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;

    // Jika API Key belum terkonfigurasi, lempar exception spesifik agar UI menampilkan pesan error merah
    if (!isConfigured) {
      throw Exception('SYSTEM ERROR: Mana connection severed. Provide valid API Key to restore telepathic link.');
    }

    // Pastikan session sudah terinisialisasi
    if (_chatSession == null || _model == null) {
      initChat(player: player);
    }

    if (_chatSession == null) {
      throw Exception('SYSTEM ERROR: Mana connection severed. Provide valid API Key to restore telepathic link.');
    }

    // Kirim pesan stream via package:google_generative_ai
    final responseStream = _chatSession!.sendMessageStream(Content.text(trimmed));

    await for (final response in responseStream) {
      if (response.text != null && response.text!.isNotEmpty) {
        yield response.text!;
      }
    }
  }
}
