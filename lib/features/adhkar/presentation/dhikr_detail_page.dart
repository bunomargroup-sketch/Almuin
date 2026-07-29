import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/extensions/context_x.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/glass.dart';
import '../domain/dhikr.dart';
import 'adhkar_providers.dart';
import 'widgets/dhikr_card.dart';

/// The full dhikr experience:
/// Arabic (Amiri, generous line height) · transliteration · translation ·
/// meaning · reward · references with authenticity · repeat counter ·
/// read-aloud · share · favorite.
class DhikrDetailPage extends ConsumerStatefulWidget {
  const DhikrDetailPage({
    super.key,
    required this.dhikrId,
    this.autoRead = false,
  });

  final String dhikrId;

  /// True when opened from the notification "استمع" action.
  final bool autoRead;

  @override
  ConsumerState<DhikrDetailPage> createState() => _DhikrDetailPageState();
}

class _DhikrDetailPageState extends ConsumerState<DhikrDetailPage> {
  int _count = 0;
  bool _readTriggered = false;

  @override
  void dispose() {
    TtsService.instance.stop();
    super.dispose();
  }

  Future<void> _maybeAutoRead(Dhikr d) async {
    if (!widget.autoRead || _readTriggered) return;
    _readTriggered = true;
    if (ref.read(settingsProvider).ttsEnabled) {
      await TtsService.instance.speakArabic(d.arabic);
    }
  }

  Future<void> _markComplete(Dhikr d) async {
    await ref.read(dhikrRepositoryProvider).markRead(d.id);
    ref.invalidate(dhikrProvider(widget.dhikrId));
    ref.invalidate(adhkarListProvider);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final async = ref.watch(dhikrProvider(widget.dhikrId));

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: context.l10n.commonShare,
            icon: const Icon(Icons.ios_share),
            onPressed: async.valueOrNull == null
                ? null
                : () {
                    final d = async.valueOrNull!;
                    final refs = d.references.map((e) => e.format()).join(' · ');
                    SharePlus.instance.share(ShareParams(
                        text: '${d.arabic}\n\n— $refs · تطبيق المُعين'));
                  },
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (dhikr) {
          if (dhikr == null) {
            return Center(child: Text(context.l10n.statsNoData));
          }
          _maybeAutoRead(dhikr);
          final done = _count >= dhikr.repeat;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              // ---- Revealed text --------------------------------------
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      AuthenticityBadge(grade: dhikr.bestGrade),
                      const Spacer(),
                      IconButton(
                        tooltip: context.l10n.commonFavorite,
                        icon: Icon(
                          dhikr.isFavorite
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: dhikr.isFavorite
                              ? context.colors.tertiary
                              : context.colors.outline,
                        ),
                        onPressed: () async {
                          await ref
                              .read(dhikrRepositoryProvider)
                              .setFavorite(dhikr.id, !dhikr.isFavorite);
                          ref.invalidate(dhikrProvider(widget.dhikrId));
                          ref.invalidate(favoritesProvider);
                        },
                      ),
                      IconButton(
                        tooltip: context.l10n.commonListen,
                        icon: const Icon(Icons.volume_up_outlined),
                        onPressed: () =>
                            TtsService.instance.speakArabic(dhikr.arabic),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Text(
                      dhikr.arabic,
                      textAlign: TextAlign.center,
                      style: AppTheme.mushafText(settings, size: 24),
                    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.04),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ---- Repeat counter --------------------------------------
              if (dhikr.repeat > 1)
                GlassCard(
                  onTap: done
                      ? null
                      : () {
                          HapticFeedback.lightImpact();
                          setState(() => _count++);
                          if (_count + 1 >= dhikr.repeat) _markComplete(dhikr);
                        },
                  child: Column(children: [
                    Text(context.l10n.dhikrTapToCount,
                        style: context.textTheme.labelLarge),
                    const SizedBox(height: 12),
                    _CounterRing(current: _count, target: dhikr.repeat),
                    const SizedBox(height: 12),
                    if (done)
                      Text(
                        '${context.l10n.dhikrCompleted} 🤍',
                        style: context.textTheme.titleMedium?.copyWith(
                          color: context.colors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ]),
                )
              else
                _MarkReadButton(
                  onPressed: () => _markComplete(dhikr),
                  label: context.l10n.commonDone,
                ),
              const SizedBox(height: 16),

              // ---- Meaning & reward ------------------------------------
              if (dhikr.transliteration.isNotEmpty)
                _InfoSection(
                  title: context.l10n.dhikrTransliteration,
                  body: dhikr.transliteration,
                  ltr: true,
                ),
              if (dhikr.translationEn.isNotEmpty)
                _InfoSection(
                  title: context.l10n.dhikrTranslation,
                  body: dhikr.translationEn,
                  ltr: true,
                ),
              if (dhikr.meaningAr.isNotEmpty)
                _InfoSection(
                    title: context.l10n.dhikrMeaning, body: dhikr.meaningAr),
              if (dhikr.rewardAr.isNotEmpty)
                _InfoSection(
                  title: context.l10n.dhikrReward,
                  body: dhikr.rewardAr,
                  highlight: true,
                ),

              // ---- References (always visible — safety requirement) ----
              _InfoSection(
                title: context.l10n.dhikrReference,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final r in dhikr.references)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(Icons.verified_outlined, size: 16),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                [
                                  r.format(),
                                  if (r.note != null) r.note!,
                                ].join(' — '),
                                style: context.textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Row(children: [
                      Text('${context.l10n.dhikrAuthenticity}: ',
                          style: context.textTheme.labelLarge),
                      AuthenticityBadge(grade: dhikr.bestGrade),
                    ]),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CounterRing extends StatelessWidget {
  const _CounterRing({required this.current, required this.target});
  final int current;
  final int target;

  @override
  Widget build(BuildContext context) {
    final progress = (current / target).clamp(0.0, 1.0);
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(alignment: Alignment.center, children: [
        CircularProgressIndicator(
          value: progress,
          strokeWidth: 8,
          strokeCap: StrokeCap.round,
          backgroundColor: context.colors.outline.withValues(alpha: 0.25),
          color: context.colors.secondary,
        ),
        Text('$current / $target',
            style: context.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class _MarkReadButton extends StatelessWidget {
  const _MarkReadButton({required this.onPressed, required this.label});
  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.check_circle_outline),
      label: Text(label),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({
    required this.title,
    this.body,
    this.child,
    this.highlight = false,
    this.ltr = false,
  });

  final String title;
  final String? body;
  final Widget? child;
  final bool highlight;
  final bool ltr;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlight
            ? scheme.secondary.withValues(alpha: 0.08)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (highlight ? scheme.secondary : scheme.outline)
              .withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title,
              style: context.textTheme.labelLarge?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w800,
              )),
          const SizedBox(height: 6),
          child ??
              Directionality(
                textDirection:
                    ltr ? TextDirection.ltr : TextDirection.rtl,
                child: Text(
                  body ?? '',
                  style: context.textTheme.bodyMedium?.copyWith(height: 1.7),
                  textAlign: ltr ? TextAlign.left : TextAlign.right,
                ),
              ),
        ],
      ),
    );
  }
}
