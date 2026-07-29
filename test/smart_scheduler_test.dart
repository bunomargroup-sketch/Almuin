import 'package:almuin/core/services/settings_service.dart';
import 'package:almuin/core/utils/date_utils_x.dart';
import 'package:almuin/features/adhkar/domain/dhikr.dart';
import 'package:almuin/features/prayer/prayer_service.dart';
import 'package:almuin/features/reminders/domain/reminder_models.dart';
import 'package:almuin/features/reminders/domain/smart_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

DayPrayerTimes fakePrayers(DateTime day) => DayPrayerTimes(day, {
      AppPrayer.fajr: DateTime(day.year, day.month, day.day, 5, 0),
      AppPrayer.sunrise: DateTime(day.year, day.month, day.day, 6, 20),
      AppPrayer.dhuhr: DateTime(day.year, day.month, day.day, 12, 10),
      AppPrayer.asr: DateTime(day.year, day.month, day.day, 15, 30),
      AppPrayer.maghrib: DateTime(day.year, day.month, day.day, 18, 45),
      AppPrayer.isha: DateTime(day.year, day.month, day.day, 20, 0),
    });

ScheduleContext ctx(
  DateTime day, {
  bool friday = false,
  bool ramadan = false,
  bool lastTen = false,
  bool eid = false,
  bool travel = false,
  bool batterySaver = false,
  TimeWindow? quiet,
  FrequencyLevel freq = FrequencyLevel.normal,
}) =>
    ScheduleContext(
      date: day,
      prayers: fakePrayers(day),
      isFriday: friday,
      isRamadan: ramadan,
      isLastTenRamadan: lastTen,
      isEid: eid,
      travelMode: travel,
      batterySaver: batterySaver,
      quietHours: quiet ?? const TimeWindow(21 * 60 + 30, 5 * 60 + 30),
      globalFrequency: freq,
    );

List<ReminderProfile> allOn() => [
      for (final c in DhikrCategory.values)
        ReminderProfile(category: c, enabled: true),
    ];

void main() {
  final day = DateTime(2026, 7, 29); // Wednesday
  const scheduler = SmartScheduler();

  group('Anchors', () {
    test('morning adhkar land 20 minutes after Fajr', () {
      final plan = scheduler.plan(ctx(day), allOn());
      final morn = plan.firstWhere((r) => r.category == DhikrCategory.morning);
      expect(morn.at, DateTime(2026, 7, 29, 5, 20));
    });

    test('evening adhkar land 20 minutes before Maghrib', () {
      final plan = scheduler.plan(ctx(day), allOn());
      final ev = plan.firstWhere((r) => r.category == DhikrCategory.evening);
      expect(ev.at, DateTime(2026, 7, 29, 18, 25));
    });

    test('after-prayer reminders follow every fard prayer', () {
      final plan = scheduler.plan(ctx(day), allOn());
      final after =
          plan.where((r) => r.category == DhikrCategory.afterPrayer).toList();
      expect(after.length, 5); // no sunrise entry
      expect(after.first.at, DateTime(2026, 7, 29, 5, 5));
      expect(after.any((r) => r.at == DateTime(2026, 7, 29, 20, 5)), isTrue);
    });

    test('disabled categories produce nothing', () {
      final profiles = [
        for (final c in DhikrCategory.values)
          ReminderProfile(
              category: c, enabled: c != DhikrCategory.morning),
      ];
      final plan = scheduler.plan(ctx(day), profiles);
      expect(plan.any((r) => r.category == DhikrCategory.morning), isFalse);
    });

    test('custom morning offset is respected', () {
      final profiles = allOn()
          .map((p) => p.category == DhikrCategory.morning
              ? p.copyWith(offsetMinutes: 35)
              : p)
          .toList();
      final plan = scheduler.plan(ctx(day), profiles);
      final morn = plan.firstWhere((r) => r.category == DhikrCategory.morning);
      expect(morn.at, DateTime(2026, 7, 29, 5, 35));
    });
  });

  group('Context adaptation', () {
    test('Friday boosts salawat reminders with a Jumuah reason', () {
      final normal = scheduler
          .plan(ctx(day), allOn())
          .where((r) => r.category == DhikrCategory.salawat)
          .length;
      final fridayPlan =
          scheduler.plan(ctx(day, friday: true), allOn());
      final fri = fridayPlan
          .where((r) => r.category == DhikrCategory.salawat)
          .toList();
      expect(fri.length, greaterThan(normal));
      expect(fri.any((r) => r.reasonAr.contains('الجمعة')), isTrue);
    });

    test('Ramadan doubles Quran nudges', () {
      final normal = scheduler
          .plan(ctx(day), allOn())
          .where((r) => r.category == DhikrCategory.quran)
          .length;
      final ramadan = scheduler
          .plan(ctx(day, ramadan: true), allOn())
          .where((r) => r.category == DhikrCategory.quran)
          .length;
      expect(ramadan, greaterThanOrEqualTo(normal * 2 - 1));
    });

    test('travel mode adds travel-dua reminders', () {
      final plan = scheduler.plan(ctx(day, travel: true), allOn());
      expect(
          plan.where((r) => r.category == DhikrCategory.travel).length, 3);
    });

    test('no travel reminders without travel mode', () {
      final plan = scheduler.plan(ctx(day), allOn());
      expect(plan.any((r) => r.category == DhikrCategory.travel), isFalse);
    });

    test('day is capped to avoid notification fatigue', () {
      final plan = scheduler.plan(
          ctx(day, friday: true, ramadan: true, travel: true, freq: FrequencyLevel.high),
          allOn());
      expect(plan.length, lessThanOrEqualTo(14));
    });

    test('nudges inside quiet hours are deferred out of them', () {
      final quiet = const TimeWindow(12 * 60, 14 * 60); // noon → 14:00
      final plan = scheduler.plan(ctx(day, quiet: quiet), allOn());
      for (final nudge in plan.where((r) => r.priority < 2)) {
        expect(quiet.contains(nudge.at), isFalse,
            reason: '${nudge.titleAr} at ${nudge.at} fell inside quiet hours');
      }
    });

    test('battery saver skips the fajr after-prayer duplicate', () {
      final plan = scheduler.plan(ctx(day, batterySaver: true), allOn());
      final after =
          plan.where((r) => r.category == DhikrCategory.afterPrayer);
      expect(after.length, 4);
    });

    test('eid adds a takbir reminder after Fajr', () {
      final plan = scheduler.plan(ctx(day, eid: true), allOn());
      expect(
          plan.any((r) =>
              r.category == DhikrCategory.tasbeeh &&
              r.reasonAr.contains('الله أكبر')),
          isTrue);
    });
  });

  group('Determinism', () {
    test('same context → identical plan', () {
      final a = scheduler.plan(ctx(day), allOn());
      final b = scheduler.plan(ctx(day), allOn());
      expect(a.map((r) => (r.category, r.at)).toList(),
          b.map((r) => (r.category, r.at)).toList());
    });
  });
}
