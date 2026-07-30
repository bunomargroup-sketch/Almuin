import 'dart:async';
import 'dart:typed_data' show Int64List;

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../constants/app_constants.dart';
import '../utils/logger.dart';
import 'app_database.dart';

/// Key used to hand a deep link from a background notification tap to the
/// next foreground frame (see MainShell).
const kPendingDeepLinkKey = 'pending.deepLink';

/// Background entry point required by flutter_local_notifications for action
/// taps while the app is terminated. Runs in its own isolate — keep it free
/// of Riverpod and InheritedWidgets.
@pragma('vm:entry-point')
Future<void> notificationBackgroundHandler(NotificationResponse r) async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase.instance;
  final notifId = r.id ?? 0;

  switch (r.actionId) {
    case AppConstants.actionDone:
      await db.completeByNotificationId(notifId);
    case AppConstants.actionSnooze:
      await db.snoozeByNotificationId(
        notifId,
        DateTime.now()
            .add(const Duration(minutes: AppConstants.snoozeMinutes)),
      );
      await NotificationService.instance.rescheduleSnoozed(r);
    case AppConstants.actionListen:
    default:
      // Taps with UI just carry the payload; queue the deep link so the app
      // (`MainShell`) can navigate once it comes to the foreground.
      final payload = r.payload;
      if (payload != null && payload.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        var link = payload;
        if (r.actionId == AppConstants.actionListen) {
          link = payload.contains('?') ? '$payload&read=1' : '$payload?read=1';
        }
        await prefs.setString(kPendingDeepLinkKey, link);
      }
  }
}

/// Notification façade.
///
/// Features
/// --------
/// * Large Arabic text via [BigTextStyleInformation].
/// * Actions: تم (completed) / تأجيل (snooze 10m) / استمع (read aloud).
/// * Exact, idle-tolerant alarms ([AndroidScheduleMode.exactAllowWhileIdle]).
/// * Optional soft sound & vibration (style follows user settings).
/// * Deep links: payload `/dhikr/<id>` (+ `?read=1` for read-aloud).
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  /// Foreground taps are forwarded here so [MainShell] can route.
  final StreamController<String> deepLinkTap =
      StreamController<String>.broadcast();

  var _soundEnabled = true;
  var _vibrationEnabled = true;

  void applyStyle({required bool sound, required bool vibration}) {
    _soundEnabled = sound;
    _vibrationEnabled = vibration;
  }

  Future<void> init() async {
    final init = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false, // requested after onboarding
        requestBadgePermission: false,
        requestSoundPermission: false,
        notificationCategories: [
          DarwinNotificationCategory(
            'DHIKR_REMINDER',
            actions: [
              DarwinNotificationAction.plain(AppConstants.actionDone, 'تم'),
              DarwinNotificationAction.plain(
                  AppConstants.actionSnooze, 'تأجيل'),
              DarwinNotificationAction.plain(
                  AppConstants.actionListen, 'استمع'),
            ],
          ),
        ],
      ),
    );

    await _plugin.initialize(
      init,
      onDidReceiveNotificationResponse: _onForegroundResponse,
      onDidReceiveBackgroundNotificationResponse: notificationBackgroundHandler,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          AppConstants.channelRemindersId,
          AppConstants.channelRemindersName,
          description: AppConstants.channelRemindersDesc,
          importance: Importance.high,
        ));
  }

  /// Ask for runtime permissions (call after onboarding, not at cold start).
  Future<void> requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestExactAlarmsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  void _onForegroundResponse(NotificationResponse r) async {
    // Update progress even when tapped from the foreground switcher.
    if (r.actionId == AppConstants.actionDone) {
      await AppDatabase.instance.completeByNotificationId(r.id ?? 0);
    }
    final payload = r.payload;
    if (payload == null || payload.isEmpty) return;
    var link = payload;
    if (r.actionId == AppConstants.actionListen) {
      link = payload.contains('?') ? '$payload&read=1' : '$payload?read=1';
    }
    deepLinkTap.add(link);
  }

  /// A deep link left by a background tap; returns null when none.
  Future<String?> consumePendingDeepLink() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(kPendingDeepLinkKey);
    if (v != null) await prefs.remove(kPendingDeepLinkKey);
    return v;
  }

  NotificationDetails _details({
    required String bigText,
    String? reason,
  }) {
    final android = AndroidNotificationDetails(
      AppConstants.channelRemindersId,
      AppConstants.channelRemindersName,
      channelDescription: AppConstants.channelRemindersDesc,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      styleInformation: BigTextStyleInformation(
        bigText,
        contentTitle: null,
        summaryText: reason,
      ),
      playSound: _soundEnabled,
      enableVibration: _vibrationEnabled,
      vibrationPattern:
          _vibrationEnabled ? Int64List.fromList([0, 250, 200, 350]) : null,
      groupKey: 'almuin_adhkar',
      actions: const [
        AndroidNotificationAction(AppConstants.actionDone, 'تم ✓',
            cancelNotification: true),
        AndroidNotificationAction(AppConstants.actionSnooze, 'تأجيل ١٠ د',
            cancelNotification: true),
        AndroidNotificationAction(AppConstants.actionListen, 'استمع',
            showsUserInterface: true, cancelNotification: false),
      ],
    );
    const ios = DarwinNotificationDetails(
      categoryIdentifier: 'DHIKR_REMINDER',
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );
    return NotificationDetails(android: android, iOS: ios);
  }

  /// Schedule a dhikr reminder at an exact local [when].
  ///
  /// Returns the notification id (also saved on the reminder event row).
  Future<int> scheduleReminder({
    required int notificationId,
    required String title,
    required String arabicBody,
    required DateTime when,
    required String payload,
    String? reason,
    int? eventRowId,
  }) async {
    // Mark the planned delivery so the scheduler and stats stay in sync.
    if (eventRowId != null) {
      final d = await AppDatabase.instance.db;
      await d.update('reminder_events', {'notification_id': notificationId},
          where: 'id = ?', whereArgs: [eventRowId]);
    }

    final scheduled = tz.TZDateTime.from(when, tz.local);
    try {
      await _plugin.zonedSchedule(
        notificationId,
        title,
        arabicBody,
        scheduled,
        _details(bigText: arabicBody, reason: reason),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    } catch (e, st) {
      logWarn('Exact alarm denied — falling back to inexact', e, st);
      await _plugin.zonedSchedule(
        notificationId,
        title,
        arabicBody,
        scheduled,
        _details(bigText: arabicBody, reason: reason),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    }
    return notificationId;
  }

  /// Re-fires a snoozed notification 10 minutes later, reusing its content.
  Future<void> rescheduleSnoozed(NotificationResponse original) async {
    final event =
        await AppDatabase.instance.eventByNotificationId(original.id ?? 0);
    final when = DateTime.now()
        .add(const Duration(minutes: AppConstants.snoozeMinutes));
    final title = (event?['title'] as String?) ?? 'المُعين';
    final body = (event?['body_preview'] as String?) ?? '';
    await scheduleReminder(
      notificationId: (original.id ?? 0) + 1000000, // avoid id collision
      title: title,
      arabicBody: body,
      when: when,
      payload: original.payload ?? '/',
      reason: 'مؤجَّل',
    );
  }

  Future<void> cancelAllReminders() => _plugin.cancelAll();

  /// Instant preview, used by the "test notification" affordance in settings.
  Future<void> showNow(
    int id,
    String title,
    String body, {
    String? payload,
    String? reason,
  }) {
    return _plugin.show(
      id,
      title,
      body,
      _details(bigText: body, reason: reason),
      payload: payload,
    );
  }
}
