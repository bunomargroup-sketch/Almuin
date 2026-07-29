import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_x.dart';
import '../../../../core/services/settings_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/glass.dart';
import '../../domain/dhikr.dart';

/// Compact glass card for lists: Arabic snippet, authenticity badge,
/// favorite heart, and the repeat hint.
class DhikrCard extends ConsumerWidget {
  const DhikrCard({super.key, required this.dhikr, this.onTap, this.onToggleFavorite});

  final Dhikr dhikr;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onToggleFavorite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AuthenticityBadge(grade: dhikr.bestGrade),
              const Spacer(),
              if (dhikr.repeat > 1)
                _RepeatHint(times: dhikr.repeat),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  dhikr.isFavorite ? Icons.favorite : Icons.favorite_border,
                  size: 20,
                  color: dhikr.isFavorite
                      ? Theme.of(context).colorScheme.tertiary
                      : Theme.of(context).colorScheme.outline,
                ),
                onPressed: () => onToggleFavorite?.call(!dhikr.isFavorite),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            dhikr.arabic,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.mushafText(settings, size: 19, height: 1.8),
            textAlign: TextAlign.right,
          ),
          if (dhikr.rewardAr.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              dhikr.rewardAr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The safety-critical authenticity chip (قرآن / صحيح / حسن / ضعيف / مضاف).
class AuthenticityBadge extends StatelessWidget {
  const AuthenticityBadge({super.key, required this.grade});

  final AuthenticityGrade grade;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (label, color) = switch (grade) {
      AuthenticityGrade.quran => (l10n.gradeQuran, AppTheme.gold),
      AuthenticityGrade.sahih => (l10n.gradeSahih, AppTheme.emerald),
      AuthenticityGrade.hasan => (l10n.gradeHasan, const Color(0xFF7A8F3F)),
      AuthenticityGrade.daif => (l10n.gradeDaif, AppTheme.rose),
      AuthenticityGrade.custom => (l10n.gradeCustom, Colors.blueGrey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.8),
      ),
      child: Text(
        label,
        style: context.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RepeatHint extends StatelessWidget {
  const _RepeatHint({required this.times});
  final int times;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 4),
      child: Text('×$times',
          style: context.textTheme.labelMedium?.copyWith(
            color: context.colors.secondary,
            fontWeight: FontWeight.w800,
          )),
    );
  }
}
