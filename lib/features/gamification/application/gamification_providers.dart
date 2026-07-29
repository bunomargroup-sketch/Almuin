import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_database.dart';
import '../../../core/utils/date_utils_x.dart';
import '../../../core/utils/hijri_utils.dart';
import '../../adhkar/domain/dhikr.dart';
import '../domain/achievements.dart';

/// A newly unlocked achievement (id) to celebrate in the UI once.
final achievementUnlockProvider = StateProvider<String?>((_) => null);

/// Currently unlocked ids.
final unlockedAchievementsProvider = FutureProvider<Set<String>>(
  (ref) => AppDatabase.instance.unlockedAchievements(),
);

/// Evaluates progress facts against the catalogue. Called after meaningful
/// events (dhikr completion, tasbeeh session, reminder done).
class AchievementEvaluator {
  static Future<List<String>> evaluate() async {
    final db = AppDatabase.instance;
    final unlocked = await db.unlockedAchievements();
    final fresh = <String>[];

    Future<void> tryUnlock(String id) async {
      if (unlocked.contains(id)) return;
      if (await db.unlockAchievement(id)) fresh.add(id);
    }

    final (current, _) = await db.computeStreak();
    final lifetime = await db.tasbeehLifetime();
    final totalCompleted = await db.totalCompletedReminders();
    final today = DateTime.now().dayKey;
    final todayProgress = await db.progressFor(today);
    final mostRead = await db.mostRead(limit: 100);
    final totalReads =
        mostRead.fold<int>(0, (sum, d) => sum + d.timesRead);

    if (totalCompleted > 0 || (todayProgress['adhkarRead'] ?? 0) > 0) {
      await tryUnlock('first_dhikr');
    }
    if (current >= 3) await tryUnlock('streak_3');
    if (current >= 7) await tryUnlock('streak_7');
    if (current >= 30) await tryUnlock('streak_30');
    if (lifetime >= 100) await tryUnlock('tasbeeh_100');
    if (lifetime >= 1000) await tryUnlock('tasbeeh_1000');
    if (totalReads >= 50) await tryUnlock('adhkar_50');

    final scheduledToday = await db.scheduledCountFor(today);
    if (scheduledToday > 0 &&
        (todayProgress['completed'] ?? 0) >= scheduledToday) {
      await tryUnlock('day_full');
    }

    // Fajr companion: ≥7 completed morning-anchor reminder events.
    final morningDone = await _completedCategoryCount(DhikrCategory.morning);
    if (morningDone >= 7) await tryUnlock('fajr_warrior');

    // Friday salawat: 100 salawat tasbeeh on a Friday.
    if (hijriOf(DateTime.now()).isFriday && lifetime >= 100) {
      final todayTasbeeh = await db.tasbeehTodayTotal();
      if (todayTasbeeh >= 100) await tryUnlock('salawat_friday');
    }

    return fresh;
  }

  static Future<int> _completedCategoryCount(DhikrCategory c) async {
    final d = await AppDatabase.instance.db;
    final r = await d.rawQuery(
      "SELECT COUNT(*) c FROM reminder_events WHERE status = 'completed' AND category = ?",
      [c.name],
    );
    return (r.first['c'] as int?) ?? 0;
  }
}
