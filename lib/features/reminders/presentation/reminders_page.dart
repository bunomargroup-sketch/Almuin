import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/context_x.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/theme/glass.dart';
import '../../adhkar/presentation/category_labels.dart';
import '../application/reminder_controller.dart';

/// Manage smart reminders: per-category toggles, frequency per category,
/// global frequency, quiet hours, travel mode, battery saver.
class RemindersPage extends ConsumerWidget {
  const RemindersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(reminderProfilesProvider);
    final settings = ref.watch(settingsProvider);
    final planner = ref.read(reminderPlannerProvider);
    final l10n = context.l10n;

    String freqLabel(FrequencyLevel f) => switch (f) {
          FrequencyLevel.low => l10n.freqLow,
          FrequencyLevel.normal => l10n.freqNormal,
          FrequencyLevel.high => l10n.freqHigh,
        };

    Future<void> replan() => planner.replan();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.remindersTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.auto_awesome, color: context.colors.secondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.remindersSmartHint,
                    style: context.textTheme.bodySmall?.copyWith(height: 1.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ---- Global frequency ---------------------------------------
          _SectionTitle(l10n.remindersFrequency),
          SegmentedButton<FrequencyLevel>(
            segments: [
              for (final f in FrequencyLevel.values)
                ButtonSegment(value: f, label: Text(freqLabel(f))),
            ],
            selected: {settings.globalFrequency},
            onSelectionChanged: (s) {
              ref
                  .read(settingsProvider.notifier)
                  .update((st) => st.copyWith(globalFrequency: s.first));
              replan();
            },
          ),
          const SizedBox(height: 20),

          // ---- Per-category -------------------------------------------
          _SectionTitle(l10n.tabAdhkar),
          for (final p in profiles)
            GlassCard(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(
                children: [
                  Icon(p.category.icon, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(adhkarCategoryLabel(context, p.category),
                        style: context.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                  ),
                  if (p.enabled)
                    DropdownButton<FrequencyLevel>(
                      value: p.frequency,
                      underline: const SizedBox.shrink(),
                      isDense: true,
                      items: [
                        for (final f in FrequencyLevel.values)
                          DropdownMenuItem(
                            value: f,
                            child: Text(freqLabel(f),
                                style: context.textTheme.labelMedium),
                          ),
                      ],
                      onChanged: (f) {
                        if (f == null) return;
                        ref
                            .read(reminderProfilesProvider.notifier)
                            .setFrequency(p.category, f);
                        replan();
                      },
                    ),
                  const SizedBox(width: 8),
                  Switch(
                    value: p.enabled,
                    onChanged: (v) {
                      ref
                          .read(reminderProfilesProvider.notifier)
                          .toggle(p.category, v);
                      replan();
                    },
                  ),
                ],
              ),
            ),

          const SizedBox(height: 20),
          _SectionTitle(l10n.remindersQuietHours),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              const Icon(Icons.do_not_disturb_on_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${_fmt(settings.quietStartMinutes)} → ${_fmt(settings.quietEndMinutes)}',
                  style: context.textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: () => _editQuietHours(context, ref, replan),
                child: const Icon(Icons.edit_outlined),
              ),
            ]),
          ),
          const SizedBox(height: 12),

          // ---- Modes ----------------------------------------------------
          GlassCard(
            padding: const EdgeInsets.all(4),
            child: Column(children: [
              SwitchListTile(
                secondary: const Icon(Icons.flight_takeoff),
                title: Text(l10n.remindersTravelMode),
                subtitle: Text(l10n.remindersTravelModeSubtitle),
                value: settings.travelMode,
                onChanged: (v) {
                  ref
                      .read(settingsProvider.notifier)
                      .update((s) => s.copyWith(travelMode: v));
                  replan();
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.battery_saver_outlined),
                title: const Text('وضع توفير البطارية'),
                subtitle: const Text(
                    'تقليل التنبيهات ودمج التذكيرات لتقليل استهلاك الطاقة'),
                value: settings.batterySaver,
                onChanged: (v) {
                  ref
                      .read(settingsProvider.notifier)
                      .update((s) => s.copyWith(batterySaver: v));
                  replan();
                },
              ),
            ]),
          ),
        ],
      ),
    );
  }

  String _fmt(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _editQuietHours(
      BuildContext context, WidgetRef ref, Future<void> Function() replan) async {
    final settings = ref.read(settingsProvider);

    Future<int?> pick(int initial) async {
      final tod = await showTimePicker(
        context: context,
        initialTime:
            TimeOfDay(hour: initial ~/ 60, minute: initial % 60),
      );
      return tod == null ? null : tod.hour * 60 + tod.minute;
    }

    final start = await pick(settings.quietStartMinutes);
    if (start == null || !context.mounted) return;
    final end = await pick(settings.quietEndMinutes);
    if (end == null) return;

    ref.read(settingsProvider.notifier).update(
        (s) => s.copyWith(quietStartMinutes: start, quietEndMinutes: end));
    await replan();
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(text,
          style: context.textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w800)),
    );
  }
}
