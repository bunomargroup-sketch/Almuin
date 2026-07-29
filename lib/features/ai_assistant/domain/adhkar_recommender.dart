import 'dart:math';

import '../../../core/utils/hijri_utils.dart';
import '../../adhkar/domain/dhikr.dart';
import 'situation_intent.dart';

/// One recommended piece of verified content (dhikr or verse).
class RecommendationItem {
  const RecommendationItem({
    required this.id,
    required this.arabic,
    required this.reference,
    required this.grade,
    this.noteAr = '',
    this.rewardAr = '',
    this.isVerse = false,
  });

  final String id;
  final String arabic;
  final String reference;
  final AuthenticityGrade grade;
  final String noteAr;
  final String rewardAr;
  final bool isVerse;

  factory RecommendationItem.fromDhikr(Dhikr d) => RecommendationItem(
        id: d.id,
        arabic: d.arabic,
        reference: d.references.map((r) => r.format()).join(' · '),
        grade: d.bestGrade,
        noteAr: d.meaningAr,
        rewardAr: d.rewardAr,
      );

  factory RecommendationItem.fromVerse(Verse v) => RecommendationItem(
        id: v.id,
        arabic: v.arabic,
        reference: v.reference,
        grade: AuthenticityGrade.quran,
        noteAr: v.tafsirBriefAr,
        isVerse: true,
      );
}

class RecommendationBundle {
  const RecommendationBundle({
    required this.intent,
    required this.items,
    required this.introAr,
  });

  final SituationIntent intent;
  final List<RecommendationItem> items;

  /// Empathetic, honest intro — templated, never claims fabricated facts.
  final String introAr;
}

/// Deterministic, fully offline recommender.
///
/// SAFETY INVARIANTS (tested in test/adhkar_recommender_test.dart):
/// 1. Only content present in the verified local DB can be returned.
/// 2. Weak (daif) items are excluded from unsolicited suggestions unless
///    [allowWeak] is explicitly ON — and they are always visibly marked.
/// 3. The intro line is picked from a fixed template per intent; numbers
///    (counts) come from the item list itself.
/// 4. When nothing matches, [introAr] must say so plainly.
class AdhkarRecommender {
  const AdhkarRecommender({this.allowWeak = false, this.maxItems = 5});

  final bool allowWeak;
  final int maxItems;

  /// intent → (adhkar categories, content tags) used for retrieval.
  static const Map<SituationIntent, ({List<DhikrCategory> cats, List<String> tags})> _map = {
    SituationIntent.anxiety: (
      cats: [DhikrCategory.distress, DhikrCategory.istighfar],
      tags: ['anxiety', 'relief'],
    ),
    SituationIntent.stress: (
      cats: [DhikrCategory.distress, DhikrCategory.istighfar],
      tags: ['stress', 'anxiety'],
    ),
    SituationIntent.worry: (
      cats: [DhikrCategory.distress],
      tags: ['worry', 'distress'],
    ),
    SituationIntent.fear: (
      cats: [DhikrCategory.distress],
      tags: ['fear', 'protection'],
    ),
    SituationIntent.sadness: (
      cats: [DhikrCategory.distress],
      tags: ['sadness', 'distress'],
    ),
    SituationIntent.insomnia: (
      cats: [DhikrCategory.sleep],
      tags: ['sleep', 'insomnia'],
    ),
    SituationIntent.travel: (
      cats: [DhikrCategory.travel],
      tags: ['travel'],
    ),
    SituationIntent.gratitude: (
      cats: [DhikrCategory.gratitude, DhikrCategory.tasbeeh],
      tags: ['gratitude'],
    ),
    SituationIntent.anger: (
      cats: [DhikrCategory.distress],
      tags: ['anger', 'patience'],
    ),
    SituationIntent.illness: (
      cats: [DhikrCategory.distress],
      tags: ['illness', 'healing'],
    ),
    SituationIntent.exam: (
      cats: [DhikrCategory.distress, DhikrCategory.tasbeeh],
      tags: ['exam', 'ease', 'focus'],
    ),
    SituationIntent.financialHardship: (
      cats: [DhikrCategory.istighfar, DhikrCategory.distress],
      tags: ['rizq', 'relief'],
    ),
    SituationIntent.rain: (
      cats: [DhikrCategory.rain],
      tags: ['rain'],
    ),
    SituationIntent.general: (
      cats: [DhikrCategory.tasbeeh, DhikrCategory.istighfar, DhikrCategory.salawat],
      tags: ['general'],
    ),
  };

  RecommendationBundle recommend({
    required SituationIntent intent,
    required List<Dhikr> adhkar,
    required List<Verse> verses,
    HijriInfo? hijri,
    ContentTime? nowWindow,
  }) {
    final spec = _map[intent] ?? _map[SituationIntent.general]!;
    final scored = <double, RecommendationItem>{};

    double scoreOf(List<String> itemTags, DhikrCategory cat, AuthenticityGrade g) {
      var score = 0.0;
      if (spec.cats.contains(cat)) score += 2.0;
      for (final t in itemTags) {
        if (spec.tags.contains(t)) score += 3.0;
        if (t == 'general') score += 0.5;
      }
      score += switch (g) {
        AuthenticityGrade.quran => 1.5,
        AuthenticityGrade.sahih => 1.0,
        AuthenticityGrade.hasan => 0.6,
        AuthenticityGrade.daif => -10, // filtered unless allowWeak
        AuthenticityGrade.custom => -1,
      };
      if (nowWindow != null && nowWindow != ContentTime.anytime) {
        // Slight time-of-day alignment bonus.
        if ((nowWindow == ContentTime.morning && cat == DhikrCategory.morning) ||
            (nowWindow == ContentTime.evening && cat == DhikrCategory.evening) ||
            (nowWindow == ContentTime.night && cat == DhikrCategory.sleep)) {
          score += 0.5;
        }
      }
      // Seasonal lifts.
      if (hijri != null) {
        if (hijri.isRamadan && cat == DhikrCategory.quran) score += 1.5;
        if (hijri.isFriday && cat == DhikrCategory.salawat) score += 1.5;
      }
      return score;
    }

    for (final d in adhkar) {
      if (d.bestGrade == AuthenticityGrade.daif && !allowWeak) continue;
      if (d.bestGrade == AuthenticityGrade.custom) continue;
      final s = scoreOf(d.tags, d.category, d.bestGrade);
      if (s >= 2.0) scored[s + _jitter(d.id)] = RecommendationItem.fromDhikr(d);
    }
    for (final v in verses) {
      final s = scoreOf(v.tags, DhikrCategory.quran, AuthenticityGrade.quran);
      if (s >= 2.0) {
        // Verses need a tag hit (or explicit Quran category request) to be
        // sure they address the situation.
        final tagHit = v.tags.any(spec.tags.contains);
        if (tagHit || intent == SituationIntent.general) {
          scored[s + _jitter(v.id)] = RecommendationItem.fromVerse(v);
        }
      }
    }

    final ranked = scored.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    final items = ranked.map((e) => e.value).take(maxItems).toList();

    return RecommendationBundle(
      intent: intent,
      items: items,
      introAr: _introFor(intent, items.length),
    );
  }

  /// Deterministic tie-breaker so equal scores have a stable order.
  double _jitter(String id) =>
      (id.codeUnits.fold<int>(0, (a, b) => (a + b) % 997) / 997) * 0.001;

  static String _introFor(SituationIntent intent, int count) {
    if (count == 0) {
      return 'لم أجد في قاعدتنا الموثّقة ذكرًا خاصًا بهذه الحالة بالضبط، '
          'ولن أختلق شيئًا. أنصحك بالإكثار من الاستغفار و«سبحان الله وبحمده» '
          'فهما صحيحان نافعان في كل حال.';
    }
    return switch (intent) {
      SituationIntent.anxiety =>
        'أسأل الله أن يشرح صدرك ويهدّئ قلبك. هذه أذكار وآيات موثّقة يُستحب ذكرها عند القلق:',
      SituationIntent.stress =>
        'جعل الله لك من كل ضيق مخرجًا. من الذكر الموثّق عند التوتر والثقل:',
      SituationIntent.worry =>
        'فرّج الله همّك. من الدعاء الثابت عن النبي ﷺ عند الهم والكرب:',
      SituationIntent.fear =>
        'ثبّت الله قلبك. من التعوذات الموثّقة عند الخوف:',
      SituationIntent.sadness =>
        'أبدلك الله بحزنك فرحًا. من الذكر الثابت للحزن:',
      SituationIntent.insomnia =>
        'أراح الله بدنك وقرّ عينك. هذه أذكار النوم الموثّقة عن النبي ﷺ:',
      SituationIntent.travel =>
        'كتب الله لك السلامة في سفرك. من أدعية السفر الثابتة:',
      SituationIntent.gratitude =>
        'زادك الله من فضله. شكر النعمة عبادة — من الذكر الموثّق للحمد والشكر:',
      SituationIntent.anger =>
        'أذهب الله غيظ قلبك. من الهدي النبوي الثابت عند الغضب:',
      SituationIntent.illness =>
        'شفى الله مريضكم شفاءً لا يغادر سقمًا. من الدعاء الثابت للمريض ولمن ألمّ به مرض:',
      SituationIntent.exam =>
        'وفّقك الله ويسّر أمرك. من الذكر الموثّق عند الحاجة إلى التيسير:',
      SituationIntent.financialHardship =>
        'رزقك الله من حيث لا تحتسب. من الذكر الثابت للكرب والرزق:',
      SituationIntent.rain =>
        'اللهم صيبًا نافعًا. من سنة المطر الموثّقة:',
      SituationIntent.general =>
        'أذكار موثّقة مختارة لك — لسانك رطب بذكر الله:',
    };
  }
}

/// Convenience: map a raw clock time to a content window.
ContentTime contentWindowOf(DateTime t) {
  final h = t.hour;
  if (h >= 3 && h < 12) return ContentTime.morning;
  if (h >= 12 && h < 18) return ContentTime.anytime;
  if (h >= 18 && h < 21) return ContentTime.evening;
  return ContentTime.night;
}

/// Fisher-independent: expose so the edge function mirrors the same policy.
List<String> allowedTopLevelSources() =>
    const ['quran', 'bukhari', 'muslim', 'hisnul_muslim'];

/// Small math sanity (kept for future weighted sampling).
double clamp01(double v) => min(1, max(0, v));
