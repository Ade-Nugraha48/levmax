// Widget Dialog Konsultasi Asisten Sistem
import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/gemini_service.dart';

class AiSystemChatSheet extends StatefulWidget {
  final UserModel player;

  const AiSystemChatSheet({super.key, required this.player});

  @override
  State<AiSystemChatSheet> createState() => _AiSystemChatSheetState();
}

class _AiSystemChatSheetState extends State<AiSystemChatSheet> {
  // Controller input pesan
  final _chatMsgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Riwayat percakapan lokal
  final List<Map<String, String>> _messages = [];
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    // Pesan sambutan awal sistem
    _messages.add({
      'sender': 'system',
      'text':
          '[THE SYSTEM ONLINE]\nHunter ${widget.player.username} (Level ${widget.player.level}, Rank ${widget.player.rank}). Ajukan konsultasi seputar Workout, Looksmaxxing, atau Disiplin Belajar harian Anda.',
    });
  }

  @override
  void dispose() {
    _chatMsgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Mengirim pesan pengguna ke Gemini dan menerima respons sistem
  Future<void> _sendMessage() async {
    final text = _chatMsgController.text.trim();
    if (text.isEmpty || _isTyping) return;

    setState(() {
      _messages.add({'sender': 'user', 'text': text});
      _isTyping = true;
    });
    _chatMsgController.clear();
    _scrollToBottom();

    // Pemanggilan service Gemini
    final reply = await GeminiService.sendMessage(
      message: text,
      player: widget.player,
    );

    if (!mounted) return;

    setState(() {
      _messages.add({'sender': 'system', 'text': reply});
      _isTyping = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.78,
        child: Column(
          children: [
            // Handle bar modal
            Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade700,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),

            // Header asisten sistem
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                    border: Border.all(color: const Color(0xFF00E5FF)),
                  ),
                  child: const Icon(Icons.bolt, color: Color(0xFF00E5FF), size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'THE SYSTEM ASSISTANT',
                        style: TextStyle(
                          color: Color(0xFF00E5FF),
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Protokol Konsultasi Gaya Hidup Hunter Solo Leveling',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 10),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(color: Color(0xFF1E293B)),

            // Daftar percakapan
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                itemCount: _messages.length,
                itemBuilder: (context, idx) {
                  final msg = _messages[idx];
                  final isSystem = msg['sender'] == 'system';

                  return Align(
                    alignment: isSystem ? Alignment.centerLeft : Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.all(12),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.80,
                      ),
                      decoration: BoxDecoration(
                        color: isSystem
                            ? const Color(0xFF131B2E)
                            : const Color(0xFF00E5FF).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSystem ? const Color(0xFF1E293B) : const Color(0xFF00E5FF),
                        ),
                      ),
                      child: Text(
                        msg['text'] ?? '',
                        style: TextStyle(
                          color: isSystem ? Colors.white : const Color(0xFF00E5FF),
                          fontSize: 12.5,
                          height: 1.45,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Indikator status analisis
            if (_isTyping)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E5FF)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '[Sistem sedang menganalisis status Hunter...]',
                      style: TextStyle(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.8),
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),

            // Kolom input teks
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _chatMsgController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Tanyakan menu latihan, looksmaxxing, atau jadwal...',
                        hintStyle: const TextStyle(color: Colors.grey, fontSize: 11),
                        filled: true,
                        fillColor: const Color(0xFF131B2E),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF1E293B)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF1E293B)),
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send, color: Color(0xFF00E5FF)),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
