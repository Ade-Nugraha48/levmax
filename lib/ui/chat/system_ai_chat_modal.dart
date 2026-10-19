// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/ui/chat/system_ai_chat_modal.dart
// Deskripsi: Pixel-Perfect AI "The System" Chat Modal (FR-5.2)
//            Google Stitch HUD, Terminal Directives, Corner Ticks, Animated
//            Equalizer Synth Waveform, Diagnostic Telemetry & Gemini Streaming.
// ==============================================================================

import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../helpers/levmax_theme.dart';
import '../../models/user_model.dart';
import '../../services/ai_system_service.dart';

/// Model pesan chat The System & Hunter
class SystemChatMessage {
  String text;
  final bool isFromUser;
  bool isStreaming;
  bool isError;
  final String directive;
  final DateTime timestamp;

  SystemChatMessage({
    required this.text,
    required this.isFromUser,
    this.isStreaming = false,
    this.isError = false,
    this.directive = 'SYSTEM DIRECTIVE',
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class SystemAiChatModal extends StatefulWidget {
  final UserModel? player;

  const SystemAiChatModal({
    super.key,
    this.player,
  });

  /// Helper statis untuk menampilkan modal bottom sheet bertema transparan
  static Future<void> show(BuildContext context, {UserModel? player}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => SystemAiChatModal(player: player),
    );
  }

  @override
  State<SystemAiChatModal> createState() => _SystemAiChatModalState();
}

class _SystemAiChatModalState extends State<SystemAiChatModal> with TickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Animation Controllers
  late AnimationController _apertureRotationController;
  late AnimationController _equalizerController;
  late AnimationController _pulseController;

  // Chat State
  final List<SystemChatMessage> _messages = [];
  bool _isSending = false;

  // Default Initial Message dari The System
  static const String _defaultInitialMessage =
      'Hunter Sung. Your push-up pace slowed by 18% in the final 20 repetitions. '
      'Fatigue accumulation detected. Consume 500ml water and proceed to Skincare '
      'recovery to avoid HP depletion.';

  @override
  void initState() {
    super.initState();

    // 1. Inisialisasi Service & ChatSession Gemini
    AiSystemService().initChat(player: widget.player);

    // 2. Controller Animasi Aperture Berputar
    _apertureRotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    // 3. Controller Animasi Equalizer Synth Freq
    _equalizerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    // 4. Controller Pulsing Ping Dot
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    // 5. Masukkan Pesan Directive Awal
    _messages.add(
      SystemChatMessage(
        text: _defaultInitialMessage,
        isFromUser: false,
        isStreaming: false,
        directive: 'FATIGUE_ACCUMULATION',
      ),
    );
  }

  @override
  void dispose() {
    _apertureRotationController.dispose();
    _equalizerController.dispose();
    _pulseController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Auto-scroll ke pesan terbawah saat streaming berlangsung
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ==========================================================================
  // LOGIKA PENGIRIMAN QUERY & STREAMING GEMINI
  // ==========================================================================
  Future<void> _submitQuery(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty || _isSending) return;

    HapticFeedback.mediumImpact();
    _textController.clear();

    setState(() {
      _isSending = true;

      // 1. Masukkan Pesan User (Hunter)
      _messages.add(
        SystemChatMessage(
          text: trimmed,
          isFromUser: true,
          directive: 'DIRECT_TELEPATHY',
        ),
      );

      // 2. Masukkan Pesan Kosong untuk Menampung Streaming AI
      _messages.add(
        SystemChatMessage(
          text: '',
          isFromUser: false,
          isStreaming: true,
          directive: 'SYSTEM PROTOCOL EXECUTION',
        ),
      );
    });

    _scrollToBottom();

    final currentAiMsg = _messages.last;

    try {
      // 3. Panggil Stream dari AiSystemService
      final stream = AiSystemService().sendQuery(trimmed, player: widget.player);

      stream.listen(
        (chunk) {
          if (!mounted) return;
          setState(() {
            currentAiMsg.text += chunk;
          });
          _scrollToBottom();
        },
        onError: (error) {
          debugPrint('[AiSystemService] Stream onError caught: $error');
          if (!mounted) return;
          setState(() {
            currentAiMsg.isStreaming = false;
            currentAiMsg.isError = true;
            currentAiMsg.text =
                'SYSTEM ERROR: Mana connection severed. Provide valid API Key to restore telepathic link.';
            _isSending = false;
          });
          _scrollToBottom();
        },
        onDone: () {
          if (!mounted) return;
          setState(() {
            currentAiMsg.isStreaming = false;
            if (currentAiMsg.text.isEmpty) {
              currentAiMsg.text = 'Protocol execution complete. The System awaits further directive.';
            }
            _isSending = false;
          });
          _scrollToBottom();
        },
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('[AiSystemService] Stream try-catch caught: $e');
      if (!mounted) return;
      setState(() {
        currentAiMsg.isStreaming = false;
        currentAiMsg.isError = true;
        currentAiMsg.text =
            'SYSTEM ERROR: Mana connection severed. Provide valid API Key to restore telepathic link.';
        _isSending = false;
      });
      _scrollToBottom();
    }
  }

  // ==========================================================================
  // KOMPONEN 1: HUD MODAL HEADER
  // ==========================================================================
  Widget _buildModalHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Kiri: Aperture Box & Title
        Expanded(
          child: Row(
            children: [
              // Kotak 36x36 dengan Aperture Berputar & Glow
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: const Color(0xFF262A35),
                  border: Border.all(color: const Color(0x3300F0FF), width: 1),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x3300F0FF),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [Color(0xFF00F0FF), Color(0xFF6001D1)],
                        ),
                      ),
                    ),
                    RotationTransition(
                      turns: _apertureRotationController,
                      child: const Icon(
                        Icons.flare,
                        size: 20,
                        color: Color(0xFF002022),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '[THE SYSTEM: CONDUIT OF MONARCH]',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: LevMaxTheme.mono(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF00F0FF),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        FadeTransition(
                          opacity: _pulseController,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF00F0FF),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: Color(0xFF00F0FF), blurRadius: 6, spreadRadius: 1),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'OBJECTIVE // ONLINE',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: LevMaxTheme.mono(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFB9CACB),
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),

        // Kanan: Tombol Close 32x32
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF1C1F2A),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0x14FFFFFF), width: 1),
            ),
            child: const Center(
              child: Icon(Icons.close, size: 18, color: Color(0xFFB9CACB)),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // KOMPONEN 2: TIMESTAMP PROTOCOL HEADER
  // ==========================================================================
  Widget _buildTimestampProtocolHeader() {
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')} WIB';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              const Icon(Icons.terminal, size: 14, color: Color(0xFFB9CACB)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'LOG // $timeStr DIRECT_TELEPATHY',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LevMaxTheme.mono(
                    fontSize: 10,
                    color: const Color(0xFFB9CACB),
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0x4D6001D1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0x66D2BBFF), width: 1),
          ),
          child: Text(
            'AUTH: SOVEREIGN',
            style: LevMaxTheme.mono(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFD2BBFF),
              letterSpacing: 0.8,
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // KOMPONEN 3: SYSTEM DIALOG WINDOW (PESAN SYSTEM DENGAN CORNER TICKS)
  // ==========================================================================
  Widget _buildAiSystemDirectiveCard(SystemChatMessage msg) {
    final isWarning = msg.isError ||
        msg.directive.contains('FATIGUE') ||
        msg.directive.contains('WARNING') ||
        msg.directive.contains('PENALTY') ||
        msg.directive.contains('ERROR');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF262A35).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: msg.isError ? const Color(0x66EF4444) : const Color(0x1A00F0FF),
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          // Corner Ticks Accents di 4 sudut
          Positioned.fill(
            child: CustomPaint(
              painter: _CornerTicksPainter(
                color: msg.isError ? const Color(0xFFEF4444) : const Color(0xFF00F0FF),
              ),
            ),
          ),

          // Watermark Shield Samar di Belakang Kanan
          Positioned(
            right: -10,
            bottom: 20,
            child: Icon(
              Icons.shield_outlined,
              size: 110,
              color: Colors.white.withValues(alpha: 0.04),
            ),
          ),

          // Konten Dialog
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Pesan: Pill Directive + Status Warning
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: msg.isError
                            ? const Color(0x26EF4444)
                            : const Color(0x2600F0FF),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: msg.isError
                              ? const Color(0x4DEF4444)
                              : const Color(0x4D00F0FF),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        msg.isError ? 'SYSTEM ALERT' : 'SYSTEM DIRECTIVE',
                        style: LevMaxTheme.mono(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: msg.isError ? const Color(0xFFEF4444) : const Color(0xFF00F0FF),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isWarning) ...[
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 14,
                        color: Color(0xFFEF4444),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          msg.directive,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: LevMaxTheme.mono(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFEF4444),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),

                // Isi Pesan Dialog
                if (msg.isError)
                  Text(
                    msg.text,
                    style: LevMaxTheme.mono(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFEF4444),
                    ).copyWith(height: 1.4),
                  )
                else
                  _buildHighlightedDialogText(msg.text, isStreaming: msg.isStreaming),

                // Equalizer Waveform Footer: Muncul saat isStreaming == true
                if (msg.isStreaming) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF171B26),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.graphic_eq, size: 14, color: Color(0xFFB9CACB)),
                            const SizedBox(width: 6),
                            Text(
                              'SYNTH_FREQ',
                              style: LevMaxTheme.mono(
                                fontSize: 10,
                                color: const Color(0xFFB9CACB),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),

                        // Animated Equalizer (8 Bar Cyan Naik Turun)
                        _buildAnimatedEqualizer(),

                        Text(
                          '0.94 ms',
                          style: LevMaxTheme.mono(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF00F0FF),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // PESAN DARI HUNTER (USER BUBBLE - RATA KANAN DENGAN AKSEN UNGU SOVEREIGN)
  // ==========================================================================
  Widget _buildUserMessageCard(SystemChatMessage msg) {
    final timeStr =
        '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(left: 48, bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF261D38),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(10),
            topRight: Radius.circular(4),
            bottomLeft: Radius.circular(10),
            bottomRight: Radius.circular(10),
          ),
          border: Border.all(color: const Color(0x666001D1), width: 1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x226001D1),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person_pin, size: 12, color: Color(0xFFD2BBFF)),
                const SizedBox(width: 4),
                Text(
                  'HUNTER DIRECTIVE // $timeStr',
                  style: LevMaxTheme.mono(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFD2BBFF),
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              msg.text,
              style: LevMaxTheme.headline(
                fontSize: 13,
                color: const Color(0xFFDFE2F1),
              ).copyWith(height: 1.35),
            ),
          ],
        ),
      ),
    );
  }

  /// Parser teks dialog untuk menyorot kata kunci (angka, persen, ml, skincare, dll.)
  Widget _buildHighlightedDialogText(String text, {bool isStreaming = false}) {
    if (text.isEmpty && isStreaming) {
      return Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00F0FF)),
          ),
          const SizedBox(width: 8),
          Text(
            'Analyzing Hunter telemetry stream...',
            style: LevMaxTheme.mono(fontSize: 12, color: const Color(0xFFB9CACB)),
          ),
        ],
      );
    }

    final words = text.split(' ');
    final spans = <TextSpan>[];

    for (final word in words) {
      final clean = word.toLowerCase();
      final isHighlight = clean.contains('%') ||
          clean.contains('ml') ||
          clean.contains('skincare') ||
          clean.contains('water') ||
          clean.contains('hp') ||
          clean.contains('penalty') ||
          clean.contains('mana') ||
          clean.contains('quest') ||
          clean.contains('18') ||
          clean.contains('500');

      spans.add(
        TextSpan(
          text: '$word ',
          style: LevMaxTheme.headline(
            fontSize: 14,
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
            color: isHighlight ? const Color(0xFF00F0FF) : const Color(0xFFDFE2F1),
          ).copyWith(height: 1.4),
        ),
      );
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  /// 8 Bar Equalizer Vertikal Cyan
  Widget _buildAnimatedEqualizer() {
    return AnimatedBuilder(
      animation: _equalizerController,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(8, (index) {
            final double height = 4.0 +
                (sin((_equalizerController.value * 2 * pi) + (index * 0.8)).abs() * 12.0);

            return Container(
              width: 3.5,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: const Color(0xFF00F0FF),
                borderRadius: BorderRadius.circular(1.5),
                boxShadow: const [
                  BoxShadow(color: Color(0x6600F0FF), blurRadius: 4),
                ],
              ),
            );
          }),
        );
      },
    );
  }

  // ==========================================================================
  // KOMPONEN 4: DIAGNOSTIC TELEMETRY SUB-CARD
  // ==========================================================================
  Widget _buildDiagnosticTelemetrySubCard() {
    final playerHp = widget.player?.hp ?? 82;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF171B26),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x14FFFFFF), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.monitor_heart, size: 14, color: Color(0xFF65F2B5)),
                  const SizedBox(width: 6),
                  Text(
                    'DIAGNOSTIC TELEMETRY',
                    style: LevMaxTheme.headline(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFDFE2F1),
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0x2665F2B5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'CALIBRATED',
                  style: LevMaxTheme.mono(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF65F2B5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HP STATUS',
                      style: LevMaxTheme.mono(fontSize: 9, color: const Color(0xFF849495), fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$playerHp',
                          style: LevMaxTheme.headline(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFFDFE2F1)),
                        ),
                        Text(
                          '/100',
                          style: LevMaxTheme.mono(fontSize: 10, color: const Color(0xFF849495)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A0E18),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: (playerHp / 100.0).clamp(0.0, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF00F0FF),
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: const [
                              BoxShadow(color: Color(0x6600F0FF), blurRadius: 4),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LACTIC ACID',
                      style: LevMaxTheme.mono(fontSize: 9, color: const Color(0xFF849495), fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '64%',
                      style: LevMaxTheme.headline(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFFEF4444)),
                    ),
                    Text(
                      'Elevated',
                      style: LevMaxTheme.mono(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFFEF4444)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ACTION',
                      style: LevMaxTheme.mono(fontSize: 9, color: const Color(0xFF849495), fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Hydration',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: LevMaxTheme.headline(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFDFE2F1)),
                    ),
                    Text(
                      '+ Skincare',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: LevMaxTheme.mono(fontSize: 10, color: const Color(0xFFB9CACB)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // KOMPONEN 5: AVAILABLE RESPONSES (QUICK PROMPTS)
  // ==========================================================================
  Widget _buildAvailableResponses() {
    final prompts = [
      {'num': '[1]', 'color': const Color(0xFF00F0FF), 'text': 'Provide optimal recovery routine'},
      {'num': '[2]', 'color': const Color(0xFFEF4444), 'text': 'Inspect penalty probability'},
      {'num': '[3]', 'color': const Color(0xFFD2BBFF), 'text': 'Review tomorrow\'s plan'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AVAILABLE RESPONSES',
          style: LevMaxTheme.mono(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: const Color(0xFFB9CACB),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        Column(
          children: prompts.map((item) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => _submitQuery(item['text'] as String),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF262A35),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0x14FFFFFF), width: 1),
                  ),
                  child: Row(
                    children: [
                      Text(
                        item['num'] as String,
                        style: LevMaxTheme.mono(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: item['color'] as Color,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item['text'] as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: LevMaxTheme.headline(
                            fontSize: 12,
                            color: const Color(0xFFDFE2F1),
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right, size: 18, color: Color(0xFF849495)),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ==========================================================================
  // KOMPONEN 6: INTERACTIVE INPUT CONSOLE BAR & ENCRYPTED STATUS
  // ==========================================================================
  Widget _buildInteractiveInputConsoleBar() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF171B26),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x2200F0FF), width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1F2A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(Icons.mic, size: 20, color: Color(0xFFB9CACB)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _textController,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _submitQuery,
                  style: LevMaxTheme.headline(
                    fontSize: 13,
                    color: Colors.white,
                  ),
                  decoration: InputDecoration.collapsed(
                    hintText: 'Inquire with The System...',
                    hintStyle: LevMaxTheme.headline(
                      fontSize: 13,
                      color: const Color(0xFF849495),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _submitQuery(_textController.text),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _isSending ? const Color(0xFF00A2AC) : const Color(0xFF00F0FF),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x6600F0FF),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Center(
                    child: _isSending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF002022),
                            ),
                          )
                        : const Icon(Icons.send, size: 18, color: Color(0xFF002022)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ENCRYPTED_TELEPATHIC_LINK_V4',
              style: LevMaxTheme.mono(
                fontSize: 9,
                color: const Color(0xFF849495),
                letterSpacing: 0.8,
              ),
            ),
            Text(
              'STATUS: SYNCED',
              style: LevMaxTheme.mono(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF849495),
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.90,
        margin: const EdgeInsets.only(top: 24),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xF20A0E18),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: const Color(0x3300F0FF), width: 1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x3300F0FF),
              blurRadius: 24,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Top Cyan Highlight Glow Line
            Positioned(
              top: 0,
              left: 30,
              right: 30,
              child: Container(
                height: 2,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Color(0xFF00F0FF), Colors.transparent],
                  ),
                ),
              ),
            ),

            // Matrix Grid Texture Backdrop
            const Positioned.fill(
              child: CustomPaint(
                painter: _DigitalGridPainter(),
              ),
            ),

            // Top Drag Handle Indicator
            Positioned(
              top: 8,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 38,
                  height: 3,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00F0FF).withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),

            // Konten Utama Scrollable
            Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 20,
                bottom: bottomInset + 16,
              ),
              child: Column(
                children: [
                  _buildModalHeader(),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildTimestampProtocolHeader(),
                          const SizedBox(height: 12),

                          // Render Seluruh Riwayat Pesan Chat (The System Directives & Hunter Messages)
                          ..._messages.map((msg) {
                            if (msg.isFromUser) {
                              return _buildUserMessageCard(msg);
                            } else {
                              return _buildAiSystemDirectiveCard(msg);
                            }
                          }),

                          // Komponen 4: Diagnostic Telemetry Sub-Card
                          _buildDiagnosticTelemetrySubCard(),

                          // Komponen 5: Available Responses (Quick Prompts)
                          _buildAvailableResponses(),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),

                  // Komponen 6: Interactive Input Console Bar
                  _buildInteractiveInputConsoleBar(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==============================================================================
// CUSTOM PAINTER: CORNER TICKS (L-SHAPED CYAN ACCENTS)
// ==============================================================================
class _CornerTicksPainter extends CustomPainter {
  final Color color;

  const _CornerTicksPainter({this.color = const Color(0xFF00F0FF)});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    const double tickLen = 8.0;

    // Kiri Atas
    canvas.drawLine(const Offset(0, 0), const Offset(tickLen, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(0, tickLen), paint);

    // Kanan Atas
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - tickLen, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, tickLen), paint);

    // Kiri Bawah
    canvas.drawLine(Offset(0, size.height), Offset(tickLen, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - tickLen), paint);

    // Kanan Bawah
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width - tickLen, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - tickLen), paint);
  }

  @override
  bool shouldRepaint(covariant _CornerTicksPainter oldDelegate) => oldDelegate.color != color;
}

// ==============================================================================
// CUSTOM PAINTER: DIGITAL DISTORTION MATRIX GRID BACKDROP
// ==============================================================================
class _DigitalGridPainter extends CustomPainter {
  const _DigitalGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()..color = const Color(0x0C00F0FF);
    const double step = 20.0;

    for (double x = 8; x < size.width; x += step) {
      for (double y = 8; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 0.8, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
