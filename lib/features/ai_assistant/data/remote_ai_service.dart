import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/utils/logger.dart';
import '../domain/adhkar_recommender.dart';

class RemoteRankResult {
  const RemoteRankResult({required this.selectedIds});
  final List<String> selectedIds;
}

/// Optional cloud enhancement for the AI assistant.
///
/// HARD CONTRACT (enforced client-side, mirrored by the edge function):
/// * The model receives ids, references, grades and tags of candidates ALREADY
///   chosen from our verified SQLite content. It does NOT receive their Arabic
///   text — it ranks on metadata, and cannot echo text it never saw.
/// * It may return exactly one thing: a re-ordered subset of those ids. The
///   response schema has no free-text field, so there is no prose to sanitize
///   and nothing for a sanitizer to miss.
/// * Any id not present in the candidates voids the whole response, and the
///   deterministic local ranking is used instead.
/// * The model can therefore NEVER inject invented hadith/verses/adhkar, and
///   never puts a word of its own in front of the user.
class RemoteAiService {
  RemoteAiService(this._client);

  final SupabaseClient _client;

  static RemoteAiService? maybeCreate() {
    if (!AppConfig.supabaseEnabled) return null;
    try {
      return RemoteAiService(Supabase.instance.client);
    } catch (_) {
      return null;
    }
  }

  Future<RemoteRankResult?> rank({
    required String userText,
    required List<RecommendationItem> candidates,
    String locale = 'ar',
  }) async {
    try {
      final res = await _client.functions.invoke(
        AppConfig.aiFunctionName,
        body: {
          'user_text': userText,
          'locale': locale,
          'candidates': [
            for (final c in candidates)
              {
                'id': c.id,
                'reference': c.reference,
                'grade': c.grade.name,
                'tags': c.tags,
              },
          ],
        },
      );
      final data = res.data as Map<String, dynamic>?;
      if (data == null) return null;

      final ids = [
        for (final x in (data['selected_ids'] as List<dynamic>? ?? const []))
          '$x',
      ];
      // SUBSET VALIDATION — the safety gate.
      final candidateIds = candidates.map((c) => c.id).toSet();
      if (ids.any((id) => !candidateIds.contains(id))) {
        logWarn('Remote AI returned unknown ids — response discarded');
        return null;
      }
      if (ids.isEmpty && candidates.isNotEmpty) return null;
      return RemoteRankResult(selectedIds: ids);
    } catch (e, st) {
      logWarn('Remote AI unavailable — using local ranking', e, st);
      return null;
    }
  }
}
