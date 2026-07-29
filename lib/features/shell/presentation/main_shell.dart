import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/context_x.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/settings_service.dart';
import '../../gamification/application/gamification_providers.dart';
import '../../gamification/domain/achievements.dart';
import '../../home/presentation/home_providers.dart';
import '../../reminders/application/reminder_controller.dart';

/// Bottom-nav shell + global side effects:
/// * routes notification taps (foreground & terminated) to `/dhikr/:id`,
/// * triggers the first smart-reminder planning pass,
/// * celebrates freshly unlocked achievements.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  StreamSubscription<String>? _linkSub;

  @override
  void initState() {
    super.initState();
    _linkSub = NotificationService.instance.deepLinkTap.listen(_open);
    _drainPendingLink();
    // First-run planning (idempotent — the engine re-arms from scratch).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(reminderPlannerProvider).replan();
    });
  }

  Future<void> _drainPendingLink() async {
    final link = await NotificationService.instance.consumePendingDeepLink();
    if (link != null) _open(link);
  }

  void _open(String link) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go(link);
    });
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    // Apply notification style preferences live.
    final settings = ref.watch(settingsProvider);
    NotificationService.instance.applyStyle(
      sound: settings.notificationSound,
      vibration: settings.notificationVibration,
    );

    // Achievement toast.
    ref.listen(achievementUnlockProvider, (_, id) {
      if (id == null) return;
      final def = AchievementCatalog.byId(id);
      if (def != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            Icon(def.icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text('🏆 ${def.titleAr} — ${def.descAr}')),
          ]),
          duration: const Duration(seconds: 4),
        ));
        ref.invalidate(unlockedAchievementsProvider);
        ref.invalidate(streakProvider);
      }
      ref.read(achievementUnlockProvider.notifier).state = null;
    });

    return Scaffold(
      body: widget.shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.shell.currentIndex,
        onDestinationSelected: (i) => widget.shell.goBranch(
          i,
          initialLocation: i == widget.shell.currentIndex,
        ),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l10n.tabHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.auto_stories_outlined),
            selectedIcon: const Icon(Icons.auto_stories),
            label: l10n.tabAdhkar,
          ),
          NavigationDestination(
            icon: const Icon(Icons.touch_app_outlined),
            selectedIcon: const Icon(Icons.touch_app),
            label: l10n.tabTasbeeh,
          ),
          NavigationDestination(
            icon: const Icon(Icons.auto_awesome_outlined),
            selectedIcon: const Icon(Icons.auto_awesome),
            label: l10n.tabAssistant,
          ),
          NavigationDestination(
            icon: const Icon(Icons.more_horiz),
            selectedIcon: const Icon(Icons.more),
            label: l10n.tabMore,
          ),
        ],
      ),
    );
  }
}
