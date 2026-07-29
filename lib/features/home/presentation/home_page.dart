import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/extensions/context_x.dart';
import '../../../core/theme/glass.dart';
import '../../../core/utils/hijri_utils.dart';
import '../../gamification/application/gamification_providers.dart';
import '../../statistics/presentation/statistics_page.dart' show progressWeekProvider;
import '../domain/daily_content.dart';
import 'home_providers.dart';
import 'widgets/daily_content_cards.dart';
import 'widgets/prayer_countdown_card.dart';

/// Dashboard: greeting · prayer countdown · today's verse & hadith ·
/// recommended dhikr · progress & streak · quick tasbeeh.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hijri = hijriOf(DateTime.now());
    final progress = ref.watch(todayProgressProvider);
    final streak = ref.watch(streakProvider);
    final tasbeeh = ref.watch(tasbeehTodayProvider);

    // Refresh derived widgets when the day rolls or achievements unlock.
    ref.watch(achievementUnlockProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(todayProgressProvider);
            ref.invalidate(streakProvider);
            ref.invalidate(recommendedDhikrProvider);
            ref.invalidate(progressWeekProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              // ---- Greeting & hijri date --------------------------------
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.l10n.homeGreeting,
                            style: context.textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text('${context.l10n.homeHijriToday}: ${hijri.formatAr()}',
                            style: context.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  if (hijri.isRamadan) const _SeasonChip('رمضان 🌙'),
                  if (hijri.isFriday) const _SeasonChip('جمعة مباركة'),
                  if (hijri.isEid) const _SeasonChip('عيد سعيد 🎉'),
                ],
              ).animate().fadeIn(duration: 350.ms),
              const SizedBox(height: 16),

              const PrayerCountdownCard()
                  .animate()
                  .fadeIn(delay: 60.ms)
                  .slideY(begin: 0.05, end: 0),
              const SizedBox(height: 16),

              // ---- Stats row --------------------------------------------
              Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      icon: Icons.local_fire_department_outlined,
                      value: '${streak.valueOrNull?.current ?? 0}',
                      label: context.l10n.homeStreak,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatTile(
                      icon: Icons.check_circle_outline,
                      value:
                          '${progress.valueOrNull?.completed ?? 0}/${progress.valueOrNull?.scheduled ?? 0}',
                      label: context.l10n.homeCompleted,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatTile(
                      icon: Icons.touch_app_outlined,
                      value: '${tasbeeh.valueOrNull ?? 0}',
                      label: context.l10n.tasbeehToday,
                      onTap: () => context.go('/tasbeeh'),
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 120.ms),
              const SizedBox(height: 20),

              // ---- Recommended rail -------------------------------------
              _SectionHeader(
                title: context.l10n.homeRecommended,
                actionLabel: context.l10n.homeOpenAll,
                onAction: () => context.go('/adhkar'),
              ),
              const SizedBox(height: 8),
              RecommendedRail(
                onOpenDhikr: (id) => context
                    .push('${AppConstants.routeDhikrPrefix}$id'),
              ).animate().fadeIn(delay: 160.ms),
              const SizedBox(height: 20),

              const TodayVerseCard().animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 12),
              const TodayHadithCard().animate().fadeIn(delay: 240.ms),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeasonChip extends StatelessWidget {
  const _SeasonChip(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsetsDirectional.only(start: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: context.colors.secondary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
            color: context.colors.secondary.withValues(alpha: 0.5)),
      ),
      child: Text(text,
          style: context.textTheme.labelSmall
              ?.copyWith(fontWeight: FontWeight.w700)),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      child: Column(
        children: [
          Icon(icon, size: 20, color: context.colors.secondary),
          const SizedBox(height: 6),
          Text(value,
              style: context.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          Text(label,
              textAlign: TextAlign.center,
              style: context.textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title,
              style: context.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
        ),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}
