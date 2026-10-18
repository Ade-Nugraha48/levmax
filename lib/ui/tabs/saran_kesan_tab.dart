// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/ui/tabs/saran_kesan_tab.dart
// Deskripsi: Tab 3 Bottom Navigation Bar: Evaluasi Mata Kuliah Pemrograman
//            Aplikasi Mobile (Saran & Kesan) via Hive & Supabase (FR-3.3)
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../helpers/boxes.dart';
import '../../models/feedback_model.dart';
import '../../models/user_model.dart';
import '../../services/supabase_api_service.dart';

class SaranKesanTab extends StatefulWidget {
  final UserModel player;

  const SaranKesanTab({super.key, required this.player});

  @override
  State<SaranKesanTab> createState() => _SaranKesanTabState();
}

class _SaranKesanTabState extends State<SaranKesanTab> {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _nimController = TextEditingController();
  final _kesanController = TextEditingController();
  final _saranController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _namaController.text = widget.player.username;
  }

  @override
  void dispose() {
    _namaController.dispose();
    _nimController.dispose();
    _kesanController.dispose();
    _saranController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final newFeedback = FeedbackModel(
      userId: widget.player.id,
      namaMahasiswa: _namaController.text.trim(),
      nim: _nimController.text.trim(),
      kesan: _kesanController.text.trim(),
      saran: _saranController.text.trim(),
      createdAt: DateTime.now().toIso8601String(),
    );

    // Simpan ke Hive (Lapisan 2)
    final box = Hive.box<FeedbackModel>(HiveBoxes.feedbackBox);
    await box.add(newFeedback);

    // Simpan ke Supabase (Lapisan 3)
    await SupabaseApiService.createFeedback(newFeedback);

    _kesanController.clear();
    _saranController.clear();

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Saran & Kesan Berhasil Dikirim ke Sistem!'),
        backgroundColor: Color(0xFF00E5FF),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF131B2E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF00E5FF)),
            ),
            child: Row(
              children: [
                const Icon(Icons.rate_review, color: Color(0xFF00E5FF), size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SARAN & KESAN MATA KULIAH',
                        style: TextStyle(
                          color: Color(0xFF00E5FF),
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Text(
                        'Evaluasi Pembelajaran Praktikum Pemrograman Aplikasi Mobile',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Form Input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF131B2E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _namaController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Nama Mahasiswa',
                      labelStyle: const TextStyle(color: Color(0xFF00E5FF), fontSize: 12),
                      filled: true,
                      fillColor: const Color(0xFF0A0E1A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _nimController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'NIM Mahasiswa',
                      labelStyle: const TextStyle(color: Color(0xFF00E5FF), fontSize: 12),
                      filled: true,
                      fillColor: const Color(0xFF0A0E1A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _kesanController,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Kesan Selama Perkuliahan',
                      labelStyle: const TextStyle(color: Color(0xFF00E5FF), fontSize: 12),
                      filled: true,
                      fillColor: const Color(0xFF0A0E1A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _saranController,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Saran untuk Dosen & Mata Kuliah',
                      labelStyle: const TextStyle(color: Color(0xFF00E5FF), fontSize: 12),
                      filled: true,
                      fillColor: const Color(0xFF0A0E1A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submitFeedback,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5FF),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Text('KIRIM SARAN & KESAN', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Riwayat Saran & Kesan
          const Text(
            'RIWAYAT SARAN & KESAN TERSIMPAN',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
              color: Color(0xFF00E5FF),
            ),
          ),
          const SizedBox(height: 10),

          ValueListenableBuilder<Box<FeedbackModel>>(
            valueListenable: Hive.box<FeedbackModel>(HiveBoxes.feedbackBox).listenable(),
            builder: (context, box, _) {
              if (box.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131B2E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text(
                      'Belum ada riwayat saran & kesan.',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: box.length,
                itemBuilder: (context, index) {
                  final fb = box.getAt(box.length - 1 - index);
                  if (fb == null) return const SizedBox.shrink();

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131B2E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF1E293B)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              fb.namaMahasiswa,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00E5FF), fontSize: 13),
                            ),
                            Text(
                              fb.nim,
                              style: const TextStyle(color: Colors.grey, fontSize: 11),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('Kesan: ${fb.kesan}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text('Saran: ${fb.saran}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
