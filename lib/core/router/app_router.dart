import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/adhkar/presentation/adhkar_library_page.dart';
import '../../features/adhkar/presentation/dhikr_detail_page.dart';
import '../../features/ai_assistant/presentation/ai_chat_page.dart';
import '../../features/gamification/presentation/achievements_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/onboarding/presentation/onboarding_wizard.dart';
import '../../features/reminders/presentation/reminders_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/shell/presentation/main_shell.dart';
import '../../features/statistics/presentation/statistics_page.dart';
import '../../features/tasbeeh/presentation/tasbeeh_page.dart';
import '../constants/app_constants.dart';
import '../services/settings_service.dart';

/// Routes
/// ------
/// Authenticated-area alive via [StatefulShellRoute] so tab state persists.
/// `/dhikr/:id?read=1` is the deep link used by notification taps (the
/// `read` query flag triggers text-to-speech on open).
/// The router instance is created ONCE; watching settings here would rebuild
/// `GoRouter` on every preference toggle and reset the navigation stack.
/// The redirect reads the latest settings at evaluation time instead.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final seen = ref.read(settingsProvider).onboardingComplete;
      final onWizard = state.matchedLocation == '/onboarding';
      if (!seen && !onWizard) return '/onboarding';
      if (seen && onWizard) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingWizard(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/', builder: (context, s) => const HomePage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/adhkar',
              builder: (context, s) => const AdhkarLibraryPage(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/tasbeeh',
              builder: (context, s) => const TasbeehPage(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/assistant',
              builder: (context, s) => const AiChatPage(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/more',
              builder: (context, s) => const SettingsPage(),
            ),
          ]),
        ],
      ),
      // Full-screen pages pushed above the shell.
      GoRoute(
        path: '${AppConstants.routeDhikrPrefix}:id',
        builder: (context, state) => DhikrDetailPage(
          dhikrId: state.pathParameters['id']!,
          autoRead: state.uri.queryParameters['read'] == '1',
        ),
      ),
      GoRoute(
        path: '/stats',
        builder: (context, s) => const StatisticsPage(),
      ),
      GoRoute(
        path: '/achievements',
        builder: (context, s) => const AchievementsPage(),
      ),
      GoRoute(
        path: '/reminders',
        builder: (context, s) => const RemindersPage(),
      ),
    ],
  );
});
