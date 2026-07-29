import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/context_x.dart';
import '../../../core/theme/glass.dart';
import '../../adhkar/domain/dhikr.dart';
import '../../adhkar/presentation/category_labels.dart';
import '../../prayer/prayer_service.dart';
import '../../../core/services/settings_service.dart';
import '../../reminders/application/reminder_controller.dart';
import '../../reminders/domain/reminder_models.dart';
import '../../../core/services/notification_service.dart';

/// First-run setup wizard:
/// 1. Welcome → 2. Pick adhkar categories → 3. Location & permissions →
/// 4. Done (schedules everything).
class OnboardingWizard extends ConsumerStatefulWidget {
  const OnboardingWizard({super.key});

  @override
  ConsumerState<OnboardingWizard> createState() => _OnboardingWizardState();
}

class _OnboardingWizardState extends ConsumerState<OnboardingWizard> {
  final _pages = PageController();
  int _page = 0;
  bool _busy = false;

  /// Categories shown in the wizard (situational ones are browsed on demand,
  /// not push-scheduled — see SmartScheduler docs).
  static const _scheduleable = [
    DhikrCategory.morning,
    DhikrCategory.evening,
    DhikrCategory.afterPrayer,
    DhikrCategory.sleep,
    DhikrCategory.wakeUp,
    DhikrCategory.leaveHome,
    DhikrCategory.travel,
    DhikrCategory.istighfar,
    DhikrCategory.tasbeeh,
    DhikrCategory.salawat,
    DhikrCategory.quran,
  ];

  final Set<DhikrCategory> _enabled = Set.of(_scheduleable);

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    setState(() => _busy = true);
    try {
      // Persist chosen profiles.
      final profiles = [
        for (final p in ReminderProfile.defaults())
          p.copyWith(enabled: _enabled.contains(p.category)),
      ];
      ref.read(reminderProfilesProvider.notifier).setAll(profiles);

      // Permissions + first planning pass.
      await NotificationService.instance.requestPermissions();
      await ref.read(reminderPlannerProvider).replan();
      await ref.read(settingsProvider.notifier).completeOnboarding();

      if (mounted) context.go('/');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resolveLocation() async {
    setState(() => _busy = true);
    try {
      final resolved = await LocationResolver.resolve();
      if (resolved != null) {
        await ref
            .read(settingsProvider.notifier)
            .setLocation(resolved.$1, resolved.$2, resolved.$3);
      } else {
        // Default: Makkah — clearly communicated, changeable later.
        await ref.read(settingsProvider.notifier).setLocation(
              PrayerTimesService.defaultLat,
              PrayerTimesService.defaultLng,
              PrayerTimesService.defaultLabel,
            );
      }
      _next();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _next() => _pages.nextPage(
      duration: const Duration(milliseconds: 350), curve: Curves.easeOut);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 4; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _page == i ? 26 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _page == i
                          ? context.colors.secondary
                          : context.colors.outline.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _WelcomeStep(onStart: _next),
                  _CategoriesStep(
                    enabled: _enabled,
                    order: _scheduleable,
                    onToggle: (c) => setState(() =>
                        _enabled.contains(c) ? _enabled.remove(c) : _enabled.add(c)),
                    onContinue: _next,
                  ),
                  _LocationStep(
                    busy: _busy,
                    onAllow: _resolveLocation,
                    onLater: _next,
                  ),
                  _DoneStep(busy: _busy, onFinish: _finish),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const IslamicStar(size: 96)
              .animate()
              .fadeIn(duration: 600.ms)
              .scale(begin: const Offset(0.7, 0.7)),
          const SizedBox(height: 28),
          Text(context.l10n.onboardingWelcomeTitle,
              textAlign: TextAlign.center,
              style: context.textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Text(
            context.l10n.onboardingWelcomeBody,
            textAlign: TextAlign.center,
            style: context.textTheme.bodyLarge?.copyWith(height: 1.9),
          ),
          const Spacer(),
          FilledButton(
              onPressed: onStart, child: Text(context.l10n.commonStart)),
        ],
      ),
    );
  }
}

class _CategoriesStep extends StatelessWidget {
  const _CategoriesStep({
    required this.enabled,
    required this.order,
    required this.onToggle,
    required this.onContinue,
  });

  final Set<DhikrCategory> enabled;
  final List<DhikrCategory> order;
  final ValueChanged<DhikrCategory> onToggle;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.l10n.onboardingPickCategories,
              textAlign: TextAlign.center,
              style: context.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(context.l10n.onboardingPickCategoriesBody,
              textAlign: TextAlign.center,
              style: context.textTheme.bodySmall),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.6,
              ),
              itemCount: order.length,
              itemBuilder: (context, i) {
                final c = order[i];
                final on = enabled.contains(c);
                return InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => onToggle(c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: on
                          ? context.colors.primary.withValues(alpha: 0.14)
                          : context.colors.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                      border: Border.all(
                        color: on
                            ? context.colors.primary
                            : context.colors.outline.withValues(alpha: 0.4),
                        width: on ? 1.6 : 1,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Icon(c.icon,
                            size: 22,
                            color: on
                                ? context.colors.primary
                                : context.colors.outline),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            adhkarCategoryLabel(context, c),
                            style: context.textTheme.labelLarge?.copyWith(
                              fontWeight:
                                  on ? FontWeight.w800 : FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (on)
                          Icon(Icons.check_circle,
                              size: 18, color: context.colors.primary),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: (i * 40).ms);
              },
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
              onPressed: onContinue, child: Text(context.l10n.commonNext)),
        ],
      ),
    );
  }
}

class _LocationStep extends StatelessWidget {
  const _LocationStep({
    required this.busy,
    required this.onAllow,
    required this.onLater,
  });

  final bool busy;
  final VoidCallback onAllow;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.mosque,
              size: 72, color: context.colors.primary.withValues(alpha: 0.8)),
          const SizedBox(height: 24),
          Text(context.l10n.onboardingLocationTitle,
              textAlign: TextAlign.center,
              style: context.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          Text(context.l10n.onboardingLocationBody,
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(height: 1.9)),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: busy ? null : onAllow,
            icon: const Icon(Icons.my_location),
            label: Text(context.l10n.onboardingLocationAllow),
          ),
          TextButton(
            onPressed: busy ? null : onLater,
            child: Text(context.l10n.onboardingLocationLater),
          ),
        ],
      ),
    );
  }
}

class _DoneStep extends StatelessWidget {
  const _DoneStep({required this.busy, required this.onFinish});
  final bool busy;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.verified,
              size: 84, color: context.colors.secondary.withValues(alpha: 0.85))
              .animate()
              .scale(begin: const Offset(0.6, 0.6), duration: 400.ms),
          const SizedBox(height: 24),
          Text(context.l10n.onboardingReadyTitle,
              textAlign: TextAlign.center,
              style: context.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          Text(context.l10n.onboardingReadyBody,
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(height: 1.9)),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: busy ? null : onFinish,
            child: busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(context.l10n.commonNext),
          ),
        ],
      ),
    );
  }
}
