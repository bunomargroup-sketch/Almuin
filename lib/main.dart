import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'bootstrap.dart';

/// Entry point. All heavy start-up work (DB, notifications, timezone,
/// optional Supabase) lives in [bootstrap] so tests can bypass it.
///
/// [bootstrap] returns a [ProviderContainer] carrying the overrides the app
/// depends on — notably `sharedPreferencesProvider`. That container must be
/// the one the widget tree reads from, so it is installed via
/// [UncontrolledProviderScope]. Wrapping in a plain `ProviderScope` instead
/// would build a *second*, empty container and every overridden provider
/// would fall back to its unimplemented default.
Future<void> main() async {
  final container = await bootstrap();
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const AlmuinApp(),
    ),
  );
}
