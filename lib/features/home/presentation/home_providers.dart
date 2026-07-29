import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_database.dart';
import '../../../core/utils/date_utils_x.dart';

/// Today's completed vs scheduled reminder counts.
final todayProgressProvider = FutureProvider<({int completed, int scheduled, int adhkarRead})>(
  (ref) async {
    final db = AppDatabase.instance;
    final day = DateTime.now().dayKey;
    final p = await db.progressFor(day);
    final scheduled = await db.scheduledCountFor(day);
    return (
      completed: p['completed'] ?? 0,
      scheduled: scheduled,
      adhkarRead: p['adhkarRead'] ?? 0,
    );
  },
);

final streakProvider = FutureProvider<({int current, int longest})>(
  (ref) async {
    final (c, l) = await AppDatabase.instance.computeStreak();
    return (current: c, longest: l);
  },
);

final tasbeehTodayProvider = FutureProvider<int>(
  (ref) => AppDatabase.instance.tasbeehTodayTotal(),
);
