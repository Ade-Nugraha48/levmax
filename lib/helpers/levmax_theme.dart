// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/helpers/levmax_theme.dart
// Deskripsi: Sistem Warna, Tipografi Monospace / Headline, & Reusable GlowingProgressBar
// ==============================================================================

import 'package:flutter/material.dart';

class LevMaxTheme {
  // Palet Warna Eksak Desain Google Stitch
  static const Color surface = Color(0xFF0F131D); // Latar belakang utama
  static const Color background = Color(0xFF0F131D);
  static const Color surfaceContainerLowest = Color(0xFF0A0E18); // Track progress, kotak ikon, pill gold
  static const Color surfaceContainerLow = Color(0xFF171B26); // Banner Streak Safeguard
  static const Color surfaceContainer = Color(0xFF1C1F2A); // Latar Hero Card, Search, Chip, Quest Card
  static const Color surfaceContainerHigh = Color(0xFF262A35); // Tombol Continue / Hover
  static const Color surfaceContainerHighest = Color(0xFF313540); // Badge DAILY dan CTRL+K

  static const Color primaryContainer = Color(0xFF00F0FF); // Electric Cyan
  static const Color primary = Color(0xFFDBFCFF); // Teks judul & input email
  static const Color onPrimary = Color(0xFF00363A); // Teks gelap tombol CTA
  static const Color onPrimaryFixed = Color(0xFF002022); // Teks gelap di atas Cyan

  static const Color tertiaryContainer = Color(0xFF65F2B5); // Neon Mint Green (EXP Bar, Cardio, Buff)
  static const Color tertiaryFixedDim = Color(0xFF4EDEA3); // Label EXP & Ikon petir
  static const Color tertiaryFixed = Color(0xFF4EDEA3); // Teks status ELIGIBLE / OPEN

  static const Color secondary = Color(0xFFD2BBFF); // Soft Lavender (Study, Shadow Initiate)
  static const Color secondaryContainer = Color(0xFF6001D1); // Deep Violet (Tombol FOCUS)

  static const Color hpRed = Color(0xFFEF4444);
  static const Color hpRedLabel = Color(0xFFF87171);
  static const Color goldAmber = Color(0xFFFCD34D);
  static const Color goldCoin = Color(0xFFFBBF24);
  static const Color amberGold = Color(0xFFFBBF24); // Vault Gold, Raid Boss, Cashout button
  static const Color errorCoral = Color(0xFFFFB4AB); // Teks PENALTY
  static const Color onSurface = Color(0xFFDFE2F1); // Teks utama putih keperakan
  static const Color onSurfaceVariant = Color(0xFFB9CACB); // Teks sekunder
  static const Color outline = Color(0xFF849495); // Teks redup / reset time

  // Tipografi Spesifik
  static TextStyle headline({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w700,
    Color color = onSurface,
    double letterSpacing = 0.5,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle mono({
    double fontSize = 10,
    FontWeight fontWeight = FontWeight.w600,
    Color color = onSurfaceVariant,
    double letterSpacing = 1.0,
  }) {
    return TextStyle(
      fontFamily: 'monospace',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }
}

// Widget GlowingProgressBar Kustom dengan BoxShadow Sesuai Spesifikasi Desain
class GlowingProgressBar extends StatelessWidget {
  final double progress; // 0.0 .. 1.0
  final Color color;
  final double height;
  final Color trackColor;
  final double glowBlurRadius;

  const GlowingProgressBar({
    super.key,
    required this.progress,
    required this.color,
    this.height = 8.0,
    this.trackColor = LevMaxTheme.surfaceContainerLowest,
    this.glowBlurRadius = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    final clampedProgress = progress.clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final barWidth = totalWidth * clampedProgress;
        return Container(
          height: height,
          width: totalWidth,
          decoration: BoxDecoration(
            color: trackColor,
            borderRadius: BorderRadius.circular(height / 2),
          ),
          child: Stack(
            children: [
              if (barWidth > 0)
                Container(
                  width: barWidth,
                  height: height,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(height / 2),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.6),
                        blurRadius: glowBlurRadius,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
