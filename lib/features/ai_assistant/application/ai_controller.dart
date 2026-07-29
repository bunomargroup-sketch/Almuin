import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/hijri_utils.dart';
import '../../adhkar/presentation/adhkar_providers.dart';
import '../data/remote_ai_service.dart';
import '../domain/adhkar_recommender.dart';
import '../domain/situation_intent.dart';

class AiMessage {
  const AiMessage.user(this.text)
      : isUser = true,
        items = const [];

  const AiMessage.assistant(this.text, {this.items = const []}) : isUser = false;

  final String text;
  final bool isUser;
  final List<RecommendationItem> items;
}

final aiChatProvider =
    NotifierProvider<AiChatController, List<AiMessage>>(AiChatController.new);

final aiBusyProvider = StateProvider<bool>((_) => false);

/// The conversational layer on top of the deterministic recommender.
///
/// Pipeline per user message:
/// 1. Classify the situation (on-device, deterministic).
/// 2. Retrieve + rank verified candidates locally (always works offline).
/// 3. If Supabase AI edge function is configured, ask it to *re-rank only*
///    (subset-validated). Otherwise the local ranking ships as-is.
/// 4. Compose the reply ONLY from database fields (text + reference + reward).
class AiChatController extends Notifier<List<AiMessage>> {
  final _recommender = const AdhkarRecommender();

  @override
  List<AiMessage> build() => const [];

  Future<void> send(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty) return;
    state = [...state, AiMessage.user(text)];
    ref.read(aiBusyProvider.notifier).state = true;

    try {
      final intent = const SituationClassifier().classify(text);
      final adhkar = await ref.read(adhkarListProvider.future);
      final verses = await ref.read(versesProvider.future);

      var bundle = _recommender.recommend(
        intent: intent.intent,
        adhkar: adhkar,
        verses: verses,
        hijri: hijriOf(DateTime.now()),
        nowWindow: contentWindowOf(DateTime.now()),
      );

      // Optional cloud re-rank — strictly validated elsewhere.
      final remote = RemoteAiService.maybeCreate();
      if (remote != null && bundle.items.isNotEmpty) {
        final result = await remote.rank(
          userText: text,
          candidates: bundle.items,
          locale: LocalizationsArEn.currentLanguage,
        );
        if (result != null) {
          final byId = {for (final i in bundle.items) i.id: i};
          final reordered = [
            for (final id in result.selectedIds)
              if (byId[id] != null) byId[id]!,
          ];
          if (reordered.isNotEmpty) {
            bundle = RecommendationBundle(
              intent: bundle.intent,
              items: reordered,
              introAr: result.empathyAr.isNotEmpty
                  ? '${result.empathyAr}\n${bundle.introAr}'
                  : bundle.introAr,
            );
          }
        }
      }

      state = [
        ...state,
        AiMessage.assistant(
          bundle.items.isEmpty
              ? bundle.introAr // honest "no authentic match" wording
              : '${bundle.introAr}\n\n${AiReplyComposer.footerNote}',
          items: bundle.items,
        ),
      ];
    } finally {
      ref.read(aiBusyProvider.notifier).state = false;
    }
  }

  void clear() => state = const [];
}

/// Neutral locale indicator for the remote function (avoid importing widgets).
abstract final class LocalizationsArEn {
  static String currentLanguage = 'ar';
}

abstract final class AiReplyComposer {
  static const footerNote =
      '— كل ما سبق بنصّه من مصادر موثّقة مبيّنة تحت كل نص. المُعين لا يختلق حديثًا ولا ذكرًا.';
}
