import 'package:flutter/widgets.dart';

import 'app.dart';
import 'bootstrap.dart';

/// Entry point. All heavy start-up work (DB, notifications, timezone,
/// optional Supabase) lives in [bootstrap] so tests can bypass it.
Future<void> main() async {
  final container = await bootstrap();
  runApp(AlmuinApp(parentContainer: container));
}
