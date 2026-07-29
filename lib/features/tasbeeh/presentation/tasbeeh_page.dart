import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/context_x.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/glass.dart';
import '../../home/presentation/home_providers.dart';
import '../application/tasbeeh_controller.dart';

/// Digital tasbeeh: huge satisfying tap area, goal ring, preset adhkar,
/// daily/lifetime stats, recent sessions.
class TasbeehPage extends ConsumerWidget {
  const TasbeehPage({super.key});

  static const goals = [33, 100, 500, 1000];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tasbeehControllerProvider);
    final controller = ref.read(tasbeehControllerProvider.notifier);
    final presets = ref.watch(tasbeehPresetsProvider);
    final today = ref.watch(tasbeehTodayProvider);
    final settings = ref.watch(settingsProvider);

    // Keep the home-tab tile fresh too.
    ref.listen(tasbeehTodayProviderShim, (_, __) {
      ref.invalidate(tasbeehTodayProvider);
    });

    final progress = (state.count / state.target).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.tasbeehTitle),
        actions: [
          IconButton(
            tooltip: context.l10n.tasbeehReset,
            icon: const Icon(Icons.restart_alt),
            onPressed: controller.reset,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // ---- Active dhikr -------------------------------------------
          presets.when(
            loading: () => const SizedBox(
                height: 44, child: Center(child: CircularProgressIndicator())),
            error: (_, __) => const SizedBox.shrink(),
            data: (items) => SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final d = items[i];
                  final active = d.id == state.dhikrId;
                  return ChoiceChip(
                    label: Text(
                      d.arabic,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.mushafText(settings, size: 14, height: 1.2),
                    ),
                    selected: active,
                    onSelected: (_) => controller.selectDhikr(d),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ---- The counter ---------------------------------------------
          GlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  state.dhikrText,
                  textAlign: TextAlign.center,
                  style: AppTheme.mushafText(settings, size: 24),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: controller.increment,
                  child: SizedBox(
                    width: 220,
                    height: 220,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 220,
                          height: 220,
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 10,
                            strokeCap: StrokeCap.round,
                            backgroundColor: context.colors.outline
                                .withValues(alpha: 0.2),
                            color: state.reached
                                ? context.colors.secondary
                                : context.colors.primary,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${state.count}',
                              style: context.textTheme.displayLarge?.copyWith(
                                fontWeight: FontWeight.w200,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                              ),
                            ),
                            Text(
                              '${context.l10n.tasbeehGoal}: ${state.target}',
                              style: context.textTheme.labelLarge,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ).animate(target: state.count.toDouble()).scale(
                      begin: const Offset(0.98, 0.98),
                      end: const Offset(1, 1),
                      duration: 90.ms),
                ),
                const SizedBox(height: 12),
                if (state.reached)
                  Text(
                    '${context.l10n.tasbeehGoalReached} 🤍',
                    style: context.textTheme.titleMedium?.copyWith(
                      color: context.colors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ).animate().fadeIn().scale(
                      begin: const Offset(0.9, 0.9), end: const Offset(1, 1)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ---- Goals ----------------------------------------------------
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final g in goals)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text('$g'),
                    selected: state.target == g,
                    onSelected: (_) => controller.setTarget(g),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ActionChip(
                  avatar: const Icon(Icons.edit, size: 16),
                  label: Text(context.l10n.tasbeehCustomGoal),
                  onPressed: () => _askCustomGoal(context, controller),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ---- Today ----------------------------------------------------
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                const Icon(Icons.today_outlined),
                const SizedBox(width: 12),
                Expanded(child: Text(context.l10n.tasbeehToday)),
                Text(
                  '${today.valueOrNull ?? 0}',
                  style: context.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _askCustomGoal(
      BuildContext context, TasbeehController controller) async {
    final c = TextEditingController();
    final v = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.tasbeehCustomGoal),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(hintText: '100'),
          onSubmitted: (_) =>
              Navigator.pop(ctx, int.tryParse(c.text.trim())),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, int.tryParse(c.text.trim())),
            child: Text(ctx.l10n.commonSave),
          ),
        ],
      ),
    );
    if (v != null && v > 0) controller.setTarget(v);
  }
}
