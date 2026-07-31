import '../../../core/constants/app_constants.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/utils/date_utils_x.dart';
import '../../adhkar/domain/dhikr.dart';
import '../../prayer/prayer_service.dart';
import 'reminder_models.dart';

/// The intelligent core of Almuin's reminder system.
///
/// Instead of fixed clock times, every reminder is *anchored to Islamic
/// context*:
///
/// | Category        | Anchor                                             |
/// |-----------------|----------------------------------------------------|
/// | morning         | Fajr + 20 min (configurable)                        |
/// | evening         | Maghrib − 20 min (configurable)                     |
/// | afterPrayer     | Every fard prayer + 5 min                           |
/// | sleep           | Isha + 45 min, moved just before quiet hours        |
/// | wakeUp          | Fajr − 10 min                                       |
/// | travel          | Sunrise+30 / midday / Asr+15 (travel mode only)     |
/// | leaveHome       | Sunrise + 10                                        |
/// | istighfar, tasbeeh, salawat | N nudges spread across the waking day |
/// | quran           | Nudges, doubled in Ramadan (×3 in last ten nights)  |
/// | friday          | Salawat nudges ×1.5 + a dedicated Jumu'ah reason    |
/// | eid             | Takbir reminder after Fajr                          |
///
/// Situational categories (rain, distress, gratitude, mosque/home entry) are
/// not pushed on a clock — they are surfaced by the AI assistant and the
/// library, because scheduling them without a real-world trigger (geofence /
/// weather) would be misleading. The integration points are documented in
/// docs/NOTIFICATIONS.md.
///
/// Respect rules: quiet hours defer nudges, battery-saver halves nudge
/// counts and batches after-prayer reminders, priorities cap the day at
/// [maxPerDay] notifications.
class SmartScheduler {
  const SmartScheduler({
    this.morningOffset = AppConstants.morningOffsetAfterFajr,
    this.eveningOffset = AppConstants.eveningOffsetBeforeMaghrib,
    this.afterPrayerDelay = AppConstants.afterPrayerDelay,
    this.sleepOffset = AppConstants.sleepOffsetAfterIsha,
    this.wakeUpOffset = AppConstants.wakeUpOffsetBeforeFajr,
    this.maxPerDay = 14,
  });

  final int morningOffset;
  final int eveningOffset;
  final int afterPrayerDelay;
  final int sleepOffset;
  final int wakeUpOffset;
  final int maxPerDay;

  List<ScheduledReminder> plan(
    ScheduleContext ctx,
    List<ReminderProfile> profiles,
  ) {
    final byCat = {for (final p in profiles) p.category: p};
    bool on(DhikrCategory c) => byCat[c]?.enabled ?? false;
    FrequencyLevel freq(DhikrCategory c) =>
        byCat[c]?.frequency ?? ctx.globalFrequency;

    final out = <ScheduledReminder>[];
    final p = ctx.prayers;

    // ---- Anchors ------------------------------------------------------
    if (on(DhikrCategory.morning)) {
      final offset = byCat[DhikrCategory.morning]?.offsetMinutes ?? morningOffset;
      out.add(_r(DhikrCategory.morning, 'أذكار الصباح',
          'بعد الفجر بـ $offset دقيقة', p[AppPrayer.fajr].add(Duration(minutes: offset)), 3));
    }
    if (on(DhikrCategory.evening)) {
      final offset = byCat[DhikrCategory.evening]?.offsetMinutes ?? eveningOffset;
      out.add(_r(DhikrCategory.evening, 'أذكار المساء',
          'قبل المغرب بـ $offset دقيقة', p[AppPrayer.maghrib].subtract(Duration(minutes: offset)), 3));
    }
    if (on(DhikrCategory.afterPrayer)) {
      for (final prayer in DayPrayerTimes.fard) {
        // Battery saver: skip the sunrise-adjacent Fajr duplicate (morning
        // adhkar already covers it) to reduce wakeups.
        if (ctx.batterySaver && prayer == AppPrayer.fajr) continue;
        out.add(_r(DhikrCategory.afterPrayer, 'أذكار بعد الصلاة',
            'بعد ${_prayerNameAr(prayer)}', p[prayer].add(Duration(minutes: afterPrayerDelay)), 3));
      }
    }
    if (on(DhikrCategory.sleep)) {
      var at = p[AppPrayer.isha].add(Duration(minutes: sleepOffset));
      // Sleep adhkar belong to bedtime: if they would land deep inside quiet
      // hours, pull them just before quiet hours begin. The anchor is the
      // *schedule* day (ctx.date), never the reminder's own day — Isha+offset
      // can roll past midnight, and anchoring to the reminder would then push
      // the pull-back target to the *following* evening (21h late, review H5).
      if (ctx.quietHours.contains(at)) {
        var quietStart = DateTime(ctx.date.year, ctx.date.month, ctx.date.day)
            .add(Duration(minutes: ctx.quietHours.startMinutes - 10));
        // Quiet hours beginning within 10 minutes of midnight would put the
        // target on the *previous* day, sending the reminder into the past
        // where the engine drops it silently. Never pull back past Isha.
        final isha = p[AppPrayer.isha];
        if (quietStart.isBefore(isha)) quietStart = isha;
        if (quietStart.isBefore(at)) at = quietStart;
      }
      out.add(_r(DhikrCategory.sleep, 'أذكار النوم', 'قبل النوم', at, 3));
    }
    if (on(DhikrCategory.wakeUp)) {
      out.add(_r(DhikrCategory.wakeUp, 'أذكار الاستيقاظ',
          'قبل الفجر بقليل', p[AppPrayer.fajr].subtract(Duration(minutes: wakeUpOffset)), 3));
    }

    // ---- Travel mode ----------------------------------------------------
    if (ctx.travelMode && on(DhikrCategory.travel)) {
      out.addAll([
        _r(DhikrCategory.travel, 'دعاء السفر', 'وضع السفر مفعّل',
            p[AppPrayer.sunrise].add(const Duration(minutes: 30)), 2),
        _r(DhikrCategory.travel, 'دعاء السفر', 'وضع السفر مفعّل',
            p[AppPrayer.dhuhr].subtract(const Duration(minutes: 10)), 2),
        _r(DhikrCategory.travel, 'دعاء السفر', 'وضع السفر مفعّل',
            p[AppPrayer.asr].add(const Duration(minutes: 15)), 2),
      ]);
    }

    // ---- Day-anchored situational --------------------------------------
    if (on(DhikrCategory.leaveHome)) {
      out.add(_r(DhikrCategory.leaveHome, 'دعاء الخروج من المنزل',
          'لا تنسَ دعاء الخروج', p[AppPrayer.sunrise].add(const Duration(minutes: 10)), 1));
    }

    // ---- Seasonal specials ---------------------------------------------
    if (ctx.isEid) {
      out.add(_r(DhikrCategory.tasbeeh, 'تكبيرات العيد',
          'الله أكبر الله أكبر لا إله إلا الله', p[AppPrayer.fajr].add(const Duration(minutes: 30)), 2));
    }

    // ---- Frequency-based nudges -----------------------------------------
    final nudgeBudget = switch (ctx.batterySaver ? FrequencyLevel.low : ctx.globalFrequency) {
      FrequencyLevel.low => 1,
      FrequencyLevel.normal => 3,
      FrequencyLevel.high => 6,
    };

    void nudges(DhikrCategory c, String title, String reason, {int priority = 1}) {
      if (!on(c)) return;
      final count = _nudgeCount(freq(c), nudgeBudget);
      if (count == 0) return;
      final slots = _spreadSlots(ctx, count);
      for (final slot in slots) {
        out.add(_r(c, title, reason, slot, priority));
      }
    }

    nudges(DhikrCategory.istighfar, 'الاستغفار', 'أكثِر من الاستغفار');
    nudges(DhikrCategory.tasbeeh, 'التسبيح', 'سبحان الله وبحمده');

    if (on(DhikrCategory.salawat)) {
      var count = _nudgeCount(freq(DhikrCategory.salawat), nudgeBudget);
      if (ctx.isFriday) count = (count * 1.5).ceil(); // Jumu'ah lift
      for (final slot in _spreadSlots(ctx, count)) {
        out.add(_r(DhikrCategory.salawat, 'الصلاة على النبي ﷺ',
            ctx.isFriday
                ? 'يوم الجمعة — أكثِر من الصلاة على النبي ﷺ'
                : 'اللهم صلِّ على محمد',
            slot, ctx.isFriday ? 2 : 1));
      }
    }

    // Quran reading — lifted in Ramadan.
    if (on(DhikrCategory.quran)) {
      var count = _nudgeCount(freq(DhikrCategory.quran), nudgeBudget);
      if (ctx.isRamadan) count *= 2;
      if (ctx.isLastTenRamadan) count = (count * 1.5).ceil();
      if (count > 0) {
        for (final slot in _spreadSlots(ctx, count)) {
          out.add(_r(DhikrCategory.quran, 'ورد القرآن',
              ctx.isRamadan ? 'رمضان — شهر القرآن' : 'وقت وردك اليومي',
              slot, ctx.isRamadan ? 2 : 1));
        }
      }
    }

    // ---- Respect quiet hours -------------------------------------------
    final deferred = out.map((r) {
      // Anchors (morning/evening/sleep/wakeUp) are exempt — the user picked
      // those windows deliberately around prayers.
      if (r.priority >= 3) return r;
      if (!ctx.quietHours.contains(r.at)) return r;
      return ScheduledReminder(
        category: r.category,
        dhikrIdHint: r.dhikrIdHint,
        titleAr: r.titleAr,
        reasonAr: r.reasonAr,
        at: ctx.quietHours.nextExit(r.at),
        priority: r.priority,
      );
    }).toList();

    // ---- De-dupe, cap, sort ---------------------------------------------
    deferred.sort((a, b) => a.at.compareTo(b.at));
    final unique = <String, ScheduledReminder>{};
    for (final r in deferred) {
      unique.putIfAbsent('${r.category.name}@${r.at.millisecondsSinceEpoch ~/ 60000}', () => r);
    }
    var all = unique.values.toList()..sort((a, b) => a.at.compareTo(b.at));
    if (all.length > maxPerDay) {
      // Hard daily cap — notification fatigue protection. Anchors (priority 3)
      // outrank seasonal lifts (2), which outrank gentle nudges (1). Within a
      // tier that overflows, slots are distributed ROUND-ROBIN across
      // categories so no category is permanently starved (review H7): every
      // enabled category keeps a daily presence before any gets a second slot.
      final anchors = all.where((r) => r.priority >= 3).toList();
      final seasonal = all.where((r) => r.priority == 2).toList();
      final nudges = all.where((r) => r.priority < 2).toList();
      final keep = _evenlyTake(anchors, maxPerDay);
      var left = maxPerDay - keep.length;
      if (left > 0) {
        keep.addAll(_roundRobinTake(seasonal, left));
        left = maxPerDay - keep.length;
      }
      if (left > 0) {
        keep.addAll(_roundRobinTake(nudges, left));
      }
      all = keep..sort((a, b) => a.at.compareTo(b.at));
    }
    return all;
  }

  /// Picks up to [count] items spaced evenly across a time-sorted [src].
  /// Always returns a *growable* list (an empty const list would crash the
  /// caller's addAll when anchors are all disabled — review C2).
  static List<ScheduledReminder> _evenlyTake(
      List<ScheduledReminder> src, int count) {
    if (count <= 0 || src.isEmpty) return <ScheduledReminder>[];
    if (src.length <= count) return List.of(src);
    final step = src.length / count;
    return [
      for (var i = 0; i < count && (i * step).floor() < src.length; i++)
        src[(i * step).floor()],
    ];
  }

  /// Picks up to [count] items from a time-sorted list, distributing slots
  /// round-robin across categories (one per category before seconds).
  /// Deterministic: categories are visited in enum order.
  static List<ScheduledReminder> _roundRobinTake(
      List<ScheduledReminder> timeSorted, int count) {
    if (count <= 0 || timeSorted.isEmpty) return <ScheduledReminder>[];
    if (timeSorted.length <= count) return List.of(timeSorted);
    final pools = <DhikrCategory, List<ScheduledReminder>>{};
    for (final r in timeSorted) {
      pools.putIfAbsent(r.category, () => []).add(r);
    }
    final cats = pools.keys.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    final cursors = {for (final c in cats) c: 0};
    final out = <ScheduledReminder>[];
    while (out.length < count) {
      var progressed = false;
      for (final c in cats) {
        final list = pools[c]!;
        final j = cursors[c]!;
        if (j < list.length) {
          out.add(list[j]);
          cursors[c] = j + 1;
          progressed = true;
          if (out.length >= count) break;
        }
      }
      if (!progressed) break; // every pool exhausted
    }
    return out;
  }

  int _nudgeCount(FrequencyLevel level, int budget) => switch (level) {
        FrequencyLevel.low => (budget / 2).floor(),
        FrequencyLevel.normal => budget,
        FrequencyLevel.high => (budget * 1.5).ceil(),
      };

  /// Evenly spreads [count] slots between sunrise+45m and isha−20m.
  List<DateTime> _spreadSlots(ScheduleContext ctx, int count) {
    if (count <= 0) return const [];
    final start = ctx.prayers[AppPrayer.sunrise].add(const Duration(minutes: 45));
    final end = ctx.prayers[AppPrayer.isha].subtract(const Duration(minutes: 20));
    if (!end.isAfter(start)) return [start];
    final span = end.difference(start);
    return [
      for (var i = 0; i < count; i++)
        start.add(Duration(minutes: (span.inMinutes * (i + 0.5) / count).floor())),
    ];
  }

  ScheduledReminder _r(DhikrCategory c, String title, String reason,
          DateTime at, int priority) =>
      ScheduledReminder(
        category: c,
        dhikrIdHint: '',
        titleAr: title,
        reasonAr: reason,
        at: at,
        priority: priority,
      );

  static String _prayerNameAr(AppPrayer p) => switch (p) {
        AppPrayer.fajr => 'الفجر',
        AppPrayer.sunrise => 'الشروق',
        AppPrayer.dhuhr => 'الظهر',
        AppPrayer.asr => 'العصر',
        AppPrayer.maghrib => 'المغرب',
        AppPrayer.isha => 'العشاء',
      };
}
