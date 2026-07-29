import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/context_x.dart';
import '../../../core/theme/glass.dart';
import '../application/gamification_providers.dart';
import '../domain/achievements.dart';

/// Badges grid: unlocked (gold) vs. upcoming (softly hinted, no shame).
class AchievementsPage extends ConsumerWidget {
  const AchievementsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unlocked = ref.watch(unlockedAchievementsProvider);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.achievementsTitle)),
      body: unlocked.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (ids) => GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.92,
          ),
          itemCount: AchievementCatalog.all.length,
          itemBuilder: (context, i) {
            final a = AchievementCatalog.all[i];
            final has = ids.contains(a.id);
            return GlassCard(
              padding: const EdgeInsets.all(14),
              borderOpacity: has ? 0.8 : 0.2,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: has
                        ? context.colors.secondary.withValues(alpha: 0.15)
                        : context.colors.outline.withValues(alpha: 0.12),
                    child: Icon(
                      a.icon,
                      color: has
                          ? context.colors.secondary
                          : context.colors.outline,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isAr ? a.titleAr : a.titleEn,
                    textAlign: TextAlign.center,
                    style: context.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    a.descAr,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodySmall,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
