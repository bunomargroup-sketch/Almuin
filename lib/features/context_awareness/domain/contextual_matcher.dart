import '../../adhkar/domain/dhikr.dart';
import 'context_topic.dart';

/// One authentic dhikr chosen for a signal, with a templated reason.
class ContextSuggestion {
  const ContextSuggestion({
    required this.topic,
    required this.dhikr,
    required this.reasonAr,
  });

  final ContextTopic topic;
  final Dhikr dhikr;

  /// A fixed, app-authored phrase — never model-generated, never derived from
  /// a headline. It says *why now*, and nothing about any event.
  final String reasonAr;
}

/// Chooses a dhikr from the verified local corpus for a [ContextTopic].
///
/// Pure and deterministic: same corpus and same topic give the same answer,
/// which is what makes it testable without a device, a network, or a clock.
class ContextualDhikrMatcher {
  const ContextualDhikrMatcher();

  static const Map<ContextTopic,
          ({List<DhikrCategory> cats, List<String> tags, String reasonAr})>
      _map = {
    ContextTopic.rain: (
      cats: [DhikrCategory.rain],
      tags: ['rain'],
      reasonAr: 'عند نزول المطر',
    ),
    ContextTopic.thunderstorm: (
      cats: [DhikrCategory.rain, DhikrCategory.distress],
      tags: ['rain', 'fear', 'protection'],
      reasonAr: 'عند الرعد والمطر',
    ),
    ContextTopic.strongWind: (
      cats: [DhikrCategory.distress],
      tags: ['protection', 'fear'],
      reasonAr: 'عند اشتداد الريح',
    ),
    ContextTopic.extremeHeat: (
      cats: [DhikrCategory.distress],
      tags: ['protection', 'relief'],
      reasonAr: 'في شدّة الحر',
    ),
    ContextTopic.extremeCold: (
      cats: [DhikrCategory.distress],
      tags: ['protection', 'relief'],
      reasonAr: 'في شدّة البرد',
    ),
    // News-derived. Comfort only — these name nothing and blame nobody.
    ContextTopic.calamity: (
      cats: [DhikrCategory.distress],
      tags: ['sadness', 'distress', 'relief'],
      reasonAr: 'عند سماع ما يُحزن',
    ),
    ContextTopic.illness: (
      cats: [DhikrCategory.distress],
      tags: ['illness', 'healing', 'protection'],
      reasonAr: 'دعاء العافية',
    ),
    ContextTopic.hardship: (
      cats: [DhikrCategory.distress, DhikrCategory.istighfar],
      tags: ['worry', 'relief', 'stress'],
      reasonAr: 'عند الضيق',
    ),
    // Calendar.
    ContextTopic.friday: (
      cats: [DhikrCategory.salawat],
      tags: ['friday', 'salawat'],
      reasonAr: 'يوم الجمعة',
    ),
    ContextTopic.ramadan: (
      cats: [DhikrCategory.quran, DhikrCategory.istighfar],
      tags: ['ramadan', 'quran'],
      reasonAr: 'في شهر رمضان',
    ),
    ContextTopic.dhulHijjah: (
      cats: [DhikrCategory.tasbeeh],
      tags: ['tasbeeh'],
      reasonAr: 'في عشر ذي الحجة',
    ),
  };

  /// Returns a suggestion, or null when the app should stay silent.
  ///
  /// Null is returned when the topic is [ContextTopic.none], when its
  /// prescribed adhkar are not yet in the corpus
  /// ([ContextTopic.awaitingCorpus]), or when nothing in the corpus matches.
  /// Silence is always preferred over a loosely related substitute.
  ContextSuggestion? match(ContextTopic topic, List<Dhikr> corpus) {
    if (topic == ContextTopic.none || topic.awaitingCorpus) return null;
    final spec = _map[topic];
    if (spec == null) return null;

    final byCategory =
        corpus.where((d) => spec.cats.contains(d.category)).toList();
    final byTag = corpus
        .where((d) =>
            !spec.cats.contains(d.category) &&
            d.tags.any(spec.tags.contains))
        .toList();

    // Category is a stronger claim than a tag, so it is preferred outright
    // rather than blended into a score.
    final pool = byCategory.isNotEmpty ? byCategory : byTag;
    if (pool.isEmpty) return null;

    // Least-read first so repeated signals rotate through the pool instead of
    // showing the same dhikr every rainfall; id breaks ties deterministically.
    pool.sort((a, b) {
      final c = a.timesRead.compareTo(b.timesRead);
      return c != 0 ? c : a.id.compareTo(b.id);
    });

    return ContextSuggestion(
      topic: topic,
      dhikr: pool.first,
      reasonAr: spec.reasonAr,
    );
  }
}
