import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../utils/logger.dart';

/// Per-isolate timezone bootstrap for zoned local notifications.
///
/// `tz.local` and the timezone database are *static* state — meaning every
/// Dart isolate has its own copy. Initializing once in `bootstrap()` (UI
/// isolate) is NOT enough: the workmanager isolate and the notification
/// action-handler isolate must each call this before computing
/// `TZDateTime`s, otherwise background scheduling silently shifts by the
/// local UTC offset (review C3).
abstract final class TimezoneService {
  static bool _initialized = false;

  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;
    tz_data.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (e, st) {
      logWarn('Timezone lookup failed — using UTC', e, st);
      tz.setLocalLocation(tz.UTC);
    }
  }
}
