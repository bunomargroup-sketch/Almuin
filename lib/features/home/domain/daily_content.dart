import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/hijri_utils.dart';
import '../../adhkar/domain/dhikr.dart';
import '../../adhkar/presentation/adhkar_providers.dart';
import '../../prayer/prayer_service.dart';

/// Deterministic "content of the day": the index advances with the day count
/// so the verse/hadith rotates without any server and stays consistent
/// across tabs and days.
int _dayIndex(int listLength) {
  if (listLength <= 0) return 0;
  final epochDays = DateTime.now().difference(DateTime(2024, 1, 1)).inDays;
  return epochDays % listLength;
}

final todayVerseProvider = FutureProvider<Verse?>((ref) async {
  final verses = await ref.watch(versesProvider.future);
  return verses.isEmpty ? null : verses[_dayIndex(verses.length)];
});

final todayHadithProvider = FutureProvider<DailyHadith?>((ref) async {
  final hadiths = await ref.watch(hadithsProvider.future);
  return hadiths.isEmpty ? null : hadiths[_dayIndex(hadiths.length)];
});

/// Time- and season-aware recommendation for the dashboard hero card:
/// mornings surface morning adhkar, late day evening ones; Qur'an lifts in
/// Ramadan; Salawat on Fridays. Deterministic rotation keeps it fresh.
final recommendedDhikrProvider = FutureProvider<List<Dhikr>>((ref) async {
  final repo = ref.watch(dhikrRepositoryProvider);
  await ref.watch(seededProvider.future);

  final now = DateTime.now();
  final prayers = ref.watch(todayPrayerTimesProvider);
  final hijri = hijriOf(now);

  DhikrCategory primary;
  if (now.isBefore(prayers[AppPrayer.sunrise])) {
    primary = DhikrCategory.morning;
  } else if (now.isBefore(prayers[AppPrayer.asr])) {
    primary = hijri.isFriday ? DhikrCategory.salawat : DhikrCategory.tasbeeh;
  } else if (now.isBefore(prayers[AppPrayer.maghrib])) {
    primary = DhikrCategory.evening;
  } else {
    primary = DhikrCategory.sleep;
  }

  final result = <Dhikr>[];
  Future<void> addTop(DhikrCategory c, {int count = 2}) async {
    final items = await repo.all(category: c);
    items.sort((a, b) => a.timesRead.compareTo(b.timesRead));
    result.addAll(items.take(count));
  }

  await addTop(primary, count: 3);
  if (hijri.isRamadan) await addTop(DhikrCategory.quran);
  if (hijri.isFriday) await addTop(DhikrCategory.salawat);
  if (hijri.isEid) await addTop(DhikrCategory.tasbeeh);
  return result.take(5).toList();
});
