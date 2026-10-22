// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/services/notification_service.dart
// Deskripsi: Layanan Notifikasi Lokal Mobile (FR-6.2) untuk Level Up,
//            Pengingat Daily Quest, Peringatan Penalti, dan Notifikasi "Anda Tidak Layak".
// ==============================================================================

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'levmax_system_channel';
  static const String _channelName = 'LevMax System Notifications';
  static const String _channelDescription =
      'Notifikasi pengingat quest, level up, penalti, dan status sistem Solo Leveling';

  /// Inisialisasi plugin notifikasi lokal pada awal aplikasi dibuka
  static Future<void> initialize() async {
    const androidInitSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const darwinInitSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidInitSettings,
      iOS: darwinInitSettings,
      macOS: darwinInitSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle ketika notifikasi ditekan
      },
    );

    // Minta izin notifikasi untuk Android 13+ (API 33+)
    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
    }
  }

  /// Konfigurasi detail notifikasi untuk Android & iOS
  static NotificationDetails get _notificationDetails =>
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'ticker',
          styleInformation: BigTextStyleInformation(''),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

  /// 1. Notifikasi Saat Naik Level (FR-6.2)
  static Future<void> showLevelUpNotification({
    required int newLevel,
    required String rank,
  }) async {
    await _notificationsPlugin.show(
      101,
      '⚡ [THE SYSTEM: LEVEL UP!]',
      'Selamat! Anda naik ke Level $newLevel (Rank $rank). Hadapi batas diri Anda dan raih kekuatan tertinggi!',
      _notificationDetails,
    );
  }

  /// 2. Notifikasi Peringatan Masuk Penalty Zone (FR-6.2)
  static Future<void> showPenaltyNotification({int hpDeduction = 20}) async {
    await _notificationsPlugin.show(
      102,
      '🚨 [PERINGATAN SISTEM: PENALTY ZONE AKTIF]',
      'Daily Quest terabaikan lewat pukul 23:59! HP berkurang -$hpDeduction. Buka Penalty Mini-Game untuk bertahan hidup!',
      _notificationDetails,
    );
  }

  /// 3. Notifikasi Saat HP <= 0: "Anda Tidak Layak" (FR-6.2)
  static Future<void> showGameOverNotification() async {
    await _notificationsPlugin.show(
      103,
      '💀 [SYSTEM TERMINATED: ANDA TIDAK LAYAK]',
      'HP Anda telah habis. Sistem menyatakan Anda gugur dalam seleksi kedisiplinan. Lakukan Re-Awakening sekarang!',
      _notificationDetails,
    );
  }

  /// 4. Notifikasi Pengingat Quest Harian (Daily Reminder)
  static Future<void> showQuestReminderNotification({
    required int pendingCount,
  }) async {
    await _notificationsPlugin.show(
      104,
      '⚔️ [SISTEM PENGINGAT DAILY QUEST]',
      'Masih ada $pendingCount quest yang menanti penyelesaian sebelum pukul 23:59. Jangan biarkan Penalti menjerat Anda!',
      _notificationDetails,
    );
  }

  /// Notifikasi Umum Kustom
  static Future<void> showCustomNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    await _notificationsPlugin.show(id, title, body, _notificationDetails);
  }
}
