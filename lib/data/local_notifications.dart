import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Local OS notifications for recall due summaries.
///
/// shortcut: no FCM / remote push yet — add Firebase when account+sync lands
class LocalNotifications {
  LocalNotifications._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const _channelId = 'pelvi_recall';
  static const _channelName = 'Client recalls';
  static const _dailyId = 41001;

  static Future<void> init() async {
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings();
      await _plugin.initialize(
        const InitializationSettings(android: android, iOS: ios),
      );
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: 'Inactive client recall reminders',
          importance: Importance.defaultImportance,
        ),
      );
      _ready = true;
    } catch (e, st) {
      // Linux/widget tests and hosts without a plugin channel.
      debugPrint('LocalNotifications.init skipped: $e\n$st');
      _ready = false;
    }
  }

  /// Refresh the daily local summary for [dueCount] recall-due clients.
  static Future<void> syncRecallDueCount(int dueCount) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(_dailyId);
      if (dueCount <= 0) return;
      final body = dueCount == 1
          ? '1 client has not been seen in a while'
          : '$dueCount clients have not been seen in a while';
      await _plugin.periodicallyShow(
        _dailyId,
        'Recall due',
        body,
        RepeatInterval.daily,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: 'Inactive client recall reminders',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e, st) {
      debugPrint('LocalNotifications.syncRecallDueCount failed: $e\n$st');
    }
  }
}
