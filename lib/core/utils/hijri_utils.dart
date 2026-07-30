import 'package:hijri/hijri_calendar.dart';

/// Islamic-calendar awareness used by the smart scheduler and the recommender:
/// Ramadan, Fridays, both Eids, Arafa, Ashura — anything that should change
/// *which* adhkar are surfaced and *how often*.
class HijriInfo {
  const HijriInfo({
    required this.year,
    required this.month,
    required this.day,
    required this.isFriday,
  });

  final int year;
  final int month;
  final int day;
  final bool isFriday;

  bool get isRamadan => month == 9;

  /// Shawwal 1–3.
  bool get isEidFitr => month == 10 && day <= 3;

  /// Dhul-Hijjah 10–13 (days of tashriq included).
  bool get isEidAdha => month == 12 && day >= 10 && day <= 13;

  bool get isEid => isEidFitr || isEidAdha;

  bool get isArafa => month == 12 && day == 9;
  bool get isAshura => month == 1 && (day == 9 || day == 10);

  /// The last ten nights of Ramadan — peak Quran/dua season.
  bool get isLastTenOfRamadan => isRamadan && day >= 21;

  String get monthNameAr => const [
        'محرم',
        'صفر',
        'ربيع الأول',
        'ربيع الآخر',
        'جمادى الأولى',
        'جمادى الآخرة',
        'رجب',
        'شعبان',
        'رمضان',
        'شوال',
        'ذو القعدة',
        'ذو الحجة',
      ][month - 1];

  String formatAr() => '$day $monthNameAr $year هـ';
}

HijriInfo hijriOf(DateTime date) {
  final h = HijriCalendar.fromDate(date);
  return HijriInfo(
    year: h.hYear,
    month: h.hMonth,
    day: h.hDay,
    isFriday: date.weekday == DateTime.friday,
  );
}
