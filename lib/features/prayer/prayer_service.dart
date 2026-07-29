import 'package:adhan/adhan.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/services/settings_service.dart';
import '../../core/utils/logger.dart';

/// The app's prayer vocabulary (includes sunrise — not a fard prayer but the
/// end of the morning-adhkar window).
enum AppPrayer { fajr, sunrise, dhuhr, asr, maghrib, isha }

class DayPrayerTimes {
  const DayPrayerTimes(this.date, this.times);

  final DateTime date;
  final Map<AppPrayer, DateTime> times;

  DateTime operator [](AppPrayer p) => times[p]!;

  /// Fard prayers only (sunrise excluded) for after-prayer scheduling.
  static const fard = [
    AppPrayer.fajr,
    AppPrayer.dhuhr,
    AppPrayer.asr,
    AppPrayer.maghrib,
    AppPrayer.isha,
  ];

  /// The prayer whose time is next (rolls to tomorrow's fajr when needed).
  (AppPrayer, DateTime)? nextAfter(DateTime t) {
    for (final p in AppPrayer.values) {
      final time = times[p]!;
      if (time.isAfter(t)) return (p, time);
    }
    return null;
  }

  /// The prayer whose window we are currently inside.
  (AppPrayer, DateTime)? currentAt(DateTime t) {
    final list = AppPrayer.values
        .map((p) => (p, times[p]!))
        .where((e) => !e.$2.isAfter(t))
        .toList();
    return list.isEmpty ? null : list.last;
  }
}

/// Thin, defensive wrapper around the `adhan` package. We deliberately only
/// take the six computed times and do countdown/next-prayer math ourselves.
class PrayerTimesService {
  const PrayerTimesService();

  /// Default coordinates (Makkah) until the user grants location or picks a
  /// city — stored afterwards in settings.
  static const defaultLat = 21.422487;
  static const defaultLng = 39.826206;
  static const defaultLabel = 'مكة المكرمة';

  DayPrayerTimes compute(
    DateTime date, {
    required double lat,
    required double lng,
    String methodName = 'muslim_world_league',
  }) {
    final params = _method(methodName).getParameters();
    final coords = Coordinates(lat, lng);
    final now = DateTime.now();
    final isToday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
    // Both constructors are from the adhan public API: `today` for the hot
    // path, DateComponents.from(dt) for other days.
    final times = isToday
        ? PrayerTimes.today(coords, params)
        : PrayerTimes(coords, DateComponents.from(date), params);
    return DayPrayerTimes(date, {
      AppPrayer.fajr: times.fajr,
      AppPrayer.sunrise: times.sunrise,
      AppPrayer.dhuhr: times.dhuhr,
      AppPrayer.asr: times.asr,
      AppPrayer.maghrib: times.maghrib,
      AppPrayer.isha: times.isha,
    });
  }

  CalculationMethod _method(String name) =>
      CalculationMethod.values.asNameMap()[name] ??
      CalculationMethod.muslim_world_league;
}

final prayerTimesServiceProvider =
    Provider<PrayerTimesService>((_) => const PrayerTimesService());

/// Today's prayer times using the stored (or default) location.
final todayPrayerTimesProvider = Provider<DayPrayerTimes>((ref) {
  final s = ref.watch(settingsProvider);
  final service = ref.watch(prayerTimesServiceProvider);
  return service.compute(
    DateTime.now(),
    lat: s.latitude ?? PrayerTimesService.defaultLat,
    lng: s.longitude ?? PrayerTimesService.defaultLng,
    methodName: s.calculationMethod,
  );
});

/// One-second ticker driving the countdown widget.
final nowTickerProvider = StreamProvider<DateTime>(
  (ref) => Stream<DateTime>.periodic(
      const Duration(seconds: 1), (_) => DateTime.now()),
);

/// Resolves the device's coarse location once and persists it to settings.
class LocationResolver {
  /// Returns (lat, lng, label) or null when permission denied / unavailable.
  static Future<(double, double, String)?> resolve() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final last = await Geolocator.getLastKnownPosition();
      final pos = last ??
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.low, // city-level is plenty
              timeLimit: Duration(seconds: 8),
            ),
          );
      return (pos.latitude, pos.longitude,
          '${pos.latitude.toStringAsFixed(2)}, ${pos.longitude.toStringAsFixed(2)}');
    } catch (e, st) {
      logWarn('Location resolve failed', e, st);
      return null;
    }
  }
}
