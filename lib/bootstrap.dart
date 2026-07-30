import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'core/config/app_config.dart';
import 'core/services/app_database.dart';
import 'core/services/background_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/settings_service.dart';
import 'core/utils/logger.dart';

/// Wires up every platform service and returns a [ProviderContainer] whose
/// overrides are shared with the widget tree.
///
/// Design notes
/// ------------
/// * The app must be fully functional with **zero network** — Supabase init is
///   skipped gracefully when credentials are not provided via --dart-define.
/// * Timezone initialisation is required for exact local-notification alarms.
/// * [AppDatabase] is a lazily opened singleton so the notification background
///   isolate can reach it without Riverpod.
Future<ProviderContainer> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Local, synchronous preferences (needed before runApp for theme/locale).
  final prefs = await SharedPreferences.getInstance();

  // 1b. intl date symbols so charts/labels can format in Arabic too.
  await initializeDateFormatting('ar');
  await initializeDateFormatting('en');
  Intl.defaultLocale = 'ar';

  // 2. Timezone data for zonedSchedule().
  tz_data.initializeTimeZones();
  try {
    // flutter_timezone 5.x returns a TimezoneInfo rather than a bare String.
    final info = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(info.identifier));
  } catch (e, st) {
    logWarn('Falling back to UTC timezone', e, st);
    tz.setLocalLocation(tz.UTC);
  }

  // 3. Local database (opens lazily on first query; seed import runs inside).
  await AppDatabase.instance.warmUp();

  // 4. Notifications — creates channels/categories and registers the
  //    background action handler (`done` / `snooze` / `listen`).
  await NotificationService.instance.init();

  // 5. Optional cloud backend. Absence of credentials is a normal, supported
  //    configuration: everything is cached in SQLite anyway.
  if (AppConfig.supabaseEnabled) {
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
      );
    } catch (e, st) {
      logWarn('Supabase init failed — continuing offline', e, st);
    }
  }

  // 6. Background rescheduler (daily re-computation of smart reminders and
  //    opportunistic content sync). No-op on unsupported platforms.
  if (!kIsWeb) {
    await BackgroundService.instance.init();
  }

  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );
  return container;
}
