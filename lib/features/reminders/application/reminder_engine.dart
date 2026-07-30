import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/app_database.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/utils/date_utils_x.dart';
import '../../../core/utils/hijri_utils.dart';
import '../../../core/utils/logger.dart';
import '../../adhkar/domain/dhikr.dart';
import '../../prayer/prayer_service.dart';
import '../domain/reminder_models.dart';
import '../domain/smart_scheduler.dart';

/// Turns the SmartScheduler's *plan* into actual OS notifications, with
/// SQLite as the source of truth for delivery/completion analytics.
///
/// Headless-safe: [rescheduleComingDaysHeadless] runs in the workmanager
/// background isolate (no Riverpod, no BuildContext).
class ReminderEngine {
  ReminderEngine._();

  /// Re-plan and re-arm reminders for today & tomorrow.
  static Future<void> rescheduleComingDaysHeadless() async {
    final prefs = await SharedPreferences.getInstance();
    final settings = _loadSettings(prefs);
    final profiles = _loadProfiles(prefs);

    final db = AppDatabase.instance;
    await db.warmUp();
    await db.ensureSeeded();

    await NotificationService.instance.init();
    NotificationService.instance.applyStyle(
      sound: settings.notificationSound,
      vibration: settings.notificationVibration,
    );

    const scheduler = SmartScheduler();
    const prayerService = PrayerTimesService();
    final lat = settings.latitude ?? PrayerTimesService.defaultLat;
    final lng = settings.longitude ?? PrayerTimesService.defaultLng;

    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    final allAdhkar = await db.adhkar();
    final byCategory = <DhikrCategory, List<Dhikr>>{};
    for (final d in allAdhkar) {
      byCategory.putIfAbsent(d.category, () => []).add(d);
    }

    for (var dayOffset = 0; dayOffset <= 1; dayOffset++) {
      final day = DateTime(now.year, now.month, now.day + dayOffset);
      final prayers = prayerService.compute(
        day,
        lat: lat,
        lng: lng,
        methodName: settings.calculationMethod,
      );
      final hijri = hijriOf(day);
      final ctx = ScheduleContext(
        date: day,
        prayers: prayers,
        isFriday: hijri.isFriday,
        isRamadan: hijri.isRamadan,
        isLastTenRamadan: hijri.isLastTenOfRamadan,
        isEid: hijri.isEid,
        travelMode: settings.travelMode,
        batterySaver: settings.batterySaver,
        quietHours: settings.quietHours,
        globalFrequency: settings.globalFrequency,
      );

      final plan = scheduler.plan(ctx, profiles);
      // History hygiene (review M6): slots whose time passed become
      // 'delivered' and are KEPT; only future, still-pending slots are
      // cancelled & re-created. A replan therefore never wipes undismissed
      // notifications from the shade, nor the analytics/history trail.
      await db.markPastScheduledAsDelivered(day.dayKey, nowIso);
      final pendingIds = await db.pendingNotificationIdsFor(day.dayKey, nowIso);
      for (final id in pendingIds) {
        await NotificationService.instance.cancelReminder(id);
      }
      await db.deleteFutureScheduledEventsFor(day.dayKey, nowIso);
      for (final r in plan) {
        // Don't schedule moments already past (with a small grace buffer).
        if (r.at.isBefore(now.add(const Duration(seconds: 30)))) continue;

        final dhikr = _pickDhikr(byCategory[r.category], r.category);
        if (dhikr == null) continue;

        // Include the HOUR in the id input (review H1): 05:05 and 20:05
        // after-prayer reminders must not collide and overwrite each other.
        final notifId = Object.hash(
                day.dayKey, r.category.name, r.at.hour * 60 + r.at.minute) &
            0x7FFFFFFF;
        final eventId = await db.insertReminderEvent({
          'notification_id': notifId,
          'dhikr_id': dhikr.id,
          'category': r.category.name,
          'title': r.titleAr,
          'body_preview': _preview(dhikr.arabic),
          'reason': r.reasonAr,
          'scheduled_at': r.at.toIso8601String(),
          'status': 'scheduled',
        });

        await NotificationService.instance.scheduleReminder(
          notificationId: notifId,
          title: '${r.titleAr} · $notifTitleSuffix',
          arabicBody: dhikr.arabic,
          when: r.at,
          payload: '${AppConstants.routeDhikrPrefix}${dhikr.id}',
          reason: r.reasonAr,
          eventRowId: eventId,
        );
      }
      logInfo('Planned ${plan.length} reminders for ${day.dayKey}');
    }
  }

  static const notifTitleSuffix = 'المُعين';

  /// Picks the dhikr to feature: prefer sahih/quran content the user hasn't
  /// read recently (round-robin by times_read).
  static Dhikr? _pickDhikr(List<Dhikr>? items, DhikrCategory category) {
    if (items == null || items.isEmpty) return null;
    const rank = {
      AuthenticityGrade.quran: 0,
      AuthenticityGrade.sahih: 1,
      AuthenticityGrade.hasan: 2,
      AuthenticityGrade.daif: 3,
      AuthenticityGrade.custom: 4,
    };
    final sorted = [...items]..sort((a, b) {
        final g = rank[a.bestGrade]!.compareTo(rank[b.bestGrade]!);
        return g != 0 ? g : a.timesRead.compareTo(b.timesRead);
      });
    return sorted.first;
  }

  static String _preview(String text) =>
      text.length <= 160 ? text : '${text.substring(0, 157)}…';

  static AppSettings _loadSettings(SharedPreferences prefs) {
    final raw = prefs.getString(AppConstants.kSettingsJson);
    if (raw == null) return const AppSettings();
    try {
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const AppSettings();
    }
  }

  static List<ReminderProfile> _loadProfiles(SharedPreferences prefs) {
    final raw = prefs.getString(AppConstants.kReminderProfilesJson);
    if (raw == null) return ReminderProfile.defaults();
    try {
      return [
        for (final j in jsonDecode(raw) as List<dynamic>)
          ReminderProfile.fromJson(j as Map<String, dynamic>),
      ];
    } catch (_) {
      return ReminderProfile.defaults();
    }
  }
}
