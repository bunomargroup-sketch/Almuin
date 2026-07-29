import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/extensions/context_x.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/glass.dart';
import '../../adhkar/domain/dhikr.dart' show AuthenticityGrade;
import '../application/ai_controller.dart';
import '../domain/adhkar_recommender.dart';

/// "اسأل المُعين" — the situation-aware assistant.
class AiChatPage extends ConsumerStatefulWidget {
  const AiChatPage({super.key});

  @override
  ConsumerState<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends ConsumerState<AiChatPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  static const _suggestionsAr = [
    'أشعر بالقلق 😟',
    'لا أستطيع النوم 🌙',
    'أنا مسافر ✈️',
    'أشعر بالامتنان 🤍',
    'أنا غاضب 😤',
    'والدتي مريضة 🤲',
    'عندي امتحان 📚',
    'أشعر بالهمّ',
  ];

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send(String text) {
    if (text.trim().isEmpty) return;
    _input.clear();
    ref.read(aiChatProvider.notifier).send(text);
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(aiChatProvider);
    final busy = ref.watch(aiBusyProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.aiTitle),
        actions: [
          IconButton(
            tooltip: 'مسح المحادثة',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(aiChatProvider.notifier).clear(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? _Welcome(onSuggestion: _send)
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length + (busy ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (busy && i == messages.length) {
                        return const _TypingBubble();
                      }
                      final m = messages[i];
                      return _Bubble(message: m, onOpenDhikr: (id) => context
                          .push('${AppConstants.routeDhikrPrefix}$id'));
                    },
                  ),
          ),
          if (messages.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _suggestionsAr.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) => ActionChip(
                  label: Text(_suggestionsAr[i]),
                  onPressed: () => _send(_suggestionsAr[i]),
                ),
              ),
            ),
          const SizedBox(height: 8),
          _InputBar(
            controller: _input,
            hint: context.l10n.aiHint,
            busy: busy,
            onSend: () => _send(_input.text),
          ),
        ],
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.onSuggestion});
  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        const Center(child: IslamicStar(size: 72)),
        const SizedBox(height: 20),
        Text(
          context.l10n.aiIntro,
          textAlign: TextAlign.center,
          style: context.textTheme.bodyLarge?.copyWith(height: 1.8),
        ),
        const SizedBox(height: 16),
        Text(
          context.l10n.aiDisclaimer,
          textAlign: TextAlign.center,
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colors.primary,
            height: 1.7,
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in _AiChatPageState._suggestionsAr)
              ActionChip(label: Text(s), onPressed: () => onSuggestion(s)),
          ],
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }
}

class _Bubble extends ConsumerWidget {
  const _Bubble({required this.message, required this.onOpenDhikr});

  final AiMessage message;
  final ValueChanged<String> onOpenDhikr;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final align = message.isUser ? Alignment.centerLeft : Alignment.centerRight;
    final bubbleColor = message.isUser
        ? context.colors.primary.withValues(alpha: 0.14)
        : context.colors.surfaceContainerHighest.withValues(alpha: 0.7);

    return Align(
      alignment: align,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: context.colors.outline.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                message.text,
                style: context.textTheme.bodyMedium?.copyWith(height: 1.7),
              ),
              if (message.items.isNotEmpty) ...[
                const SizedBox(height: 10),
                for (final item in message.items)
                  _RecommendationTile(
                    item: item,
                    mushaf: AppTheme.mushafText(settings, size: 17),
                    onOpen: item.isVerse
                        ? null
                        : () => onOpenDhikr(item.id),
                  ),
              ],
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.03);
  }
}

class _RecommendationTile extends StatelessWidget {
  const _RecommendationTile({
    required this.item,
    required this.mushaf,
    this.onOpen,
  });

  final RecommendationItem item;
  final TextStyle mushaf;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border(
          right: BorderSide(
            color: item.grade == AuthenticityGrade.quran
                ? AppTheme.gold
                : AppTheme.emerald,
            width: 3,
          ),
        ),
      ),
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(item.arabic,
                textAlign: TextAlign.right, style: mushaf.copyWith(height: 1.8)),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  item.isVerse ? Icons.menu_book : Icons.verified_outlined,
                  size: 14,
                  color: context.colors.secondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    item.reference,
                    style: context.textTheme.labelSmall?.copyWith(
                      color: context.colors.secondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (onOpen != null)
                  Icon(Icons.open_in_new,
                      size: 14, color: context.colors.outline),
              ],
            ),
            if (item.rewardAr.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(item.rewardAr,
                  style: context.textTheme.bodySmall?.copyWith(height: 1.6)),
            ],
          ],
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: context.colors.surfaceContainerHighest.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(context.l10n.aiThinking,
            style: context.textTheme.bodySmall),
      ),
    ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms);
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.hint,
    required this.busy,
    required this.onSend,
  });

  final TextEditingController controller;
  final String hint;
  final bool busy;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: hint,
                  filled: true,
                  fillColor: context.colors.surfaceContainerHighest
                      .withValues(alpha: 0.7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: busy ? null : onSend,
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
