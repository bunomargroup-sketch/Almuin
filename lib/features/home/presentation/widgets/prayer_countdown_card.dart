import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_x.dart';
import '../../../../core/theme/glass.dart';
import '../../../prayer/prayer_service.dart';

/// Hero card: current prayer, next prayer, live countdown ring.
class PrayerCountdownCard extends ConsumerWidget {
  const PrayerCountdownCard({super.key});

  String _prayerLabel(BuildContext context, AppPrayer p) {
    final l10n = context.l10n;
    return switch (p) {
      AppPrayer.fajr => l10n.prayerFajr,
      AppPrayer.sunrise => l10n.prayerSunrise,
      AppPrayer.dhuhr => l10n.prayerDhuhr,
      AppPrayer.asr => l10n.prayerAsr,
      AppPrayer.maghrib => l10n.prayerMaghrib,
      AppPrayer.isha => l10n.prayerIsha,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prayers = ref.watch(todayPrayerTimesProvider);
    final now = ref.watch(nowTickerProvider).valueOrNull ?? DateTime.now();

    final next = prayers.nextAfter(now);
    final current = prayers.currentAt(now);

    final nextName =
        next == null ? context.l10n.prayerFajr : _prayerLabel(context, next.$1);
    final nextTime = next?.$2 ??
        prayers[AppPrayer.fajr].add(const Duration(days: 1));
    final prevTime = current?.$2 ?? nextTime.subtract(const Duration(hours: 1));
    final remaining = nextTime.difference(now);
    final total = nextTime.difference(prevTime);
    final progress =
        1 - (remaining.inSeconds / total.inSeconds).clamp(0.0, 1.0);

    final hh = remaining.inHours.toString().padLeft(2, '0');
    final mm = (remaining.inMinutes % 60).toString().padLeft(2, '0');
    final ss = (remaining.inSeconds % 60).toString().padLeft(2, '0');

    return GlassCard(
      padding: const EdgeInsets.all(22),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.homeNextPrayer,
                  style: context.textTheme.labelLarge
                      ?.copyWith(color: context.colors.primary),
                ),
                const SizedBox(height: 4),
                Text(nextName,
                    style: context.textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(
                  '$hh:$mm:$ss',
                  style: context.textTheme.displaySmall?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                    fontWeight: FontWeight.w300,
                    letterSpacing: 2,
                  ),
                ),
                if (current != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${context.l10n.homeCurrentPrayer}: ${_prayerLabel(context, current.$1)}',
                    style: context.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          SizedBox(
            width: 76,
            height: 76,
            child: Stack(alignment: Alignment.center, children: [
              CircularProgressIndicator(
                value: progress,
                strokeWidth: 6,
                strokeCap: StrokeCap.round,
                backgroundColor:
                    context.colors.outline.withValues(alpha: 0.25),
                color: context.colors.secondary,
              ),
              Text('${(progress * 100).round()}%',
                  style: context.textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ]),
          ),
        ],
      ),
    );
  }
}
