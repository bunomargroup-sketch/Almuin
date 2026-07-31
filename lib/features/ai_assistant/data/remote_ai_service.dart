import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/utils/logger.dart';
import '../domain/adhkar_recommender.dart';

class RemoteRankResult {
  const RemoteRankResult({required this.selectedIds, required this.empathyAr});
  final List<String> selectedIds;
  final String empathyAr;
}

/// Optional cloud enhancement for the AI assistant.
///
/// HARD CONTRACT (enforced client-side, mirrored by the edge function):
/// * The model receives ONLY the candidate items fetched from our verified
///   SQLite content — ids, Arabic text, references, tags.
/// * It may return: (a) a re-ordered subset of those ids, and (b) one short
///   empathetic sentence in Arabic (non-Islamic content).
/// * Any id not present in the candidates is rejected, the whole response
///   discarded, and the deterministic local ranking used instead.
/// * The model can therefore NEVER inject invented hadith/verses/adhkar.
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
                'arabic': c.arabic,
                'reference': c.reference,
                'grade': c.grade.name,
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
      final empathy = (data['empathy'] as String?)?.trim() ?? '';

      // SUBSET VALIDATION — the safety gate.
      final candidateIds = candidates.map((c) => c.id).toSet();
      if (ids.any((id) => !candidateIds.contains(id))) {
        logWarn('Remote AI returned unknown ids — response discarded');
        return null;
      }
      if (ids.isEmpty && candidates.isNotEmpty) return null;
      return RemoteRankResult(selectedIds: ids, empathyAr: empathy);
    } catch (e, st) {
      logWarn('Remote AI unavailable — using local ranking', e, st);
      return null;
    }
  }
}

/// Defensive gate for the ONE free-form string the LLM may return (review
/// S4). Replies carry a footer saying everything comes from verified sources
/// — so anything that *looks like* Quran/hadith text is dropped, and the
/// line is capped short. Deterministic template intros remain the default
/// whether remote AI works or not.
String sanitizeEmpathy(String raw) {
  var s = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (s.isEmpty) return '';
  const markers = [
    'ﷺ', '﴿', '﴾', 'قال رسول', 'قال النبي', 'رواه', 'عن أبي', 'عن عبد',
    'حديث', 'آية', 'ﷲ',
    // Quran attribution. Without these, 'قال الله تعالى ...' passed straight
    // through and was rendered under the verified-sources footer.
    'قال الله', 'قال تعالى', 'قال عز', 'يقول الله', 'يقول تعالى',
    'في القرآن', 'سورة', 'الآية', 'صدق الله',
  ];
  if (markers.any(s.contains)) return '';
  if (s.length > 120) s = s.substring(0, 120);
  return s;
}
