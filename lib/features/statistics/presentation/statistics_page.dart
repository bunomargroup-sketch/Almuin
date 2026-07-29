import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/extensions/context_x.dart';
import '../../../core/services/app_database.dart';
import '../../../core/theme/glass.dart';
import '../../home/presentation/home_providers.dart';

/// Weekly series of completed+read counts (oldest → newest).
final progressWeekProvider = FutureProvider<List<(String, int)>>(
  (ref) => AppDatabase.instance.progressSeries(days: 7),
);

/// Monthly tasbeeh series.
final tasbeehMonthProvider = FutureProvider<List<(String, int)>>(
  (ref) => AppDatabase.instance.tasbeehSeries(days: 30),
);

final mostReadProvider =
    FutureProvider((ref) => AppDatabase.instance.mostRead(limit: 5));

final totalCompletedProvider = FutureProvider(
  (ref) => AppDatabase.instance.totalCompletedReminders(),
);

/// Weekly/monthly progress, most-read adhkar, longest streak.
class StatisticsPage extends ConsumerWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final week = ref.watch(progressWeekProvider);
    final month = ref.watch(tasbeehMonthProvider);
    final streak = ref.watch(streakProvider);
    final mostRead = ref.watch(mostReadProvider);
    final totals = ref.watch(totalCompletedProvider);

    final locale = Localizations.localeOf(context).languageCode;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.statsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // ---- Summary row --------------------------------------------
          Row(children: [
            Expanded(
              child: _SummaryTile(
                label: context.l10n.statsLongestStreak,
                value: '${streak.valueOrNull?.longest ?? 0}',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryTile(
                label: context.l10n.statsCompleted,
                value: '${totals.valueOrNull ?? 0}',
              ),
            ),
          ]),
          const SizedBox(height: 16),

          // ---- Weekly chart -------------------------------------------
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(context.l10n.statsWeekly,
                    style: context.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                SizedBox(
                  height: 180,
                  child: week.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, __) => Text(context.l10n.statsNoData),
                    data: (series) => _barChart(context, series, locale),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ---- Monthly tasbeeh ----------------------------------------
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(context.l10n.statsMonthly,
                    style: context.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                SizedBox(
                  height: 160,
                  child: month.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, __) => Text(context.l10n.statsNoData),
                    data: (series) =>
                        _barChart(context, series, locale, dense: true),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ---- Most read ----------------------------------------------
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(context.l10n.statsMostRead,
                    style: context.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                mostRead.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) => Text(context.l10n.statsNoData),
                  data: (items) => items.isEmpty
                      ? Text(context.l10n.statsNoData)
                      : Column(children: [
                          for (final d in items)
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                d.arabic,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Text('×${d.timesRead}',
                                  style: context.textTheme.labelLarge?.copyWith(
                                    color: context.colors.secondary,
                                    fontWeight: FontWeight.w800,
                                  )),
                            ),
                        ]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _barChart(
      BuildContext context, List<(String, int)> series, String locale,
      {bool dense = false}) {
    final values = series.map((e) => e.$2.toDouble()).toList();
    final maxY = values.fold<double>(1, (m, v) => v > m ? v : m) * 1.25;
    return BarChart(
      BarChartData(
        maxY: maxY,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (v, _) => v == v.roundToDouble() && v > 0
                  ? Text('${v.round()}',
                      style: context.textTheme.labelSmall)
                  : const SizedBox.shrink(),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= series.length) return const SizedBox.shrink();
                if (dense && i % 5 != 0) return const SizedBox.shrink();
                final day = DateTime.parse(series[i].$1);
                return Text(
                  DateFormat.E(locale).format(day).characters.first,
                  style: context.textTheme.labelSmall,
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < series.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: series[i].$2.toDouble(),
                width: dense ? 5 : 14,
                borderRadius: BorderRadius.circular(6),
                color: context.colors.primary,
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxY,
                  color: context.colors.outline.withValues(alpha: 0.12),
                ),
              ),
            ]),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Text(value,
            style: context.textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(label, style: context.textTheme.labelMedium),
      ]),
    );
  }
}
