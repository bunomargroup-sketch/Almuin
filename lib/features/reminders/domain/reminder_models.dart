import '../../../core/services/settings_service.dart';
import '../../../core/utils/date_utils_x.dart';
import '../../adhkar/domain/dhikr.dart';
import '../../prayer/prayer_service.dart';

/// Per-category user preference (one row per DhikrCategory in the wizard).
class ReminderProfile {
  const ReminderProfile({
    required this.category,
    this.enabled = true,
    this.frequency = FrequencyLevel.normal,
    this.offsetMinutes,
  });

  final DhikrCategory category;
  final bool enabled;
  final FrequencyLevel frequency;

  /// Optional override of the category's default anchor offset (e.g. morning
  /// adhkar N minutes *after* Fajr instead of the default 20).
  final int? offsetMinutes;

  ReminderProfile copyWith({
    bool? enabled,
    FrequencyLevel? frequency,
    int? offsetMinutes,
  }) =>
      ReminderProfile(
        category: category,
        enabled: enabled ?? this.enabled,
        frequency: frequency ?? this.frequency,
        offsetMinutes: offsetMinutes ?? this.offsetMinutes,
      );

  Map<String, dynamic> toJson() => {
        'category': category.name,
        'enabled': enabled,
        'frequency': frequency.name,
        if (offsetMinutes != null) 'offsetMinutes': offsetMinutes,
      };

  factory ReminderProfile.fromJson(Map<String, dynamic> j) => ReminderProfile(
        category: DhikrCategory.fromName(j['category'] as String?),
        enabled: j['enabled'] as bool? ?? true,
        frequency: FrequencyLevel.values
                .asNameMap()[j['frequency'] as String?] ??
            FrequencyLevel.normal,
        offsetMinutes: (j['offsetMinutes'] as num?)?.toInt(),
      );

  /// The starter set offered by the onboarding wizard (all categories on,
  /// balanced frequency — the app explains it can be tuned any time).
  static List<ReminderProfile> defaults() => [
        for (final c in DhikrCategory.values)
          ReminderProfile(
            category: c,
            // Situational categories are browsed/AI-suggested rather than
            // push-scheduled by default (documented behaviour).
            enabled: !const {
              DhikrCategory.rain,
              DhikrCategory.distress,
              DhikrCategory.gratitude,
            }.contains(c),
          ),
      ];
}

/// Everything the scheduler needs to know about a day. Pure value type so
/// `SmartScheduler` is deterministically unit-testable.
class ScheduleContext {
  const ScheduleContext({
    required this.date,
    required this.prayers,
    required this.isFriday,
    required this.isRamadan,
    required this.isLastTenRamadan,
    required this.isEid,
    required this.travelMode,
    required this.batterySaver,
    required this.quietHours,
    required this.globalFrequency,
  });

  final DateTime date;
  final DayPrayerTimes prayers;
  final bool isFriday;
  final bool isRamadan;
  final bool isLastTenRamadan;
  final bool isEid;
  final bool travelMode;
  final bool batterySaver;
  final TimeWindow quietHours;
  final FrequencyLevel globalFrequency;
}

/// One planned notification.
class ScheduledReminder {
  const ScheduledReminder({
    required this.category,
    required this.dhikrIdHint,
    required this.titleAr,
    required this.reasonAr,
    required this.at,
    required this.priority,
  });

  final DhikrCategory category;

  /// Which dhikr to feature. May be empty meaning "pick top item of category".
  final String dhikrIdHint;
  final String titleAr;
  final String reasonAr;
  final DateTime at;

  /// 3 = anchor of the day (morning/evening/prayer/sleep), 2 = seasonal lift,
  /// 1 = gentle nudge. Used when capping the day's total.
  final int priority;
}
