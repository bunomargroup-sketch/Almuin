import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/context_x.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/glass.dart';
import '../application/context_providers.dart';
import '../domain/context_topic.dart';

/// Surfaces one authentic dhikr chosen for today's context.
///
/// Renders nothing at all when there is no signal, which is the ordinary
/// case. It shows the dhikr, its grade-bearing reference, and a short
/// app-authored reason — never a headline, a place, or any text the app did
/// not ship and grade itself.
class ContextSuggestionCard extends ConsumerWidget {
  const ContextSuggestionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final async = ref.watch(contextSuggestionProvider);

    return async.when(
      // Silence while loading and on failure: context is a nice-to-have and
      // must never put a spinner or an error on the home screen.
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (s) {
        if (s == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: GlassCard(
            onTap: () => context.push('/dhikr/${s.dhikr.id}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_iconFor(s.topic),
                        size: 18, color: context.colors.secondary),
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.homeContextTitle,
                      style: context.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  s.reasonAr,
                  textAlign: TextAlign.center,
                  style: context.textTheme.labelMedium?.copyWith(
                    color: context.colors.secondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  s.dhikr.arabic,
                  textAlign: TextAlign.center,
                  style: AppTheme.mushafText(settings, size: 20),
                ),
                if (s.dhikr.references.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    '${s.dhikr.references.first.collection} '
                    '${s.dhikr.references.first.number}',
                    textAlign: TextAlign.center,
                    style: context.textTheme.labelSmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  static IconData _iconFor(ContextTopic t) => switch (t) {
        ContextTopic.rain => Icons.water_drop_outlined,
        ContextTopic.thunderstorm => Icons.thunderstorm_outlined,
        ContextTopic.strongWind => Icons.air,
        ContextTopic.snow => Icons.ac_unit,
        ContextTopic.extremeHeat => Icons.wb_sunny_outlined,
        ContextTopic.extremeCold => Icons.severe_cold,
        ContextTopic.calamity => Icons.favorite_outline,
        ContextTopic.illness => Icons.healing_outlined,
        ContextTopic.hardship => Icons.volunteer_activism_outlined,
        ContextTopic.friday => Icons.mosque_outlined,
        ContextTopic.ramadan => Icons.nightlight_outlined,
        ContextTopic.dhulHijjah => Icons.star_outline,
        _ => Icons.auto_awesome_outlined,
      };
}
