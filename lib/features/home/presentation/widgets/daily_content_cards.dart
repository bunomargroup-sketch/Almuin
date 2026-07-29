import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_x.dart';
import '../../../../core/services/settings_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/glass.dart';
import '../../domain/daily_content.dart';

/// "Verse of the day" — mushaf typography with its reference.
class TodayVerseCard extends ConsumerWidget {
  const TodayVerseCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final async = ref.watch(todayVerseProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (verse) {
        if (verse == null) return const SizedBox.shrink();
        return GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CardHeader(
                icon: Icons.menu_book_outlined,
                title: context.l10n.homeTodayVerse,
              ),
              const SizedBox(height: 12),
              Text(
                '﴿${verse.arabic}﴾',
                textAlign: TextAlign.center,
                style: AppTheme.mushafText(settings, size: 21),
              ),
              const SizedBox(height: 10),
              Text(
                verse.reference,
                textAlign: TextAlign.center,
                style: context.textTheme.labelMedium?.copyWith(
                  color: context.colors.secondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (verse.tafsirBriefAr.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  verse.tafsirBriefAr,
                  textAlign: TextAlign.center,
                  style: context.textTheme.bodySmall?.copyWith(height: 1.6),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// "Hadith of the day" — always with collection + number + grade.
class TodayHadithCard extends ConsumerWidget {
  const TodayHadithCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final async = ref.watch(todayHadithProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (hadith) {
        if (hadith == null) return const SizedBox.shrink();
        return GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CardHeader(
                icon: Icons.format_quote_outlined,
                title: context.l10n.homeTodayHadith,
              ),
              const SizedBox(height: 12),
              Text(
                hadith.arabic,
                textAlign: TextAlign.center,
                style: AppTheme.mushafText(settings, size: 19),
              ),
              const SizedBox(height: 10),
              Text(
                hadith.reference,
                textAlign: TextAlign.center,
                style: context.textTheme.labelMedium?.copyWith(
                  color: context.colors.secondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (hadith.benefitAr.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  hadith.benefitAr,
                  textAlign: TextAlign.center,
                  style: context.textTheme.bodySmall?.copyWith(height: 1.6),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Horizontal recommendation rail ("ذكر اليوم المقترح").
class RecommendedRail extends ConsumerWidget {
  const RecommendedRail({super.key, required this.onOpenDhikr});

  final void Function(String dhikrId) onOpenDhikr;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final async = ref.watch(recommendedDhikrProvider);
    return async.when(
      loading: () => const SizedBox(
          height: 120, child: Center(child: CircularProgressIndicator())),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) => SizedBox(
        height: 150,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, i) {
            final d = items[i];
            return SizedBox(
              width: 250,
              child: GlassCard(
                onTap: () => onOpenDhikr(d.id),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      d.arabic,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style:
                          AppTheme.mushafText(settings, size: 16, height: 1.7),
                      textAlign: TextAlign.right,
                    ),
                    const Spacer(),
                    if (d.rewardAr.isNotEmpty)
                      Text(
                        d.rewardAr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.labelSmall?.copyWith(
                            color: context.colors.primary,
                            fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: context.colors.secondary),
        const SizedBox(width: 8),
        Text(
          title,
          style: context.textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
