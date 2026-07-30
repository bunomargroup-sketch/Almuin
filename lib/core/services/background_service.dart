import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../../features/reminders/application/reminder_engine.dart';
import '../utils/logger.dart';

/// Unique task names.
abstract final class BackgroundTasks {
  /// Periodic job: recompute prayer-anchored reminders for today + tomorrow,
  /// prune stale notifications, and opportunistically sync content.
  static const reschedule = 'almuin.reschedule.v1';
}

/// Background isolate entry point. ReminderEngine is headless-safe: it reads
/// SharedPreferences + SQLite directly and never touches Riverpod/UI.
@pragma('vm:entry-point')
void backgroundDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    logInfo('Background task: $task');
    try {
      await ReminderEngine.rescheduleComingDaysHeadless();
      return true;
    } catch (e, st) {
      logWarn('Background task failed', e, st);
      return false;
    }
  });
}

/// Registers periodic background work. Best-effort: Android throttles
/// periodic tasks (15-minute minimum); iOS runs BGProcessingTasks
/// opportunistically. Exact wake-ups still come from the local-notification
/// alarms themselves — this job only keeps the *plan* fresh.
class BackgroundService {
  BackgroundService._();
  static final BackgroundService instance = BackgroundService._();

  Future<void> init() async {
    await Workmanager().initialize(backgroundDispatcher);
    await Workmanager().registerPeriodicTask(
      BackgroundTasks.reschedule,
      BackgroundTasks.reschedule,
      frequency: const Duration(hours: 12),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(
        networkType: NetworkType.notRequired, // reminders work offline
      ),
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 30),
    );
  }

  /// Developer affordance: trigger the daily planning pass immediately.
  Future<void> runNowForDebug() => Workmanager()
      .registerOneOffTask('debug.reschedule', BackgroundTasks.reschedule);
}
