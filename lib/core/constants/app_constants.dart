/// Cross-app constants: storage keys, notification identifiers, and
/// smart-scheduling defaults.
abstract final class AppConstants {
  // ---- SharedPreferences keys ----
  static const kSettingsJson = 'settings.v1';
  static const kOnboardingComplete = 'onboarding.complete';
  static const kReminderProfilesJson = 'reminders.profiles.v1';
  static const kDailySeedVerse = 'daily.verse';
  static const kDailySeedHadith = 'daily.hadith';
  static const kStreakCurrent = 'streak.current';
  static const kStreakLongest = 'streak.longest';
  static const kStreakLastDay = 'streak.lastDay';
  static const kLastSyncAt = 'sync.lastAt';
  static const kTasbeehLifetime = 'tasbeeh.lifetime';

  // ---- Notification channels ----
  static const channelRemindersId = 'adhkar_reminders';
  static const channelRemindersName = 'تذكيرات الأذكار';
  static const channelRemindersDesc =
      'Smart adhkar reminders scheduled around your prayer times';
  static const channelNudgesId = 'gentle_nudges';
  static const channelNudgesName = 'تنبيهات لطيفة';

  // ---- Notification action ids (also used by the background isolate) ----
  static const actionDone = 'action_done';
  static const actionSnooze = 'action_snooze';
  static const actionListen = 'action_listen';

  // ---- Smart scheduling defaults (minutes) ----
  static const morningOffsetAfterFajr = 20;
  static const eveningOffsetBeforeMaghrib = 20;
  static const afterPrayerDelay = 5;
  static const sleepOffsetAfterIsha = 45;
  static const wakeUpOffsetBeforeFajr = 10;
  static const snoozeMinutes = 10;

  // Route used as notification deep links (`/dhikr/:id`).
  static const routeDhikrPrefix = '/dhikr/';
}
