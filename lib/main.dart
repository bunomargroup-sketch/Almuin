import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'bootstrap.dart';

/// Entry point. All heavy start-up work (DB, notifications, timezone,
/// optional Supabase) lives in [bootstrap] so tests can bypass it.
Future<void> main() async {
  final container = await bootstrap();
  // The container carries the SharedPreferences override — the widget tree
  // must share THAT same container, not a fresh default ProviderScope.
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const AlmuinApp(),
    ),
  );
}
